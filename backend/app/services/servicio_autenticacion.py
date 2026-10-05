"""
Servicio de lógica de negocio para identidad, onboarding y autenticación de socios COSMOL R.L.
"""
import asyncio
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


def enmascarar_telefono(t: Optional[str]) -> str:
    """Enmascara el número celular para visualización segura (ej. +591 7*** **384)."""
    if not t:
        return ""
    clean = str(t).strip().replace(" ", "").replace("-", "")
    if len(clean) >= 11 and clean.startswith("+591"):
        digitos = clean[4:]
        if len(digitos) == 8:
            return f"+591 {digitos[0]}*** **{digitos[-3:]}"
    if len(clean) >= 8:
        return f"{clean[:3]}***{clean[-3:]}"
    return clean


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

    async def _obtener_nombre_socio(self, cod_socio: str) -> Optional[str]:
        """
        Recupera el nombre oficial del socio con soporte de caché en Redis (TTL 24 horas).
        Evita saturar el backend comercial y reduce la latencia a <1ms tras la primera consulta.
        """
        cache_key = f"socio:nombre:{cod_socio}"
        try:
            nombre_cache = await self.redis.get(cache_key)
            if nombre_cache:
                return nombre_cache.decode("utf-8") if isinstance(nombre_cache, bytes) else str(nombre_cache)
        except Exception:
            pass

        try:
            datos = await self.cosmol_client.obtener_datos_socio(cod_socio)
            if datos and datos.get("NOMBRE"):
                nom = str(datos["NOMBRE"]).strip()
                try:
                    await self.redis.set(cache_key, nom, ex=86400)
                except Exception:
                    pass
                return nom
        except Exception:
            pass
        return None

    # --------------------------------------------------------------------------
    # PASO 1: VERIFICACIÓN INICIAL EN SISTEMA OFICIAL DE COSMOL
    # --------------------------------------------------------------------------
    async def verificar_primer_acceso(self, cod_socio: str, ci: str) -> Dict[str, Any]:
        """
        Valida que el socio exista en el sistema comercial oficial de COSMOL
        mediante su Código de Socio y Carnet de Identidad (NROCIONIT).
        Si el socio ya cuenta con cuenta TITULAR registrada, devuelve cuenta_existente=True
        junto con el teléfono celular enmascarado para habilitar el diálogo de migración o login.
        """
        cod_socio = cod_socio.strip()
        ci = ci.strip()

        # 1. Comprobar si ya existe cuenta TITULAR registrada en el sistema
        cuenta_existente = False
        telefono_titular = None

        if self.db:
            stmt = (
                select(Suministro)
                .where(Suministro.cod_socio == cod_socio, Suministro.rol == "TITULAR")
            )
            res = await self.db.execute(stmt)
            sum_titular = res.scalars().first()
            if sum_titular:
                cuenta_existente = True
                stmt_u = select(Usuario).where(Usuario.id == sum_titular.usuario_id)
                res_u = await self.db.execute(stmt_u)
                u = res_u.scalars().first()
                if u:
                    telefono_titular = u.telefono
        elif cod_socio in USUARIOS_REGISTRADOS_DB:
            cuenta_existente = True
            telefono_titular = USUARIOS_REGISTRADOS_DB[cod_socio].get("telefono")

        # 2. Validar contra el sistema comercial oficial de COSMOL (vía POST /socios/validar)
        datos_socio = await self.cosmol_client.validar_credenciales_socio(cod_socio, ci)
        if not datos_socio:
            logger.warning(f"Validación de credenciales rechazada para socio '{cod_socio}' con CI provisto")
            raise UnauthorizedException(
                message="El código de socio o carnet de identidad no coinciden con los registros oficiales de COSMOL.",
                error_code="SOCIO_NOT_FOUND"
            )

        nombre_oficial = str(datos_socio.get("NOMBRE") or datos_socio.get("nombre") or "Socio COSMOL").strip()
        tel_enmascarado = enmascarar_telefono(telefono_titular) if telefono_titular else None

        logger.info(
            f"Socio verificado exitosamente en COSMOL: {cod_socio} ({nombre_oficial}) "
            f"[cuenta_existente={cuenta_existente}, telefono={tel_enmascarado}]"
        )

        if cuenta_existente:
            mensaje = (
                f"Socio verificado. Su cuenta ya se encuentra registrada y vinculada al número {tel_enmascarado}."
                if tel_enmascarado else
                "Socio verificado. Su cuenta ya se encuentra registrada previamente."
            )
        else:
            mensaje = "Socio verificado correctamente. Proceda a asociar su teléfono celular."

        return {
            "cod_socio": cod_socio,
            "nombre_titular": nombre_oficial,
            "cuenta_existente": cuenta_existente,
            "telefono_enmascarado": tel_enmascarado,
            "es_recuperacion": cuenta_existente,
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
            # Exigir que el login diario sea con el código de socio que posee rol TITULAR
            stmt_sum = (
                select(Suministro)
                .where(Suministro.cod_socio == cod_socio, Suministro.rol == "TITULAR")
                .order_by(Suministro.es_suministro_principal.desc(), Suministro.created_at.asc())
            )
            res_sum = await self.db.execute(stmt_sum)
            suministro_db = res_sum.scalars().first()

            if not suministro_db:
                # Comprobar si el código existe únicamente en modo CONSULTA_PAGO
                stmt_inq = select(Suministro).where(Suministro.cod_socio == cod_socio)
                res_inq = await self.db.execute(stmt_inq)
                if res_inq.scalars().first():
                    raise UnauthorizedException(
                        message="Este código de socio está vinculado en modo consulta. Debe iniciar sesión con el código de socio titular de su cuenta.",
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
                nom_real = await self._obtener_nombre_socio(cod_socio)
                if nom_real:
                    nombre_socio = nom_real

                # Consulta concurrente de todos los nombres oficiales mediante asyncio.gather
                nombres = await asyncio.gather(
                    *[self._obtener_nombre_socio(s.cod_socio) for s in usuario_db.suministros],
                    return_exceptions=True
                )
                suministros_lista = [
                    SuministroResponse(
                        id=s.id,
                        cod_socio=s.cod_socio,
                        alias=s.alias,
                        nombre=nom if isinstance(nom, str) else None,
                        rol=s.rol,
                        es_suministro_principal=s.es_suministro_principal
                    )
                    for s, nom in zip(usuario_db.suministros, nombres)
                ]

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
            
            suministros_mem = usuario_mem.get("suministros", [])
            nombres_mem = await asyncio.gather(
                *[self._obtener_nombre_socio(s["cod_socio"]) for s in suministros_mem],
                return_exceptions=True
            )
            suministros_lista = [
                SuministroResponse(
                    id=s["id"],
                    cod_socio=s["cod_socio"],
                    alias=s["alias"],
                    nombre=nom if isinstance(nom, str) else None,
                    rol=s["rol"],
                    es_suministro_principal=s["es_suministro_principal"]
                )
                for s, nom in zip(suministros_mem, nombres_mem)
            ]

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
    # MIGRACIÓN SEGURA DE NÚMERO CELULAR (CAMBIO DE CHIP / TELÉFONO NUEVO)
    # --------------------------------------------------------------------------
    async def iniciar_migracion_telefono(
        self,
        cod_socio: str,
        ci: str,
        pin_actual: str,
        nuevo_telefono: str,
        canal: str = "WHATSAPP"
    ) -> Dict[str, Any]:
        """
        Inicia la migración de la cuenta titular a un nuevo número de celular.
        Exige la validación estricta del PIN actual para evitar secuestro de cuentas con facturas ajenas.
        """
        cod_socio = cod_socio.strip()
        ci = ci.strip()
        nuevo_telefono = normalizar_telefono(nuevo_telefono)

        # 1. Validar contra el sistema comercial oficial
        datos_socio = await self.cosmol_client.validar_credenciales_socio(cod_socio, ci)
        if not datos_socio:
            raise UnauthorizedException(
                message="El código de socio o carnet de identidad no coinciden con los registros oficiales de COSMOL.",
                error_code="SOCIO_NOT_FOUND"
            )

        # 2. Localizar usuario titular en BD o memoria
        password_hash = None
        user_id = None

        if self.db:
            stmt = (
                select(Suministro)
                .where(Suministro.cod_socio == cod_socio, Suministro.rol == "TITULAR")
            )
            res = await self.db.execute(stmt)
            sum_titular = res.scalars().first()
            if not sum_titular:
                raise NotFoundException(
                    message=f"No se encontró una cuenta titular activa para el socio '{cod_socio}'.",
                    error_code="ACCOUNT_NOT_FOUND"
                )
            stmt_u = select(Usuario).where(Usuario.id == sum_titular.usuario_id)
            res_u = await self.db.execute(stmt_u)
            usuario_db = res_u.scalars().first()
            if not usuario_db or not usuario_db.esta_activo:
                raise UnauthorizedException(
                    message="La cuenta de socio se encuentra inactiva o deshabilitada.",
                    error_code="ACCOUNT_DISABLED"
                )
            password_hash = usuario_db.password_hash
            user_id = str(usuario_db.id)
        elif cod_socio in USUARIOS_REGISTRADOS_DB:
            usuario_mem = USUARIOS_REGISTRADOS_DB[cod_socio]
            password_hash = usuario_mem.get("password_hash")
            user_id = usuario_mem.get("user_id")

        if not password_hash:
            raise NotFoundException(
                message="El socio no cuenta con una contraseña registrada. Realice el primer acceso.",
                error_code="ACCOUNT_NOT_FOUND"
            )

        # 3. Validar PIN actual
        if not verify_password(pin_actual, password_hash):
            raise UnauthorizedException(
                message="El PIN actual ingresado es incorrecto. Verifique sus credenciales.",
                error_code="INVALID_PIN"
            )

        # 4. Rate limit en el nuevo teléfono
        rate_key = f"rate_otp:{nuevo_telefono}"
        solicitudes = await self.redis.incr(rate_key)
        if solicitudes == 1:
            await self.redis.expire(rate_key, 3600)
        elif solicitudes > 3:
            ttl_rate = await self.redis.ttl(rate_key)
            raise ForbiddenException(
                message=f"Ha superado el límite de 3 solicitudes de OTP por hora. Intente en {max(1, ttl_rate // 60)} min.",
                error_code="OTP_RATE_LIMIT_EXCEEDED"
            )

        # 5. Generar OTP y sesión de migración (TTL 5 min)
        session_id = f"mig_{uuid.uuid4()}"
        codigo_otp = f"{secrets.randbelow(900000) + 100000}"

        datos_migracion = {
            "user_id": user_id,
            "cod_socio": cod_socio,
            "nuevo_telefono": nuevo_telefono,
            "codigo_otp": codigo_otp,
        }
        await self.redis.set(f"migracion_sesion:{session_id}", json.dumps(datos_migracion), ex=300)

        # 6. Despachar OTP al NUEVO número celular
        canal_upper = canal.upper()
        if canal_upper == "WHATSAPP":
            await whatsapp_client.enviar_otp(nuevo_telefono, codigo_otp)
        elif canal_upper == "SMS":
            await sms_client.enviar_sms_otp(nuevo_telefono, codigo_otp)

        logger.info(f"[MIGRACIÓN TELÉFONO INICIADA] Socio: {cod_socio} | Nuevo Tel: {nuevo_telefono} | OTP: {codigo_otp}")

        return {
            "session_id": session_id,
            "mensaje": f"Código de seguridad enviado al nuevo número celular vía {canal_upper}.",
            "ttl_segundos": 300,
            "debug_codigo_otp": codigo_otp if settings.ENVIRONMENT == "development" else None
        }

    async def confirmar_migracion_telefono(
        self,
        session_id: str,
        codigo_otp: str
    ) -> Dict[str, Any]:
        """
        Confirma la migración validando el OTP del nuevo celular.
        Actualiza el teléfono en PostgreSQL, revoca sesiones previas y emite nuevos JWTs.
        """
        mig_key = f"migracion_sesion:{session_id}"
        datos_raw = await self.redis.get(mig_key)
        if not datos_raw:
            raise BadRequestException(
                message="La sesión de migración ha expirado o no existe. Inicie el proceso nuevamente.",
                error_code="MIGRATION_SESSION_EXPIRED"
            )

        datos = json.loads(datos_raw if isinstance(datos_raw, str) else datos_raw.decode("utf-8"))
        codigo_esperado = datos["codigo_otp"]
        user_id_str = datos["user_id"]
        nuevo_telefono = datos["nuevo_telefono"]
        cod_socio = datos["cod_socio"]

        if codigo_otp.strip() != codigo_esperado:
            raise BadRequestException(
                message="El código de seguridad ingresado es incorrecto.",
                error_code="OTP_INVALID"
            )

        # Destruir sesión de migración usada
        await self.redis.delete(mig_key)

        nombre_titular = "Socio COSMOL"
        suministros_lista: List[SuministroResponse] = []

        if self.db:
            u_id = uuid.UUID(user_id_str)
            stmt = select(Usuario).options(selectinload(Usuario.suministros)).where(Usuario.id == u_id)
            res = await self.db.execute(stmt)
            usuario_db = res.scalars().first()
            if usuario_db:
                usuario_db.telefono = nuevo_telefono
                await self.db.commit()
                await self.db.refresh(usuario_db)

                # Revocar sesiones previas en otros dispositivos
                await self.redis.delete(f"sesion_activa:{u_id}")

                nom_real = await self._obtener_nombre_socio(cod_socio)
                if nom_real:
                    nombre_titular = nom_real

                nombres = await asyncio.gather(
                    *[self._obtener_nombre_socio(s.cod_socio) for s in usuario_db.suministros],
                    return_exceptions=True
                )
                suministros_lista = [
                    SuministroResponse(
                        id=s.id,
                        cod_socio=s.cod_socio,
                        alias=s.alias,
                        nombre=nom if isinstance(nom, str) else None,
                        rol=s.rol,
                        es_suministro_principal=s.es_suministro_principal
                    )
                    for s, nom in zip(usuario_db.suministros, nombres)
                ]

        if cod_socio in USUARIOS_REGISTRADOS_DB:
            USUARIOS_REGISTRADOS_DB[cod_socio]["telefono"] = nuevo_telefono

        # Emitir tokens JWT
        access_token = create_access_token({"sub": user_id_str, "cod_socio": cod_socio})
        refresh_token = create_refresh_token({"sub": user_id_str, "cod_socio": cod_socio})

        logger.info(f"[MIGRACIÓN TELÉFONO EXITOSA] Socio {cod_socio} migrado a {nuevo_telefono}.")

        return {
            "mensaje": "Número de teléfono actualizado exitosamente. Bienvenido a COSMOL.",
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "cod_socio": cod_socio,
            "nombre": nombre_titular,
            "suministros": suministros_lista
        }

    # --------------------------------------------------------------------------
    # RECUPERACIÓN SEGURA DE CONTRASEÑA / PIN (ZERO-TRUST PHONE BINDING)
    # --------------------------------------------------------------------------
    async def validar_titular_recuperacion(self, cod_socio: str, ci: str) -> Dict[str, Any]:
        """
        Paso 1 Recuperación: Valida titularidad y devuelve el teléfono enmascarado registrado en BD.
        """
        cod_socio = cod_socio.strip()
        ci = ci.strip()

        # Validar credenciales con sistema comercial oficial
        datos_socio = await self.cosmol_client.validar_credenciales_socio(cod_socio, ci)
        if not datos_socio:
            raise UnauthorizedException(
                message="El código de socio o carnet de identidad no coinciden.",
                error_code="SOCIO_NOT_FOUND"
            )

        telefono = None
        user_id = None

        if self.db:
            stmt = select(Suministro).where(Suministro.cod_socio == cod_socio, Suministro.rol == "TITULAR")
            res = await self.db.execute(stmt)
            sum_titular = res.scalars().first()
            if not sum_titular:
                raise NotFoundException(
                    message="Este socio no tiene una cuenta registrada en la aplicación.",
                    error_code="ACCOUNT_NOT_REGISTERED"
                )
            stmt_u = select(Usuario).where(Usuario.id == sum_titular.usuario_id)
            res_u = await self.db.execute(stmt_u)
            u = res_u.scalars().first()
            if not u or not u.esta_activo:
                raise UnauthorizedException(
                    message="La cuenta del socio se encuentra inactiva o deshabilitada.",
                    error_code="ACCOUNT_DISABLED"
                )
            telefono = u.telefono
            user_id = str(u.id)
        elif cod_socio in USUARIOS_REGISTRADOS_DB:
            usuario_mem = USUARIOS_REGISTRADOS_DB[cod_socio]
            telefono = usuario_mem.get("telefono")
            user_id = usuario_mem.get("user_id")

        if not telefono:
            raise NotFoundException(
                message="No se encontró un número telefónico registrado para esta cuenta.",
                error_code="ACCOUNT_NOT_REGISTERED"
            )

        nombre_oficial = str(datos_socio.get("NOMBRE") or "Socio COSMOL").strip()
        session_id = f"rec_{uuid.uuid4()}"
        datos_sesion = {
            "user_id": user_id,
            "cod_socio": cod_socio,
            "telefono": telefono,
        }
        await self.redis.set(f"recuperacion_sesion:{session_id}", json.dumps(datos_sesion), ex=300)

        return {
            "session_id": session_id,
            "cod_socio": cod_socio,
            "nombre_titular": nombre_oficial,
            "telefono_enmascarado": enmascarar_telefono(telefono),
            "mensaje": "Titular validado correctamente. Seleccione el canal para recibir su código de seguridad."
        }

    async def solicitar_otp_recuperacion(self, session_id: str, canal: str = "WHATSAPP") -> Dict[str, Any]:
        """
        Paso 2 Recuperación: Envía el OTP al celular previamente registrado en PostgreSQL.
        """
        raw = await self.redis.get(f"recuperacion_sesion:{session_id}")
        if not raw:
            raise BadRequestException(
                message="La sesión de recuperación ha expirado. Reinicie el proceso.",
                error_code="RECOVERY_SESSION_EXPIRED"
            )
        datos = json.loads(raw if isinstance(raw, str) else raw.decode("utf-8"))
        telefono = datos["telefono"]

        # Rate limit por teléfono
        rate_key = f"rate_otp_recuperacion:{telefono}"
        solicitudes = await self.redis.incr(rate_key)
        if solicitudes == 1:
            await self.redis.expire(rate_key, 3600)
        elif solicitudes > 3:
            raise ForbiddenException(
                message="Ha superado el límite de 3 solicitudes de OTP por hora.",
                error_code="OTP_RATE_LIMIT_EXCEEDED"
            )

        codigo_otp = f"{secrets.randbelow(900000) + 100000}"
        await self.redis.set(f"otp_recuperacion:{session_id}", codigo_otp, ex=300)

        canal_upper = canal.upper()
        if canal_upper == "WHATSAPP":
            await whatsapp_client.enviar_otp(telefono, codigo_otp)
        elif canal_upper == "SMS":
            await sms_client.enviar_sms_otp(telefono, codigo_otp)

        return {
            "mensaje": f"Código de seguridad enviado exitosamente vía {canal_upper}.",
            "canal": canal_upper,
            "telefono_enmascarado": enmascarar_telefono(telefono),
            "ttl_segundos": 300,
            "debug_codigo_otp": codigo_otp if settings.ENVIRONMENT == "development" else None
        }

    async def verificar_otp_recuperacion(self, session_id: str, codigo: str) -> Dict[str, Any]:
        """
        Paso 3 Recuperación: Valida el OTP y emite un token de recuperación temporal de 10 min.
        """
        raw = await self.redis.get(f"recuperacion_sesion:{session_id}")
        if not raw:
            raise BadRequestException(
                message="La sesión de recuperación ha expirado.",
                error_code="RECOVERY_SESSION_EXPIRED"
            )
        datos = json.loads(raw if isinstance(raw, str) else raw.decode("utf-8"))

        otp_guardado = await self.redis.get(f"otp_recuperacion:{session_id}")
        if not otp_guardado:
            raise BadRequestException(
                message="El código OTP ha expirado o no fue solicitado.",
                error_code="OTP_EXPIRED"
            )

        otp_str = otp_guardado if isinstance(otp_guardado, str) else otp_guardado.decode("utf-8")
        if codigo.strip() != otp_str:
            raise BadRequestException(
                message="Código de seguridad incorrecto.",
                error_code="OTP_INVALID"
            )

        # Destruir OTP usado
        await self.redis.delete(f"otp_recuperacion:{session_id}")

        # Emitir token de recuperación temporal (TTL 10 min)
        token_rec = f"rst_{secrets.token_hex(20)}"
        await self.redis.set(f"token_recuperacion:{token_rec}", raw if isinstance(raw, str) else raw.decode("utf-8"), ex=600)

        return {
            "mensaje": "Código verificado exitosamente. Proceda a definir su nueva contraseña.",
            "token_recuperacion": token_rec,
            "cod_socio": datos["cod_socio"]
        }

    async def cambiar_pin_recuperacion(self, token_recuperacion: str, nuevo_pin: str) -> Dict[str, Any]:
        """
        Paso 4 Recuperación: Actualiza el PIN con hash bcrypt y resetea bloqueos.
        """
        raw = await self.redis.get(f"token_recuperacion:{token_recuperacion}")
        if not raw:
            raise UnauthorizedException(
                message="El pase de recuperación es inválido o ha expirado.",
                error_code="INVALID_RECOVERY_TOKEN"
            )
        datos = json.loads(raw if isinstance(raw, str) else raw.decode("utf-8"))
        user_id_str = datos["user_id"]
        cod_socio = datos["cod_socio"]

        pin_hash = get_password_hash(nuevo_pin)

        if self.db:
            u_id = uuid.UUID(user_id_str)
            stmt = select(Usuario).where(Usuario.id == u_id)
            res = await self.db.execute(stmt)
            u = res.scalars().first()
            if u:
                u.password_hash = pin_hash
                await self.db.commit()

        if cod_socio in USUARIOS_REGISTRADOS_DB:
            USUARIOS_REGISTRADOS_DB[cod_socio]["password_hash"] = pin_hash

        # Limpiar bloqueos de cuenta y token de recuperación
        await self.redis.delete(f"token_recuperacion:{token_recuperacion}")
        await self.redis.delete(f"bloqueado:{cod_socio}")
        await self.redis.delete(f"intentos_fallidos:{cod_socio}")
        await self.redis.delete(f"sesion_activa:{user_id_str}")

        logger.info(f"[RECUPERACIÓN PIN COMPLETADA] PIN actualizado para socio {cod_socio}.")

        return {
            "mensaje": "¡Su contraseña ha sido actualizada exitosamente! Ya puede iniciar sesión con su nuevo PIN.",
            "cod_socio": cod_socio
        }


