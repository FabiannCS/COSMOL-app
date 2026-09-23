"""
Endpoints de la API REST para Consulta de Deuda y Dashboard Multicuenta (COSMOL R.L.).
Provee endpoints de alto rendimiento (<20ms con Redis) protegidos con JWT Bearer.
"""
from typing import Any, Dict
from uuid import UUID
import logging
from fastapi import APIRouter, BackgroundTasks, Depends, Query, status
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user_id, get_db, get_redis
from app.schemas.deuda import (
    DashboardMultiSuministroResponse,
    ResumenDeudaResponse,
)
from app.services.servicio_deuda import ServicioDeuda
from app.tasks.auditoria_reportes import despachar_auditoria_reportes

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
    background_tasks: BackgroundTasks,
    forzar_refresco: bool = Query(
        False,
        description="Si es true, ignora la caché de Redis y consulta en vivo al sistema comercial legado."
    ),
    force_refresh: bool = Query(
        False,
        description="Alias en inglés para forzar_refresco."
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
    - Si existe una ventana de verificación activa (pago_en_proceso), consulta en vivo a Informix.
    - Rechaza con HTTP 403 si el suministro no pertenece al usuario autenticado.
    """
    from app.services.servicio_cache_pagos import esta_en_ventana_verificacion, cerrar_ventana_verificacion

    refresco_efectivo = forzar_refresco or force_refresh
    if not refresco_efectivo:
        # Si el socio tiene un pago en proceso en pasarela externa, consultar fresco
        if await esta_en_ventana_verificacion(redis_client, cod_socio):
            refresco_efectivo = True

    servicio = ServicioDeuda(db=db, redis_client=redis_client)
    resumen = await servicio.obtener_deuda_suministro(
        usuario_id=UUID(current_user_id),
        cod_socio=cod_socio,
        forzar_refresco=refresco_efectivo
    )

    # Si la deuda ya fue liquidada (saldo 0 Bs), cerrar ventana de verificación
    if resumen.saldo_pendiente_bs <= 0.0 or resumen.cantidad_facturas_pendientes == 0:
        await cerrar_ventana_verificacion(redis_client, cod_socio)

    # Despachar evento de Consulta de Deuda a COSMOL-Reportes en segundo plano
    try:
        cod_socio_int = int(str(cod_socio).strip())
    except (ValueError, TypeError):
        cod_socio_int = 0

    nombre_titular = (
        resumen.suministro.nombre_titular
        if hasattr(resumen, "suministro") and resumen.suministro and hasattr(resumen.suministro, "nombre_titular")
        else None
    ) or f"SOCIO {cod_socio_int}"

    background_tasks.add_task(
        despachar_auditoria_reportes,
        codigo_socio=cod_socio_int,
        nombres=nombre_titular,
        id_tipo=2,
        tipo_consulta="Consulta de Deuda",
    )

    return resumen


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
