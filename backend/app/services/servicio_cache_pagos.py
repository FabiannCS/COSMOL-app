"""
Servicio de Caché en Redis para la Ventana de Verificación Inteligente de Pagos.
COSMOL R.L. - App de Socios (Fase 5).
"""
import logging
from typing import Optional
from redis.asyncio import Redis

from app.core.config import settings

logger = logging.getLogger(__name__)

PREFIJO_VENTANA_PAGO = "pago_en_proceso:"
PREFIJO_CACHE_DEUDA = "deuda:"


async def activar_ventana_verificacion(
    redis: Redis,
    cod_socio: str,
    ttl: int = settings.VENTANA_VERIFICACION_PAGO_SEGUNDOS,
) -> bool:
    """
    Activa la ventana de verificación inteligente en Redis con opción atómica NX=True.
    Si el socio hace múltiples clics consecutivos, SET NX preserva el tiempo original
    sin resetear el contador de 15 minutos ni corromper el estado.
    Invalida de inmediato la clave de deuda en caché para forzar consulta fresca.
    """
    clave_ventana = f"{PREFIJO_VENTANA_PAGO}{cod_socio.strip()}"
    clave_deuda = f"{PREFIJO_CACHE_DEUDA}{cod_socio.strip()}"

    try:
        # SET NX=True: Solo establece la clave si NO existe previamente
        fue_activada = await redis.set(clave_ventana, "activo", ex=ttl, nx=True)

        # Purgar caché de deuda vieja
        await redis.delete(clave_deuda)

        if fue_activada:
            logger.info(f"[CACHE PAGOS] Ventana de verificación activada para socio '{cod_socio}' (TTL: {ttl}s).")
            return True
        else:
            logger.info(f"[CACHE PAGOS] Ventana ya estaba activa para socio '{cod_socio}', ignorando clic repetido (NX).")
            return False
    except Exception as exc:
        logger.error(f"[CACHE PAGOS] Error al activar ventana en Redis para socio '{cod_socio}': {exc}")
        return False


async def esta_en_ventana_verificacion(redis: Redis, cod_socio: str) -> bool:
    """
    Verifica si el socio se encuentra dentro de la ventana de verificación post-pago (15 minutos).
    """
    clave_ventana = f"{PREFIJO_VENTANA_PAGO}{cod_socio.strip()}"
    try:
        existe = await redis.exists(clave_ventana)
        return bool(existe > 0)
    except Exception as exc:
        logger.error(f"[CACHE PAGOS] Error al comprobar ventana en Redis para socio '{cod_socio}': {exc}")
        return False


async def cerrar_ventana_verificacion(redis: Redis, cod_socio: str) -> None:
    """
    Cierra la ventana de verificación al constatar que la deuda ha sido liquidada (Saldo Bs 0.00).
    """
    clave_ventana = f"{PREFIJO_VENTANA_PAGO}{cod_socio.strip()}"
    try:
        await redis.delete(clave_ventana)
        logger.info(f"[CACHE PAGOS] Ventana de verificación cerrada para socio '{cod_socio}' (deuda saldada).")
    except Exception as exc:
        logger.error(f"[CACHE PAGOS] Error al cerrar ventana en Redis para socio '{cod_socio}': {exc}")
