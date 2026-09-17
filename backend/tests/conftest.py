"""
Configuración global y fixtures de pytest para pruebas unitarias y de integración.
"""
from typing import AsyncGenerator
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
import redis.asyncio as aioredis
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.api.deps import get_db, get_redis
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


@pytest_asyncio.fixture(autouse=True)
async def db_override():
    """
    Garantiza que cada prueba asíncrona tenga su propio motor PostgreSQL con NullPool,
    evitando que conexiones en el pool global queden vinculadas a event loops cerrados.
    """
    test_engine = create_async_engine(
        settings.DATABASE_URL,
        poolclass=NullPool,
        future=True,
    )
    test_session_maker = async_sessionmaker(
        bind=test_engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )

    async def _test_get_db() -> AsyncGenerator[AsyncSession, None]:
        async with test_session_maker() as session:
            try:
                yield session
            finally:
                await session.close()

    app.dependency_overrides[get_db] = _test_get_db
    yield
    app.dependency_overrides.pop(get_db, None)
    await test_engine.dispose()


@pytest_asyncio.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """
    Fixture directa para pruebas que requieran interactuar directamente con la base de datos.
    """
    test_engine = create_async_engine(
        settings.DATABASE_URL,
        poolclass=NullPool,
        future=True,
    )
    test_session_maker = async_sessionmaker(
        bind=test_engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with test_session_maker() as session:
        yield session
    await test_engine.dispose()


@pytest_asyncio.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    """
    Fixture que provee un cliente HTTP asíncrono para probar los endpoints de FastAPI.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

