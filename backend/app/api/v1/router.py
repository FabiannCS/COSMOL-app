from fastapi import APIRouter
from app.api.v1.health import router as health_router

# Router agregador principal para la versión 1 de la API
api_router = APIRouter()

from app.api.v1.autenticacion import router as autenticacion_router
from app.api.v1.deuda import router as deuda_router

# 1. Endpoint de verificación y salud
api_router.include_router(health_router, prefix="", tags=["Salud del Sistema"])

# 2. Módulo de Identidad, Onboarding Dual OTP y Autenticación (DEV 2)
api_router.include_router(
    autenticacion_router,
    prefix="/autenticacion",
    tags=["Identidad, Onboarding OTP y Multicuenta"]
)

# 3. Módulo de Consulta de Deuda y Dashboard (DEV 2)
api_router.include_router(
    deuda_router,
    prefix="/deuda",
    tags=["Consulta de Deuda y Dashboard"]
)

# ------------------------------------------------------------------------------
# PUNTOS DE ENGANCHE PARA MÓDULOS DE NEGOCIO RESTANTES:
# ------------------------------------------------------------------------------
# from app.api.v1.socio import router as socio_router
# from app.api.v1.documents import router as documents_router
# from app.api.v1.payments import router as payments_router
#
# api_router.include_router(socio_router, prefix="/socio", tags=["Gestión de Socio y Deuda"])
# api_router.include_router(documents_router, prefix="/documents", tags=["Facturas y Avisos"])
# api_router.include_router(payments_router, prefix="/payments", tags=["Pasarelas de Pago"])

