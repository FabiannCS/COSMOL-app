"""
Servicio de lógica de negocio para identidad, onboarding y autenticación de socios COSMOL R.L.
"""
import json
import logging
import secrets
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
import redis.asyncio as aioredis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import settings
from app.core.exceptions import (
    AppException,
    BadRequestException,
    ForbiddenException,
    NotFoundException,
    UnauthorizedException,
)
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    get_password_hash,
    verify_password,
)
from app.db.models import Dispositivo, Suministro, Usuario
from app.integrations.cosmol_client import cosmol_client, CosmolLegacyClient
from app.integrations.sms_client import sms_client
from app.integrations.whatsapp_client import whatsapp_client
from app.schemas.suministro import SuministroResponse
from app.schemas.usuario import TokenResponse

logger = logging.getLogger(__name__)

# Base de datos simulada en memoria para usuarios registrados (modo fallback testing)
USUARIOS_REGISTRADOS_DB: Dict[str, Dict[str, Any]] = {}


def normalizar_telefono(t: str) -> str:
    """Normaliza números bolivianos a formato estándar internacional (+591XXXXXXXX)."""
    clean = str(t or "").strip().replace(" ", "").replace("-", "")
    if len(clean) == 8 and clean.isdigit():
        return f"+591{clean}"
    if clean.startswith("+"):
        return clean
    return f"+{clean}" if clean else ""


class ServicioAutenticacion:
    """
    Controlador de negocio para el flujo completo de autenticación y seguridad.
    Integrado con PostgreSQL (AsyncSession), Redis, API Comercial de COSMOL y Gateways de Mensajería.
    """

    def __init__(
        self,
        redis_client: aioredis.Redis,
        db: Optional[AsyncSession] = None,
        client_legado: Optional[CosmolLegacyClient] = None
    ):
        self.redis = redis_client
        self.db = db
        self.cosmol_client = client_legado or cosmol_client

    # --------------------------------------------------------------------------
    # PASO 1: VERIFICACIÓN INICIAL EN SISTEMA OFICIAL DE COSMOL
    # --------------------------------------------------------------------------
    async def verificar_primer_acceso(self, cod_socio: str, ci: str) -> Dict[str, Any]:
        """
        Valida que el socio exista en el sistema comercial oficial de COSMOL
        mediante su Código de Socio y Carnet de Identidad (NROCIONIT).
        Si el socio ya cuenta con PIN registrado, esta acción habilita la
        recuperación/desbloqueo de su cuenta mediante OTP.
        """
        cod_socio = cod_socio.strip()
        ci = ci.strip()

        # 1. Comprobar si es un primer ingreso o una recuperación/desbloqueo de PIN
        es_recuperacion = False
        if self.db:
            stmt = select(Suministro).where(
                Suministro.cod_socio == cod_socio,
                Suministro.rol == "TITULAR"
            )
            res = await self.db.execute(stmt)
            if res.scalars().first():
                es_recuperacion = True
        elif cod_socio in USUARIOS_REGISTRADOS_DB:
            es_recuperacion = True

        # 2. Validar contra el sistema comercial oficial de COSMOL (vía POST /socios/validar)
        datos_socio = await self.cosmol_client.validar_credenciales_socio(cod_socio, ci)
        if not datos_socio:
            logger.warning(f"Validación de credenciales rechazada para socio '{cod_socio}' con CI provisto")
            raise UnauthorizedException(
                message="El código de socio o carnet de identidad no coinciden con los registros oficiales de COSMOL.",
                error_code="SOCIO_NOT_FOUND"
            )

        nombre_oficial = str(datos_socio.get("NOMBRE") or datos_socio.get("nombre") or "Socio COSMOL").strip()

        logger.info(f"Socio verificado exitosamente en COSMOL: {cod_socio} ({nombre_oficial}) [es_recuperacion={es_recuperacion}]")
        mensaje = (
            "Socio verificado correctamente. Proceda a confirmar su celular para restablecer su PIN y desbloquear su cuenta."
            if es_recuperacion else
            "Socio verificado correctamente. Proceda a asociar su teléfono celular."
        )
        return {
            "cod_socio": cod_socio,
            "nombre_titular": nombre_oficial,
            "es_recuperacion": es_recuperacion,
            "mensaje": mensaje
        }

    # --------------------------------------------------------------------------
    # PASO 2: DESPACHO DE CÓDIGO OTP (WHATSAPP / SMS)
    # --------------------------------------------------------------------------
    async def solicitar_otp(self, cod_socio: str, telefono: str, canal: str) -> Dict[str, Any]:
        """
        Genera un código OTP de 6 dígitos con TTL de 5 minutos, lo persiste en Redis
        y despacha la notificación a través de WhatsApp Cloud API o SMS.
        """
        telefono = normalizar_telefono(telefono)

        # Rate limit preventivo: máximo 3 solicitudes por teléfono en 1 hora
        rate_key = f"rate_otp:{telefono}"
        solicitudes = await self.redis.incr(rate_key)
        if solicitudes == 1:
            await self.redis.expire(rate_key, 3600)  # 1 hora
        elif solicitudes > 3:
            ttl_rate = await self.redis.ttl(rate_key)
            raise ForbiddenException(
                message=f"Ha superado el límite de 3 solicitudes de OTP por hora. Intente en {max(1, ttl_rate // 60)} minutos.",
                error_code="OTP_RATE_LIMIT_EXCEEDED"
            )

        # Generar código criptográficamente seguro de 6 dígitos
        codigo_otp = f"{secrets.randbelow(900000) + 100000}"

        # Guardar en Redis con TTL de 300 segundos (5 minutos)
        otp_key = f"otp:{telefono}"
        otp_data = f"{codigo_otp}:{cod_socio}"
        await self.redis.set(otp_key, otp_data, ex=300)

        # Enmascarar celular para respuesta segura al frontend (+591 7***9384)
        tel_len = len(telefono)
        tel_enmascarado = f"{telefono[:4]} {'*' * (tel_len - 8)} {telefono[-4:]}" if tel_len >= 8 else telefono

        # Despacho por canal oficial (Meta WhatsApp Cloud API o SMS Gateway)
        canal_upper = canal.upper()
        if canal_upper == "WHATSAPP":
            await whatsapp_client.enviar_otp(telefono, codigo_otp)
        elif canal_upper == "SMS":
            await sms_client.enviar_sms_otp(telefono, codigo_otp)

        logger.info(f"[DESPACHO OTP] Canal: {canal_upper} | Teléfono: {telefono} | Código: {codigo_otp} | Expira: 300s")

        return {
            "mensaje": f"Código de seguridad enviado exitosamente vía {canal}.",
            "canal": canal,
            "telefono_enmascarado": tel_enmascarado,
            "ttl_segundos": 300,
            # En entorno dev exponemos el código para facilitar pruebas en Swagger / Postman
            "debug_codigo_otp": codigo_otp if settings.ENVIRONMENT == "development" else None
        }

    # --------------------------------------------------------------------------
    # PASO 3: VALIDACIÓN DEL CÓDIGO OTP
    # --------------------------------------------------------------------------
    async def verificar_otp(self, telefono: str, codigo: str) -> Dict[str, Any]:
        """
        Valida el código de 6 dígitos contra Redis. Al coincidir, invalida el OTP (un solo uso)
        y emite un token de paso temporal para autorizar la creación del PIN.
        """
        telefono = normalizar_telefono(telefono)
        otp_key = f"otp:{telefono}"
        valor_almacenado = await self.redis.get(otp_key)

        if not valor_almacenado:
            raise BadRequestException(
                message="El código de seguridad ha expirado o nunca fue solicitado. Solicite uno nuevo.",
                error_code="OTP_EXPIRED"
            )

        codigo_esperado, cod_socio = valor_almacenado.split(":")

        if codigo.strip() != codigo_esperado:
            # Control de reintentos de código incorrecto
            fallos_key = f"otp_fallos:{telefono}"
            intentos = await self.redis.incr(fallos_key)
            if intentos >= 3:
                await self.redis.delete(otp_key)
                await self.redis.delete(fallos_key)
                raise ForbiddenException(
                    message="Demasiados intentos erróneos. El código ha sido invalidado por seguridad.",
                    error_code="OTP_MAX_ATTEMPTS"
                )
            raise BadRequestException(
                message=f"Código de seguridad incorrecto. Intento {intentos} de 3.",
                error_code="OTP_INVALID"
            )

        # Código correcto: eliminar de Redis para evitar reuso
        await self.redis.delete(otp_key)
        await self.redis.delete(f"otp_fallos:{telefono}")

        # Generar un token temporal criptográfico con vigencia de 10 minutos para el Paso 4
        token_otp_valido = secrets.token_urlsafe(32)
        token_key = f"token_otp_valido:{token_otp_valido}"
        await self.redis.set(token_key, f"{telefono}:{cod_socio}", ex=600)

        logger.info(f"OTP verificado con éxito para celular {telefono}, socio {cod_socio}")
        return {
            "mensaje": "Número de teléfono verificado exitosamente. Proceda a crear su PIN personal.",
            "token_otp_valido": token_otp_valido,
            "cod_socio": cod_socio
        }

    # --------------------------------------------------------------------------
    # PASO 4: CREACIÓN DE PIN Y CIERRE DE ONBOARDING
    # --------------------------------------------------------------------------
    async def establecer_pin(
        self,
        telefono: str,
        token_otp_valido: str,
        nuevo_pin: str
    ) -> Dict[str, Any]:
        """
        Registra el nuevo PIN hasheado (bcrypt). A partir de este momento,
        la CI queda invalidada como contraseña para siempre.
        Desbloquea inmediatamente la cuenta si estaba bloqueada por intentos fallidos.
        """
        token_key = f"token_otp_valido:{token_otp_valido}"
        valor_token = await self.redis.get(token_key)

        if not valor_token:
            raise UnauthorizedException(
                message="El pase de verificación OTP ha expirado o no es válido. Repita el proceso de verificación.",
                error_code="INVALID_OTP_TOKEN"
            )

        tel_almacenado, cod_socio = valor_token.split(":")
        telefono = normalizar_telefono(telefono)
        tel_almacenado = normalizar_telefono(tel_almacenado)

        if tel_almacenado != telefono:
            logger.warning(f"Discrepancia de teléfono en establecer-pin: almacenado='{tel_almacenado}' vs enviado='{telefono}'")
            raise UnauthorizedException(
                message="El teléfono no corresponde al token de validación.",
                error_code="PHONE_MISMATCH"
            )

        # Generar hash seguro con bcrypt
        password_hash = get_password_hash(nuevo_pin)

        # Persistir en PostgreSQL si se dispone de sesión
        user_id_str = str(uuid.uuid4())
        suministro_id = uuid.uuid4()

        if self.db:
            stmt_user = select(Usuario).where(Usuario.telefono == telefono)
            res_user = await self.db.execute(stmt_user)
            usuario_db = res_user.scalars().first()
            if not usuario_db:
                usuario_db = Usuario(
                    telefono=telefono,
                    password_hash=password_hash,
                    esta_activo=True,
                    intentos_fallidos=0
                )
                self.db.add(usuario_db)
                await self.db.flush()
            else:
                usuario_db.password_hash = password_hash
                usuario_db.esta_activo = True
                usuario_db.intentos_fallidos = 0
                usuario_db.bloqueado_hasta = None

            user_id_str = str(usuario_db.id)

            stmt_sum = select(Suministro).where(
                Suministro.usuario_id == usuario_db.id,
                Suministro.cod_socio == cod_socio
            )
            res_sum = await self.db.execute(stmt_sum)
            suministro_db = res_sum.scalars().first()
            if not suministro_db:
                suministro_db = Suministro(
                    usuario_id=usuario_db.id,
                    cod_socio=cod_socio,
                    alias=f"Socio: {cod_socio}",
                    rol="TITULAR",
                    es_suministro_principal=True
                )
                self.db.add(suministro_db)
                await self.db.flush()
            suministro_id = suministro_db.id
            await self.db.commit()

        # Mantener réplica en memoria para pruebas y compatibilidad
        datos_socio = await self.cosmol_client.obtener_datos_socio(cod_socio) or {}
        nombre_socio = datos_socio.get("NOMBRE", "Socio COSMOL")
        USUARIOS_REGISTRADOS_DB[cod_socio] = {
            "user_id": user_id_str,
            "telefono": telefono,
            "password_hash": password_hash,
            "nombre": nombre_socio,
            "suministros": [
                {
                    "id": suministro_id,
                    "cod_socio": cod_socio,
                    "alias": f"Socio: {cod_socio}",
                    "rol": "TITULAR",
                    "es_suministro_principal": True
                }
            ]
        }

        # Consumir y borrar el token temporal
        await self.redis.delete(token_key)

        # Desbloquear inmediatamente la cuenta en Redis si estaba bloqueada
        await self.redis.delete(f"bloqueado:{cod_socio}")
        await self.redis.delete(f"intentos_fallidos:{cod_socio}")

        logger.info(f"PIN establecido y cuenta asegurada para socio '{cod_socio}'. CI invalidada como credencial.")
        return {
            "mensaje": "¡Registro completado exitosamente! Ahora puede iniciar sesión con su Código de Socio y su PIN personal.",
            "cod_socio": cod_socio
        }

    # --------------------------------------------------------------------------
    # LOGIN DIARIO CON BLOQUEO PROGRESIVO POR INTENTOS
    # --------------------------------------------------------------------------
    async def autenticar_socio(
        self,
        cod_socio: str,
        pin_password: str,
        device_id: str,
        modelo_dispositivo: Optional[str] = None
    ) -> TokenResponse:
        """
        Autentica al socio con su cod_socio + PIN.
        Aplica la política de bloqueo progresivo tras 3 intentos fallidos (1m -> 5m -> 15m -> 30m -> 1h).
        Controla sesión única por hardware (device_id) y emite tokens JWT.
        """
        cod_socio = cod_socio.strip()

        # 1. Verificar si la cuenta está bloqueada en Redis
        bloqueo_key = f"bloqueado:{cod_socio}"
        tiempo_restante = await self.redis.ttl(bloqueo_key)
        if tiempo_restante > 0:
            minutos = max(1, tiempo_restante // 60)
            logger.warning(f"Intento de acceso a cuenta bloqueada: '{cod_socio}' (TTL restante: {tiempo_restante}s)")
            raise ForbiddenException(
                message=f"Su cuenta se encuentra bloqueada por exceso de intentos fallidos. Intente nuevamente en {minutos} minuto(s).",
                error_code="ACCOUNT_LOCKED",
                details={"bloqueado_segundos_restantes": tiempo_restante}
            )

        # 2. Buscar usuario registrado en PostgreSQL o memoria
        usuario_db = None
        suministro_db = None
        password_hash = None
        user_id = None
        nombre_socio = "SOCIO COSMOL"
        suministros_lista: List[SuministroResponse] = []

        if self.db:
            # Autenticar estrictamente con el suministro TITULAR oficial
            stmt_sum = (
                select(Suministro)
                .where(
                    Suministro.cod_socio == cod_socio,
                    Suministro.rol == "TITULAR"
                )
            )
            res_sum = await self.db.execute(stmt_sum)
            suministro_db = res_sum.scalars().first()

            if not suministro_db:
                # Verificar si el código solo está vinculado como consulta/inquilino
                stmt_inq = select(Suministro).where(Suministro.cod_socio == cod_socio)
                res_inq = await self.db.execute(stmt_inq)
                if res_inq.scalars().first():
                    raise UnauthorizedException(
                        message="El código provisto corresponde a un suministro secundario o de inquilino. Inicie sesión con su código de socio titular.",
                        error_code="LOGIN_TITULAR_REQUIRED"
                    )

            if suministro_db:
                stmt_user = (
                    select(Usuario)
                    .options(selectinload(Usuario.suministros), selectinload(Usuario.dispositivos))
                    .where(Usuario.id == suministro_db.usuario_id)
                )
                res_user = await self.db.execute(stmt_user)
                usuario_db = res_user.scalars().first()

                if not usuario_db or not usuario_db.esta_activo:
                    raise UnauthorizedException(
                        message="La cuenta de socio se encuentra inactiva o deshabilitada.",
                        error_code="ACCOUNT_DISABLED"
                    )

                password_hash = usuario_db.password_hash
                user_id = str(usuario_db.id)
                nombre_socio = "Socio COSMOL"
                datos_socio_real = await self.cosmol_client.obtener_datos_socio(cod_socio)
                if datos_socio_real and datos_socio_real.get("NOMBRE"):
                    nombre_socio = datos_socio_real["NOMBRE"]
                suministros_lista = []
                for s in usuario_db.suministros:
                    nom_s = None
                    try:
                        datos_s = await self.cosmol_client.obtener_datos_socio(s.cod_socio)
                        if datos_s:
                            nom_s = datos_s.get("NOMBRE")
                    except Exception:
                        nom_s = None
                    suministros_lista.append(
                        SuministroResponse(
                            id=s.id,
                            cod_socio=s.cod_socio,
                            alias=s.alias,
                            nombre=nom_s,
                            rol=s.rol,
                            es_suministro_principal=s.es_suministro_principal
                        )
                    )

        if not password_hash:
            usuario_mem = USUARIOS_REGISTRADOS_DB.get(cod_socio)
            if not usuario_mem:
                raise UnauthorizedException(
                    message="El socio no tiene un PIN configurado. Realice el proceso de primer ingreso para activar su cuenta.",
                    error_code="ONBOARDING_REQUIRED"
                )
            password_hash = usuario_mem["password_hash"]
            user_id = usuario_mem["user_id"]
            nombre_socio = usuario_mem.get("nombre", "SOCIO COSMOL")
            suministros_lista = []
            for s in usuario_mem["suministros"]:
                nom_s = None
                try:
                    datos_s = await self.cosmol_client.obtener_datos_socio(s["cod_socio"])
                    if datos_s:
                        nom_s = datos_s.get("NOMBRE")
                except Exception:
                    nom_s = None
                suministros_lista.append(
                    SuministroResponse(
                        id=s["id"],
                        cod_socio=s["cod_socio"],
                        alias=s["alias"],
                        nombre=nom_s,
                        rol=s["rol"],
                        es_suministro_principal=s["es_suministro_principal"]
                    )
                )

        fallos_key = f"intentos_fallidos:{cod_socio}"

        # 3. Validar PIN con bcrypt
        es_valido = verify_password(pin_password, password_hash)

        if not es_valido:
            intentos = await self.redis.incr(fallos_key)
            logger.warning(f"Contraseña incorrecta para socio '{cod_socio}'. Fallo #{intentos}")

            if intentos >= 3:
                escalas = {3: 60, 4: 300, 5: 900}
                bloqueo_segundos = escalas.get(intentos, 3600)

                await self.redis.set(bloqueo_key, "1", ex=bloqueo_segundos)
                minutos = bloqueo_segundos // 60

                raise ForbiddenException(
                    message=f"Ha alcanzado 3 intentos fallidos consecutivos. Su cuenta ha sido bloqueada temporalmente por {minutos} minuto(s).",
                    error_code="ACCOUNT_LOCKED",
                    details={"bloqueado_segundos_restantes": bloqueo_segundos}
                )

            intentos_restantes = 3 - intentos
            raise UnauthorizedException(
                message=f"PIN o contraseña incorrecta. Le quedan {intentos_restantes} intento(s) antes del bloqueo.",
                error_code="INVALID_CREDENTIALS"
            )

        # 4. Login exitoso: limpiar contadores de fallos y bloqueos
        await self.redis.delete(fallos_key)
        await self.redis.delete(bloqueo_key)

        # 5. Persistir o actualizar Dispositivo si hay conexión DB
        if self.db and usuario_db:
            stmt_disp = select(Dispositivo).where(
                Dispositivo.usuario_id == usuario_db.id,
                Dispositivo.device_id == device_id
            )
            res_disp = await self.db.execute(stmt_disp)
            disp_existente = res_disp.scalars().first()
            if disp_existente:
                if modelo_dispositivo:
                    disp_existente.modelo_dispositivo = modelo_dispositivo
                disp_existente.ultimo_acceso = datetime.now(timezone.utc)
            else:
                disp_nuevo = Dispositivo(
                    usuario_id=usuario_db.id,
                    device_id=device_id,
                    modelo_dispositivo=modelo_dispositivo,
                    ultimo_acceso=datetime.now(timezone.utc)
                )
                self.db.add(disp_nuevo)
            await self.db.commit()

        # 6. Sesión única por hardware (device_id) en Redis
        sesion_dispositivo_key = f"sesion_activa:{user_id}"
        await self.redis.set(sesion_dispositivo_key, device_id)

        # 7. Emitir JWT Access Token y Refresh Token
        extra_claims = {
            "cod_socio": cod_socio,
            "device_id": device_id,
            "nombre": nombre_socio
        }

        access_token = create_access_token(subject=user_id, extra_claims=extra_claims)
        refresh_token = create_refresh_token(subject=user_id)

        logger.info(f"Socio '{cod_socio}' autenticado exitosamente desde dispositivo '{device_id}' ({modelo_dispositivo})")
        return TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer",
            suministros=suministros_lista
        )

    # --------------------------------------------------------------------------
    # RENOVACIÓN SILENCIOSA DE TOKEN
    # --------------------------------------------------------------------------
    async def renovar_token(self, refresh_token: str, device_id: str) -> TokenResponse:
        """
        Valida el refresh token y emite un nuevo access token si el device_id sigue vigente.
        """
        try:
            payload = decode_token(refresh_token)
        except Exception:
            raise UnauthorizedException(
                message="El token de renovación es inválido o ha expirado. Inicie sesión nuevamente.",
                error_code="INVALID_REFRESH_TOKEN"
            )

        if payload.get("type") != "refresh":
            raise UnauthorizedException(
                message="Tipo de token inválido.",
                error_code="INVALID_TOKEN_TYPE"
            )

        user_id = payload.get("sub")
        sesion_key = f"sesion_activa:{user_id}"
        device_activo = await self.redis.get(sesion_key)

        # Si el usuario inició sesión en otro dispositivo, revocar esta sesión
        if device_activo and device_activo != device_id:
            raise UnauthorizedException(
                message="Se ha iniciado sesión en otro dispositivo. Su sesión en este equipo ha sido cerrada.",
                error_code="SESSION_REVOKED_NEW_DEVICE"
            )

        # Recuperar suministro principal y lista de suministros del usuario
        cod_socio = ""
        nombre_socio = ""
        suministros_lista: List[SuministroResponse] = []

        if self.db:
            try:
                u_uuid = uuid.UUID(str(user_id))
                stmt = (
                    select(Suministro)
                    .where(Suministro.usuario_id == u_uuid)
                    .order_by(Suministro.es_suministro_principal.desc(), Suministro.created_at.asc())
                )
                res = await self.db.execute(stmt)
                suministros_db = res.scalars().all()
                if suministros_db:
                    cod_socio = suministros_db[0].cod_socio
                    for s in suministros_db:
                        nom_s = None
                        try:
                            datos_s = await self.cosmol_client.obtener_datos_socio(s.cod_socio)
                            if datos_s:
                                nom_s = datos_s.get("NOMBRE")
                        except Exception:
                            nom_s = None
                        if s.es_suministro_principal and nom_s:
                            nombre_socio = nom_s
                        suministros_lista.append(
                            SuministroResponse(
                                id=s.id,
                                cod_socio=s.cod_socio,
                                alias=s.alias,
                                nombre=nom_s,
                                rol=s.rol,
                                es_suministro_principal=s.es_suministro_principal
                            )
                        )
            except Exception as e:
                logger.warning(f"No se pudieron cargar suministros en renovación de token: {e}")

        # Emitir nuevo access token con claims completos
        extra_claims = {
            "device_id": device_id,
            "cod_socio": cod_socio,
            "nombre": nombre_socio
        }
        nuevo_access_token = create_access_token(
            subject=user_id,
            extra_claims=extra_claims
        )

        return TokenResponse(
            access_token=nuevo_access_token,
            refresh_token=refresh_token,
            token_type="bearer",
            suministros=suministros_lista
        )

    # --------------------------------------------------------------------------
    # CIERRE DE SESIÓN LIMPIO
    # --------------------------------------------------------------------------
    async def cerrar_sesion(self, user_id: str, device_id: Optional[str] = None) -> Dict[str, Any]:
        """
        Revoca la sesión activa en Redis asociada al usuario y hardware.
        """
        sesion_key = f"sesion_activa:{user_id}"
        await self.redis.delete(sesion_key)
        logger.info(f"Sesión cerrada en servidor para usuario {user_id} (dispositivo: {device_id})")
        return {"mensaje": "Sesión cerrada exitosamente en el servidor.", "status": "ok"}

    # --------------------------------------------------------------------------
    # FLUJO SEGURO DE RECUPERACIÓN DE CONTRASEÑA / PIN (ZERO-TRUST PHONE BINDING)
    # --------------------------------------------------------------------------
    async def validar_titular_recuperacion(self, cod_socio: str, ci: str) -> Dict[str, Any]:
        """
        Paso 1: Valida titularidad contra Informix y recupera el teléfono
        previamente registrado del socio en la base de datos (PostgreSQL).
        El usuario NUNCA ingresa el celular en el formulario (Anti-Hijacking).
        """
        cod_socio = str(cod_socio).strip()
        ci = str(ci).strip()

        # 1. Validar contra el sistema comercial oficial de COSMOL
        datos_socio = await self.cosmol_client.validar_credenciales_socio(cod_socio, ci)
        if not datos_socio:
            logger.warning(f"[RECUPERACION] Credenciales inválidas para socio '{cod_socio}' con CI provista")
            raise UnauthorizedException(
                message="El código de socio o carnet de identidad no coinciden con los registros oficiales de COSMOL.",
                error_code="SOCIO_NOT_FOUND"
            )

        nombre_oficial = str(datos_socio.get("NOMBRE") or datos_socio.get("nombre") or "Socio COSMOL").strip()

        # 2. Buscar usuario TITULAR registrado en PostgreSQL o memoria
        usuario_db = None
        telefono = None
        user_id_str = None

        if self.db:
            stmt = (
                select(Usuario)
                .join(Suministro, Suministro.usuario_id == Usuario.id)
                .where(
                    Suministro.cod_socio == cod_socio,
                    Suministro.rol == "TITULAR"
                )
            )
            res = await self.db.execute(stmt)
            usuario_db = res.scalars().first()
            if usuario_db:
                telefono = usuario_db.telefono
                user_id_str = str(usuario_db.id)
                if not usuario_db.esta_activo:
                    raise UnauthorizedException(
                        message="La cuenta de socio se encuentra inactiva o dada de baja.",
                        error_code="ACCOUNT_DISABLED"
                    )

        if not usuario_db and cod_socio in USUARIOS_REGISTRADOS_DB:
            mem = USUARIOS_REGISTRADOS_DB[cod_socio]
            telefono = mem.get("telefono")
            user_id_str = str(mem.get("user_id", uuid.uuid4()))

        if not telefono:
            logger.warning(f"[RECUPERACION] Socio '{cod_socio}' validado en Informix pero sin cuenta registrada en app")
            raise NotFoundException(
                message="Este socio no posee una cuenta registrada en la aplicación. Debe completar su registro inicial (Onboarding).",
                error_code="ACCOUNT_NOT_REGISTERED"
            )

        # 3. Enmascarar celular para respuesta (+591 7*** **384)
        tel_len = len(telefono)
        if tel_len >= 8:
            tel_enmascarado = f"{telefono[:4]} {'*' * (tel_len - 8)} {telefono[-3:]}"
        else:
            tel_enmascarado = telefono

        # 4. Crear sesión temporal de recuperación en Redis (TTL: 5 min / 300 s)
        session_id = f"rec_{uuid.uuid4()}"
        sesion_data = {
            "user_id": user_id_str,
            "telefono": telefono,
            "cod_socio": cod_socio,
            "nombre_titular": nombre_oficial
        }
        await self.redis.set(f"recuperacion_sesion:{session_id}", json.dumps(sesion_data), ex=300)

        logger.info(f"[RECUPERACION] Sesión iniciada: {session_id} para socio {cod_socio} ({tel_enmascarado})")
        return {
            "session_id": session_id,
            "cod_socio": cod_socio,
            "nombre_titular": nombre_oficial,
            "telefono_enmascarado": tel_enmascarado,
            "mensaje": "Titular validado correctamente. Seleccione el canal para recibir su código de seguridad."
        }

    async def solicitar_otp_recuperacion(self, session_id: str, canal: str = "WHATSAPP") -> Dict[str, Any]:
        """
        Paso 2: Genera un OTP de 6 dígitos y lo despacha estrictamente al celular
        registrado del socio (obtenido de la sesión de Redis).
        """
        session_id = str(session_id).strip()
        canal_upper = str(canal or "WHATSAPP").strip().upper()

        sesion_raw = await self.redis.get(f"recuperacion_sesion:{session_id}")
        if not sesion_raw:
            raise BadRequestException(
                message="La sesión de recuperación ha expirado o es inválida. Debe reiniciar el proceso.",
                error_code="RECOVERY_SESSION_EXPIRED"
            )

        sesion = json.loads(sesion_raw)
        telefono = sesion["telefono"]
        cod_socio = sesion["cod_socio"]

        # Control de tasa (Rate Limiting): Máximo 3 solicitudes por hora por número
        rate_key = f"rate_otp_recuperacion:{telefono}"
        solicitudes = await self.redis.incr(rate_key)
        if solicitudes == 1:
            await self.redis.expire(rate_key, 3600)
        if solicitudes > settings.OTP_MAX_REQUESTS_PER_HOUR:
            ttl_rate = await self.redis.ttl(rate_key)
            minutos = max(1, ttl_rate // 60)
            logger.warning(f"[RECUPERACION] Rate limit superado para teléfono: {telefono}")
            raise ForbiddenException(
                message=f"Ha superado el límite de {settings.OTP_MAX_REQUESTS_PER_HOUR} solicitudes de código por hora. Intente en {minutos} minutos.",
                error_code="OTP_RATE_LIMIT_EXCEEDED"
            )

        # Generar código criptográfico de 6 dígitos
        codigo_otp = "".join([str(secrets.randbelow(10)) for _ in range(6)])

        # Guardar OTP con TTL de 300 segundos (5 minutos)
        await self.redis.set(f"otp_recuperacion:{session_id}", codigo_otp, ex=300)
        await self.redis.delete(f"otp_recuperacion_fallos:{session_id}")

        # Enmascarar celular
        tel_len = len(telefono)
        tel_enmascarado = f"{telefono[:4]} {'*' * (tel_len - 8)} {telefono[-3:]}" if tel_len >= 8 else telefono

        # Despachar por canal
        if canal_upper == "WHATSAPP":
            await whatsapp_client.enviar_otp(telefono, codigo_otp)
        elif canal_upper == "SMS":
            await sms_client.enviar_sms_otp(telefono, codigo_otp)

        logger.info(f"[RECUPERACION] OTP despachado para socio {cod_socio} por {canal_upper}")
        return {
            "mensaje": f"Código de seguridad enviado exitosamente vía {canal_upper}.",
            "canal": canal_upper,
            "telefono_enmascarado": tel_enmascarado,
            "ttl_segundos": 300,
            "debug_codigo_otp": codigo_otp if settings.ENVIRONMENT == "development" else None
        }

    async def verificar_otp_recuperacion(self, session_id: str, codigo: str) -> Dict[str, Any]:
        """
        Paso 3: Valida el código de 6 dígitos ingresado.
        Si es correcto, consume el OTP y emite un token de recuperación temporal de 10 min.
        """
        session_id = str(session_id).strip()
        codigo = str(codigo).strip()

        sesion_raw = await self.redis.get(f"recuperacion_sesion:{session_id}")
        if not sesion_raw:
            raise BadRequestException(
                message="La sesión de recuperación ha expirado o es inválida.",
                error_code="RECOVERY_SESSION_EXPIRED"
            )

        sesion = json.loads(sesion_raw)
        cod_socio = sesion["cod_socio"]

        otp_guardado = await self.redis.get(f"otp_recuperacion:{session_id}")
        if not otp_guardado:
            raise BadRequestException(
                message="El código de seguridad ha expirado o no fue solicitado.",
                error_code="OTP_EXPIRED"
            )

        if codigo != otp_guardado:
            fallos_key = f"otp_recuperacion_fallos:{session_id}"
            fallos = await self.redis.incr(fallos_key)
            if fallos >= 3:
                await self.redis.delete(f"otp_recuperacion:{session_id}")
                await self.redis.delete(f"recuperacion_sesion:{session_id}")
                await self.redis.delete(fallos_key)
                logger.warning(f"[RECUPERACION] 3 intentos erróneos de OTP para sesión {session_id}. Cancelando.")
                raise ForbiddenException(
                    message="Demasiados intentos erróneos. El proceso de recuperación ha sido cancelado por seguridad.",
                    error_code="OTP_MAX_ATTEMPTS"
                )
            restantes = 3 - fallos
            raise BadRequestException(
                message=f"Código de seguridad incorrecto. Le quedan {restantes} intento(s).",
                error_code="OTP_INVALID",
                details={"intentos_restantes": restantes}
            )

        # Destruir OTP utilizado (un solo uso)
        await self.redis.delete(f"otp_recuperacion:{session_id}")
        await self.redis.delete(f"otp_recuperacion_fallos:{session_id}")
        await self.redis.delete(f"recuperacion_sesion:{session_id}")

        # Emitir token temporal de autorización criptográfica (TTL: 10 min / 600 s)
        token_recuperacion = f"rst_{secrets.token_hex(24)}"
        await self.redis.set(
            f"token_recuperacion_valido:{token_recuperacion}",
            json.dumps(sesion),
            ex=600
        )

        logger.info(f"[RECUPERACION] OTP verificado con éxito para socio {cod_socio}. Token emitido.")
        return {
            "mensaje": "Código verificado exitosamente. Proceda a definir su nueva contraseña.",
            "token_recuperacion": token_recuperacion,
            "cod_socio": cod_socio
        }

    async def cambiar_pin_recuperacion(self, token_recuperacion: str, nuevo_pin: str) -> Dict[str, Any]:
        """
        Paso 4: Valida el token_recuperacion, actualiza el hash bcrypt del PIN,
        desbloquea la cuenta y revoca sesiones previas en otros dispositivos.
        """
        token_recuperacion = str(token_recuperacion).strip()
        nuevo_pin = str(nuevo_pin).strip()

        token_key = f"token_recuperacion_valido:{token_recuperacion}"
        sesion_raw = await self.redis.get(token_key)
        if not sesion_raw:
            raise UnauthorizedException(
                message="El token de recuperación es inválido o ha expirado.",
                error_code="INVALID_RECOVERY_TOKEN"
            )

        sesion = json.loads(sesion_raw)
        user_id_str = sesion["user_id"]
        cod_socio = sesion["cod_socio"]

        # Generar nuevo hash bcrypt
        nuevo_hash = get_password_hash(nuevo_pin)

        # Actualizar en PostgreSQL
        if self.db:
            try:
                uid = uuid.UUID(user_id_str)
                stmt = select(Usuario).where(Usuario.id == uid)
                res = await self.db.execute(stmt)
                user = res.scalars().first()
                if user:
                    user.password_hash = nuevo_hash
                    user.intentos_fallidos = 0
                    user.bloqueado_hasta = None
                    await self.db.commit()
            except Exception as e:
                await self.db.rollback()
                logger.error(f"[RECUPERACION] Error al persistir nuevo PIN en PostgreSQL: {e}")
                raise AppException(
                    message="Error interno al actualizar la contraseña.",
                    status_code=500,
                    error_code="DB_UPDATE_ERROR"
                )

        if cod_socio in USUARIOS_REGISTRADOS_DB:
            USUARIOS_REGISTRADOS_DB[cod_socio]["password_hash"] = nuevo_hash

        # Limpiar Redis: consumir token, resetear bloqueos y revocar sesiones activas
        await self.redis.delete(token_key)
        await self.redis.delete(f"bloqueado:{cod_socio}")
        await self.redis.delete(f"intentos_fallidos:{cod_socio}")
        await self.redis.delete(f"sesion_activa:{user_id_str}")

        logger.info(f"[RECUPERACION] PIN restablecido exitosamente para socio {cod_socio}. Cuenta desbloqueada.")
        return {
            "mensaje": "¡Su contraseña ha sido actualizada exitosamente! Ya puede iniciar sesión con su nuevo PIN.",
            "cod_socio": cod_socio
        }


