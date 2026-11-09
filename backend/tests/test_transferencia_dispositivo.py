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
from app.core.security import get_password_hash, create_access_token, decode_token


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
    assert res.status_code == 409
    body = res.json()
    assert body["success"] is False
    assert body["error"]["code"] == "DEVICE_CHANGE_DETECTED"
    data = body["error"]["details"]

    assert data["requiere_transferencia"] is True
    assert data["session_transfer_id"] is not None
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

    # 1. Login inicial en nuevo hardware -> retorna 409 DEVICE_CHANGE_DETECTED
    res_login = await client.post(
        "/api/v1/autenticacion/login",
        json={
            "cod_socio": datos["cod_socio"],
            "pin_password": datos["pin"],
            "device_id": nuevo_device_id,
            "modelo_dispositivo": nuevo_modelo
        }
    )
    assert res_login.status_code == 409
    body_login = res_login.json()
    assert body_login["error"]["code"] == "DEVICE_CHANGE_DETECTED"
    transfer_id = body_login["error"]["details"]["session_transfer_id"]
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


@pytest.mark.asyncio
async def test_dispositivo_viejo_revocado_al_transferir_sesion(client: AsyncClient, redis_override, usuario_con_sesion_activa):
    """
    Verifica que al transferir la sesión al nuevo dispositivo B,
    el token previo del dispositivo A quede INMEDIATAMENTE revocado
    en cualquier petición a la API con 401 SESSION_REVOKED_NEW_DEVICE.
    """
    datos = usuario_con_sesion_activa
    nuevo_device_id = "hardware-pixel-8-new"
    nuevo_modelo = "Google Pixel 8"

    # Generar token previo para el dispositivo A
    token_dispositivo_a = create_access_token(
        subject=datos["user_id"],
        extra_claims={
            "cod_socio": datos["cod_socio"],
            "device_id": datos["device_id_viejo"]
        }
    )

    # 1. Login inicial en nuevo hardware -> 409
    res_login = await client.post(
        "/api/v1/autenticacion/login",
        json={
            "cod_socio": datos["cod_socio"],
            "pin_password": datos["pin"],
            "device_id": nuevo_device_id,
            "modelo_dispositivo": nuevo_modelo
        }
    )
    transfer_id = res_login.json()["error"]["details"]["session_transfer_id"]

    # 2. Solicitar OTP
    res_otp = await client.post(
        "/api/v1/autenticacion/transferir-dispositivo/solicitar-otp",
        json={"session_transfer_id": transfer_id, "canal": "WHATSAPP"}
    )
    codigo_otp = res_otp.json()["debug_codigo_otp"]

    # 3. Confirmar transferencia hacia dispositivo B
    res_ok = await client.post(
        "/api/v1/autenticacion/transferir-dispositivo/confirmar",
        json={"session_transfer_id": transfer_id, "codigo_otp": codigo_otp}
    )
    assert res_ok.status_code == 200
    token_dispositivo_b = res_ok.json()["access_token"]

    # 4. El dispositivo B consulta consumo -> 200 OK
    res_b = await client.get(
        f"/api/v1/consumo/{datos['cod_socio']}",
        headers={"Authorization": f"Bearer {token_dispositivo_b}"}
    )
    assert res_b.status_code == 200

    # 5. El dispositivo A intenta consultar consumo -> 401 SESSION_REVOKED_NEW_DEVICE
    res_a = await client.get(
        f"/api/v1/consumo/{datos['cod_socio']}",
        headers={"Authorization": f"Bearer {token_dispositivo_a}"}
    )
    assert res_a.status_code == 401
    assert res_a.json()["error"]["code"] == "SESSION_REVOKED_NEW_DEVICE"


@pytest.mark.asyncio
async def test_migracion_telefono_emite_sub_uuid_limpio(client: AsyncClient, redis_override, usuario_con_sesion_activa):
    """
    Verifica que la migración de teléfono no corrompa el claim 'sub' del JWT
    y permita consultar endpoints protegidos sin generar ValueError UUID (HTTP 500).
    """
    datos = usuario_con_sesion_activa
    nuevo_celular = "+59178899001"

    # 1. Iniciar migración
    res_init = await client.post(
        "/api/v1/autenticacion/migrar-telefono/iniciar",
        json={
            "cod_socio": datos["cod_socio"],
            "ci": datos["ci"],
            "pin_actual": datos["pin"],
            "nuevo_telefono": nuevo_celular,
            "canal": "WHATSAPP"
        }
    )
    assert res_init.status_code == 200
    session_id = res_init.json()["session_id"]
    otp = res_init.json()["debug_codigo_otp"]

    # 2. Confirmar migración
    res_conf = await client.post(
        "/api/v1/autenticacion/migrar-telefono/confirmar",
        json={
            "session_id": session_id,
            "codigo_otp": otp
        },
        headers={"X-Device-Id": "hardware-migrado-001"}
    )
    assert res_conf.status_code == 200
    nuevo_token = res_conf.json()["access_token"]

    # 3. Decodificar el token y verificar que 'sub' sea un UUID válido directamente
    payload = decode_token(nuevo_token)
    assert isinstance(payload["sub"], str)
    # No debe tener llaves de diccionario:
    assert not payload["sub"].startswith("{")
    val_uuid = uuid.UUID(payload["sub"])
    assert str(val_uuid) == datos["user_id"]

    # 4. Probar endpoint protegido con el nuevo token (no debe arrojar 500)
    res_consumo = await client.get(
        f"/api/v1/consumo/{datos['cod_socio']}",
        headers={"Authorization": f"Bearer {nuevo_token}"}
    )
    assert res_consumo.status_code == 200

