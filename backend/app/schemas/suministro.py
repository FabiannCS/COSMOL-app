"""
Esquemas Pydantic v2 para la gestión de suministros asociados a socios de COSMOL R.L.
"""
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, Field, ConfigDict


class VincularSuministroRequest(BaseModel):
    """
    Petición enviada desde la app móvil para agregar un suministro a la cuenta del usuario.
    Permite administrar múltiples medidores/contratos bajo un mismo número de celular.
    """
    cod_socio: str = Field(
        ...,
        min_length=3,
        max_length=20,
        description="Código de socio o suministro en el sistema comercial de COSMOL.",
        examples=["104523"]
    )
    ci_o_medidor: Optional[str] = Field(
        default=None,
        max_length=20,
        description=(
            "Carnet de Identidad o número de medidor del titular. "
            "Si se proporciona y coincide, otorga rol 'TITULAR'. "
            "Si no se proporciona, otorga rol 'CONSULTA_PAGO'."
        ),
        examples=["8392019"]
    )
    alias: str = Field(
        default="Mi Suministro",
        min_length=1,
        max_length=50,
        description="Nombre descriptivo asignado por el socio (ej. 'Mi Casa', 'Alquiler Bolívar').",
        examples=["Casa Principal"]
    )


class SuministroResponse(BaseModel):
    """
    Respuesta que describe un suministro enlazado al usuario.
    Si el rol es CONSULTA_PAGO, los datos confidenciales del titular no se exponen.
    """
    model_config = ConfigDict(from_attributes=True)

    id: UUID = Field(..., description="Identificador único del registro de suministro.")
    cod_socio: str = Field(..., description="Código de socio o contrato.")
    alias: str = Field(..., description="Alias personalizado configurado por el usuario.")
    rol: str = Field(..., description="Nivel de acceso: 'TITULAR' o 'CONSULTA_PAGO'.")
    es_suministro_principal: bool = Field(
        default=False,
        description="Indica si es el suministro predeterminado al abrir la aplicación."
    )
