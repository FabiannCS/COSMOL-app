"""
Esquemas de datos y DTOs basados en Pydantic v2:
- Validación de entradas (Request bodies).
- Serialización de salidas (Response models).
"""
from app.schemas.suministro import (
    VincularSuministroRequest,
    SuministroResponse,
)
from app.schemas.usuario import (
    VerificarSocioRequest,
    SolicitarOtpRequest,
    VerificarOtpRequest,
    CrearPinPasswordRequest,
    LoginRequest,
    TokenResponse,
    RenovarTokenRequest,
)

from app.schemas.deuda import (
    FacturaPendienteResponse,
    DetalleSuministroResponse,
    ResumenDeudaResponse,
    DashboardMultiSuministroResponse,
)

from app.schemas.documento import (
    DocumentoResponse,
    ListaDocumentosResponse,
)

__all__ = [
    "VincularSuministroRequest",
    "SuministroResponse",
    "VerificarSocioRequest",
    "SolicitarOtpRequest",
    "VerificarOtpRequest",
    "CrearPinPasswordRequest",
    "LoginRequest",
    "TokenResponse",
    "RenovarTokenRequest",
    "FacturaPendienteResponse",
    "DetalleSuministroResponse",
    "ResumenDeudaResponse",
    "DashboardMultiSuministroResponse",
    "DocumentoResponse",
    "ListaDocumentosResponse",
]

