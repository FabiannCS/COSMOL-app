"""
Pruebas unitarias para los esquemas Pydantic v2 de Autenticación y Suministros (DEV 2).
"""
import pytest
from pydantic import ValidationError
from app.schemas.usuario import (
    VerificarSocioRequest,
    SolicitarOtpRequest,
    VerificarOtpRequest,
    CrearPinPasswordRequest,
    LoginRequest,
)
from app.schemas.suministro import VincularSuministroRequest


def test_verificar_socio_request_limpia_espacios():
    req = VerificarSocioRequest(cod_socio="  104523  ", ci="  8392019-SCZ  ")
    assert req.cod_socio == "104523"
    assert req.ci == "8392019-SCZ"


def test_solicitar_otp_normaliza_celular_bolivia():
    # Número estándar de 8 dígitos de Bolivia debe recibir el prefijo +591
    req = SolicitarOtpRequest(cod_socio="104523", telefono="71029384", canal="WHATSAPP")
    assert req.telefono == "+59171029384"
    assert req.canal == "WHATSAPP"

    # Con espacios y guiones
    req2 = SolicitarOtpRequest(cod_socio="104523", telefono=" 710-29-384 ", canal="SMS")
    assert req2.telefono == "+59171029384"
    assert req2.canal == "SMS"


def test_solicitar_otp_telefono_invalido():
    with pytest.raises(ValidationError):
        SolicitarOtpRequest(cod_socio="104523", telefono="123", canal="WHATSAPP")


def test_verificar_otp_exige_exactamente_6_digitos():
    # Válido
    req = VerificarOtpRequest(telefono="+59171029384", codigo="123456")
    assert req.codigo == "123456"

    # Inválido: menos dígitos
    with pytest.raises(ValidationError):
        VerificarOtpRequest(telefono="+59171029384", codigo="12345")

    # Inválido: letras
    with pytest.raises(ValidationError):
        VerificarOtpRequest(telefono="+59171029384", codigo="12345A")


def test_crear_pin_valida_longitud_minima():
    req = CrearPinPasswordRequest(
        telefono="+59171029384",
        token_otp_valido="tok_12345",
        nuevo_pin="1234"
    )
    assert req.nuevo_pin == "1234"

    # Menos de 4 dígitos debe fallar
    with pytest.raises(ValidationError):
        CrearPinPasswordRequest(
            telefono="+59171029384",
            token_otp_valido="tok_12345",
            nuevo_pin="12"
        )


def test_login_request_valido():
    req = LoginRequest(
        cod_socio="104523",
        pin_password="mi_pin_seguro",
        device_id="dev-samsung-a54-uuid",
        modelo_dispositivo="Samsung A54"
    )
    assert req.cod_socio == "104523"
    assert req.device_id == "dev-samsung-a54-uuid"


def test_vincular_suministro_request():
    # Con CI para Titular
    req = VincularSuministroRequest(
        cod_socio="205566",
        ci_o_medidor="8392019",
        alias="Casa Montero"
    )
    assert req.alias == "Casa Montero"
    assert req.ci_o_medidor == "8392019"

    # Sin CI para Consulta/Pago
    req_inquilino = VincularSuministroRequest(
        cod_socio="205566",
        alias="Oficina"
    )
    assert req_inquilino.ci_o_medidor is None


def test_solicitar_otp_normaliza_canal_case_insensitive():
    # Minúsculas
    req1 = SolicitarOtpRequest(cod_socio="104523", telefono="71029384", canal="whatsapp")
    assert req1.canal == "WHATSAPP"

    # CamelCase / Mixto
    req2 = SolicitarOtpRequest(cod_socio="104523", telefono="71029384", canal="WhatsApp")
    assert req2.canal == "WHATSAPP"

    # SMS en minúsculas
    req3 = SolicitarOtpRequest(cod_socio="104523", telefono="71029384", canal="sms")
    assert req3.canal == "SMS"


def test_crear_pin_tolera_campos_extras_y_contextuales():
    # Envío de campos contextuales que Flutter suele incluir (cod_socio, ci, username, etc.)
    data = {
        "telefono": "+59171029384",
        "token_otp_valido": "tok_seguro_123",
        "nuevo_pin": "1234",
        "cod_socio": "104523",
        "ci": "8392019",
        "username": "usuario_flutter",
        "campo_desconocido": "ignorado_por_extra_ignore"
    }
    req = CrearPinPasswordRequest(**data)
    assert req.telefono == "+59171029384"
    assert req.token_otp_valido == "tok_seguro_123"
    assert req.nuevo_pin == "1234"
    assert req.cod_socio == "104523"
    assert req.ci == "8392019"

