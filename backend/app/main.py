import logging
import sys
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.exceptions import register_exception_handlers
from app.core.redis import init_redis_pool, close_redis_pool
from app.api.v1.router import api_router

# Configuración de Logging para stdout en Docker
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)


import asyncio
from app.tasks.auditoria_reportes import worker_flusher_auditoria


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Ciclo de vida de la aplicación FastAPI:
    - Inicializa conexiones y worker de reintentos en segundo plano al arrancar.
    - Cierra recursos y cancela workers ordenadamente al terminar.
    """
    # Startup
    await init_redis_pool()
    flusher_task = asyncio.create_task(worker_flusher_auditoria(intervalo_segundos=30))
    yield
    # Shutdown
    flusher_task.cancel()
    try:
        await flusher_task
    except asyncio.CancelledError:
        pass
    await close_redis_pool()


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="API REST Backend (BFF) para la plataforma de socios de COSMOL R.L.",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    lifespan=lifespan
)

# Configuración de CORS
if settings.BACKEND_CORS_ORIGINS:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.BACKEND_CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

# Registro de manejadores estándar de excepciones
register_exception_handlers(app)

# Montaje de router maestro de la versión 1 (v1)
app.include_router(api_router, prefix=settings.API_V1_STR)


@app.get("/", tags=["Root"])
async def root():
    return {
        "message": "Bienvenido a la API de COSMOL R.L.",
        "docs": "/docs",
        "health": f"{settings.API_V1_STR}/health"
    }
