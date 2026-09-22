"""
Batería de pruebas automatizadas para Pasarelas de Pago Externas y Verificación Inteligente (DEV 2).
COSMOL R.L. - App de Socios (Fase 5).
Valida catálogo de canales oficiales (Multipago y Pago al Paso), registro de intención,
activación atómica de ventana en Redis (NX=True), auditoría y verificación post-pago.
"""
import uuid
import pytest
from httpx import AsyncClient
from redis.asyncio import Redis
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import create_access_token
from app.db.models import Suministro, Usuario
from app.services.servicio_cache_pagos import (
    activar_ventana_verificacion,
    esta_en_ventana_verificacion,
    cerrar_ventana_verificacion,
)


def generar_telefono_unico() -> str:
    """Genera un número de teléfono aleatorio para evitar colisiones de unicidad en PostgreSQL."""
    return f"+5917{uuid.uuid4().int % 9000000 + 1000000}"


async def crear_usuario_y_suministro(
    db: AsyncSession, cod_socio: str = "540", rol: str = "TITULAR"
) -> tuple[Usuario, str]:
    """Crea un usuario de prueba en PostgreSQL vinculado al código de socio y devuelve su JWT."""
    # Limpiar suministros previos con este código para aislar el test
    await db.execute(delete(Suministro).where(Suministro.cod_socio == cod_socio))
    await db.commit()

    user_id = uuid.uuid4()
    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash_for_test",
        esta_activo=True
    )
    suministro = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio,
        alias="Suministro de Prueba",
        rol=rol,
        es_suministro_principal=True
    )
    db.add(usuario)
    db.add(suministro)
    await db.commit()

    token = create_access_token(subject=str(user_id))
    return usuario, token


# ------------------------------------------------------------------------------
# 1. Pruebas Unitarias del Servicio de Caché Redis
# ------------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_cache_pagos_activacion_nx_y_cierre(redis_override: Redis):
    """
    Verifica que la activación de la ventana en Redis sea atómica e idempotente (NX=True),
    purgue la clave de deuda y se cierre adecuadamente.
    """
    cod_socio = f"TEST_{uuid.uuid4().hex[:6]}"

    # Simular una clave de deuda previa
    await redis_override.set(f"deuda:{cod_socio}", '{"saldo": 100}', ex=600)
    assert await redis_override.exists(f"deuda:{cod_socio}") == 1

    # 1. Primera activación: debe retornar True
    activada = await activar_ventana_verificacion(redis_override, cod_socio, ttl=60)
    assert activada is True
    assert await esta_en_ventana_verificacion(redis_override, cod_socio) is True

    # Comprobar que purgó la deuda vieja
    assert await redis_override.exists(f"deuda:{cod_socio}") == 0

    # 2. Clic repetido (Idempotencia con NX): debe retornar False sin reiniciar el TTL
    segundo_intento = await activar_ventana_verificacion(redis_override, cod_socio, ttl=60)
    assert segundo_intento is False
    assert await esta_en_ventana_verificacion(redis_override, cod_socio) is True

    # 3. Cierre manual de la ventana
    await cerrar_ventana_verificacion(redis_override, cod_socio)
    assert await esta_en_ventana_verificacion(redis_override, cod_socio) is False


# ------------------------------------------------------------------------------
# 2. Pruebas de Endpoints REST (HTTP)
# ------------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_obtener_canales_pago_exitoso(client: AsyncClient, db_session: AsyncSession):
    """
    Verifica que un socio autenticado reciba el catálogo de canales con sus URLs oficiales.
    """
    usuario, token = await crear_usuario_y_suministro(db_session, cod_socio="540")

    response = await client.get(
        "/api/v1/pagos/canales/540",
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    data = response.json()
    assert data["cod_socio"] == "540"
    assert data["total_deuda_bs"] > 0
    assert len(data["canales"]) == 2

    # Validar canal Multipago
    multipago = next(c for c in data["canales"] if c["id"] == "multipago")
    assert multipago["nombre"] == "Multipago Bolivia"
    assert multipago["url_redireccion"] == settings.URL_MULTIPAGO_COSMOL
    assert multipago["soporta_qr"] is True

    # Validar canal Pago al Paso
    al_paso = next(c for c in data["canales"] if c["id"] == "pago_al_paso")
    assert al_paso["nombre"] == "Pago al Paso 24/7"
    assert al_paso["url_redireccion"] == settings.URL_PAGO_AL_PASO_COSMOL


@pytest.mark.asyncio
async def test_obtener_canales_socio_no_autorizado(client: AsyncClient, db_session: AsyncSession):
    """
    Verifica HTTP 403 si el usuario intenta consultar los canales de un socio que no le pertenece.
    """
    usuario, token = await crear_usuario_y_suministro(db_session, cod_socio="540")

    # Intentar consultar un suministro no vinculado a su cuenta
    response = await client.get(
        "/api/v1/pagos/canales/999999",
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "SUPPLY_ACCESS_DENIED"


@pytest.mark.asyncio
async def test_obtener_canales_sin_autenticacion(client: AsyncClient):
    """
    Verifica HTTP 401 si no se envía el header Authorization Bearer.
    """
    response = await client.get("/api/v1/pagos/canales/540")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_registrar_intento_pago_activa_ventana(
    client: AsyncClient, db_session: AsyncSession, redis_override: Redis
):
    """
    Verifica el registro de intención, la respuesta de redirección y la activación en Redis.
    """
    usuario, token = await crear_usuario_y_suministro(db_session, cod_socio="540")

    response = await client.post(
        "/api/v1/pagos/registrar-intento/540",
        json={"canal_id": "multipago"},
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    data = response.json()
    assert data["exito"] is True
    assert data["canal_id"] == "multipago"
    assert data["url_redireccion"] == settings.URL_MULTIPAGO_COSMOL
    assert data["ventana_verificacion_activa"] is True

    # Verificar que Redis tiene la clave activa
    assert await esta_en_ventana_verificacion(redis_override, "540") is True


@pytest.mark.asyncio
async def test_registrar_intento_canal_invalido(client: AsyncClient, db_session: AsyncSession):
    """
    Verifica error de validación ante un canal desconocido.
    """
    usuario, token = await crear_usuario_y_suministro(db_session, cod_socio="540")

    response = await client.post(
        "/api/v1/pagos/registrar-intento/540",
        json={"canal_id": "canal_ficticio_bitcoin"},
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code in (400, 422)


@pytest.mark.asyncio
async def test_verificar_estado_post_pago(client: AsyncClient, db_session: AsyncSession):
    """
    Verifica la consulta rápida post-pago para constatar el saldo reportado por COSMOL.
    """
    usuario, token = await crear_usuario_y_suministro(db_session, cod_socio="540")

    response = await client.get(
        "/api/v1/pagos/verificar-estado/540",
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    data = response.json()
    assert data["cod_socio"] == "540"
    assert "deuda_saldada" in data
    assert "saldo_actual_bs" in data
    assert "ventana_activa" in data


@pytest.mark.asyncio
async def test_deuda_endpoint_soporta_force_refresh(client: AsyncClient, db_session: AsyncSession):
    """
    Verifica que el endpoint de deuda acepte force_refresh=true sin errores.
    """
    usuario, token = await crear_usuario_y_suministro(db_session, cod_socio="540")

    response = await client.get(
        "/api/v1/deuda/540?force_refresh=true",
        headers={"Authorization": f"Bearer {token}"}
    )

    assert response.status_code == 200
    data = response.json()
    assert data["cod_socio"] == "540"
    assert data["saldo_pendiente_bs"] > 0
