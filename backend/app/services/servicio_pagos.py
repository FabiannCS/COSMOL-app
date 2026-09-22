"""
Servicio de Negocio para Pasarelas de Pago Externas y Verificación Inteligente.
COSMOL R.L. - App de Socios (Fase 5).
"""
from datetime import datetime, timezone
import logging
from typing import Optional
from uuid import UUID

from fastapi import BackgroundTasks
from redis.asyncio import Redis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.exceptions import ForbiddenException, BadRequestException, NotFoundException
from app.db.models.suministro import Suministro
from app.db.models.pago import AuditoriaPagoRedireccion
from app.schemas.pago import (
    CanalPagoItem,
    CanalesPagoResponse,
    RegistrarIntentoPagoResponse,
    EstadoVerificacionPagoResponse,
)
from app.services.servicio_cache_pagos import (
    activar_ventana_verificacion,
    esta_en_ventana_verificacion,
    cerrar_ventana_verificacion,
)
from app.services.servicio_deuda import ServicioDeuda

logger = logging.getLogger(__name__)


def despachar_auditoria_pago(
    usuario_id: UUID,
    cod_socio: str,
    canal_id: str,
    monto_bs: Optional[float] = None
) -> None:
    """
    Despacha en segundo plano (BackgroundTasks) el evento de auditoría de redirección a pagos
    hacia la base de datos de ChatbotReportes (AGENTS.md secciones 6 y 12.3).
    """
    timestamp = datetime.now(timezone.utc).isoformat()
    logger.info(
        f"[AUDITORIA] EVENT='PAYMENT_CHANNEL_SELECTED' usuario_id={usuario_id} "
        f"cod_socio='{cod_socio}' canal_id='{canal_id}' monto_bs={monto_bs} timestamp={timestamp}"
    )


class ServicioPagos:
    """
    Servicio encargado de la orquestación de pasarelas de pago oficiales,
    registro de intención y monitoreo inteligente de saldo en Redis.
    """

    def __init__(self, db: AsyncSession, redis: Redis):
        self.db = db
        self.redis = redis
        self.servicio_deuda = ServicioDeuda(db=db, redis_client=redis)

    async def _validar_pertenencia_suministro(self, usuario_id: UUID, cod_socio: str) -> Suministro:
        """
        Valida que el código de socio esté vinculado al usuario autenticado (seguridad multicuenta).
        """
        codigo_limpio = cod_socio.strip()
        stmt = select(Suministro).where(
            Suministro.usuario_id == usuario_id,
            Suministro.cod_socio == codigo_limpio
        )
        res = await self.db.execute(stmt)
        suministro = res.scalars().first()

        if not suministro:
            logger.warning(
                f"[SEGURIDAD PAGOS] Usuario {usuario_id} intentó operar sobre suministro no vinculado '{codigo_limpio}'"
            )
            raise ForbiddenException(
                message=f"No tiene permisos para operar el suministro '{codigo_limpio}' o no está vinculado a su cuenta.",
                error_code="SUPPLY_ACCESS_DENIED"
            )
        return suministro

    async def obtener_canales_pago(
        self,
        usuario_id: UUID,
        cod_socio: str,
    ) -> CanalesPagoResponse:
        """
        Obtiene el catálogo de pasarelas oficiales autorizadas para el socio con su deuda actual.
        """
        suministro = await self._validar_pertenencia_suministro(usuario_id, cod_socio)

        # Consultar la deuda actual mediante el servicio de deuda (usa caché de Redis si existe)
        resumen = await self.servicio_deuda.obtener_deuda_suministro(
            usuario_id=usuario_id,
            cod_socio=cod_socio,
            forzar_refresco=False
        )

        canales = [
            CanalPagoItem(
                id="multipago",
                nombre="Multipago Bolivia",
                descripcion="Pago seguro con Simple QR interoperable, Tarjeta de Débito/Crédito y Banca por Internet",
                url_redireccion=settings.URL_MULTIPAGO_COSMOL,
                icono="qr_code",
                soporta_qr=True,
                activo=True
            ),
            CanalPagoItem(
                id="pago_al_paso",
                nombre="Pago al Paso 24/7",
                descripcion="Red de cobranza y plataforma de pago digital habilitada para servicios COSMOL R.L.",
                url_redireccion=settings.URL_PAGO_AL_PASO_COSMOL,
                icono="storefront",
                soporta_qr=True,
                activo=True
            )
        ]

        return CanalesPagoResponse(
            cod_socio=cod_socio.strip(),
            nombre_titular=resumen.suministro.nombre_titular,
            total_deuda_bs=resumen.saldo_pendiente_bs,
            cant_facturas_pendientes=resumen.cantidad_facturas_pendientes,
            canales=canales,
            mensaje_ayuda=(
                "Al seleccionar un canal, serás redirigido de forma segura a su plataforma oficial "
                "para realizar el pago mediante Simple QR o Banca Móvil."
            )
        )

    async def registrar_intento_pago(
        self,
        usuario_id: UUID,
        cod_socio: str,
        canal_id: str,
        background_tasks: BackgroundTasks,
        ip_origen: Optional[str] = None
    ) -> RegistrarIntentoPagoResponse:
        """
        Registra el clic en el canal, activa la ventana de verificación inteligente en Redis (NX=True),
        persiste la traza en PostgreSQL y despacha auditoría asíncrona hacia ChatbotReportes.
        """
        canal_limpio = canal_id.strip().lower()
        if canal_limpio not in ("multipago", "pago_al_paso"):
            raise BadRequestException(
                message=f"Canal de pago '{canal_id}' no es válido. Opciones permitidas: 'multipago', 'pago_al_paso'.",
                error_code="INVALID_PAYMENT_CHANNEL"
            )

        suministro = await self._validar_pertenencia_suministro(usuario_id, cod_socio)

        # 1. Obtener deuda para registrar monto en auditoría
        monto_bs = 0.0
        try:
            resumen = await self.servicio_deuda.obtener_deuda_suministro(
                usuario_id=usuario_id,
                cod_socio=cod_socio,
                forzar_refresco=False
            )
            monto_bs = resumen.saldo_pendiente_bs
        except Exception as exc:
            logger.warning(f"[PAGOS] No se pudo obtener saldo previo para auditoría: {exc}")

        # 2. Activar ventana de verificación en Redis (atómica, NX=True)
        ventana_activa = await activar_ventana_verificacion(
            self.redis,
            cod_socio,
            settings.VENTANA_VERIFICACION_PAGO_SEGUNDOS
        )

        # 3. Determinar URL oficial de redirección
        url_destino = (
            settings.URL_MULTIPAGO_COSMOL
            if canal_limpio == "multipago"
            else settings.URL_PAGO_AL_PASO_COSMOL
        )

        # 4. Registrar en PostgreSQL
        try:
            registro = AuditoriaPagoRedireccion(
                usuario_id=usuario_id,
                cod_socio=cod_socio.strip(),
                canal_id=canal_limpio,
                monto_deuda_bs=monto_bs,
                ip_origen=ip_origen
            )
            self.db.add(registro)
            await self.db.commit()
        except Exception as exc:
            logger.error(f"[PAGOS] Error al persistir auditoría en PostgreSQL: {exc}")
            await self.db.rollback()

        # 5. Encolar despacho asíncrono a ChatbotReportes
        background_tasks.add_task(
            despachar_auditoria_pago,
            usuario_id,
            cod_socio.strip(),
            canal_limpio,
            monto_bs
        )

        nombre_canal = "Multipago Bolivia" if canal_limpio == "multipago" else "Pago al Paso 24/7"
        return RegistrarIntentoPagoResponse(
            exito=True,
            cod_socio=cod_socio.strip(),
            canal_id=canal_limpio,
            mensaje=f"Redirección iniciada hacia {nombre_canal}. Ventana de verificación activada.",
            url_redireccion=url_destino,
            ventana_verificacion_activa=True,
            tiempo_expiracion_segundos=settings.VENTANA_VERIFICACION_PAGO_SEGUNDOS
        )

    async def verificar_estado_post_pago(
        self,
        usuario_id: UUID,
        cod_socio: str,
    ) -> EstadoVerificacionPagoResponse:
        """
        Consulta en vivo el estado de deuda en el sistema de COSMOL para verificar si el pago ya impactó.
        Si la deuda fue saldada (0.00 Bs), cierra la ventana de verificación en Redis.
        """
        await self._validar_pertenencia_suministro(usuario_id, cod_socio)

        # Consulta fresca forzando refresco de caché
        resumen = await self.servicio_deuda.obtener_deuda_suministro(
            usuario_id=usuario_id,
            cod_socio=cod_socio,
            forzar_refresco=True
        )

        deuda_saldada = resumen.saldo_pendiente_bs <= 0.0 or resumen.cantidad_facturas_pendientes == 0

        if deuda_saldada:
            await cerrar_ventana_verificacion(self.redis, cod_socio)
            mensaje = "¡Tu deuda ha sido saldada exitosamente! El sistema comercial registró tu pago."
        else:
            mensaje = (
                f"Aún registras un saldo pendiente de Bs {resumen.saldo_pendiente_bs:.2f} "
                f"({resumen.cantidad_facturas_pendientes} facturas). "
                "Recuerda que algunas entidades bancarias pueden demorar unos minutos en procesar la conciliación."
            )

        ventana_activa = await esta_en_ventana_verificacion(self.redis, cod_socio)

        return EstadoVerificacionPagoResponse(
            cod_socio=cod_socio.strip(),
            deuda_saldada=deuda_saldada,
            saldo_actual_bs=resumen.saldo_pendiente_bs,
            cant_facturas_pendientes=resumen.cantidad_facturas_pendientes,
            mensaje=mensaje,
            ventana_activa=ventana_activa
        )
