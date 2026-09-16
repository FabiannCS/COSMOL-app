import redis.asyncio as aioredis
from typing import Optional
from app.core.config import settings

# Cliente global de Redis
redis_client: Optional[aioredis.Redis] = None


async def init_redis_pool() -> aioredis.Redis:
    """
    Inicializa el pool de conexiones asíncronas con Redis.
    """
    global redis_client
    redis_client = aioredis.from_url(
        settings.REDIS_URL,
        encoding="utf-8",
        decode_responses=True
    )
    return redis_client


async def close_redis_pool():
    """
    Cierra la conexión con Redis ordenadamente al apagar el servidor.
    """
    global redis_client
    if redis_client:
        await redis_client.close()


async def get_redis() -> aioredis.Redis:
    """
    Dependencia FastAPI para inyectar la instancia de Redis.
    """
    global redis_client
    if redis_client is None:
        redis_client = await init_redis_pool()
    return redis_client
