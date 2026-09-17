"""
Batería de pruebas automatizadas para Consulta de Deuda y Dashboard Multicuenta (DEV 2).
Valida semaforización, montos en Bs, alertas de corte, caché en Redis (<20ms),
enmascaramiento de privacidad y control de acceso multicuenta en PostgreSQL.
"""
import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy import delete
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token
from app.db.models import Suministro, Usuario
from app.services.servicio_deuda import (
    ServicioDeuda,
    enmascarar_ci_nit,
    enmascarar_nombre_titular,
)
from app.core.exceptions import ForbiddenException, NotFoundException


def generar_telefono_unico() -> str:
    """Genera un número telefónico único para evitar colisiones de unicidad en PostgreSQL."""
    return f"+5917{uuid.uuid4().int % 9000000 + 1000000}"


@pytest.mark.asyncio
async def test_utilitarios_enmascaramiento():
    """
    Verifica las funciones de ofuscación de datos confidenciales para inquilinos.
    """
    assert enmascarar_nombre_titular("DURAN ELOISA RIVERA DE") == "D**** E**** R**** D****"
    assert enmascarar_nombre_titular("PEREZ JUAN") == "P**** J****"
    assert enmascarar_ci_nit("2823231") == "***231"
    assert enmascarar_ci_nit("12") == "****"


@pytest.mark.asyncio
async def test_servicio_deuda_socio_al_dia(db_session: AsyncSession, redis_override: Redis):
    """
    Verifica la respuesta para un socio que no tiene deudas pendientes (al día).
    """
    user_id = uuid.uuid4()
    cod_socio = "556"  # Socio al día en MOCK_SOCIOS_LEGADO

    # Limpiar suministros previos con este código para aislar el test
    await db_session.execute(delete(Suministro).where(Suministro.cod_socio == cod_socio))
    await db_session.commit()

    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True
    )
    suministro = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio,
        alias="Mi Casa",
        rol="TITULAR",
        es_suministro_principal=True
    )
    db_session.add(usuario)
    db_session.add(suministro)
    await db_session.commit()

    await redis_override.delete(f"deuda:{cod_socio}")

    servicio = ServicioDeuda(db=db_session, redis_client=redis_override)
    resumen = await servicio.obtener_deuda_suministro(usuario_id=user_id, cod_socio=cod_socio)

    assert resumen.cod_socio == cod_socio
    assert resumen.moneda == "Bs"
    assert resumen.saldo_pendiente_bs == 0.0
    assert resumen.cantidad_facturas_pendientes == 0
    assert resumen.esta_vencido is False
    assert resumen.alerta_corte is False
    assert "al día" in resumen.mensaje_alerta.lower()
    assert resumen.suministro.nombre_titular == "SUAREZ BALTAZAR VICTOR HUGO,CAROLINA"
    assert resumen.origen_datos == "SISTEMA_LEGADO"


@pytest.mark.asyncio
async def test_servicio_deuda_socio_en_mora_y_alerta_corte(db_session: AsyncSession, redis_override: Redis):
    """
    Verifica que un socio con 2 facturas pendientes active la alerta roja de corte
    y calcule correctamente los montos y días de mora.
    """
    user_id = uuid.uuid4()
    cod_socio = "540"  # Socio con 2 facturas en MOCK_DEUDAS_LEGADO (Agosto y Septiembre 2026)

    await db_session.execute(delete(Suministro).where(Suministro.cod_socio == cod_socio))
    await db_session.commit()

    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True
    )
    suministro = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio,
        alias="Casa Principal",
        rol="TITULAR",
        es_suministro_principal=True
    )
    db_session.add(usuario)
    db_session.add(suministro)
    await db_session.commit()

    await redis_override.delete(f"deuda:{cod_socio}")

    servicio = ServicioDeuda(db=db_session, redis_client=redis_override)
    resumen = await servicio.obtener_deuda_suministro(usuario_id=user_id, cod_socio=cod_socio)

    assert resumen.cod_socio == cod_socio
    assert resumen.saldo_pendiente_bs == round(70.92 + 61.42, 2)
    assert resumen.cantidad_facturas_pendientes == 2
    assert resumen.alerta_corte is True  # 2 facturas -> riesgo de corte
    assert "corte del servicio" in resumen.mensaje_alerta.lower()
    assert len(resumen.facturas_pendientes) == 2


@pytest.mark.asyncio
async def test_servicio_deuda_cache_hit_redis(db_session: AsyncSession, redis_override: Redis):
    """
    Verifica que la primera consulta almacene en Redis y la segunda retorne desde CACHE (<20ms).
    """
    user_id = uuid.uuid4()
    cod_socio = "556"

    await db_session.execute(delete(Suministro).where(Suministro.cod_socio == cod_socio))
    await db_session.commit()

    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True
    )
    suministro = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio,
        alias="Casa",
        rol="TITULAR",
        es_suministro_principal=True
    )
    db_session.add(usuario)
    db_session.add(suministro)
    await db_session.commit()

    await redis_override.delete(f"deuda:{cod_socio}")

    servicio = ServicioDeuda(db=db_session, redis_client=redis_override)

    # 1. Primera llamada: Cache Miss
    res1 = await servicio.obtener_deuda_suministro(usuario_id=user_id, cod_socio=cod_socio)
    assert res1.origen_datos == "SISTEMA_LEGADO"

    # 2. Segunda llamada: Cache Hit en Redis
    res2 = await servicio.obtener_deuda_suministro(usuario_id=user_id, cod_socio=cod_socio)
    assert res2.origen_datos == "CACHE"
    assert res2.saldo_pendiente_bs == res1.saldo_pendiente_bs


@pytest.mark.asyncio
async def test_servicio_deuda_forzar_refresco(db_session: AsyncSession, redis_override: Redis):
    """
    Verifica que 'forzar_refresco=True' ignore la caché y consulte en vivo al sistema legado.
    """
    user_id = uuid.uuid4()
    cod_socio = "556"

    await db_session.execute(delete(Suministro).where(Suministro.cod_socio == cod_socio))
    await db_session.commit()

    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True
    )
    suministro = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio,
        alias="Casa",
        rol="TITULAR",
        es_suministro_principal=True
    )
    db_session.add(usuario)
    db_session.add(suministro)
    await db_session.commit()

    servicio = ServicioDeuda(db=db_session, redis_client=redis_override)

    # Poblar caché
    await servicio.obtener_deuda_suministro(usuario_id=user_id, cod_socio=cod_socio)

    # Forzar refresco
    res_forzado = await servicio.obtener_deuda_suministro(
        usuario_id=user_id, cod_socio=cod_socio, forzar_refresco=True
    )
    assert res_forzado.origen_datos == "SISTEMA_LEGADO"


@pytest.mark.asyncio
async def test_servicio_deuda_enmascaramiento_inquilino(db_session: AsyncSession, redis_override: Redis):
    """
    Verifica que para un usuario en rol CONSULTA_PAGO (inquilino), los datos sensibles se enmascaren con asteriscos.
    """
    user_id = uuid.uuid4()
    cod_socio = "540"

    await db_session.execute(delete(Suministro).where(Suministro.cod_socio == cod_socio))
    await db_session.commit()

    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True
    )
    suministro = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio,
        alias="Alquiler Don Bosco",
        rol="CONSULTA_PAGO",  # Rol inquilino
        es_suministro_principal=False
    )
    db_session.add(usuario)
    db_session.add(suministro)
    await db_session.commit()

    await redis_override.delete(f"deuda:{cod_socio}")

    servicio = ServicioDeuda(db=db_session, redis_client=redis_override)
    resumen = await servicio.obtener_deuda_suministro(usuario_id=user_id, cod_socio=cod_socio)

    assert resumen.suministro.rol_usuario == "CONSULTA_PAGO"
    assert "*" in resumen.suministro.nombre_titular
    assert "D****" in resumen.suministro.nombre_titular
    assert resumen.suministro.ci_nit == "***231"  # CI enmascarada


@pytest.mark.asyncio
async def test_servicio_deuda_suministro_ajeno_retorna_403(db_session: AsyncSession, redis_override: Redis):
    """
    Verifica que un usuario no pueda consultar un suministro ajeno no vinculado a su cuenta (HTTP 403).
    """
    user_id = uuid.uuid4()
    cod_socio_no_vinculado = "999888"

    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True
    )
    db_session.add(usuario)
    await db_session.commit()

    servicio = ServicioDeuda(db=db_session, redis_client=redis_override)

    with pytest.raises(ForbiddenException):
        await servicio.obtener_deuda_suministro(
            usuario_id=user_id, cod_socio=cod_socio_no_vinculado
        )


@pytest.mark.asyncio
async def test_endpoint_get_deuda_http(client: AsyncClient, db_session: AsyncSession, redis_override: Redis):
    """
    Prueba HTTP end-to-end del endpoint GET /api/v1/deuda/{cod_socio}.
    """
    user_id = uuid.uuid4()
    cod_socio = "556"

    await db_session.execute(delete(Suministro).where(Suministro.cod_socio == cod_socio))
    await db_session.commit()

    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True
    )
    suministro = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio,
        alias="Casa",
        rol="TITULAR",
        es_suministro_principal=True
    )
    db_session.add(usuario)
    db_session.add(suministro)
    await db_session.commit()

    await redis_override.delete(f"deuda:{cod_socio}")

    token = create_access_token(subject=str(user_id))
    headers = {"Authorization": f"Bearer {token}"}

    response = await client.get(f"/api/v1/deuda/{cod_socio}", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["cod_socio"] == cod_socio
    assert data["moneda"] == "Bs"
    assert data["saldo_pendiente_bs"] == 0.0


@pytest.mark.asyncio
async def test_endpoint_dashboard_resumen_multisuministro(
    client: AsyncClient, db_session: AsyncSession, redis_override: Redis
):
    """
    Prueba HTTP del endpoint GET /api/v1/deuda/dashboard/resumen consolidando
    múltiples contratos bajo un mismo socio digital.
    """
    user_id = uuid.uuid4()
    cod_socio1 = "556"  # Saldo 0.0
    cod_socio2 = "540"  # Saldo 132.34 (70.92 + 61.42)

    await db_session.execute(delete(Suministro).where(Suministro.cod_socio.in_([cod_socio1, cod_socio2])))
    await db_session.commit()

    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True
    )
    sum1 = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio1,
        alias="Casa Principal",
        rol="TITULAR",
        es_suministro_principal=True
    )
    sum2 = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio2,
        alias="Alquiler Central",
        rol="CONSULTA_PAGO",
        es_suministro_principal=False
    )
    db_session.add(usuario)
    db_session.add(sum1)
    db_session.add(sum2)
    await db_session.commit()

    await redis_override.delete(f"deuda:{cod_socio1}", f"deuda:{cod_socio2}")

    token = create_access_token(subject=str(user_id))
    headers = {"Authorization": f"Bearer {token}"}

    response = await client.get("/api/v1/deuda/dashboard/resumen", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["usuario_id"] == str(user_id)
    assert data["cantidad_suministros"] == 2
    assert data["deuda_total_consolidada_bs"] == round(0.0 + 132.34, 2)
    assert len(data["suministros"]) == 2


@pytest.mark.asyncio
async def test_endpoint_invalidar_cache(
    client: AsyncClient, db_session: AsyncSession, redis_override: Redis
):
    """
    Prueba HTTP de invalidación manual de caché en Redis.
    """
    user_id = uuid.uuid4()
    cod_socio = "556"

    await db_session.execute(delete(Suministro).where(Suministro.cod_socio == cod_socio))
    await db_session.commit()

    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True
    )
    suministro = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio,
        alias="Casa",
        rol="TITULAR",
        es_suministro_principal=True
    )
    db_session.add(usuario)
    db_session.add(suministro)
    await db_session.commit()

    # Pre-cargar clave en Redis
    await redis_override.set(f"deuda:{cod_socio}", '{"mock": "data"}', ex=600)

    token = create_access_token(subject=str(user_id))
    headers = {"Authorization": f"Bearer {token}"}

    response = await client.post(f"/api/v1/deuda/{cod_socio}/invalidar-cache", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["cache_invalidada"] is True

    # Verificar que ya no existe en Redis
    existe = await redis_override.get(f"deuda:{cod_socio}")
    assert existe is None
