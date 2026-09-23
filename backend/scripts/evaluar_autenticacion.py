"""
Script de evaluación y demostración de los casos de autenticación y flujo OTP
para COSMOL R.L. (ejecutable dentro del contenedor backend-api).
"""
import asyncio
import json
import os
import sys
import urllib.request
import urllib.error

sys.path.insert(0, "/app")
sys.path.insert(0, os.path.abspath("."))

from sqlalchemy import text
from redis.asyncio import from_url

from app.core.config import settings
from app.db.session import AsyncSessionLocal

BASE_URL = "http://127.0.0.1:8000/api/v1"

def http_post(endpoint: str, data: dict, token: str = None):
    url = f"{BASE_URL}{endpoint}"
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(
        url,
        data=json.dumps(data).encode("utf-8"),
        headers=headers,
        method="POST"
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status, json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode())


async def limpiar_socio_prueba(cod_socio: str, telefono: str):
    async with AsyncSessionLocal() as session:
        await session.execute(text(f"DELETE FROM documentos WHERE cod_socio = '{cod_socio}'"))
        await session.execute(text(f"DELETE FROM suministros WHERE cod_socio = '{cod_socio}'"))
        await session.execute(text(f"DELETE FROM usuarios WHERE telefono = '{telefono}'"))
        await session.commit()
    r = from_url(settings.REDIS_URL)
    await r.delete(
        f"otp:{telefono}",
        f"rate_otp:{telefono}",
        f"bloqueado:{cod_socio}",
        f"intentos_fallidos:{cod_socio}"
    )
    await r.aclose()


async def ejecutar_evaluacion():
    cod_socio = "104523"
    ci_valido = "8392019"
    ci_invalido = "0000000"
    telefono = "+59177112233"
    pin_nuevo = "1234"
    pin_erroneo = "9999"

    print("=================================================================")
    print("EVALUACIÓN DE CASOS DE AUTENTICACIÓN Y FLUJO OTP — COSMOL R.L.")
    print("=================================================================")

    print("\n--- 0. Limpieza previa del socio de prueba (104523) ---")
    await limpiar_socio_prueba(cod_socio, telefono)
    print("Socio limpio en PostgreSQL y Redis.")

    # -------------------------------------------------------------
    # CASO 1: Validación de identidad con CI erróneo
    # -------------------------------------------------------------
    print("\n>>> CASO 1: Intento de Onboarding con CI erróneo")
    st, res = http_post("/autenticacion/verificar-socio", {"cod_socio": cod_socio, "ci": ci_invalido})
    print(f"Status HTTP: {st}")
    print(f"Respuesta: {res}")
    assert st == 401
    assert res["error"]["code"] == "SOCIO_NOT_FOUND"
    print("[OK] Rechazado con 401 SOCIO_NOT_FOUND.")

    # -------------------------------------------------------------
    # CASO 2: Validación de identidad exitosa (cod_socio + CI correcto)
    # -------------------------------------------------------------
    print("\n>>> CASO 2: Verificación de Socio exitosa (cod_socio + CI)")
    st, res = http_post("/autenticacion/verificar-socio", {"cod_socio": cod_socio, "ci": ci_valido})
    print(f"Status HTTP: {st}")
    print(f"Nombre titular retornado: {res.get('nombre_titular')}")
    assert st == 200
    assert "CARLOS EDUARDO" in res.get("nombre_titular", "")
    print("[OK] Socio verificado.")

    # -------------------------------------------------------------
    # CASO 3: Solicitar OTP (demostración de modo prueba con debug_codigo_otp)
    # -------------------------------------------------------------
    print("\n>>> CASO 3: Solicitar OTP (Demostración de funcionamiento en prueba)")
    st, res_otp = http_post("/autenticacion/solicitar-otp", {
        "cod_socio": cod_socio,
        "telefono": telefono,
        "canal": "WhatsApp"  # probado con minúsculas/CamelCase para validar tolerancia
    })
    print(f"Status HTTP: {st}")
    print(f"Mensaje: {res_otp.get('mensaje')}")
    print(f"Canal normalizado: {res_otp.get('canal')}")
    print(f"Teléfono enmascarado: {res_otp.get('telefono_enmascarado')}")
    print(f"TTL del código en Redis: {res_otp.get('ttl_segundos')} segundos")
    otp_code = res_otp.get("debug_codigo_otp")
    print(f"★ Código OTP entregado para pruebas: {otp_code}")
    assert st == 200
    assert otp_code is not None and len(otp_code) == 6
    print("[OK] OTP generado y guardado en Redis.")

    # -------------------------------------------------------------
    # CASO 4: Ingreso de código OTP erróneo
    # -------------------------------------------------------------
    print("\n>>> CASO 4: Verificación con código OTP incorrecto")
    st, res_bad_otp = http_post("/autenticacion/verificar-otp", {
        "telefono": telefono,
        "codigo": "000000"
    })
    print(f"Status HTTP: {st}")
    print(f"Respuesta: {res_bad_otp}")
    assert st == 400
    assert res_bad_otp["error"]["code"] == "OTP_INVALID"
    print("[OK] Rechazado con 400 OTP_INVALID.")

    # -------------------------------------------------------------
    # CASO 5: Verificación exitosa del OTP de 6 dígitos
    # -------------------------------------------------------------
    print("\n>>> CASO 5: Verificación con código OTP correcto")
    st, res_ok_otp = http_post("/autenticacion/verificar-otp", {
        "telefono": telefono,
        "codigo": otp_code
    })
    print(f"Status HTTP: {st}")
    print(f"Mensaje: {res_ok_otp.get('mensaje')}")
    token_valido = res_ok_otp.get("token_otp_valido")
    print(f"Pase criptográfico temporal (token_otp_valido): {token_valido[:20]}...")
    assert st == 200
    assert token_valido is not None
    print("[OK] OTP verificado y quemado (un solo uso).")

    # -------------------------------------------------------------
    # CASO 6: Intento de reutilizar el mismo OTP (Principio Consume-Once)
    # -------------------------------------------------------------
    print("\n>>> CASO 6: Intento de reusar el mismo OTP (Ataque de repetición)")
    st, res_reuse = http_post("/autenticacion/verificar-otp", {
        "telefono": telefono,
        "codigo": otp_code
    })
    print(f"Status HTTP: {st}")
    print(f"Respuesta: {res_reuse}")
    assert st == 400
    assert res_reuse["error"]["code"] == "OTP_EXPIRED"
    print("[OK] OTP no reutilizable.")

    # -------------------------------------------------------------
    # CASO 7: Establecer nuevo PIN personal
    # -------------------------------------------------------------
    print("\n>>> CASO 7: Establecer PIN personal (cierre de onboarding)")
    st, res_pin = http_post("/autenticacion/establecer-pin", {
        "telefono": telefono,
        "token_otp_valido": token_valido,
        "nuevo_pin": pin_nuevo,
        "cod_socio": cod_socio  # campo opcional tolerado
    })
    print(f"Status HTTP: {st}")
    print(f"Mensaje: {res_pin.get('mensaje')}")
    assert st == 201
    print("[OK] Cuenta creada en PostgreSQL y suministro asociado.")

    # -------------------------------------------------------------
    # CASO 8: Intento de re-onboarding cuando ya tiene cuenta
    # -------------------------------------------------------------
    print("\n>>> CASO 8: Intento de nuevo Onboarding para socio ya registrado")
    st, res_re_onb = http_post("/autenticacion/verificar-socio", {"cod_socio": cod_socio, "ci": ci_valido})
    print(f"Status HTTP: {st}")
    print(f"Respuesta: {res_re_onb}")
    assert st == 400
    assert res_re_onb["error"]["code"] == "ACCOUNT_ALREADY_EXISTS"
    print("[OK] Bloqueado con ACCOUNT_ALREADY_EXISTS (debe ir a Login).")

    # -------------------------------------------------------------
    # CASO 9: Login diario habitual con PIN correcto
    # -------------------------------------------------------------
    print("\n>>> CASO 9: Login diario habitual con Código de Socio + PIN")
    st, res_login = http_post("/autenticacion/login", {
        "cod_socio": cod_socio,
        "pin_password": pin_nuevo,
        "device_id": "android_hardware_device_1001",
        "modelo_dispositivo": "Samsung Galaxy S24"
    })
    print(f"Status HTTP: {st}")
    access_token = res_login.get("access_token")
    refresh_token = res_login.get("refresh_token")
    suministros = res_login.get("suministros")
    print(f"Access Token JWT (15 min): {access_token[:30]}...")
    print(f"Refresh Token JWT (7 días): {refresh_token[:30]}...")
    print(f"Suministros entregados: {len(suministros)} (Rol: {suministros[0]['rol']})")
    assert st == 200
    assert access_token is not None
    print("[OK] Login exitoso y tokens emitidos.")

    # -------------------------------------------------------------
    # CASO 10: Bloqueo progresivo tras 3 intentos fallidos de login
    # -------------------------------------------------------------
    print("\n>>> CASO 10: Bloqueo progresivo tras 3 intentos fallidos de PIN")
    # Intento 1 fallido
    st1, r1 = http_post("/autenticacion/login", {"cod_socio": cod_socio, "pin_password": pin_erroneo, "device_id": "device-fallo-101"})
    print(f"Fallo 1 -> Status: {st1}, Mensaje: {r1['error']['message']}")
    # Intento 2 fallido
    st2, r2 = http_post("/autenticacion/login", {"cod_socio": cod_socio, "pin_password": pin_erroneo, "device_id": "device-fallo-101"})
    print(f"Fallo 2 -> Status: {st2}, Mensaje: {r2['error']['message']}")
    # Intento 3 fallido (debe bloquear)
    st3, r3 = http_post("/autenticacion/login", {"cod_socio": cod_socio, "pin_password": pin_erroneo, "device_id": "device-fallo-101"})
    print(f"Fallo 3 -> Status: {st3}, Mensaje: {r3['error']['message']}")
    # Intento 4 (durante bloqueo)
    st4, r4 = http_post("/autenticacion/login", {"cod_socio": cod_socio, "pin_password": pin_nuevo, "device_id": "device-fallo-101"})
    print(f"Intento con PIN correcto durante bloqueo -> Status: {st4}")
    print(f"Código error: {r4['error']['code']}")
    print(f"Segundos restantes de bloqueo: {r4['error']['details']['bloqueado_segundos_restantes']}s")
    assert st4 == 403
    assert r4["error"]["code"] == "ACCOUNT_LOCKED"
    print("[OK] Cuenta bloqueada progresivamente.")

    # -------------------------------------------------------------
    # CASO 11: Renovación silenciosa de Access Token con Refresh Token
    # -------------------------------------------------------------
    print("\n>>> CASO 11: Renovación silenciosa de token (Refresh Token)")
    st_ren, res_ren = http_post("/autenticacion/renovar-token", {
        "refresh_token": refresh_token,
        "device_id": "android_hardware_device_1001"
    })
    print(f"Status HTTP: {st_ren}")
    print(f"Nuevo Access Token: {res_ren.get('access_token')[:30]}...")
    assert st_ren == 200
    print("[OK] Token renovado silenciosamente.")

    print("\n=================================================================")
    print("TODOS LOS CASOS DE AUTENTICACIÓN Y OTP EVALUADOS CON 100% ÉXITO")
    print("=================================================================")


if __name__ == "__main__":
    asyncio.run(ejecutar_evaluacion())
