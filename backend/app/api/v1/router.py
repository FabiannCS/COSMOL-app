from fastapi import APIRouter
from app.api.v1.health import router as health_router

# Router agregador principal para la versión 1 de la API
api_router = APIRouter()

# 1. Endpoint de verificación y salud
api_router.include_router(health_router, prefix="", tags=["Salud del Sistema"])

# ------------------------------------------------------------------------------
# PUNTOS DE ENGANCHE PARA MÓDULOS DE NEGOCIO (Dev 2 / Backend):
# ------------------------------------------------------------------------------
# from app.api.v1.auth import router as auth_router
# from app.api.v1.socio import router as socio_router
# from app.api.v1.documents import router as documents_router
# from app.api.v1.payments import router as payments_router
#
# api_router.include_router(auth_router, prefix="/auth", tags=["Autenticación y OTP"])
# api_router.include_router(socio_router, prefix="/socio", tags=["Gestión de Socio y Deuda"])
# api_router.include_router(documents_router, prefix="/documents", tags=["Facturas y Avisos"])
# api_router.include_router(payments_router, prefix="/payments", tags=["Pasarelas de Pago"])
