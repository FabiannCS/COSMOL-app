from typing import Any, AsyncGenerator, Dict, Optional
from fastapi import Depends
from fastapi.security import OAuth2PasswordBearer
import jwt
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.redis import get_redis as _get_redis
from app.core.security import decode_token
from app.core.exceptions import UnauthorizedException
from app.db.session import get_db as _get_db

# Esquema OAuth2 con Bearer Token (auto_error=False para personalizar el mensaje de error)
oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl=f"{settings.API_V1_STR}/auth/login",
    auto_error=False
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Dependencia de sesión de Base de Datos PostgreSQL.
    Re-exportada para conveniencia en endpoints: Depends(get_db).
    """
    async for session in _get_db():
        yield session


async def get_redis() -> Redis:
    """
    Dependencia de cliente Redis.
    Re-exportada para conveniencia en endpoints: Depends(get_redis).
    """
    return await _get_redis()


async def get_token_payload(token: Optional[str] = Depends(oauth2_scheme)) -> Dict[str, Any]:
    """
    Extrae, decodifica y valida el Bearer JWT Token de la cabecera Authorization.
    Lanza UnauthorizedException si no se envía o si el token no es válido.
    """
    if not token:
        raise UnauthorizedException(
            message="No se proporcionó token de autenticación",
            error_code="AUTH_TOKEN_MISSING"
        )
    try:
        payload = decode_token(token)
        if payload.get("type") != "access":
            raise UnauthorizedException(
                message="El token proporcionado no es un token de acceso válido",
                error_code="AUTH_TOKEN_INVALID_TYPE"
            )
        return payload
    except jwt.ExpiredSignatureError:
        raise UnauthorizedException(
            message="La sesión ha expirado. Por favor, inicie sesión nuevamente",
            error_code="AUTH_TOKEN_EXPIRED"
        )
    except (jwt.PyJWTError, Exception):
        raise UnauthorizedException(
            message="Token de autenticación inválido o corrupto",
            error_code="AUTH_TOKEN_INVALID"
        )


async def get_current_user_id(payload: Dict[str, Any] = Depends(get_token_payload)) -> str:
    """
    Obtiene el ID del usuario digital autenticado extraído directamente del JWT payload ('sub').
    """
    user_id: Optional[str] = payload.get("sub")
    if not user_id:
        raise UnauthorizedException(
            message="El token no contiene un identificador de usuario válido",
            error_code="AUTH_TOKEN_NO_SUBJECT"
        )
    return user_id
