"""
Esquemas Pydantic v2 para el detalle fiscal oficial de Facturas SIAT (COSMOL R.L.).
Estructura los datos requeridos por Flutter para la visualización en pantalla
y auditoría fiscal conforme a la normativa de facturación electrónica.
"""
from typing import List, Optional
from pydantic import BaseModel, Field, ConfigDict


class ItemFacturaDetalle(BaseModel):
    """
    Desglose unitario de un concepto facturado (agua, alcantarillado, fondos, tasas, etc.).
    """
    model_config = ConfigDict(populate_by_name=True)

    prefijo: Optional[str] = Field(None, description="Prefijo contable del concepto")
    codigo_servicio: str = Field(..., description="Código del servicio o producto facturado")
    cantidad: float = Field(1.0, description="Cantidad facturada")
    unidad_medida: str = Field("SERVICIO", description="Unidad de medida (ej: SERVICIO, M3)")
    concepto: str = Field(..., description="Descripción detallada del concepto")
    precio_unitario: float = Field(..., description="Precio unitario en Bolivianos (Bs)")
    descuento: float = Field(0.0, description="Descuento aplicado en Bs")
    subtotal: float = Field(..., description="Subtotal del ítem en Bs")


class FacturaDetalleResponse(BaseModel):
    """
    Respuesta estructurada completa del detalle fiscal de una factura oficial de COSMOL R.L.
    """
    model_config = ConfigDict(populate_by_name=True)

    # Identificación Fiscal
    nro_factura: str = Field(..., description="Número de factura interna en COSMOL")
    nro_factura_imp: str = Field(..., description="Número de factura fiscal emitido (NROFACIP)")
    cod_autorizacion: str = Field(..., description="Código de Autorización / CUF de Impuestos Nacionales")
    tipo_factura: str = Field("1", description="Tipo de factura (1: Con Derecho a Crédito Fiscal)")
    nit_emisor: str = Field("1028317027", description="NIT de la Cooperativa COSMOL R.L.")
    empresa: str = Field("COSMOL RL", description="Razón Social del emisor")
    actividad_economica: str = Field("CAPTACIÓN Y DISTRIBUCIÓN DE AGUA", description="Actividad económica fiscal")
    casa_matriz: str = Field("CASA MATRIZ", description="Sucursal o casa matriz")
    punto_venta: str = Field("No. punto de venta 0", description="Punto de venta fiscal")
    ciudad: str = Field("MONTERO", description="Municipio o ciudad de emisión")
    dir_empresa: str = Field("CALLE ISAIAS PARADA Nro. 219", description="Dirección legal del emisor")
    telf_empresa: str = Field("TELEFONO 392-20212 - 61555507", description="Teléfonos institucionales")

    # Datos del Socio / Contratante
    cod_socio: str = Field(..., description="Código de socio asignado en COSMOL")
    nombre_razon_social: str = Field(..., description="Nombre o razón social del titular facturado")
    nit_ci: str = Field(..., description="Cédula de Identidad o NIT del titular")
    direccion: str = Field(..., description="Dirección del inmueble o suministro")
    cod_ubicacion: str = Field(..., description="Código catastral o ubicación técnica")
    consumo_m3: int = Field(0, description="Volumen de agua potable consumido en m³")

    # Periodo y Fechas
    periodo_mes: int = Field(..., description="Mes del periodo facturado (1-12)")
    periodo_anio: int = Field(..., description="Año del periodo facturado")
    periodo_formateado: str = Field(..., description="Periodo en formato MM/YYYY")
    fecha_emision: str = Field(..., description="Fecha de emisión fiscal (YYYY-MM-DD)")

    # Montos e Importes
    subtotal: float = Field(..., description="Subtotal acumulado en Bolivianos (Bs)")
    descuento: float = Field(0.0, description="Descuento total en Bs")
    total: float = Field(..., description="Total a pagar en Bs")
    monto_gift_card: float = Field(0.0, description="Monto cubierto con tarjeta regalo / gift card")
    monto_a_pagar: float = Field(..., description="Monto neto a pagar en Bs")
    importe_credito_fiscal: float = Field(..., description="Importe base para crédito fiscal (IVA)")
    total_literal: str = Field(..., description="Importe total en palabras legales bolivianas")

    # Estado y Datos de Pago
    estado_factura: str = Field("0", description="Código del estado de factura (0: Pendiente, 1: Pagada, etc.)")
    fecha_pago: Optional[str] = Field(None, description="Fecha de pago si la factura fue cancelada")
    hora_pago: Optional[str] = Field(None, description="Hora de pago")
    caja_pago: Optional[str] = Field(None, description="Identificador de la caja o canal de cobro")

    # Leyendas Fiscales y Enlace QR
    codigo_qr: str = Field(..., description="URL oficial de validación del SIAT en Impuestos Nacionales")
    des_leyenda: str = Field(..., description="Leyenda de protección al consumidor (Ley N° 453)")
    leyenda_1: str = Field(..., description="Leyenda tributaria nacional")
    leyenda_3: str = Field(..., description="Leyenda de modalidad de facturación electrónica en línea")

    # Desglose de Servicios
    detalle: List[ItemFacturaDetalle] = Field(default_factory=list, description="Desglose de conceptos facturados")
    url_descarga_pdf: Optional[str] = Field(None, description="Ruta relativa para descargar o ver el PDF oficial")
