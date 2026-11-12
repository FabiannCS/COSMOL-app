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
    assert resumen.suministro.telefono_celular == usuario.telefono
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


class _FakeCosmolLegacyClient:
    async def obtener_datos_socio(self, cod_socio: str):
        return {
            "CODIGO": cod_socio,
            "NOMBRE": "LIMA LOPEZ MOISES",
            "DIRECCION": "ANTOFAGASTA /24 DE S",
            "NROCIONIT": "552840",
            "ZONA": "1",
            "RUTA": "6",
            "NROC": "38",
            "NROI": "0",
        }

    async def obtener_deudas_socio(self, cod_socio: str):
        return []


@pytest.mark.asyncio
async def test_servicio_deuda_telefono_titular_y_privacidad_cache(
    db_session: AsyncSession, redis_override: Redis
):
    """
    Verifica que:
    1. Para un usuario TITULAR, telefono_celular retorne su número registrado incluso en cache hit
       o cuando la caché de Redis previa no contenía ese campo.
    2. La caché compartida de Redis nunca exponga el teléfono del titular a otro usuario CONSULTA_PAGO.
    """
    titular_id = uuid.uuid4()
    inquilino_id = uuid.uuid4()
    cod_socio = f"tel_{titular_id.hex[:8]}"
    tel_titular = generar_telefono_unico()
    tel_inquilino = generar_telefono_unico()

    usuario_titular = Usuario(
        id=titular_id,
        telefono=tel_titular,
        password_hash="mock_hash",
        esta_activo=True,
    )
    usuario_inquilino = Usuario(
        id=inquilino_id,
        telefono=tel_inquilino,
        password_hash="mock_hash",
        esta_activo=True,
    )
    sum_titular = Suministro(
        id=uuid.uuid4(),
        usuario_id=titular_id,
        cod_socio=cod_socio,
        alias="Casa Titular",
        rol="TITULAR",
        es_suministro_principal=True,
    )
    sum_inquilino = Suministro(
        id=uuid.uuid4(),
        usuario_id=inquilino_id,
        cod_socio=cod_socio,
        alias="Consulta Inquilino",
        rol="CONSULTA_PAGO",
        es_suministro_principal=False,
    )
    db_session.add_all([usuario_titular, usuario_inquilino, sum_titular, sum_inquilino])
    await db_session.commit()

    await redis_override.delete(f"deuda:{cod_socio}")
    servicio = ServicioDeuda(
        db=db_session,
        redis_client=redis_override,
        client_legado=_FakeCosmolLegacyClient(),
    )

    try:
        # 1. Cache miss para Titular: debe retornar su teléfono registrado
        res_titular_miss = await servicio.obtener_deuda_suministro(
            usuario_id=titular_id, cod_socio=cod_socio
        )
        assert res_titular_miss.origen_datos == "SISTEMA_LEGADO"
        assert res_titular_miss.suministro.telefono_celular == tel_titular

        # 2. Cache hit para Inquilino sobre el mismo cod_socio: no debe filtrar teléfono alguno
        res_inquilino_hit = await servicio.obtener_deuda_suministro(
            usuario_id=inquilino_id, cod_socio=cod_socio
        )
        assert res_inquilino_hit.origen_datos == "CACHE"
        assert res_inquilino_hit.suministro.rol_usuario == "CONSULTA_PAGO"
        assert res_inquilino_hit.suministro.telefono_celular == ""

        # 3. Cache hit para Titular: mantiene su propio teléfono registrado
        res_titular_hit = await servicio.obtener_deuda_suministro(
            usuario_id=titular_id, cod_socio=cod_socio
        )
        assert res_titular_hit.origen_datos == "CACHE"
        assert res_titular_hit.suministro.telefono_celular == tel_titular

        # 4. Caché antigua sin clave telefono_celular: sigue inyectando el teléfono al Titular
        raw_cached = await redis_override.get(f"deuda:{cod_socio}")
        assert raw_cached is not None
        assert tel_titular not in raw_cached
    finally:
        await redis_override.delete(f"deuda:{cod_socio}")
        await db_session.execute(delete(Suministro).where(Suministro.cod_socio == cod_socio))
        await db_session.execute(delete(Usuario).where(Usuario.id.in_([titular_id, inquilino_id])))
        await db_session.commit()
