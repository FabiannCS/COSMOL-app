"""
Esquemas Pydantic v2 para la identidad, onboarding dual OTP y autenticación de socios.
"""
import re
from typing import Any, List, Literal, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator
from app.schemas.suministro import SuministroResponse


class VerificarSocioRequest(BaseModel):
    """
    Paso 1 del Onboarding: El socio ingresa su Código de Socio y Carnet de Identidad (CI)
    para validar su existencia en el sistema comercial legado de COSMOL R.L.
    """
    cod_socio: str = Field(
        ...,
        min_length=3,
        max_length=20,
        description="Código de socio asignado por COSMOL.",
        examples=["104523"]
    )
    ci: str = Field(
        ...,
        min_length=4,
        max_length=20,
        description="Carnet de Identidad del titular (con o sin complemento/expedido).",
        examples=["8392019"]
    )

    @field_validator("cod_socio", "ci")
    @classmethod
    def limpiar_espacios(cls, v: str) -> str:
        return v.strip()


class SolicitarOtpRequest(BaseModel):
    """
    Paso 2 del Onboarding: Tras verificar la coincidencia de CI, el socio asocia
    su número de teléfono celular y elige el canal de recepción del código de 6 dígitos.
    """
    cod_socio: str = Field(..., min_length=3, max_length=20, description="Código de socio verificado.")
    telefono: str = Field(
        ...,
        min_length=8,
        max_length=20,
        description="Número de teléfono celular (ej. '71029384' o '+59171029384').",
        examples=["71029384"]
    )
    canal: Literal["WHATSAPP", "SMS"] = Field(
        default="WHATSAPP",
        description="Canal de entrega seleccionado: 'WHATSAPP' (Cloud API) o 'SMS' (nacional)."
    )

    @field_validator("canal", mode="before")
    @classmethod
    def normalizar_canal(cls, v: Any) -> Any:
        if isinstance(v, str):
            return v.strip().upper()
        return v

    @field_validator("telefono")
    @classmethod
    def normalizar_telefono(cls, v: str) -> str:
        v = v.strip().replace(" ", "").replace("-", "")
        # Si tiene 8 dígitos (formato estándar Bolivia), anteponer el prefijo +591
        if len(v) == 8 and v.isdigit():
            return f"+591{v}"
        if not re.match(r"^\+?[0-9]{8,15}$", v):
            raise ValueError("El formato del número telefónico no es válido.")
        return v if v.startswith("+") else f"+{v}"


class VerificarOtpRequest(BaseModel):
    """
    Paso 3 del Onboarding: El socio ingresa el código de 6 dígitos recibido por WhatsApp o SMS.
    """
    telefono: str = Field(..., description="Número de teléfono celular registrado en el paso anterior.")
    codigo: str = Field(
        ...,
        min_length=6,
        max_length=6,
        description="Código numérico de seguridad de 6 dígitos.",
        examples=["384920"]
    )

    @field_validator("telefono")
    @classmethod
    def normalizar_telefono(cls, v: str) -> str:
        v = v.strip().replace(" ", "").replace("-", "")
        if len(v) == 8 and v.isdigit():
            return f"+591{v}"
        if not re.match(r"^\+?[0-9]{8,15}$", v):
            raise ValueError("El formato del número telefónico no es válido.")
        return v if v.startswith("+") else f"+{v}"

    @field_validator("codigo")
    @classmethod
    def validar_codigo_numerico(cls, v: str) -> str:
        v = v.strip()
        if not v.isdigit() or len(v) != 6:
            raise ValueError("El código OTP debe contener exactamente 6 dígitos numéricos.")
        return v


class CrearPinPasswordRequest(BaseModel):
    """
    Paso 4 del Onboarding: Una vez verificado el OTP, el socio define su nuevo PIN personal.
    A partir de este momento, la CI queda invalidada permanentemente como contraseña.
    """
    model_config = ConfigDict(extra="ignore")

    telefono: str = Field(..., description="Número de teléfono celular verificado.")
    token_otp_valido: str = Field(
        ...,
        description="Token temporal criptográfico que acredita la superación del paso OTP."
    )
    nuevo_pin: str = Field(
        ...,
        min_length=4,
        max_length=30,
        description="Nuevo PIN o contraseña secreta (mínimo 4 caracteres).",
        examples=["1234"]
    )
    cod_socio: Optional[str] = Field(None, description="Código de socio contextual")
    ci: Optional[str] = Field(None, description="CI contextual")

    @field_validator("telefono")
    @classmethod
    def normalizar_telefono(cls, v: str) -> str:
        v = v.strip().replace(" ", "").replace("-", "")
        if len(v) == 8 and v.isdigit():
            return f"+591{v}"
        if not re.match(r"^\+?[0-9]{8,15}$", v):
            raise ValueError("El formato del número telefónico no es válido.")
        return v if v.startswith("+") else f"+{v}"

    @field_validator("nuevo_pin")
    @classmethod
    def validar_pin(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 4:
            raise ValueError("El PIN o contraseña debe contener al menos 4 caracteres.")
        return v


class LoginRequest(BaseModel):
    """
    Login Diario Habitual: El socio ingresa mediante su Código de Socio y su PIN personal.
    El backend registrará el device_id para gestionar la sesión única (estilo WhatsApp).
    """
    cod_socio: str = Field(..., min_length=3, max_length=20, description="Código de socio.")
    pin_password: str = Field(..., min_length=4, max_length=30, description="PIN o contraseña personal.")
    device_id: str = Field(
        ...,
        min_length=5,
        max_length=100,
        description="Identificador único del hardware del dispositivo móvil.",
        examples=["a1b2c3d4-e5f6-7890"]
    )
    modelo_dispositivo: Optional[str] = Field(
        default=None,
        max_length=100,
        description="Modelo del teléfono para auditoría (ej. 'Samsung Galaxy A54').",
        examples=["Samsung Galaxy A54"]
    )


class TokenResponse(BaseModel):
    """
    Respuesta exitosa de autenticación con tokens JWT y la lista de suministros asociados.
    """
    access_token: str = Field(..., description="JWT de acceso de corta duración (15 minutos).")
    refresh_token: str = Field(..., description="JWT de renovación de larga duración (7 días).")
    token_type: str = Field(default="bearer", description="Tipo de autorización HTTP.")
    suministros: List[SuministroResponse] = Field(
        default_factory=list,
        description="Suministros vinculados a este socio para el selector del Dashboard."
    )


class RenovarTokenRequest(BaseModel):
    """
    Renovación silenciosa de sesión desde Flutter en segundo plano cuando expira el access token.
    """
    refresh_token: str = Field(..., description="Token de refresco vigente.")
    device_id: str = Field(..., description="Device ID para verificar que la sesión no fue tomada por otro equipo.")


class PrimerAccesoResponse(BaseModel):
    """
    Respuesta enriquecida del Paso 1 de Onboarding.
    Informa si el socio ya tiene cuenta previa para activar el diálogo de migración/login.
    """
    cod_socio: str = Field(..., description="Código de socio verificado.")
    nombre_titular: str = Field(..., description="Nombre oficial del titular registrado en COSMOL.")
    cuenta_existente: bool = Field(default=False, description="True si ya existe una cuenta TITULAR activa.")
    telefono_enmascarado: Optional[str] = Field(default=None, description="Teléfono celular enmascarado si la cuenta ya existe.")
    es_recuperacion: bool = Field(default=False, description="Indica si debe derivar a recuperación/migración.")
    mensaje: str = Field(..., description="Mensaje contextual para el usuario.")


# ------------------------------------------------------------------------------
# MIGRACIÓN SEGURA DE TELÉFONO (CAMBIO DE CHIP / CELULAR NUEVO)
# ------------------------------------------------------------------------------

class MigrarTelefonoIniciarRequest(BaseModel):
    """
    Solicitud para iniciar el traspaso de la cuenta titular a un nuevo número de celular.
    Exige la validación estricta del PIN actual para prevenir robo de cuentas con facturas físicas.
    """
    cod_socio: str = Field(..., min_length=3, max_length=20, description="Código de socio titular.")
    ci: str = Field(..., min_length=4, max_length=20, description="Cédula de Identidad del titular.")
    pin_actual: str = Field(..., min_length=4, max_length=30, description="PIN o clave secreta actual de la cuenta.")
    nuevo_telefono: str = Field(..., min_length=8, max_length=20, description="Nuevo número celular a vincular.")
    canal: Literal["WHATSAPP", "SMS"] = Field(default="WHATSAPP", description="Canal para recibir el OTP.")

    @field_validator("cod_socio", "ci")
    @classmethod
    def limpiar_espacios(cls, v: str) -> str:
        return v.strip()

    @field_validator("canal", mode="before")
    @classmethod
    def normalizar_canal(cls, v: Any) -> Any:
        if isinstance(v, str):
            return v.strip().upper()
        return v

    @field_validator("nuevo_telefono")
    @classmethod
    def normalizar_nuevo_telefono(cls, v: str) -> str:
        v = v.strip().replace(" ", "").replace("-", "")
        if len(v) == 8 and v.isdigit():
            return f"+591{v}"
        if not re.match(r"^\+?[0-9]{8,15}$", v):
            raise ValueError("El formato del nuevo número telefónico no es válido.")
        return v if v.startswith("+") else f"+{v}"


class MigrarTelefonoIniciarResponse(BaseModel):
    session_id: str = Field(..., description="ID de sesión temporal de migración (TTL 5 min).")
    mensaje: str = Field(..., description="Mensaje descriptivo.")
    ttl_segundos: int = Field(default=300, description="Tiempo de expiración del OTP.")
    debug_codigo_otp: Optional[str] = Field(default=None, description="Código OTP en desarrollo.")


class MigrarTelefonoConfirmarRequest(BaseModel):
    session_id: str = Field(..., description="ID de sesión obtenido al iniciar la migración.")
    codigo_otp: str = Field(..., min_length=6, max_length=6, description="Código de 6 dígitos recibido en el nuevo celular.")

    @field_validator("codigo_otp")
    @classmethod
    def validar_codigo(cls, v: str) -> str:
        v = v.strip()
        if not v.isdigit() or len(v) != 6:
            raise ValueError("El código OTP debe ser numérico de 6 dígitos.")
        return v


class MigrarTelefonoConfirmarResponse(BaseModel):
    mensaje: str = Field(..., description="Confirmación de actualización.")
    access_token: str = Field(..., description="Nuevo JWT de acceso.")
    refresh_token: str = Field(..., description="Nuevo JWT de renovación.")
    token_type: str = Field(default="bearer")
    cod_socio: str = Field(...)
    nombre: str = Field(...)
    suministros: List[SuministroResponse] = Field(default_factory=list)


# ------------------------------------------------------------------------------
# RECUPERACIÓN SEGURA DE CONTRASEÑA / PIN (ZERO-TRUST)
# ------------------------------------------------------------------------------

class RecuperarValidarTitularRequest(BaseModel):
    cod_socio: str = Field(..., min_length=3, max_length=20, description="Código de socio.")
    ci: str = Field(..., min_length=4, max_length=20, description="Carnet de Identidad del titular.")

    @field_validator("cod_socio", "ci")
    @classmethod
    def limpiar_espacios(cls, v: str) -> str:
        return v.strip()


class RecuperarValidarTitularResponse(BaseModel):
    session_id: str = Field(..., description="Identificador de sesión de recuperación.")
    cod_socio: str = Field(..., description="Código de socio.")
    nombre_titular: str = Field(..., description="Nombre del titular.")
    telefono_enmascarado: str = Field(..., description="Número celular enmascarado registrado en BD.")
    mensaje: str = Field(...)


class RecuperarSolicitarOtpRequest(BaseModel):
    session_id: str = Field(..., description="ID de sesión obtenido en validar titular.")
    canal: Literal["WHATSAPP", "SMS"] = Field(default="WHATSAPP")

    @field_validator("canal", mode="before")
    @classmethod
    def normalizar_canal(cls, v: Any) -> Any:
        if isinstance(v, str):
            return v.strip().upper()
        return v


class RecuperarSolicitarOtpResponse(BaseModel):
    mensaje: str
    canal: str
    telefono_enmascarado: str
    ttl_segundos: int = 300
    debug_codigo_otp: Optional[str] = None


class RecuperarVerificarOtpRequest(BaseModel):
    session_id: str = Field(..., description="ID de sesión de recuperación.")
    codigo: str = Field(..., min_length=6, max_length=6, description="Código de 6 dígitos.")

    @field_validator("codigo")
    @classmethod
    def validar_codigo(cls, v: str) -> str:
        v = v.strip()
        if not v.isdigit() or len(v) != 6:
            raise ValueError("El código debe contener exactamente 6 dígitos.")
        return v


class RecuperarVerificarOtpResponse(BaseModel):
    mensaje: str
    token_recuperacion: str = Field(..., description="Token criptográfico para cambiar el PIN.")
    cod_socio: str


class RecuperarCambiarPinRequest(BaseModel):
    token_recuperacion: str = Field(..., description="Token criptográfico emitido tras verificar OTP.")
    nuevo_pin: str = Field(..., min_length=4, max_length=30, description="Nuevo PIN personal.")

    @field_validator("nuevo_pin")
    @classmethod
    def validar_pin(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 4:
            raise ValueError("El PIN debe contener al menos 4 caracteres.")
        return v


class RecuperarCambiarPinResponse(BaseModel):
    mensaje: str
    cod_socio: str

