from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
import redis.asyncio as aioredis

from app.db.session import get_db
from app.core.redis import get_redis
from app.core.config import settings

router = APIRouter(tags=["Salud del Sistema"])


@router.get(
    "/health",
    summary="Verificar estado del sistema",
    description="Comprueba la conectividad de la API con PostgreSQL y Redis.",
    status_code=status.HTTP_200_OK
)
async def health_check(
    db: AsyncSession = Depends(get_db),
    redis: aioredis.Redis = Depends(get_redis)
):
    postgres_status = "healthy"
    redis_status = "healthy"

    # 1. Comprobar PostgreSQL
    try:
        result = await db.execute(text("SELECT 1"))
        result.scalar()
    except Exception as exc:
        postgres_status = f"unhealthy: {str(exc)}"

    # 2. Comprobar Redis
    try:
        pong = await redis.ping()
        if not pong:
            redis_status = "unhealthy: ping fallido"
    except Exception as exc:
        redis_status = f"unhealthy: {str(exc)}"

    overall_status = "ok" if postgres_status == "healthy" and redis_status == "healthy" else "degraded"

    return {
        "status": overall_status,
        "app": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "environment": settings.ENVIRONMENT,
        "services": {
            "postgres": postgres_status,
            "redis": redis_status
        }
    }
