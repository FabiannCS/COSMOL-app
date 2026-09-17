"""
Configuración global y fixtures de pytest para pruebas unitarias y de integración.
"""
from typing import AsyncGenerator
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
import redis.asyncio as aioredis
from app.api.deps import get_redis
from app.core.config import settings
from app.main import app


@pytest_asyncio.fixture(autouse=True)
async def redis_override():
    """
    Garantiza que cada prueba asíncrona de pytest tenga su propia conexión de Redis
    vinculada al event loop actual, evitando el error de 'Event loop is closed'.
    """
    client = aioredis.from_url(
        settings.REDIS_URL,
        encoding="utf-8",
        decode_responses=True
    )
    app.dependency_overrides[get_redis] = lambda: client
    yield client
    await client.close()
    app.dependency_overrides.pop(get_redis, None)


@pytest_asyncio.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    """
    Fixture que provee un cliente HTTP asíncrono para probar los endpoints de FastAPI.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

