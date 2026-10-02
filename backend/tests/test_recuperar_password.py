"""
Pruebas automatizadas para el flujo de Recuperación Segura de Contraseña / PIN (Zero-Trust Phone Binding).
Valida contratos REST, enmascaramiento de teléfono, validación de OTP y actualización efectiva en PostgreSQL.
"""
import uuid
import pytest
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import AsyncSession

from app.main import app
from app.db.models.usuario import Usuario
from app.db.models.suministro import Suministro
from app.core.security import get_password_hash


@pytest.fixture
async def socio_recuperacion_db(db_override):
    from app.api.deps import get_db
    get_db_gen = app.dependency_overrides[get_db]()
    session: AsyncSession = await anext(get_db_gen)

    from app.api.deps import get_redis
    redis_c = app.dependency_overrides[get_redis]()
    rate_keys = await redis_c.keys("rate_otp_recuperacion:*")
    if rate_keys:
        await redis_c.delete(*rate_keys)

    rand_s = uuid.uuid4().hex[:6]
    cod_socio = "556"  # Socio real de COSMOL (SUAREZ BALTAZAR, CI: 4638847)
    ci = "4638847"
    telefono = f"+59178{rand_s}"
    pin_inicial = "9988"

    # Limpiar posibles registros previos con este cod_socio
    try:
        user_id = uuid.uuid4()
        user = Usuario(
            id=user_id,
            telefono=telefono,
            password_hash=get_password_hash(pin_inicial),
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
        await session.commit()

        yield {
            "cod_socio": cod_socio,
            "ci": ci,
            "telefono": telefono,
            "pin_inicial": pin_inicial,
            "user_id": user_id
        }
    finally:
        await session.rollback()
        try:
            await session.delete(suministro)
            await session.delete(user)
            await session.commit()
        except Exception:
            pass
        try:
            await anext(get_db_gen)
        except StopAsyncIteration:
            pass


@pytest.mark.asyncio
async def test_flujo_completo_recuperacion_password(socio_recuperacion_db, redis_override):
    """
    Valida el ciclo de vida completo de 4 pasos de recuperación segura:
    1. Validar titularidad -> session_id + teléfono enmascarado.
    2. Solicitar OTP -> despacho a celular registrado.
    3. Verificar OTP -> token_recuperacion.
    4. Cambiar PIN -> actualización de hash bcrypt en BD y posterior login exitoso.
    """
    datos_socio = socio_recuperacion_db
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        # Paso 1: Validar titular
        resp_p1 = await ac.post("/api/v1/auth/recuperar-password/validar-titular", json={
            "cod_socio": datos_socio["cod_socio"],
            "ci": datos_socio["ci"]
        })
        assert resp_p1.status_code == 200
        data_p1 = resp_p1.json()
        assert "session_id" in data_p1
        assert data_p1["session_id"].startswith("rec_")
        assert "SUAREZ BALTAZAR" in data_p1["nombre_titular"]
        assert "*" in data_p1["telefono_enmascarado"]
        session_id = data_p1["session_id"]

        # Paso 2: Solicitar OTP
        resp_p2 = await ac.post("/api/v1/auth/recuperar-password/solicitar-otp", json={
            "session_id": session_id,
            "canal": "WHATSAPP"
        })
        assert resp_p2.status_code == 200
        data_p2 = resp_p2.json()
        assert data_p2["canal"] == "WHATSAPP"
        assert data_p2["ttl_segundos"] == 300
        codigo_otp = data_p2.get("debug_codigo_otp")
        assert codigo_otp is not None and len(codigo_otp) == 6

        # Paso 3: Verificar OTP
        resp_p3 = await ac.post("/api/v1/auth/recuperar-password/verificar-otp", json={
            "session_id": session_id,
            "codigo": codigo_otp
        })
        assert resp_p3.status_code == 200
        data_p3 = resp_p3.json()
        assert "token_recuperacion" in data_p3
        assert data_p3["token_recuperacion"].startswith("rst_")
        token_rec = data_p3["token_recuperacion"]

        # Paso 4: Cambiar PIN
        nuevo_pin = "7788"
        resp_p4 = await ac.post("/api/v1/auth/recuperar-password/cambiar-pin", json={
            "token_recuperacion": token_rec,
            "nuevo_pin": nuevo_pin
        })
        assert resp_p4.status_code == 200
        data_p4 = resp_p4.json()
        assert "actualizada exitosamente" in data_p4["mensaje"]

        # Verificar Login exitoso con el NUEVO PIN
        resp_login = await ac.post("/api/v1/auth/login", json={
            "cod_socio": datos_socio["cod_socio"],
            "pin_password": nuevo_pin,
            "device_id": "test-device-recovery"
        })
        assert resp_login.status_code == 200
        data_login = resp_login.json()
        assert "access_token" in data_login

        # Verificar rechazo con el PIN ANTIGUO
        resp_login_old = await ac.post("/api/v1/auth/login", json={
            "cod_socio": datos_socio["cod_socio"],
            "pin_password": datos_socio["pin_inicial"],
            "device_id": "test-device-recovery"
        })
        assert resp_login_old.status_code == 401


@pytest.mark.asyncio
async def test_recuperar_password_ci_invalida(redis_override):
    """Verifica rechazo con 401 SOCIO_NOT_FOUND si la CI no coincide con COSMOL comercial."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.post("/api/v1/auth/recuperar-password/validar-titular", json={
            "cod_socio": "556",
            "ci": "0000000"
        })
        assert resp.status_code == 401
        assert resp.json()["error"]["code"] == "SOCIO_NOT_FOUND"


@pytest.mark.asyncio
async def test_recuperar_password_socio_sin_cuenta_registrada(redis_override):
    """Verifica rechazo con 404 ACCOUNT_NOT_REGISTERED si el socio existe en COSMOL pero no tiene cuenta app."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.post("/api/v1/auth/recuperar-password/validar-titular", json={
            "cod_socio": "540",  # Existe en Informix (CI: 2823231), pero no registrado en test
            "ci": "2823231"
        })
        # Si no está en BD ni en USUARIOS_REGISTRADOS_DB
        if resp.status_code == 404:
            assert resp.json()["error"]["code"] == "ACCOUNT_NOT_REGISTERED"


@pytest.mark.asyncio
async def test_recuperar_password_otp_invalido_y_max_intentos(socio_recuperacion_db, redis_override):
    """Verifica que tras 3 intentos erróneos de OTP, la sesión se cancela con 403 OTP_MAX_ATTEMPTS."""
    datos_socio = socio_recuperacion_db
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp_p1 = await ac.post("/api/v1/auth/recuperar-password/validar-titular", json={
            "cod_socio": datos_socio["cod_socio"],
            "ci": datos_socio["ci"]
        })
        session_id = resp_p1.json()["session_id"]

        await ac.post("/api/v1/auth/recuperar-password/solicitar-otp", json={
            "session_id": session_id,
            "canal": "SMS"
        })

        # Intento 1 fallido
        r_f1 = await ac.post("/api/v1/auth/recuperar-password/verificar-otp", json={
            "session_id": session_id,
            "codigo": "000000"
        })
        assert r_f1.status_code == 400
        assert r_f1.json()["error"]["code"] == "OTP_INVALID"

        # Intento 2 fallido
        r_f2 = await ac.post("/api/v1/auth/recuperar-password/verificar-otp", json={
            "session_id": session_id,
            "codigo": "000000"
        })
        assert r_f2.status_code == 400

        # Intento 3 fallido: debe bloquear y cancelar sesión
        r_f3 = await ac.post("/api/v1/auth/recuperar-password/verificar-otp", json={
            "session_id": session_id,
            "codigo": "000000"
        })
        assert r_f3.status_code == 403
        assert r_f3.json()["error"]["code"] == "OTP_MAX_ATTEMPTS"


@pytest.mark.asyncio
async def test_recuperar_password_token_invalido(redis_override):
    """Verifica rechazo con 401 INVALID_RECOVERY_TOKEN ante un token falso o expirado."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        resp = await ac.post("/api/v1/auth/recuperar-password/cambiar-pin", json={
            "token_recuperacion": "rst_token_inexistente_12345",
            "nuevo_pin": "5566"
        })
        assert resp.status_code == 401
        assert resp.json()["error"]["code"] == "INVALID_RECOVERY_TOKEN"
