import pytest
from redis.asyncio import Redis
from app.core.redis import get_redis
from app.services.servicio_otp import (
    generar_codigo_otp,
    guardar_otp_en_redis,
    verificar_otp_en_redis,
    validar_limite_envios_redis,
    despachar_otp
)
from app.services.servicio_bloqueo import (
    calcular_segundos_bloqueo,
    registrar_intento_fallido,
    verificar_bloqueo_activo,
    limpiar_bloqueo_e_intentos
)


from app.core.config import settings


@pytest.fixture
async def redis_conn():
    client = Redis.from_url(settings.REDIS_URL, decode_responses=True)
    yield client
    await client.aclose()


def test_generador_codigo_otp():
    codigo = generar_codigo_otp(6)
    assert len(codigo) == 6
    assert codigo.isdigit()

    codigo_8 = generar_codigo_otp(8)
    assert len(codigo_8) == 8
    assert codigo_8.isdigit()


@pytest.mark.asyncio
async def test_guardar_y_verificar_otp_un_solo_uso(redis_conn: Redis):
    telefono = "+59170099901"
    codigo = "849201"

    # 1. Guardar en Redis
    await guardar_otp_en_redis(redis_conn, telefono, codigo, "ONBOARDING")

    # 2. Verificar con código incorrecto
    es_valido_erroneo = await verificar_otp_en_redis(redis_conn, telefono, "000000")
    assert es_valido_erroneo is False

    # 3. Verificar con código correcto
    es_valido_correcto = await verificar_otp_en_redis(redis_conn, telefono, codigo)
    assert es_valido_correcto is True

    # 4. Verificar que se quemó (principio de un solo uso)
    segundo_intento = await verificar_otp_en_redis(redis_conn, telefono, codigo)
    assert segundo_intento is False


@pytest.mark.asyncio
async def test_limite_solicitudes_otp_por_hora(redis_conn: Redis):
    telefono = "+59170099902"
    clave_rate = f"otp_rate:{telefono}"
    await redis_conn.delete(clave_rate)

    # Primeras 3 solicitudes deben ser permitidas
    assert await validar_limite_envios_redis(redis_conn, telefono) is True
    assert await validar_limite_envios_redis(redis_conn, telefono) is True
    assert await validar_limite_envios_redis(redis_conn, telefono) is True

    # La 4ta solicitud en la misma hora debe ser rechazada
    assert await validar_limite_envios_redis(redis_conn, telefono) is False

    await redis_conn.delete(clave_rate)


@pytest.mark.asyncio
async def test_despachar_otp_mock_whatsapp_y_sms(redis_conn: Redis):
    telefono_wsp = "+59170099903"
    telefono_sms = "+59170099904"
    await redis_conn.delete(
        f"otp_rate:{telefono_wsp}",
        f"otp_rate:{telefono_sms}",
        f"otp:{telefono_wsp}",
        f"otp:{telefono_sms}"
    )
    codigo_wsp = await despachar_otp(redis_conn, telefono_wsp, canal="WHATSAPP")
    assert len(codigo_wsp) == 6
    assert await verificar_otp_en_redis(redis_conn, telefono_wsp, codigo_wsp) is True

    telefono_sms = "+59170099904"
    codigo_sms = await despachar_otp(redis_conn, telefono_sms, canal="SMS")
    assert len(codigo_sms) == 6
    assert await verificar_otp_en_redis(redis_conn, telefono_sms, codigo_sms) is True


def test_escala_segundos_bloqueo():
    assert calcular_segundos_bloqueo(1) is None
    assert calcular_segundos_bloqueo(2) is None
    assert calcular_segundos_bloqueo(3) == 60     # 1 min
    assert calcular_segundos_bloqueo(4) == 300    # 5 min
    assert calcular_segundos_bloqueo(5) == 900    # 15 min
    assert calcular_segundos_bloqueo(6) == 1800   # 30 min
    assert calcular_segundos_bloqueo(7) == 3600   # 1 hora
    assert calcular_segundos_bloqueo(10) == 3600  # 1 hora


@pytest.mark.asyncio
async def test_motor_bloqueo_progresivo(redis_conn: Redis):
    socio_id = "socio_test_bloqueo_1001"
    await limpiar_bloqueo_e_intentos(redis_conn, socio_id)

    # Intento 1: no bloquea
    intentos, penalizacion = await registrar_intento_fallido(redis_conn, socio_id)
    assert intentos == 1
    assert penalizacion is None
    assert await verificar_bloqueo_activo(redis_conn, socio_id) is None

    # Intento 2: no bloquea
    intentos, penalizacion = await registrar_intento_fallido(redis_conn, socio_id)
    assert intentos == 2
    assert penalizacion is None
    assert await verificar_bloqueo_activo(redis_conn, socio_id) is None

    # Intento 3: BLOQUEA por 60 segundos
    intentos, penalizacion = await registrar_intento_fallido(redis_conn, socio_id)
    assert intentos == 3
    assert penalizacion == 60
    segundos_restantes = await verificar_bloqueo_activo(redis_conn, socio_id)
    assert segundos_restantes is not None
    assert 0 < segundos_restantes <= 60

    # Limpiar bloqueo (ej. tras desbloqueo con OTP)
    await limpiar_bloqueo_e_intentos(redis_conn, socio_id)
    assert await verificar_bloqueo_activo(redis_conn, socio_id) is None
