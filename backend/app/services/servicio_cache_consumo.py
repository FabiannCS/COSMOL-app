"""
Servicio de caché en Redis para el Historial de Consumo Mensual (COSMOL R.L.).
Permite responder en <20 ms, protegiendo al sistema comercial legado Informix
de consultas repetidas desde la aplicación móvil.
"""
import json
import logging
from typing import Any, Dict, List, Optional
from redis.asyncio import Redis

from app.core.config import settings

logger = logging.getLogger(__name__)

PREFIX_CACHE_CONSUMO = "consumo"


def construir_clave_cache_consumo(cod_socio: str) -> str:
    """
    Construye el identificador de clave estándar en Redis para el consumo del socio.
    Ejemplo: 'consumo:540'
    """
    return f"{PREFIX_CACHE_CONSUMO}:{str(cod_socio).strip()}"


async def guardar_consumo_cache(
    redis_client: Redis,
    cod_socio: str,
    datos: Any,
    ttl_seconds: Optional[int] = None
) -> bool:
    """
    Almacena los datos de consumo del socio en Redis con TTL de expiración.
    Por defecto TTL = settings.CONSUMO_CACHE_TTL_SECONDS (900 s = 15 minutos).
    Retorna True si se guardó exitosamente, o False si ocurrió algún fallo (degradación suave).
    """
    if redis_client is None:
        return False

    key = construir_clave_cache_consumo(cod_socio)
    ttl = ttl_seconds if ttl_seconds is not None else settings.CONSUMO_CACHE_TTL_SECONDS

    try:
        json_data = json.dumps(datos, ensure_ascii=False, default=str)
        await redis_client.set(key, json_data, ex=ttl)
        logger.debug(f"[CACHE CONSUMO] Guardado exitoso para socio '{cod_socio}' (TTL: {ttl}s)")
        return True
    except Exception as exc:
        logger.warning(f"[CACHE CONSUMO] No se pudo guardar en Redis para socio '{cod_socio}': {exc}")
        return False


async def obtener_consumo_cache(
    redis_client: Redis,
    cod_socio: str
) -> Optional[Any]:
    """
    Recupera el historial de consumo en caché desde Redis (<5 ms).
    Retorna los datos deserializados (Dict o List) o None en caso de cache-miss o desconexión.
    """
    if redis_client is None:
        return None

    key = construir_clave_cache_consumo(cod_socio)

    try:
        raw = await redis_client.get(key)
        if raw is None:
            return None

        if isinstance(raw, bytes):
            raw = raw.decode("utf-8")

        data = json.loads(raw)
        logger.debug(f"[CACHE CONSUMO] Hit en caché para socio '{cod_socio}'")
        return data
    except Exception as exc:
        logger.warning(f"[CACHE CONSUMO] Error al leer de Redis para socio '{cod_socio}': {exc}")
        return None


async def invalidar_consumo_cache(
    redis_client: Redis,
    cod_socio: str
) -> bool:
    """
    Invalida y elimina la clave de consumo en Redis.
    Utilizado ante solicitud de pull-to-refresh en móvil o cambios en las mediciones.
    """
    if redis_client is None:
        return False

    key = construir_clave_cache_consumo(cod_socio)

    try:
        deleted = await redis_client.delete(key)
        logger.debug(f"[CACHE CONSUMO] Clave invalidada para socio '{cod_socio}' (eliminadas: {deleted})")
        return bool(deleted > 0)
    except Exception as exc:
        logger.warning(f"[CACHE CONSUMO] Error al invalidar clave para socio '{cod_socio}': {exc}")
        return False
