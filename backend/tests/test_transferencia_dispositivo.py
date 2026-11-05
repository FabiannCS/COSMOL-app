"""
Pruebas automatizadas para el flujo de migración / transferencia de sesión entre dispositivos
(Handover estilo WhatsApp con Zero-Impact sobre el dispositivo previo en caso de cancelación).
"""
import uuid
import pytest
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import AsyncSession

from app.main import app
from app.db.models.usuario import Usuario
from app.db.models.suministro import Suministro
from app.db.models.dispositivo import Dispositivo
from app.core.security import get_password_hash


@pytest.fixture
async def usuario_con_sesion_activa(db_override):
    from app.api.deps import get_db, get_redis
    get_db_gen = app.dependency_overrides[get_db]()
    session: AsyncSession = await anext(get_db_gen)
    redis_c = app.dependency_overrides[get_redis]()

    cod_socio = "23807"
    ci = "6259185"
    rand_s = uuid.uuid4().hex[:6]
    telefono = f"+59171{rand_s}"
    pin = "1234"
    user_id = uuid.uuid4()
    device_id_viejo = "hardware-samsung-s23-old"
    modelo_viejo = "Samsung Galaxy S23"

    try:
        user = Usuario(
            id=user_id,
            telefono=telefono,
            password_hash=get_password_hash(pin),
            esta_activo=True
        )
        session.add(user)
        await session.flush()

        suministro = Suministro(
            usuario_id=user_id,
            cod_socio=cod_socio,
            alias="Mi Casa",
            rol="TITULAR",
            es_suministro_principal=True
        )
        session.add(suministro)

        dispositivo_viejo = Dispositivo(
            usuario_id=user_id,
            device_id=device_id_viejo,
            modelo=modelo_viejo,
            sistema_operativo="Android 14",
            esta_activo=True
        )
        session.add(dispositivo_viejo)
        await session.commit()

        # Simular sesión activa en Redis en el dispositivo anterior
        await redis_c.set(f"sesion_activa:{str(user_id)}", device_id_viejo, ex=86400)

        yield {
            "cod_socio": cod_socio,
            "ci": ci,
            "telefono": telefono,
            "pin": pin,
            "user_id": str(user_id),
            "device_id_viejo": device_id_viejo,
            "modelo_viejo": modelo_viejo,
        }
    finally:
        await session.rollback()
        try:
            await session.delete(dispositivo_viejo)
            await session.delete(suministro)
            await session.delete(user)
            await session.commit()
        except Exception:
            pass
        await redis_c.delete(f"sesion_activa:{str(user_id)}")


@pytest.mark.asyncio
async def test_intento_login_dispositivo_diferente_requiere_transferencia(client: AsyncClient, redis_override, usuario_con_sesion_activa):
    """
    Cuando un socio intenta ingresar desde un nuevo device_id teniendo una sesión activa
    en otro equipo, el backend debe responder requiere_transferencia=True, retornar
    session_transfer_id y NO alterar la sesión activa del dispositivo anterior.
    """
    datos = usuario_con_sesion_activa
    nuevo_device_id = "hardware-iphone-15-new"
    nuevo_modelo = "iPhone 15 Pro"

    res = await client.post(
        "/api/v1/autenticacion/login",
        json={
            "cod_socio": datos["cod_socio"],
            "pin_password": datos["pin"],
            "device_id": nuevo_device_id,
            "modelo_dispositivo": nuevo_modelo
        }
    )
    assert res.status_code == 200
    data = res.json()

    assert data["requiere_transferencia"] is True
    assert data["session_transfer_id"] is not None
    assert data["access_token"] is None
    assert data["refresh_token"] is None
    assert data["dispositivo_anterior_modelo"] == datos["modelo_viejo"]
    assert "***" in data["telefono_enmascarado"]

    # Verificar que el dispositivo viejo continúa como sesión activa en Redis (Zero Impact)
    sesion_en_redis = await redis_override.get(f"sesion_activa:{datos['user_id']}")
    assert sesion_en_redis == datos["device_id_viejo"]


@pytest.mark.asyncio
async def test_flujo_completo_transferencia_dispositivo(client: AsyncClient, redis_override, usuario_con_sesion_activa):
    """
    Flujo completo:
    1. Login desde nuevo equipo -> requiere_transferencia
    2. Solicitar OTP -> genera código y lo guarda en Redis con TTL de 10 min
    3. Validación OTP erróneo -> falla sin alterar la sesión del dispositivo anterior
    4. Confirmar OTP correcto -> transfiere la sesión activa al nuevo equipo y emite JWTs
    """
    datos = usuario_con_sesion_activa
    nuevo_device_id = "hardware-pixel-8-new"
    nuevo_modelo = "Google Pixel 8"

    # 1. Login inicial en nuevo hardware
    res_login = await client.post(
        "/api/v1/autenticacion/login",
        json={
            "cod_socio": datos["cod_socio"],
            "pin_password": datos["pin"],
            "device_id": nuevo_device_id,
            "modelo_dispositivo": nuevo_modelo
        }
    )
    transfer_id = res_login.json()["session_transfer_id"]
    assert transfer_id is not None

    # 2. Solicitar OTP para la migración
    res_otp = await client.post(
        "/api/v1/autenticacion/transferir-dispositivo/solicitar-otp",
        json={
            "session_transfer_id": transfer_id,
            "canal": "WHATSAPP"
        }
    )
    assert res_otp.status_code == 200
    data_otp = res_otp.json()
    assert data_otp["session_transfer_id"] == transfer_id
    codigo_otp = data_otp["debug_codigo_otp"]
    assert codigo_otp is not None
    assert len(codigo_otp) == 6

    # 3. Validar con OTP incorrecto -> debe fallar con 400
    res_fail = await client.post(
        "/api/v1/autenticacion/transferir-dispositivo/confirmar",
        json={
            "session_transfer_id": transfer_id,
            "codigo_otp": "000000"
        }
    )
    assert res_fail.status_code == 400
    assert "incorrecto" in res_fail.json()["detail"].lower()

    # Verificar que el dispositivo viejo sigue con su sesión intacta
    sesion_en_redis = await redis_override.get(f"sesion_activa:{datos['user_id']}")
    assert sesion_en_redis == datos["device_id_viejo"]

    # 4. Confirmar con OTP correcto -> éxito y migración de sesión
    res_ok = await client.post(
        "/api/v1/autenticacion/transferir-dispositivo/confirmar",
        json={
            "session_transfer_id": transfer_id,
            "codigo_otp": codigo_otp
        }
    )
    assert res_ok.status_code == 200
    data_ok = res_ok.json()
    assert data_ok["access_token"] is not None
    assert data_ok["refresh_token"] is not None
    assert len(data_ok["suministros"]) == 1

    # Verificar que la sesión en Redis ahora pertenece al NUEVO equipo
    sesion_actualizada = await redis_override.get(f"sesion_activa:{datos['user_id']}")
    assert sesion_actualizada == nuevo_device_id

    # La clave temporal de transferencia debe haber sido consumida / eliminada
    clave_transfer = await redis_override.get(f"transferencia_dispositivo:{transfer_id}")
    assert clave_transfer is None

