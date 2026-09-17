"""
Endpoints de la API REST para Consulta de Deuda y Dashboard Multicuenta (COSMOL R.L.).
Provee endpoints de alto rendimiento (<20ms con Redis) protegidos con JWT Bearer.
"""
from typing import Any, Dict
from uuid import UUID
import logging
from fastapi import APIRouter, Depends, Query, status
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user_id, get_db, get_redis
from app.schemas.deuda import (
    DashboardMultiSuministroResponse,
    ResumenDeudaResponse,
)
from app.services.servicio_deuda import ServicioDeuda

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get(
    "/dashboard/resumen",
    response_model=DashboardMultiSuministroResponse,
    status_code=status.HTTP_200_OK,
    summary="Resumen multicuenta para Dashboard principal",
    description="Retorna el consolidado de deuda de todos los suministros vinculados al usuario autenticado.",
)
async def obtener_dashboard_resumen(
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
    redis_client: Redis = Depends(get_redis),
) -> DashboardMultiSuministroResponse:
    """
    Agrupa todos los contratos administrados por el socio (casa, alquiler, negocio),
    aprovechando la caché de Redis para cada suministro y sumando el saldo total en Bs.
    """
    servicio = ServicioDeuda(db=db, redis_client=redis_client)
    return await servicio.obtener_dashboard_general(usuario_id=UUID(current_user_id))


@router.get(
    "/{cod_socio}",
    response_model=ResumenDeudaResponse,
    status_code=status.HTTP_200_OK,
    summary="Consultar deuda y facturas de un suministro",
    description="Obtiene el saldo en Bs, semaforización de mora, facturas pendientes y datos del suministro.",
)
async def obtener_deuda_suministro(
    cod_socio: str,
    forzar_refresco: bool = Query(
        False,
        description="Si es true, ignora la caché de Redis y consulta en vivo al sistema comercial legado."
    ),
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
    redis_client: Redis = Depends(get_redis),
) -> ResumenDeudaResponse:
    """
    Consulta el estado de deuda en tiempo real:
    - Retorna en <20 ms si la respuesta está en caché de Redis.
    - Aplica semaforización de vencimiento y alerta de corte (2 o más facturas).
    - Aplica enmascaramiento estricto si el usuario tiene rol CONSULTA_PAGO (inquilino).
    - Rechaza con HTTP 403 si el suministro no pertenece al usuario autenticado.
    """
    servicio = ServicioDeuda(db=db, redis_client=redis_client)
    return await servicio.obtener_deuda_suministro(
        usuario_id=UUID(current_user_id),
        cod_socio=cod_socio,
        forzar_refresco=forzar_refresco
    )


@router.post(
    "/{cod_socio}/invalidar-cache",
    status_code=status.HTTP_200_OK,
    summary="Invalidar caché de deuda en Redis",
    description="Purga la clave de deuda en Redis para forzar una consulta fresca en la siguiente petición.",
)
async def invalidar_cache_deuda(
    cod_socio: str,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
    redis_client: Redis = Depends(get_redis),
) -> Dict[str, Any]:
    """
    Invalida manualmente la caché de deuda del suministro.
    Valida previamente que el usuario tenga acceso al suministro en PostgreSQL.
    """
    servicio = ServicioDeuda(db=db, redis_client=redis_client)
    # Validar primero que tenga permiso sobre el suministro
    await servicio.obtener_deuda_suministro(
        usuario_id=UUID(current_user_id),
        cod_socio=cod_socio,
        forzar_refresco=False
    )
    invalidado = await servicio.invalidar_cache_socio(cod_socio)
    return {
        "cod_socio": cod_socio,
        "cache_invalidada": invalidado,
        "mensaje": f"Caché de deuda para el suministro '{cod_socio}' invalidada exitosamente."
    }
