import json
import logging
from typing import Any, Dict, Optional
from redis.asyncio import Redis

from app.core.config import settings

logger = logging.getLogger(__name__)

PREFIX_CACHE_DEUDA = "deuda"


def construir_clave_cache_deuda(cod_socio: str) -> str:
    """
    Construye el identificador de clave estándar en Redis para el socio.
    Ejemplo: 'deuda:540'
    """
    return f"{PREFIX_CACHE_DEUDA}:{str(cod_socio).strip()}"


async def guardar_deuda_cache(
    redis_client: Redis,
    cod_socio: str,
    datos: Dict[str, Any],
    ttl_seconds: Optional[int] = None
) -> bool:
    """
    Guarda el estado de deuda del socio en Redis con TTL de expiración.
    Por defecto TTL = settings.DEBT_CACHE_TTL_SECONDS (600 s = 10 minutos).
    Retorna True si se guardó exitosamente, o False si ocurrió algún fallo (degradación suave).
    """
    if redis_client is None:
        return False

    key = construir_clave_cache_deuda(cod_socio)
    ttl = ttl_seconds if ttl_seconds is not None else settings.DEBT_CACHE_TTL_SECONDS

    try:
        json_data = json.dumps(datos, ensure_ascii=False, default=str)
        await redis_client.set(key, json_data, ex=ttl)
        logger.debug(f"[CACHE DEUDA] Guardado exitoso para socio '{cod_socio}' (TTL: {ttl}s)")
        return True
    except Exception as exc:
        logger.warning(f"[CACHE DEUDA] No se pudo guardar en Redis para socio '{cod_socio}': {exc}")
        return False


async def obtener_deuda_cache(
    redis_client: Redis,
    cod_socio: str
) -> Optional[Dict[str, Any]]:
    """
    Recupera el estado de deuda en caché desde Redis (<5 ms).
    Retorna el diccionario deserializado o None en caso de cache-miss o desconexión.
    """
    if redis_client is None:
        return None

    key = construir_clave_cache_deuda(cod_socio)

    try:
        raw = await redis_client.get(key)
        if raw is None:
            return None

        if isinstance(raw, bytes):
            raw = raw.decode("utf-8")

        data = json.loads(raw)
        logger.debug(f"[CACHE DEUDA] Hit en caché para socio '{cod_socio}'")
        return data
    except Exception as exc:
        logger.warning(f"[CACHE DEUDA] Error al leer de Redis para socio '{cod_socio}': {exc}")
        return None


async def invalidar_deuda_cache(
    redis_client: Redis,
    cod_socio: str
) -> bool:
    """
    Invalida y elimina la clave de deuda en Redis.
    Utilizado tras un pago exitoso o cuando el usuario solicita refresco forzado.
    """
    if redis_client is None:
        return False

    key = construir_clave_cache_deuda(cod_socio)

    try:
        deleted = await redis_client.delete(key)
        logger.debug(f"[CACHE DEUDA] Clave invalidada para socio '{cod_socio}' (eliminadas: {deleted})")
        return bool(deleted > 0)
    except Exception as exc:
        logger.warning(f"[CACHE DEUDA] Error al invalidar clave para socio '{cod_socio}': {exc}")
        return False
