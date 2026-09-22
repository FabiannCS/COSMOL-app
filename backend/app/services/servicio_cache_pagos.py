import logging
from typing import Optional
from redis.asyncio import Redis

from app.core.config import settings
from app.services.servicio_cache_deuda import invalidar_deuda_cache

logger = logging.getLogger(__name__)

PREFIX_CACHE_PAGO_EN_PROCESO = "pago_en_proceso"


def construir_clave_pago_en_proceso(cod_socio: str) -> str:
    """
    Construye la clave de Redis para la bandera de pago en proceso.
    Ejemplo: 'pago_en_proceso:540'
    """
    return f"{PREFIX_CACHE_PAGO_EN_PROCESO}:{str(cod_socio).strip()}"


async def activar_ventana_verificacion(
    redis_client: Redis,
    cod_socio: str,
    ttl_seconds: Optional[int] = None
) -> bool:
    """
    Activa la ventana de verificación post-pago para un socio.

    Comportamiento:
    1. Ejecuta SET con la opción NX=True (Not eXists) para ser 100% IDEMPOTENTE.
       Si el socio da dos o más clics a la URL, Redis no altera ni reinicia el temporizador.
    2. Invalida de inmediato la caché de deuda anterior (deuda:{cod_socio})
       para que la próxima consulta lea directamente de Informix.

    Retorna:
    - True: Si la ventana se activó por primera vez (clave creada).
    - False: Si la ventana ya estaba activa (doble clic o reintento).
    """
    if redis_client is None:
        return False

    key = construir_clave_pago_en_proceso(cod_socio)
    ttl = ttl_seconds if ttl_seconds is not None else settings.VENTANA_VERIFICACION_PAGO_SEGUNDOS

    try:
        # SET ... EX ttl NX: atómico e idempotente
        resultado = await redis_client.set(key, "activo", ex=ttl, nx=True)
        fue_activado = bool(resultado)

        # Siempre purgar la deuda cacheada para asegurar datos frescos
        await invalidar_deuda_cache(redis_client, cod_socio)

        if fue_activado:
            logger.info(
                f"[PAGOS CACHE] Ventana de verificación activada para socio '{cod_socio}' "
                f"(TTL: {ttl}s, clave: '{key}')"
            )
        else:
            logger.debug(
                f"[PAGOS CACHE] Clic reiterado detectado para socio '{cod_socio}'. "
                f"Ventana ya se encontraba activa (NX=True protegió el temporizador)."
            )

        return fue_activado
    except Exception as exc:
        logger.warning(
            f"[PAGOS CACHE] Error al activar ventana de verificación para socio '{cod_socio}': {exc}"
        )
        return False


async def esta_en_ventana_verificacion(
    redis_client: Redis,
    cod_socio: str
) -> bool:
    """
    Verifica si el socio se encuentra dentro de la ventana de verificación de pago.
    Retorna True si la clave existe en Redis, o False si no existe o expiró.
    """
    if redis_client is None:
        return False

    key = construir_clave_pago_en_proceso(cod_socio)

    try:
        existe = await redis_client.exists(key)
        return bool(existe > 0)
    except Exception as exc:
        logger.warning(
            f"[PAGOS CACHE] Error al consultar ventana de verificación para socio '{cod_socio}': {exc}"
        )
        return False


async def cerrar_ventana_verificacion(
    redis_client: Redis,
    cod_socio: str
) -> bool:
    """
    Cierra la ventana de verificación y elimina la clave en Redis.
    Se invoca cuando el backend detecta que la deuda en Informix ha sido saldada (Bs 0.00).
    """
    if redis_client is None:
        return False

    key = construir_clave_pago_en_proceso(cod_socio)

    try:
        eliminadas = await redis_client.delete(key)
        logger.info(
            f"[PAGOS CACHE] Ventana de verificación cerrada para socio '{cod_socio}' "
            f"(claves eliminadas: {eliminadas})"
        )
        return bool(eliminadas > 0)
    except Exception as exc:
        logger.warning(
            f"[PAGOS CACHE] Error al cerrar ventana de verificación para socio '{cod_socio}': {exc}"
        )
        return False


async def obtener_tiempo_restante_ventana(
    redis_client: Redis,
    cod_socio: str
) -> int:
    """
    Retorna los segundos restantes de la ventana de verificación en Redis.
    Retorna:
    - > 0: Segundos restantes antes de que la ventana expire.
    - -1: Si la clave existe pero no tiene TTL asignado.
    - -2: Si la clave no existe o ya expiró.
    """
    if redis_client is None:
        return -2

    key = construir_clave_pago_en_proceso(cod_socio)

    try:
        ttl = await redis_client.ttl(key)
        return int(ttl)
    except Exception as exc:
        logger.warning(
            f"[PAGOS CACHE] Error al obtener TTL de ventana para socio '{cod_socio}': {exc}"
        )
        return -2
