"""
Esquemas Pydantic v2 para el módulo de Consulta de Deuda y Dashboard (COSMOL R.L.).
Define las estructuras de respuesta con semaforización, montos en Bs y privacidad multicuenta.
"""
from datetime import date, datetime
from typing import List, Literal, Optional
from uuid import UUID
from pydantic import BaseModel, Field, ConfigDict


class FacturaPendienteResponse(BaseModel):
    """
    Representa una factura mensual impaga emitida por el sistema comercial de COSMOL.
    """
    model_config = ConfigDict(from_attributes=True)

    nro_facip: str = Field(..., description="Identificador interno del aviso de facturación")
    nro_factura: str = Field(..., description="Número de factura fiscal")
    cod_autorizacion: str = Field(..., description="Código de autorización digital SIAT/SIN")
    periodo: str = Field(..., description="Periodo de consumo en formato MM/YYYY (ej: '08/2026')")
    mes_lectura: str = Field(..., description="Nombre del mes y año (ej: 'Agosto 2026')")
    anio: int = Field(..., description="Año de facturación")
    mes: int = Field(..., description="Mes numérico de facturación (1-12)")
    monto_bs: float = Field(..., description="Monto total adeudado en Bolivianos (Bs)")
    esta_vencida: bool = Field(..., description="Indica si la fecha límite de pago de esta factura ya expiró")
    dias_mora: int = Field(0, description="Días transcurridos desde el vencimiento (0 si no está vencida)")


class DetalleSuministroResponse(BaseModel):
    """
    Datos catastrales y del titular del suministro en COSMOL.
    Aplica enmascaramiento automático de confidencialidad si el rol es CONSULTA_PAGO.
    """
    model_config = ConfigDict(from_attributes=True)

    cod_socio: str = Field(..., description="Código de socio / suministro en COSMOL")
    nombre_titular: str = Field(..., description="Nombre del titular (enmascarado para inquilinos)")
    ci_nit: str = Field(..., description="Cédula o NIT del titular (enmascarado para inquilinos)")
    direccion: str = Field(..., description="Dirección física del predio (enmascarada para inquilinos)")
    ubicacion: str = Field(..., description="Código técnico catastral ZONA.RUTA.NROC.NROI")
    categoria: str = Field("DOMESTICA", description="Categoría de tarifa del servicio")
    rol_usuario: Literal["TITULAR", "CONSULTA_PAGO"] = Field(
        ..., description="Nivel de acceso del usuario autenticado sobre este suministro"
    )


class ResumenDeudaResponse(BaseModel):
    """
    Resumen integral de deuda de un suministro específico con banderas de semaforización.
    """
    model_config = ConfigDict(from_attributes=True)

    cod_socio: str = Field(..., description="Código del suministro consultado")
    suministro: DetalleSuministroResponse = Field(..., description="Información descriptiva del suministro")
    moneda: str = Field("Bs", description="Unidad monetaria oficial (Bolivianos)")
    saldo_pendiente_bs: float = Field(..., description="Monto total adeudado acumulado en Bs")
    cantidad_facturas_pendientes: int = Field(..., description="Cantidad total de facturas impagas")
    fecha_proximo_vencimiento: Optional[date] = Field(
        None, description="Fecha de vencimiento de la factura más antigua pendiente"
    )
    esta_vencido: bool = Field(..., description="Indica si el socio tiene al menos una factura con fecha expirada")
    alerta_corte: bool = Field(
        ..., description="Bandera roja: true si adeuda 2 o más facturas o tiene orden de corte inminente"
    )
    mensaje_alerta: Optional[str] = Field(
        None, description="Mensaje institucional preventivo para el socio"
    )
    facturas_pendientes: List[FacturaPendienteResponse] = Field(
        default_factory=list, description="Lista detallada de facturas impagas ordenadas cronológicamente"
    )
    fecha_consulta: datetime = Field(
        default_factory=datetime.now, description="Marca de tiempo en que se generó la consulta"
    )
    origen_datos: Literal["CACHE", "SISTEMA_LEGADO"] = Field(
        ..., description="Indica si la respuesta se sirvió desde Redis (<20ms) o consultando el sistema legado"
    )


class DashboardMultiSuministroResponse(BaseModel):
    """
    Resumen consolidado para la pantalla de aterrizaje multicuenta.
    Agrupa todos los contratos vinculados al usuario con el balance total en Bs.
    """
    model_config = ConfigDict(from_attributes=True)

    usuario_id: UUID = Field(..., description="Identificador único del usuario digital")
    deuda_total_consolidada_bs: float = Field(..., description="Suma total de deudas de todos los suministros")
    cantidad_suministros: int = Field(..., description="Total de suministros administrados por el usuario")
    suministros: List[ResumenDeudaResponse] = Field(
        default_factory=list, description="Desglose individual de cada suministro vinculado"
    )
