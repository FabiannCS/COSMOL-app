"""
Configuración global y fixtures de pytest para pruebas unitarias y de integración.
"""
from typing import AsyncGenerator
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from app.main import app


@pytest_asyncio.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    """
    Fixture que provee un cliente HTTP asíncrono para probar los endpoints de FastAPI.
    """
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
