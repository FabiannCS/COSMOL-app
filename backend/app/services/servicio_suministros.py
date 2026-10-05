"""
Servicio de lógica de negocio para gestión Multicuenta de Suministros (COSMOL R.L.).
Permite que un único socio administre múltiples contratos (casa, alquiler, negocio).
"""
import asyncio
import logging
import uuid
from typing import Any, Dict, List, Optional
import redis.asyncio as aioredis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import BadRequestException, NotFoundException
from app.db.models import Suministro, Usuario
from app.integrations.cosmol_client import cosmol_client, CosmolLegacyClient
from app.schemas.suministro import SuministroResponse, VincularSuministroRequest
from app.services.servicio_autenticacion import (
    USUARIOS_REGISTRADOS_DB,
)

logger = logging.getLogger(__name__)


class ServicioSuministros:
    """
    Controlador para vinculación, desvinculación y consulta de suministros multicuenta.
    Integrado con PostgreSQL (AsyncSession) y modelos ORM.
    """

    def __init__(
        self,
        redis_client: aioredis.Redis,
        db: Optional[AsyncSession] = None,
        cliente_cosmol: Optional[CosmolLegacyClient] = None,
    ):
        self.redis = redis_client
        self.db = db
        self.cosmol_client = cliente_cosmol or cosmol_client

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

    async def vincular_suministro(
        self,
        cod_socio_principal: str,
        datos: VincularSuministroRequest,
        usuario_id_token: Optional[str] = None
    ) -> SuministroResponse:
        """
        Vincula un nuevo código de suministro a la cuenta del socio autenticado.
        - Modo TITULAR: Si ingresa el CI o medidor oficial del titular.
        - Modo CONSULTA_PAGO: Si solo conoce el código de socio (Inquilino).
        """
        cod_socio = datos.cod_socio.strip()

        # 1. Verificar si el suministro existe en COSMOL
        datos_socio = await self.cosmol_client.obtener_datos_socio(cod_socio)
        if not datos_socio:
            raise NotFoundException(
                message=f"El código de suministro '{cod_socio}' no fue encontrado en los registros de COSMOL.",
                error_code="SUMINISTRO_NOT_FOUND"
            )

        # 2. Determinar rol según credencial adicional (CI o Medidor)
        rol = "CONSULTA_PAGO"
        if datos.ci_o_medidor:
            ci_med = datos.ci_o_medidor.strip()
            ci_oficial = str(datos_socio.get("NROCIONIT", "")).strip()
            if ci_med == ci_oficial:
                rol = "TITULAR"
                logger.info(f"Suministro '{cod_socio}' vinculado en modo TITULAR con validación exitosa.")
            else:
                logger.info(f"CI/Medidor no coincidió para '{cod_socio}'. Asignando modo CONSULTA_PAGO.")

        # 3. Registrar en PostgreSQL si hay sesión activa
        suministro_id = uuid.uuid4()
        if self.db:
            usuario_id = None
            if usuario_id_token:
                try:
                    usuario_id = uuid.UUID(str(usuario_id_token))
                except Exception:
                    usuario_id = None

            if not usuario_id and cod_socio_principal:
                stmt = select(Suministro).where(Suministro.cod_socio == cod_socio_principal)
                res = await self.db.execute(stmt)
                sum_principal = res.scalars().first()
                if sum_principal:
                    usuario_id = sum_principal.usuario_id

            if usuario_id:
                stmt_dup = select(Suministro).where(
                    Suministro.usuario_id == usuario_id,
                    Suministro.cod_socio == cod_socio
                )
                res_dup = await self.db.execute(stmt_dup)
                if res_dup.scalars().first():
                    raise BadRequestException(
                        message=f"El suministro '{cod_socio}' ya se encuentra vinculado a su perfil.",
                        error_code="SUMINISTRO_ALREADY_LINKED"
                    )

                nuevo_sum_db = Suministro(
                    usuario_id=usuario_id,
                    cod_socio=cod_socio,
                    alias=datos.alias,
                    rol=rol,
                    es_suministro_principal=False
                )
                self.db.add(nuevo_sum_db)
                await self.db.commit()
                await self.db.refresh(nuevo_sum_db)
                suministro_id = nuevo_sum_db.id

        # 4. Mantener sincronizado en memoria para pruebas y retrocompatibilidad
        nuevo_suministro_dict = {
            "id": suministro_id,
            "cod_socio": cod_socio,
            "alias": datos.alias,
            "rol": rol,
            "es_suministro_principal": False
        }

        usuario = USUARIOS_REGISTRADOS_DB.get(cod_socio_principal)
        if usuario:
            ya_existe = any(s["cod_socio"] == cod_socio for s in usuario.get("suministros", []))
            if ya_existe:
                raise BadRequestException(
                    message=f"El suministro '{cod_socio}' ya se encuentra vinculado a su perfil.",
                    error_code="SUMINISTRO_ALREADY_LINKED"
                )
            usuario["suministros"].append(nuevo_suministro_dict)

        nombre_socio = datos_socio.get("NOMBRE") if datos_socio else None

        return SuministroResponse(
            id=suministro_id,
            cod_socio=cod_socio,
            alias=datos.alias,
            nombre=nombre_socio,
            rol=rol,
            es_suministro_principal=False
        )

    async def desvincular_suministro(
        self,
        cod_socio_principal: str,
        cod_socio_a_desvincular: str,
        usuario_id_token: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Desvincula un suministro secundario (sea TITULAR adicional o CONSULTA_PAGO) de la cuenta del usuario.
        Rechaza la desvinculación únicamente si el suministro es el principal con el que se registró la cuenta.
        """
        cod_socio_a_desvincular = str(cod_socio_a_desvincular).strip()
        cod_socio_principal = str(cod_socio_principal).strip()

        desvinculado_exitoso = False

        if self.db:
            usuario_id = None
            if usuario_id_token:
                try:
                    usuario_id = uuid.UUID(str(usuario_id_token))
                except Exception:
                    usuario_id = None

            if not usuario_id and cod_socio_principal:
                stmt_user = select(Suministro).where(Suministro.cod_socio == cod_socio_principal)
                res_user = await self.db.execute(stmt_user)
                sum_p = res_user.scalars().first()
                if sum_p:
                    usuario_id = sum_p.usuario_id

            if usuario_id:
                stmt = select(Suministro).where(
                    Suministro.usuario_id == usuario_id,
                    Suministro.cod_socio == cod_socio_a_desvincular
                )
                res = await self.db.execute(stmt)
                suministro = res.scalars().first()

                if not suministro:
                    raise NotFoundException(
                        message=f"El suministro '{cod_socio_a_desvincular}' no está vinculado a su cuenta.",
                        error_code="SUMINISTRO_NOT_LINKED"
                    )

                if suministro.es_suministro_principal:
                    raise BadRequestException(
                        message="No es posible desvincular el suministro principal registrado con el que se creó su cuenta.",
                        error_code="CANNOT_UNLINK_PRIMARY"
                    )

                await self.db.delete(suministro)
                await self.db.commit()
                desvinculado_exitoso = True
                logger.info(f"Suministro '{cod_socio_a_desvincular}' desvinculado exitosamente del usuario {usuario_id} en PostgreSQL.")

        # Sincronización en memoria
        for cod_key, usuario_mem in USUARIOS_REGISTRADOS_DB.items():
            if (usuario_id_token and usuario_mem.get("user_id") == str(usuario_id_token)) or cod_key == cod_socio_principal:
                suministros_previos = usuario_mem.get("suministros", [])
                sum_target = next((s for s in suministros_previos if s.get("cod_socio") == cod_socio_a_desvincular), None)
                if sum_target:
                    if sum_target.get("es_suministro_principal", False) and not self.db:
                        raise BadRequestException(
                            message="No es posible desvincular el suministro principal registrado con el que se creó su cuenta.",
                            error_code="CANNOT_UNLINK_PRIMARY"
                        )
                    usuario_mem["suministros"] = [
                        s for s in suministros_previos
                        if s.get("cod_socio") != cod_socio_a_desvincular
                    ]
                    desvinculado_exitoso = True
                    break

        if not desvinculado_exitoso and not self.db:
            raise NotFoundException(
                message=f"El suministro '{cod_socio_a_desvincular}' no está vinculado a su cuenta.",
                error_code="SUMINISTRO_NOT_LINKED"
            )

        return {
            "mensaje": "Suministro desvinculado exitosamente.",
            "cod_socio": cod_socio_a_desvincular
        }

    async def listar_suministros(
        self,
        cod_socio_principal: str,
        usuario_id_token: Optional[str] = None
    ) -> List[SuministroResponse]:
        """
        Retorna todos los contratos vinculados al socio actual con su nombre oficial.
        Optimizado con asyncio.gather concurrente y caché en Redis.
        """
        if self.db:
            usuario_id = None
            if usuario_id_token:
                try:
                    usuario_id = uuid.UUID(str(usuario_id_token))
                except Exception:
                    usuario_id = None

            if not usuario_id and cod_socio_principal:
                stmt = select(Suministro).where(
                    Suministro.cod_socio == cod_socio_principal,
                    Suministro.rol == "TITULAR"
                )
                res = await self.db.execute(stmt)
                sum_principal = res.scalars().first()
                if sum_principal:
                    usuario_id = sum_principal.usuario_id

            if usuario_id:
                stmt_all = (
                    select(Suministro)
                    .where(Suministro.usuario_id == usuario_id)
                    .order_by(Suministro.es_suministro_principal.desc(), Suministro.created_at.asc())
                )
                res_all = await self.db.execute(stmt_all)
                suministros_db = res_all.scalars().all()
                if suministros_db:
                    # Consulta concurrente de nombres oficiales con asyncio.gather
                    nombres = await asyncio.gather(
                        *[self._obtener_nombre_socio(s.cod_socio) for s in suministros_db],
                        return_exceptions=True
                    )
                    return [
                        SuministroResponse(
                            id=s.id,
                            cod_socio=s.cod_socio,
                            alias=s.alias,
                            nombre=nom if isinstance(nom, str) else None,
                            rol=s.rol,
                            es_suministro_principal=s.es_suministro_principal
                        )
                        for s, nom in zip(suministros_db, nombres)
                    ]

        usuario = USUARIOS_REGISTRADOS_DB.get(cod_socio_principal)
        if not usuario:
            return []

        suministros_mem = usuario.get("suministros", [])
        nombres_mem = await asyncio.gather(
            *[self._obtener_nombre_socio(s["cod_socio"]) for s in suministros_mem],
            return_exceptions=True
        )

        return [
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

