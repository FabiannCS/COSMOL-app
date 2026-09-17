"""
Capa de lógica de negocio desacoplada:
- ServicioAutenticacion: Onboarding, verificación OTP en Redis, emisión de JWT y bloqueo por intentos fallidos.
- ServicioSuministros: Vinculación y gestión multicuenta de suministros (Titular vs Consulta/Pago).
"""
from app.services.servicio_autenticacion import ServicioAutenticacion
from app.services.servicio_suministros import ServicioSuministros

__all__ = [
    "ServicioAutenticacion",
    "ServicioSuministros",
]
