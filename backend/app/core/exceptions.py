from typing import Any, Dict, Optional
from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


class AppException(Exception):
    """
    Excepción base para todos los errores de lógica de negocio de la aplicación.
    Garantiza una estructura de respuesta JSON predecible para el cliente (Flutter / Web).
    """
    def __init__(
        self,
        message: str,
        error_code: str = "INTERNAL_ERROR",
        status_code: int = status.HTTP_400_BAD_REQUEST,
        details: Optional[Any] = None
    ):
        self.message = message
        self.error_code = error_code
        self.status_code = status_code
        self.details = details
        super().__init__(message)


class NotFoundException(AppException):
    def __init__(self, message: str = "Recurso no encontrado", error_code: str = "NOT_FOUND", details: Optional[Any] = None):
        super().__init__(
            message=message,
            error_code=error_code,
            status_code=status.HTTP_404_NOT_FOUND,
            details=details
        )


class BadRequestException(AppException):
    def __init__(self, message: str = "Solicitud inválida", error_code: str = "BAD_REQUEST", details: Optional[Any] = None):
        super().__init__(
            message=message,
            error_code=error_code,
            status_code=status.HTTP_400_BAD_REQUEST,
            details=details
        )


class UnauthorizedException(AppException):
    def __init__(self, message: str = "Credenciales inválidas o sesión expirada", error_code: str = "UNAUTHORIZED", details: Optional[Any] = None):
        super().__init__(
            message=message,
            error_code=error_code,
            status_code=status.HTTP_401_UNAUTHORIZED,
            details=details
        )


class ForbiddenException(AppException):
    def __init__(self, message: str = "Acceso denegado al recurso", error_code: str = "FORBIDDEN", details: Optional[Any] = None):
        super().__init__(
            message=message,
            error_code=error_code,
            status_code=status.HTTP_403_FORBIDDEN,
            details=details
        )


class ConflictException(AppException):
    def __init__(self, message: str = "Conflicto con el estado actual del recurso", error_code: str = "CONFLICT", details: Optional[Any] = None):
        super().__init__(
            message=message,
            error_code=error_code,
            status_code=status.HTTP_409_CONFLICT,
            details=details
        )


async def app_exception_handler(request: Request, exc: AppException) -> JSONResponse:
    """
    Captura y formatea las excepciones de negocio AppException.
    """
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "error": {
                "code": exc.error_code,
                "message": exc.message,
                "details": exc.details
            }
        }
    )


async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    """
    Captura y formatea los errores de validación de esquemas Pydantic / FastAPI.
    """
    errors = []
    for err in exc.errors():
        field = " -> ".join([str(loc) for loc in err.get("loc", []) if loc != "body"])
        errors.append({
            "field": field,
            "message": err.get("msg", "Error de validación"),
            "type": err.get("type", "")
        })

    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "success": False,
            "error": {
                "code": "VALIDATION_ERROR",
                "message": "Los datos enviados no cumplen con el formato requerido",
                "details": errors
            }
        }
    )


def register_exception_handlers(app: FastAPI) -> None:
    """
    Registra los manejadores de excepciones estándar en la aplicación FastAPI.
    """
    app.add_exception_handler(AppException, app_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
