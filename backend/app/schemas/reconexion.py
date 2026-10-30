from enum import IntEnum
from typing import List, Optional
from pydantic import BaseModel, Field, field_validator


class TipoReconexionEnum(IntEnum):
    CORTE_NORMAL = 1
    CON_MEDIDOR = 2
    CON_MATERIAL = 3
    OTROS = 4


class ReconexionHistorialItem(BaseModel):
    id_reconexion: int = Field(..., description="ID numérico de la orden de reconexión")
    fecha: Optional[str] = Field(None, description="Fecha y hora de registro")
    tipo: Optional[str] = Field(None, description="Tipo descriptivo de corte/reconexión")
    estado: str = Field(..., description="Estado actual: PENDIENTE, EN_PROCESO, FINALIZADO, etc.")
    glosa: Optional[str] = Field(None, description="Observaciones y referencias del inmueble")


class ElegibilidadReconexionResponse(BaseModel):
    codigo_socio: str = Field(..., description="Código fijo del socio")
    es_elegible: bool = Field(..., description="Indica si cumple con las reglas comerciales para solicitar reconexión")
    motivo_bloqueo: Optional[str] = Field(
        None,
        description="Código del motivo de bloqueo: 'TRAMITE_DUPLICADO', 'ALTA_MOROSIDAD', 'SOCIO_NO_ENCONTRADO'"
    )
    mensaje_usuario: str = Field(..., description="Mensaje explicativo para presentar al usuario en la UI")
    facturas_pendientes: int = Field(0, description="Cantidad de facturas impagas registradas")
    total_deuda_bs: float = Field(0.0, description="Monto total adeudado acumulado en Bs")
    tramite_pendiente_id: Optional[int] = Field(None, description="ID del trámite en curso si existe duplicidad")
    ubicacion_catastral: Optional[str] = Field(None, description="Ubicación técnica normalizada ZONA.RUTA.NROC.NROI")
    zona: Optional[int] = Field(None, description="Zona técnica")
    ruta: Optional[int] = Field(None, description="Ruta técnica")
    nombres: Optional[str] = Field(None, description="Nombre o razón social del titular")


class SolicitudReconexionCreate(BaseModel):
    codigo_socio: str = Field(..., description="Código fijo del socio a reconectar")
    id_tipo_reconexion: int = Field(
        1,
        ge=1,
        le=4,
        description="Tipo de reconexión: 1=Corte normal, 2=Con medidor, 3=Con material, 4=Otros"
    )
    coordenadas_gps: str = Field(
        ...,
        min_length=5,
        max_length=60,
        description="Coordenadas GPS en formato 'latitud, longitud'"
    )
    glosa: str = Field(
        ...,
        min_length=5,
        max_length=500,
        description="Descripción con referencias visibles del domicilio (color de puerta, árbol, etc.)"
    )
    foto_url: Optional[str] = Field(
        None,
        description="URL accesible de la fotografía de evidencia cargada previamente a MinIO"
    )

    @field_validator("glosa")
    @classmethod
    def validar_glosa(cls, v: str) -> str:
        limpio = v.strip()
        if len(limpio) < 5:
            raise ValueError("La descripción debe tener al menos 5 caracteres con referencias claras del domicilio.")
        return limpio


class SolicitudReconexionResponse(BaseModel):
    id_reconexion: int = Field(..., description="Número de ticket/orden de trabajo asignado en el sistema central")
    estado: str = Field(..., description="Estado inicial del trámite (habitualmente 'PENDIENTE')")
    facturas_pendientes: int = Field(0, description="Facturas adeudadas contabilizadas en el momento del registro")
    mensaje: str = Field(..., description="Mensaje de confirmación para el asociado")

