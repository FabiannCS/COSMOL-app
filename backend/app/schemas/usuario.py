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


# ------------------------------------------------------------------------------
# ESQUEMAS PARA RECUPERACIÓN SEGURA DE CONTRASEÑA / PIN (ZERO-TRUST)
# ------------------------------------------------------------------------------

class RecuperarValidarTitularRequest(BaseModel):
    """
    Paso 1 Recuperación: El socio ingresa su Código de Socio y Carnet de Identidad.
    El backend valida la titularidad y busca en BD el teléfono previamente registrado.
    """
    cod_socio: str = Field(..., min_length=3, max_length=20, description="Código de socio oficial.")
    ci: str = Field(..., min_length=4, max_length=20, description="Carnet de Identidad del titular.")

    @field_validator("cod_socio", "ci")
    @classmethod
    def limpiar_espacios(cls, v: str) -> str:
        return v.strip()


class RecuperarValidarTitularResponse(BaseModel):
    """
    Respuesta exitosa del Paso 1: Retorna el session_id temporal y el teléfono enmascarado.
    """
    session_id: str = Field(..., description="Identificador único de sesión de recuperación.")
    cod_socio: str = Field(..., description="Código de socio validado.")
    nombre_titular: str = Field(..., description="Nombre oficial del titular registrado.")
    telefono_enmascarado: str = Field(..., description="Número celular enmascarado (+591 7*** **384).")
    mensaje: str = Field(..., description="Instrucción para el siguiente paso.")


class RecuperarSolicitarOtpRequest(BaseModel):
    """
    Paso 2 Recuperación: El socio solicita el envío del OTP de 6 dígitos a su número registrado.
    """
    session_id: str = Field(..., description="Identificador de sesión obtenido en el Paso 1.")
    canal: Literal["WHATSAPP", "SMS"] = Field(
        default="WHATSAPP",
        description="Canal de entrega: 'WHATSAPP' o 'SMS'."
    )

    @field_validator("canal", mode="before")
    @classmethod
    def normalizar_canal(cls, v: Any) -> Any:
        if isinstance(v, str):
            return v.strip().upper()
        return v


class RecuperarSolicitarOtpResponse(BaseModel):
    """
    Respuesta exitosa del Paso 2: Confirma el despacho del código de seguridad.
    """
    mensaje: str = Field(..., description="Mensaje de confirmación del envío.")
    canal: str = Field(..., description="Canal utilizado para el envío.")
    telefono_enmascarado: str = Field(..., description="Celular destino enmascarado.")
    ttl_segundos: int = Field(default=300, description="Tiempo de validez del código OTP (segundos).")
    debug_codigo_otp: Optional[str] = Field(
        default=None,
        description="Código OTP visible únicamente en entorno de desarrollo/pruebas."
    )


class RecuperarVerificarOtpRequest(BaseModel):
    """
    Paso 3 Recuperación: El socio ingresa el código OTP recibido de 6 dígitos.
    """
    session_id: str = Field(..., description="Identificador de sesión de recuperación.")
    codigo: str = Field(..., min_length=6, max_length=6, description="Código de 6 dígitos.")

    @field_validator("codigo")
    @classmethod
    def limpiar_codigo(cls, v: str) -> str:
        return v.strip()


class RecuperarVerificarOtpResponse(BaseModel):
    """
    Respuesta exitosa del Paso 3: Retorna el token de recuperación criptográfico temporal.
    """
    mensaje: str = Field(..., description="Mensaje de éxito.")
    token_recuperacion: str = Field(..., description="Token temporal para autorizar el cambio de PIN.")
    cod_socio: str = Field(..., description="Código de socio asociado.")


class RecuperarCambiarPinRequest(BaseModel):
    """
    Paso 4 Recuperación: El socio define su nuevo PIN personal usando el token_recuperacion.
    """
    token_recuperacion: str = Field(..., description="Token de autorización temporal emitido en el Paso 3.")
    nuevo_pin: str = Field(..., min_length=4, max_length=30, description="Nuevo PIN o contraseña personal.")

    @field_validator("nuevo_pin")
    @classmethod
    def validar_pin(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 4:
            raise ValueError("El nuevo PIN debe contener al menos 4 caracteres.")
        return v


class RecuperarCambiarPinResponse(BaseModel):
    """
    Respuesta exitosa del Paso 4: Confirma la actualización y desbloqueo de la cuenta.
    """
    mensaje: str = Field(..., description="Mensaje de confirmación.")
    cod_socio: str = Field(..., description="Código de socio actualizado.")

