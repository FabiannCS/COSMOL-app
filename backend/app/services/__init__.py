"""
Capa de lógica de negocio desacoplada:
- ServicioAutenticacion: Onboarding, verificación OTP en Redis, emisión de JWT y bloqueo por intentos fallidos.
- ServicioSuministros: Vinculación y gestión multicuenta de suministros (Titular vs Consulta/Pago).
- servicio_cache_deuda: Utilitarios Redis para almacenamiento acelerado (<20ms) e invalidación de deudas (DEV 1).
"""
from app.services.servicio_autenticacion import ServicioAutenticacion
from app.services.servicio_suministros import ServicioSuministros
from app.services.servicio_cache_deuda import (
    guardar_deuda_cache,
    obtener_deuda_cache,
    invalidar_deuda_cache,
    construir_clave_cache_deuda,
)

__all__ = [
    "ServicioAutenticacion",
    "ServicioSuministros",
    "guardar_deuda_cache",
    "obtener_deuda_cache",
    "invalidar_deuda_cache",
    "construir_clave_cache_deuda",
]
