"""
Endpoints de la API REST para Pasarelas de Pago Externas y Verificación Inteligente.
COSMOL R.L. - App de Socios (Fase 5).
"""
import logging
from uuid import UUID
from fastapi import APIRouter, BackgroundTasks, Depends, Request, status
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user_id, get_db, get_redis
from app.schemas.pago import (
    CanalesPagoResponse,
    RegistrarIntentoPagoRequest,
    RegistrarIntentoPagoResponse,
    EstadoVerificacionPagoResponse,
)
from app.services.servicio_pagos import ServicioPagos
from app.tasks.auditoria_reportes import despachar_auditoria_reportes

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get(
    "/canales/{cod_socio}",
    response_model=CanalesPagoResponse,
    status_code=status.HTTP_200_OK,
    summary="Obtener canales oficiales de pago para el socio",
    description="Retorna la lista dinámica de pasarelas de pago (Multipago y Pago al Paso) con sus URLs oficiales y el saldo adeudado en Bs.",
)
async def obtener_canales_pago(
    cod_socio: str,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
) -> CanalesPagoResponse:
    """
    Entrega el catálogo de pasarelas de recaudación autorizadas por COSMOL R.L.
    Permite a Flutter construir el BottomSheet dinámico sin quemar URLs en la app móvil.
    """
    servicio = ServicioPagos(db=db, redis=redis)
    return await servicio.obtener_canales_pago(
        usuario_id=UUID(current_user_id),
        cod_socio=cod_socio
    )


@router.post(
    "/registrar-intento/{cod_socio}",
    response_model=RegistrarIntentoPagoResponse,
    status_code=status.HTTP_200_OK,
    summary="Registrar intención de pago e iniciar ventana de verificación",
    description="Registra el clic en el canal seleccionado, activa la ventana de verificación en Redis (NX=True) y despacha auditoría asíncrona hacia ChatbotReportes.",
)
async def registrar_intento_pago(
    cod_socio: str,
    payload: RegistrarIntentoPagoRequest,
    request: Request,
    background_tasks: BackgroundTasks,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
) -> RegistrarIntentoPagoResponse:
    """
    Activa la ventana de verificación inteligente (15 min) en Redis con SET NX=True.
    Invalida la caché previa de deuda y entrega la URL oficial que Flutter abrirá con url_launcher.
    """
    servicio = ServicioPagos(db=db, redis=redis)
    ip_origen = request.client.host if request.client else None
    respuesta = await servicio.registrar_intento_pago(
        usuario_id=UUID(current_user_id),
        cod_socio=cod_socio,
        canal_id=payload.canal_id,
        background_tasks=background_tasks,
        ip_origen=ip_origen
    )

    # Despachar evento de Intento de Pago a COSMOL-Reportes en segundo plano (Contrato § 4)
    try:
        cod_socio_int = int(str(cod_socio).strip())
    except (ValueError, TypeError):
        cod_socio_int = 0

    background_tasks.add_task(
        despachar_auditoria_reportes,
        codigo_socio=cod_socio_int,
        nombres=f"SOCIO {cod_socio_int}",
        id_tipo=10,
        tipo_consulta="Intento de Pago",
    )

    return respuesta


@router.get(
    "/verificar-estado/{cod_socio}",
    response_model=EstadoVerificacionPagoResponse,
    status_code=status.HTTP_200_OK,
    summary="Verificar impacto del pago en el sistema comercial",
    description="Consulta en vivo al sistema comercial Informix de COSMOL para constatar si la deuda fue saldada (Saldo Bs 0.00). Si se saldó, cierra la ventana en Redis.",
)
async def verificar_estado_pago(
    cod_socio: str,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis),
) -> EstadoVerificacionPagoResponse:
    """
    Endpoint rápido para validación post-pago desde Flutter.
    """
    servicio = ServicioPagos(db=db, redis=redis)
    return await servicio.verificar_estado_post_pago(
        usuario_id=UUID(current_user_id),
        cod_socio=cod_socio
    )
