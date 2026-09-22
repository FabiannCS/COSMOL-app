"""
Endpoints de la API REST para la Analítica e Historial de Consumo (COSMOL R.L.).
Permite consultar el historial de 6 a 12 meses en m³ e importes en Bs para gráficos (fl_chart),
con caché acelerada en Redis (<20 ms), privacidad multicuenta y detección de fugas (>= +30%).
"""
from typing import Any, Dict
from uuid import UUID
import logging
from fastapi import APIRouter, BackgroundTasks, Depends, Query, status
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user_id, get_db, get_redis
from app.schemas.consumo import HistorialConsumoResponse
from app.services.servicio_consumo import ServicioConsumo
from app.tasks.auditoria_reportes import despachar_auditoria_reportes

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get(
    "/{cod_socio}",
    response_model=HistorialConsumoResponse,
    status_code=status.HTTP_200_OK,
    summary="Historial mensual y analítica de consumo del socio",
    description=(
        "Retorna entre 6 y 12 periodos mensuales con lecturas y volumen facturado en m³ y Bs, "
        "calculando estadísticas (promedio, máximos, mínimos) y activando alerta preventiva "
        "si el último consumo supera en 30% o más el promedio histórico (posible fuga)."
    ),
)
async def obtener_historial_consumo(
    cod_socio: str,
    background_tasks: BackgroundTasks,
    forzar_refresco: bool = Query(
        False,
        description="Si es true, elude la caché de Redis y refresca en vivo contra el sistema legado."
    ),
    meses: int = Query(
        12,
        ge=1,
        le=24,
        description="Cantidad de meses de historial requeridos (por defecto 12 periodos)."
    ),
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
    redis_client: Redis = Depends(get_redis),
) -> HistorialConsumoResponse:
    """
    Endpoint principal para alimentar la vista de consumo histórico en Flutter (fl_chart).
    """
    servicio = ServicioConsumo(db=db, redis_client=redis_client)
    historial = await servicio.consultar_historial(
        usuario_id=UUID(current_user_id),
        cod_socio=cod_socio,
        forzar_refresco=forzar_refresco,
        meses=meses,
    )

    # Despachar evento de Historial de Facturas a COSMOL-Reportes en segundo plano
    try:
        cod_socio_int = int(str(cod_socio).strip())
    except (ValueError, TypeError):
        cod_socio_int = 0

    background_tasks.add_task(
        despachar_auditoria_reportes,
        codigo_socio=cod_socio_int,
        nombres=f"SOCIO {cod_socio_int}",
        id_tipo=3,
        tipo_consulta="Historial de Facturas",
    )

    return historial


@router.post(
    "/{cod_socio}/invalidar-cache",
    status_code=status.HTTP_200_OK,
    summary="Invalidar caché de consumo en Redis",
    description="Fuerza la eliminación de la clave en Redis para recargar lecturas frescas.",
)
async def invalidar_cache_consumo(
    cod_socio: str,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
    redis_client: Redis = Depends(get_redis),
) -> Dict[str, Any]:
    """
    Invalida manualmente la caché de Redis para un suministro del usuario.
    """
    servicio = ServicioConsumo(db=db, redis_client=redis_client)
    # Validamos primero que el suministro pertenezca al usuario
    await servicio.consultar_historial(
        usuario_id=UUID(current_user_id),
        cod_socio=cod_socio,
        forzar_refresco=False,
        meses=1,
    )
    resultado = await servicio.invalidar_cache_consumo(cod_socio=cod_socio)
    return {
        "cod_socio": cod_socio,
        "cache_invalidada": resultado,
        "mensaje": f"Caché de consumo para suministro '{cod_socio}' invalidada correctamente.",
    }
