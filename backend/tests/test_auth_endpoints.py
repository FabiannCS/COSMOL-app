"""
Pruebas de integración HTTP para los endpoints de Autenticación, Onboarding y Multicuenta (DEV 2).
"""
import pytest
from httpx import AsyncClient
from app.services.servicio_autenticacion import USUARIOS_REGISTRADOS_DB


@pytest.mark.asyncio
async def test_endpoint_flujo_onboarding_completo(client: AsyncClient, redis_override, db_session):
    from sqlalchemy import delete
    from app.db.models import Suministro, Usuario

    cod_socio = "301144"
    ci = "6102938"
    telefono = "71029384"
    pin = "9988"

    USUARIOS_REGISTRADOS_DB.pop(cod_socio, None)
    # Limpiar rate-limit y claves en Redis para este teléfono
    await redis_override.delete(
        f"rate_otp:+591{telefono}",
        f"otp:+591{telefono}",
        f"intentos_fallidos:{cod_socio}",
        f"bloqueado:{cod_socio}"
    )

    # Limpiar registros previos en PostgreSQL para garantizar idempotencia total
    await db_session.execute(delete(Suministro).where(Suministro.cod_socio.in_([cod_socio, "104523"])))
    await db_session.execute(delete(Usuario).where(Usuario.telefono == f"+591{telefono}"))
    await db_session.commit()

    # 1. Paso 1: Verificar socio
    res1 = await client.post(
        "/api/v1/autenticacion/verificar-socio",
        json={"cod_socio": cod_socio, "ci": ci}
    )
    assert res1.status_code == 200
    data1 = res1.json()
    assert data1["cod_socio"] == cod_socio
    assert "JUAN PABLO" in data1["nombre_titular"]

    # 2. Paso 2: Solicitar OTP
    res2 = await client.post(
        "/api/v1/autenticacion/solicitar-otp",
        json={"cod_socio": cod_socio, "telefono": telefono, "canal": "WHATSAPP"}
    )
    assert res2.status_code == 200
    data2 = res2.json()
    assert data2["canal"] == "WHATSAPP"
    codigo_otp = data2["debug_codigo_otp"]

    # 3. Paso 3: Verificar OTP
    res3 = await client.post(
        "/api/v1/autenticacion/verificar-otp",
        json={"telefono": f"+591{telefono}", "codigo": codigo_otp}
    )
    assert res3.status_code == 200
    data3 = res3.json()
    token_otp_valido = data3["token_otp_valido"]

    # 4. Paso 4: Establecer PIN
    res4 = await client.post(
        "/api/v1/autenticacion/establecer-pin",
        json={
            "telefono": f"+591{telefono}",
            "token_otp_valido": token_otp_valido,
            "nuevo_pin": pin
        }
    )
    assert res4.status_code == 201
    assert res4.json()["cod_socio"] == cod_socio

    # 5. Login habitual
    res5 = await client.post(
        "/api/v1/autenticacion/login",
        json={
            "cod_socio": cod_socio,
            "pin_password": pin,
            "device_id": "test-device-hardware-99",
            "modelo_dispositivo": "Motorola Edge 40"
        }
    )
    assert res5.status_code == 200
    data5 = res5.json()
    access_token = data5["access_token"]
    assert access_token is not None
    assert len(data5["suministros"]) == 1

    # 6. Multicuenta: Vincular nuevo suministro protegido con JWT
    headers = {"Authorization": f"Bearer {access_token}"}
    res6 = await client.post(
        "/api/v1/autenticacion/suministros/vincular",
        headers=headers,
        json={
            "cod_socio": "104523",
            "ci_o_medidor": "8392019",
            "alias": "Casa Centro"
        }
    )
    assert res6.status_code == 201
    assert res6.json()["rol"] == "TITULAR"

    # 7. Listar suministros del socio
    res7 = await client.get("/api/v1/autenticacion/suministros", headers=headers)
    assert res7.status_code == 200
    lista_suministros = res7.json()
    assert len(lista_suministros) >= 2


@pytest.mark.asyncio
async def test_endpoint_verificar_socio_inexistente(client: AsyncClient):
    res = await client.post(
        "/api/v1/autenticacion/verificar-socio",
        json={"cod_socio": "999999", "ci": "000000"}
    )
    assert res.status_code == 401
    body = res.json()
    assert body["success"] is False
    assert body["error"]["code"] == "SOCIO_NOT_FOUND"


@pytest.mark.asyncio
async def test_endpoint_login_credenciales_invalidas(client: AsyncClient):
    res = await client.post(
        "/api/v1/autenticacion/login",
        json={
            "cod_socio": "301144",
            "pin_password": "pin_incorrecto",
            "device_id": "dev-01"
        }
    )
    assert res.status_code in (401, 403)
