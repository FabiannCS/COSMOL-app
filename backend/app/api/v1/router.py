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

from app.api.v1.documentos import router as documentos_router
from app.api.v1.consumo import router as consumo_router

# 4. Módulo de Repositorio Digital de Documentos y Descarga PDF (DEV 2)
api_router.include_router(
    documentos_router,
    prefix="/documentos",
    tags=["Documentos y Facturas Digitales"]
)

# 5. Módulo de Analítica e Historial de Consumo (DEV 2)
api_router.include_router(
    consumo_router,
    prefix="/consumo",
    tags=["Analítica e Historial de Consumo"]
)

from app.api.v1.pagos import router as pagos_router

# 6. Módulo de Pasarelas de Pago Externas y Verificación Inteligente (DEV 2)
api_router.include_router(
    pagos_router,
    prefix="/pagos",
    tags=["Pasarelas de Pago y Recaudación"]
)


