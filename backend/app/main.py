from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.redis import init_redis_pool, close_redis_pool
from app.api.v1.health import router as health_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Ciclo de vida de la aplicación FastAPI:
    - Inicializa conexiones al arrancar.
    - Cierra recursos ordenadamente al terminar.
    """
    # Startup
    await init_redis_pool()
    yield
    # Shutdown
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

# Montaje de routers de la versión 1
app.include_router(health_router, prefix=settings.API_V1_STR)


@app.get("/", tags=["Root"])
async def root():
    return {
        "message": "Bienvenido a la API de COSMOL R.L.",
        "docs": "/docs",
        "health": f"{settings.API_V1_STR}/health"
    }
