"""
Pruebas unitarias de integración de lógica de negocio para ServicioAutenticacion y ServicioSuministros.
Utiliza la instancia viva de Redis en Docker para validar TTLs, bloqueo por intentos y revocación.
"""
import pytest
import redis.asyncio as aioredis
from app.core.config import settings
from app.core.exceptions import (
    BadRequestException,
    ForbiddenException,
    UnauthorizedException,
)
from app.schemas.suministro import VincularSuministroRequest
from app.services.servicio_autenticacion import (
    USUARIOS_REGISTRADOS_DB,
    ServicioAutenticacion,
)
from app.services.servicio_suministros import ServicioSuministros


@pytest.fixture
async def redis_conn():
    client = aioredis.from_url(
        settings.REDIS_URL,
        encoding="utf-8",
        decode_responses=True
    )
    yield client
    await client.close()


@pytest.fixture
def auth_service(redis_conn):
    return ServicioAutenticacion(redis_conn)


@pytest.fixture
def suministro_service(redis_conn):
    return ServicioSuministros(redis_conn)


@pytest.mark.asyncio
async def test_flujo_completo_onboarding(auth_service, redis_conn):
    cod_socio = "104523"
    ci = "8392019"
    telefono = "+59171029384"
    pin = "4455"

    USUARIOS_REGISTRADOS_DB.pop(cod_socio, None)
    await redis_conn.delete(
        f"rate_otp:{telefono}",
        f"otp:{telefono}",
        f"intentos_fallidos:{cod_socio}",
        f"bloqueado:{cod_socio}"
    )

    # 1. Verificar socio en sistema legado
    verif = await auth_service.verificar_primer_acceso(cod_socio, ci)
    assert verif["cod_socio"] == cod_socio
    assert "CARLOS EDUARDO" in verif["nombre_titular"]

    # Socio inexistente debe fallar
    with pytest.raises(UnauthorizedException):
        await auth_service.verificar_primer_acceso("999999", "12345")

    # 2. Solicitar OTP
    solicitud = await auth_service.solicitar_otp(cod_socio, telefono, "WHATSAPP")
    assert solicitud["canal"] == "WHATSAPP"
    assert solicitud["ttl_segundos"] == 300
    assert solicitud["debug_codigo_otp"] is not None

    codigo_generado = solicitud["debug_codigo_otp"]

    # 3. Validar código erróneo
    with pytest.raises(BadRequestException):
        await auth_service.verificar_otp(telefono, "000000")

    # Validar código correcto
    verif_otp = await auth_service.verificar_otp(telefono, codigo_generado)
    assert "token_otp_valido" in verif_otp
    token_valido = verif_otp["token_otp_valido"]

    # 4. Establecer PIN personal
    registro = await auth_service.establecer_pin(telefono, token_valido, pin)
    assert registro["cod_socio"] == cod_socio

    # 5. Login habitual con el PIN nuevo
    token_resp = await auth_service.autenticar_socio(
        cod_socio=cod_socio,
        pin_password=pin,
        device_id="dispositivo-pruebas-01"
    )
    assert token_resp.access_token is not None
    assert token_resp.refresh_token is not None
    assert len(token_resp.suministros) == 1
    assert token_resp.suministros[0].rol == "TITULAR"


@pytest.mark.asyncio
async def test_bloqueo_por_tres_intentos_fallidos(auth_service, redis_conn):
    cod_socio = "205566"
    telefono = "+59172233445"
    pin_correcto = "8899"

    # Preparar cuenta activa
    USUARIOS_REGISTRADOS_DB.pop(cod_socio, None)
    await redis_conn.delete(
        f"rate_otp:{telefono}",
        f"otp:{telefono}",
        f"intentos_fallidos:{cod_socio}",
        f"bloqueado:{cod_socio}"
    )

    solicitud = await auth_service.solicitar_otp(cod_socio, telefono, "SMS")
    verif = await auth_service.verificar_otp(telefono, solicitud["debug_codigo_otp"])
    await auth_service.establecer_pin(telefono, verif["token_otp_valido"], pin_correcto)

    # Intento 1 fallido
    with pytest.raises(UnauthorizedException) as exc1:
        await auth_service.autenticar_socio(cod_socio, "0000", "dev-1")
    assert "Le quedan 2 intento(s)" in str(exc1.value.message)

    # Intento 2 fallido
    with pytest.raises(UnauthorizedException) as exc2:
        await auth_service.autenticar_socio(cod_socio, "0000", "dev-1")
    assert "Le quedan 1 intento(s)" in str(exc2.value.message)

    # Intento 3 fallido: debe bloquear la cuenta
    with pytest.raises(ForbiddenException) as exc3:
        await auth_service.autenticar_socio(cod_socio, "0000", "dev-1")
    assert exc3.value.error_code == "ACCOUNT_LOCKED"
    assert "bloqueada temporalmente" in str(exc3.value.message)


@pytest.mark.asyncio
async def test_multicuenta_titular_vs_inquilino(suministro_service):
    cod_socio_principal = "104523"

    # Vincular segundo suministro con CI (Modo TITULAR)
    req_titular = VincularSuministroRequest(
        cod_socio="205566",
        ci_o_medidor="4920192",
        alias="Alquiler Bolívar"
    )
    resp_titular = await suministro_service.vincular_suministro(cod_socio_principal, req_titular)
    assert resp_titular.rol == "TITULAR"
    assert resp_titular.alias == "Alquiler Bolívar"

    # Vincular tercer suministro sin CI (Modo CONSULTA_PAGO / Inquilino)
    req_inquilino = VincularSuministroRequest(
        cod_socio="301144",
        alias="Departamento Alquiler"
    )
    resp_inquilino = await suministro_service.vincular_suministro(cod_socio_principal, req_inquilino)
    assert resp_inquilino.rol == "CONSULTA_PAGO"

    # Listar suministros del socio
    lista = await suministro_service.listar_suministros(cod_socio_principal)
    assert len(lista) >= 3
