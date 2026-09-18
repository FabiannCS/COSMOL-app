"""
Esquemas Pydantic v2 para el repositorio digital de documentos (COSMOL R.L. - DEV 2).
Define los DTOs de salida para consulta por pestañas (Facturas, Avisos de Cobranza, Avisos de Corte)
y metadatos de descarga por streaming.
"""
from datetime import date
from typing import List, Literal, Optional
from uuid import UUID
from pydantic import BaseModel, Field, ConfigDict


class DocumentoResponse(BaseModel):
    """
    Metadatos de un documento digital disponible para consulta y descarga.
    """
    model_config = ConfigDict(from_attributes=True)

    id: UUID = Field(..., description="Identificador único universal del documento")
    cod_socio: str = Field(..., description="Código del socio o suministro asociado")
    tipo_documento: Literal["FACTURA", "AVISO_COBRANZA", "AVISO_CORTE"] = Field(
        ..., description="Tipo oficial de documento"
    )
    nro_factura: Optional[str] = Field(None, description="Número fiscal de la factura oficial")
    nro_facip: Optional[str] = Field(None, description="Número de aviso de cobranza interno FACIP")
    cod_autorizacion: Optional[str] = Field(None, description="Código de autorización digital SIAT")
    periodo: str = Field(..., description="Periodo de facturación en formato MM/YYYY")
    anio: int = Field(..., description="Año de emisión")
    mes: int = Field(..., description="Mes numérico de emisión (1-12)")
    monto_bs: float = Field(..., description="Importe del documento expresado en Bolivianos (Bs)")
    fecha_emision: date = Field(..., description="Fecha de emisión del documento")
    fecha_vencimiento: Optional[date] = Field(None, description="Fecha de vencimiento reglamentaria")
    estado_pago: str = Field("PENDIENTE", description="Estado de pago: 'PENDIENTE' o 'PAGADO'")
    s3_key: Optional[str] = Field(None, description="Clave de almacenamiento del objeto en MinIO S3")
    permite_descarga: bool = Field(True, description="Indica si el usuario actual tiene permisos de descarga")
    url_descarga: Optional[str] = Field(None, description="Ruta relativa o prefirmada para descarga directa")


class ListaDocumentosResponse(BaseModel):
    """
    Colección estructurada de documentos organizados para visualización
    por pestañas en la interfaz de usuario (Flutter / Web).
    Aplica exclusión de documentos fiscales/sensibles para el rol CONSULTA_PAGO.
    """
    model_config = ConfigDict(from_attributes=True)

    cod_socio: str = Field(..., description="Código de socio consultado")
    rol_acceso: Literal["TITULAR", "CONSULTA_PAGO"] = Field(
        ..., description="Rol del usuario autenticado sobre este suministro"
    )
    total_documentos: int = Field(..., description="Cantidad total de documentos disponibles")
    facturas: List[DocumentoResponse] = Field(
        default_factory=list,
        description="Listado de facturas oficiales (vacío para rol CONSULTA_PAGO)"
    )
    avisos_cobranza: List[DocumentoResponse] = Field(
        default_factory=list,
        description="Listado de avisos de cobranza preventivos"
    )
    avisos_corte: List[DocumentoResponse] = Field(
        default_factory=list,
        description="Listado de notificaciones de corte por mora (vacío para rol CONSULTA_PAGO)"
    )
    documentos: List[DocumentoResponse] = Field(
        default_factory=list,
        description="Lista unificada de todos los documentos accesibles para este rol"
    )
