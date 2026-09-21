"""
Capa de lógica de negocio desacoplada:
- ServicioAutenticacion: Onboarding, verificación OTP en Redis, emisión de JWT y bloqueo por intentos fallidos.
- ServicioSuministros: Vinculación y gestión multicuenta de suministros (Titular vs Consulta/Pago).
- servicio_cache_deuda: Utilitarios Redis para almacenamiento acelerado (<20ms) e invalidación de deudas (DEV 1).
"""
from app.services.servicio_autenticacion import ServicioAutenticacion
from app.services.servicio_suministros import ServicioSuministros
from app.services.servicio_deuda import ServicioDeuda
from app.services.servicio_cache_deuda import (
    guardar_deuda_cache,
    obtener_deuda_cache,
    invalidar_deuda_cache,
    construir_clave_cache_deuda,
)

from app.services.servicio_documentos import (
    ServicioDocumentos,
    registrar_auditoria_descarga,
)

from app.services.servicio_consumo import (
    ServicioConsumo,
    enmascarar_numero_medidor,
)
from app.services.servicio_cache_consumo import (
    guardar_consumo_cache,
    obtener_consumo_cache,
    invalidar_consumo_cache,
    construir_clave_cache_consumo,
)

__all__ = [
    "ServicioAutenticacion",
    "ServicioSuministros",
    "ServicioDeuda",
    "ServicioDocumentos",
    "ServicioConsumo",
    "enmascarar_numero_medidor",
    "registrar_auditoria_descarga",
    "guardar_deuda_cache",
    "obtener_deuda_cache",
    "invalidar_deuda_cache",
    "construir_clave_cache_deuda",
    "guardar_consumo_cache",
    "obtener_consumo_cache",
    "invalidar_consumo_cache",
    "construir_clave_cache_consumo",
]

