"""
Servicio de lógica de negocio para gestión Multicuenta de Suministros (COSMOL R.L.).
Permite que un único socio administre múltiples contratos (casa, alquiler, negocio).
"""
import logging
import uuid
from typing import List, Optional
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
    Controlador para vinculación y consulta de suministros multicuenta.
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

    async def listar_suministros(
        self,
        cod_socio_principal: str,
        usuario_id_token: Optional[str] = None
    ) -> List[SuministroResponse]:
        """
        Retorna todos los contratos vinculados al socio actual con su nombre oficial.
        """
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
                stmt_all = (
                    select(Suministro)
                    .where(Suministro.usuario_id == usuario_id)
                    .order_by(Suministro.es_suministro_principal.desc(), Suministro.created_at.asc())
                )
                res_all = await self.db.execute(stmt_all)
                suministros_db = res_all.scalars().all()
                if suministros_db:
                    resultado = []
                    for s in suministros_db:
                        nom = None
                        try:
                            datos_s = await self.cosmol_client.obtener_datos_socio(s.cod_socio)
                            if datos_s:
                                nom = datos_s.get("NOMBRE")
                        except Exception:
                            nom = None
                        resultado.append(
                            SuministroResponse(
                                id=s.id,
                                cod_socio=s.cod_socio,
                                alias=s.alias,
                                nombre=nom,
                                rol=s.rol,
                                es_suministro_principal=s.es_suministro_principal
                            )
                        )
                    return resultado

        usuario = USUARIOS_REGISTRADOS_DB.get(cod_socio_principal)
        if not usuario:
            return []

        resultado_mem = []
        for s in usuario.get("suministros", []):
            nom = None
            try:
                datos_s = await self.cosmol_client.obtener_datos_socio(s["cod_socio"])
                if datos_s:
                    nom = datos_s.get("NOMBRE")
            except Exception:
                nom = None
            resultado_mem.append(
                SuministroResponse(
                    id=s["id"],
                    cod_socio=s["cod_socio"],
                    alias=s["alias"],
                    nombre=nom,
                    rol=s["rol"],
                    es_suministro_principal=s["es_suministro_principal"]
                )
            )
        return resultado_mem
