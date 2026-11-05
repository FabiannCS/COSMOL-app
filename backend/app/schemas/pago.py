"""
Esquemas Pydantic v2 para Pasarelas de Pago Externas y Verificación Inteligente (Fase 5).
COSMOL R.L. - App de Socios.
"""
from datetime import datetime, timezone
from typing import List, Optional
from pydantic import BaseModel, Field


class CanalPagoItem(BaseModel):
    """
    Representa una pasarela o red de recaudación autorizada por COSMOL.
    """
    id: str = Field(..., description="Identificador único del canal ('multipago' o 'pago_al_paso')")
    nombre: str = Field(..., description="Nombre comercial del canal")
    descripcion: str = Field(..., description="Detalle de medios aceptados (QR Simple, tarjetas, etc.)")
    url_redireccion: str = Field(..., description="URL oficial preconfigurada para abrir la pasarela")
    icono: str = Field(default="qr_code", description="Nombre del ícono visual en Flutter ('qr_code', 'storefront')")
    soporta_qr: bool = Field(default=True, description="Indica si la pasarela genera Simple QR de Bolivia")
    activo: bool = Field(default=True, description="Disponibilidad operativa del canal")


class CanalesPagoResponse(BaseModel):
    """
    Respuesta que entrega el catálogo dinámico de canales disponibles para un socio.
    """
    cod_socio: str = Field(..., description="Código de socio consultado")
    nombre_titular: str = Field(..., description="Nombre del titular o enmascarado según rol")
    total_deuda_bs: float = Field(..., description="Monto total adeudado en Bolivianos (Bs)")
    cant_facturas_pendientes: int = Field(..., description="Cantidad de facturas impagas")
    canales: List[CanalPagoItem] = Field(..., description="Lista de pasarelas oficiales autorizadas")
    mensaje_ayuda: str = Field(
        default="Al seleccionar un canal, serás redirigido de forma segura a su plataforma para completar el pago.",
        description="Instrucción amigable para el socio"
    )
    fecha_consulta: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        description="Marca de tiempo de la consulta"
    )


class RegistrarIntentoPagoRequest(BaseModel):
    """
    Petición enviada desde Flutter cuando el socio pulsa en pagar con un canal específico.
    """
    canal_id: str = Field(..., description="Identificador del canal seleccionado ('multipago' o 'pago_al_paso')")


class RegistrarIntentoPagoResponse(BaseModel):
    """
    Respuesta tras registrar la intención de pago e iniciar la ventana de verificación en Redis.
    """
    exito: bool = Field(default=True, description="Resultado de la operación")
    cod_socio: str = Field(..., description="Código de socio")
    canal_id: str = Field(..., description="Canal elegido")
    mensaje: str = Field(..., description="Mensaje explicativo para la UI")
    url_redireccion: str = Field(..., description="URL de pago a abrir con url_launcher")
    ventana_verificacion_activa: bool = Field(
        default=True,
        description="Indica si se activó la ventana de monitoreo inteligente en Redis"
    )
    tiempo_expiracion_segundos: int = Field(
        default=900,
        description="Tiempo de vigencia de la ventana de verificación (ej. 15 minutos)"
    )


class EstadoVerificacionPagoResponse(BaseModel):
    """
    Respuesta de verificación rápida post-pago.
    """
    cod_socio: str = Field(..., description="Código de socio")
    deuda_saldada: bool = Field(..., description="True si la deuda ya fue liquidada a 0.00 Bs")
    saldo_actual_bs: float = Field(..., description="Saldo vigente reportado por COSMOL en Bs")
    cant_facturas_pendientes: int = Field(..., description="Cantidad actual de facturas pendientes")
    mensaje: str = Field(..., description="Estado descriptivo para el socio")
    ventana_activa: bool = Field(..., description="Indica si la ventana de verificación sigue activa en Redis")


class SimularPagoRequest(BaseModel):
    """
    Petición para simular el flujo de pago demostrativo (solo vista / demo).
    """
    canal_id: str = Field(default="qr_simple", description="Canal de pago utilizado ('qr_simple', 'multipago', etc.)")
    monto_bs: float = Field(..., description="Monto en Bolivianos a pagar")
    periodos: Optional[str] = Field(default=None, description="Periodos o meses facturados (ej. '08/2026, 09/2026')")


class SimularPagoResponse(BaseModel):
    """
    Respuesta del comprobante de pago simulado (sin impacto financiero ni contable).
    """
    exito: bool = Field(default=True, description="Resultado de la simulación")
    cod_socio: str = Field(..., description="Código de socio")
    canal_id: str = Field(..., description="Canal simulado")
    nro_transaccion: str = Field(..., description="Número de transacción ficticio para la demostración")
    monto_bs: float = Field(..., description="Monto simulado en Bolivianos")
    fecha_pago: str = Field(..., description="Fecha y hora de la transacción simulada")
    mensaje: str = Field(..., description="Mensaje explicativo para la UI")
    es_simulacion: bool = Field(default=True, description="Indica explícitamente que es una simulación")

