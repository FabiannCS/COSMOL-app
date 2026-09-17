"""
Servicio de lógica de negocio para gestión Multicuenta de Suministros (COSMOL R.L.).
Permite que un único socio administre múltiples contratos (casa, alquiler, negocio).
"""
import logging
import uuid
from typing import List, Optional
import redis.asyncio as aioredis

from app.core.exceptions import BadRequestException, NotFoundException
from app.schemas.suministro import SuministroResponse, VincularSuministroRequest
from app.services.servicio_autenticacion import (
    SOCIOS_MOCK_LEGADO,
    USUARIOS_REGISTRADOS_DB,
)

logger = logging.getLogger(__name__)


class ServicioSuministros:
    """
    Controlador para vinculación y consulta de suministros multicuenta.
    """

    def __init__(self, redis_client: aioredis.Redis):
        self.redis = redis_client

    async def vincular_suministro(
        self,
        cod_socio_principal: str,
        datos: VincularSuministroRequest
    ) -> SuministroResponse:
        """
        Vincula un nuevo código de suministro a la cuenta del socio autenticado.
        - Modo TITULAR: Si ingresa el CI o medidor oficial del titular.
        - Modo CONSULTA_PAGO: Si solo conoce el código de socio (Inquilino).
        """
        cod_socio = datos.cod_socio.strip()

        # 1. Verificar si el suministro existe en COSMOL
        datos_legado = SOCIOS_MOCK_LEGADO.get(cod_socio)
        if not datos_legado:
            raise NotFoundException(
                message=f"El código de suministro '{cod_socio}' no fue encontrado en los registros de COSMOL.",
                error_code="SUMINISTRO_NOT_FOUND"
            )

        # 2. Determinar rol según credencial adicional (CI o Medidor)
        rol = "CONSULTA_PAGO"
        if datos.ci_o_medidor:
            ci_med = datos.ci_o_medidor.strip()
            if ci_med == datos_legado.get("ci") or ci_med == datos_legado.get("medidor"):
                rol = "TITULAR"
                logger.info(f"Suministro '{cod_socio}' vinculado en modo TITULAR con validación exitosa.")
            else:
                logger.info(f"CI/Medidor no coincidió para '{cod_socio}'. Asignando modo CONSULTA_PAGO.")

        # 3. Registrar en los suministros del usuario
        nuevo_suministro = {
            "id": uuid.uuid4(),
            "cod_socio": cod_socio,
            "alias": datos.alias,
            "rol": rol,
            "es_suministro_principal": False
        }

        usuario = USUARIOS_REGISTRADOS_DB.get(cod_socio_principal)
        if usuario:
            # Evitar vincular duplicados
            ya_existe = any(s["cod_socio"] == cod_socio for s in usuario.get("suministros", []))
            if ya_existe:
                raise BadRequestException(
                    message=f"El suministro '{cod_socio}' ya se encuentra vinculado a su perfil.",
                    error_code="SUMINISTRO_ALREADY_LINKED"
                )
            usuario["suministros"].append(nuevo_suministro)

        return SuministroResponse(
            id=nuevo_suministro["id"],
            cod_socio=nuevo_suministro["cod_socio"],
            alias=nuevo_suministro["alias"],
            rol=nuevo_suministro["rol"],
            es_suministro_principal=nuevo_suministro["es_suministro_principal"]
        )

    async def listar_suministros(self, cod_socio_principal: str) -> List[SuministroResponse]:
        """
        Retorna todos los contratos vinculados al socio actual.
        """
        usuario = USUARIOS_REGISTRADOS_DB.get(cod_socio_principal)
        if not usuario:
            return []

        return [
            SuministroResponse(
                id=s["id"],
                cod_socio=s["cod_socio"],
                alias=s["alias"],
                rol=s["rol"],
                es_suministro_principal=s["es_suministro_principal"]
            )
            for s in usuario.get("suministros", [])
        ]
