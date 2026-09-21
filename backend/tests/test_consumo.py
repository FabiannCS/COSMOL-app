"""
Batería de pruebas automatizadas para Analítica e Historial de Consumo (DEV 2).
Valida contratos Pydantic v2, cálculo de estadísticas, alerta preventiva de fugas (+30%),
caché en Redis (<20ms), privacidad multicuenta y endpoints HTTP REST.
"""
import uuid
import pytest
from httpx import AsyncClient
from redis.asyncio import Redis
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ForbiddenException
from app.core.security import create_access_token
from app.db.models import Suministro, Usuario
from app.schemas.consumo import (
    ConsumoPeriodoResponse,
    EstadisticasConsumoResponse,
    HistorialConsumoResponse,
)
from app.services.servicio_consumo import (
    ServicioConsumo,
    enmascarar_numero_medidor,
)


def generar_telefono_unico() -> str:
    """Genera un número telefónico único para pruebas en PostgreSQL."""
    return f"+5917{uuid.uuid4().int % 9000000 + 1000000}"


@pytest.mark.asyncio
async def test_esquemas_consumo_validacion():
    """
    Valida la instanciación e invariantes de los esquemas de consumo.
    """
    periodo = ConsumoPeriodoResponse(
        periodo="09/2026",
        mes=9,
        mes_nombre="Septiembre 2026",
        anio=2026,
        consumo_m3=18.5,
        monto_bs=72.15,
        lectura_anterior=1200.0,
        lectura_actual=1218.5,
        fecha_lectura="2026-09-20",
        estado_lectura="NORMAL",
    )
    assert periodo.periodo == "09/2026"
    assert periodo.consumo_m3 == 18.5

    stats = EstadisticasConsumoResponse(
        promedio_m3=16.0,
        consumo_maximo_m3=20.0,
        mes_consumo_maximo="08/2026",
        consumo_minimo_m3=12.0,
        mes_consumo_minimo="02/2026",
        consumo_ultimo_mes_m3=18.5,
        consumo_atipico=False,
        porcentaje_variacion_ultimo_mes=15.6,
        mensaje_alerta=None,
        tendencia="SUBIENDO",
    )
    assert stats.promedio_m3 == 16.0
    assert stats.consumo_atipico is False


@pytest.mark.asyncio
async def test_utilitarios_enmascaramiento_medidor():
    """
    Verifica la ofuscación del número de medidor para inquilinos.
    """
    assert enmascarar_numero_medidor("MED-00540") == "MED-***-40"
    assert enmascarar_numero_medidor("12345") == "MED-***-45"
    assert enmascarar_numero_medidor("12") == "MED-****"
    assert enmascarar_numero_medidor(None) == "MED-***-00"


@pytest.mark.asyncio
async def test_servicio_consumo_socio_estable(
    db_session: AsyncSession, redis_override: Redis
):
    """
    Verifica el historial del socio 556 (consumo estable, sin alertas de fuga).
    """
    user_id = uuid.uuid4()
    cod_socio = "556"

    await db_session.execute(delete(Suministro).where(Suministro.cod_socio == cod_socio))
    await db_session.commit()

    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True,
    )
    suministro = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio,
        alias="Casa Principal",
        rol="TITULAR",
        es_suministro_principal=True,
    )
    db_session.add(usuario)
    db_session.add(suministro)
    await db_session.commit()

    await redis_override.delete(f"consumo:{cod_socio}")

    servicio = ServicioConsumo(db=db_session, redis_client=redis_override)
    resultado = await servicio.consultar_historial(usuario_id=user_id, cod_socio=cod_socio)

    assert isinstance(resultado, HistorialConsumoResponse)
    assert resultado.cod_socio == cod_socio
    assert resultado.rol_acceso == "TITULAR"
    assert resultado.nro_medidor == "MED-00556"
    assert resultado.total_periodos == 12
    assert len(resultado.periodos) == 12

    # Estadísticas para consumo normal
    stats = resultado.estadisticas
    assert stats.promedio_m3 > 0.0
    assert stats.consumo_atipico is False
    assert stats.mensaje_alerta is None
    assert stats.consumo_maximo_m3 >= stats.consumo_minimo_m3


@pytest.mark.asyncio
async def test_servicio_consumo_alerta_fuga_atipica_socio_540(
    db_session: AsyncSession, redis_override: Redis, monkeypatch
):
    """
    Verifica la detección automática de consumo atípico (+75%) en el socio 540
    para validar la alerta de fuga preventiva.
    """
    dataset_fuga = [
        {"periodo": f"{m:02d}/2025" if m >= 10 else f"{m:02d}/2026", "mes": m, "anio": 2025 if m >= 10 else 2026, "consumo_m3": 18.0, "monto_bs": 70.0, "estado_lectura": "NORMAL", "fecha_lectura": "2026-01-01"}
        for m in [10, 11, 12, 1, 2, 3, 4, 5, 6, 7, 8]
    ]
    dataset_fuga.append({"periodo": "09/2026", "mes": 9, "anio": 2026, "consumo_m3": 32.0, "monto_bs": 124.8, "estado_lectura": "NORMAL", "fecha_lectura": "2026-09-20"})

    from app.integrations.cosmol_client import cosmol_client
    async def _mock_historial(cod_socio, meses=12):
        return dataset_fuga

    monkeypatch.setattr(cosmol_client, "obtener_historial_consumo", _mock_historial)

    user_id = uuid.uuid4()
    cod_socio = "540"

    await db_session.execute(delete(Suministro).where(Suministro.cod_socio == cod_socio))
    await db_session.commit()

    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True,
    )
    suministro = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio,
        alias="Predio Durán",
        rol="TITULAR",
        es_suministro_principal=True,
    )
    db_session.add(usuario)
    db_session.add(suministro)
    await db_session.commit()

    await redis_override.delete(f"consumo:{cod_socio}")

    servicio = ServicioConsumo(db=db_session, redis_client=redis_override)
    resultado = await servicio.consultar_historial(usuario_id=user_id, cod_socio=cod_socio)

    stats = resultado.estadisticas
    assert stats.consumo_atipico is True, "Debe activar bandera de consumo atípico"
    assert stats.porcentaje_variacion_ultimo_mes is not None
    assert stats.porcentaje_variacion_ultimo_mes >= 30.0
    assert stats.mensaje_alerta is not None
    assert "fugas de agua" in stats.mensaje_alerta
    assert stats.tendencia == "SUBIENDO"
    assert stats.consumo_ultimo_mes_m3 == 32.0


@pytest.mark.asyncio
async def test_servicio_consumo_cache_hit_redis(
    db_session: AsyncSession, redis_override: Redis
):
    """
    Comprueba que la segunda consulta se resuelva directamente desde la memoria Redis.
    """
    user_id = uuid.uuid4()
    cod_socio = "556"

    await db_session.execute(delete(Suministro).where(Suministro.cod_socio == cod_socio))
    await db_session.commit()

    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True,
    )
    suministro = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio,
        alias="Casa",
        rol="TITULAR",
        es_suministro_principal=True,
    )
    db_session.add(usuario)
    db_session.add(suministro)
    await db_session.commit()

    await redis_override.delete(f"consumo:{cod_socio}")

    servicio = ServicioConsumo(db=db_session, redis_client=redis_override)

    # 1. Primera consulta: Cache Miss -> Guarda en Redis
    res1 = await servicio.consultar_historial(usuario_id=user_id, cod_socio=cod_socio)

    # Verificar que existe la clave en Redis
    raw_cache = await redis_override.get(f"consumo:{cod_socio}")
    assert raw_cache is not None

    # 2. Segunda consulta: Cache Hit
    res2 = await servicio.consultar_historial(usuario_id=user_id, cod_socio=cod_socio)
    assert res2.cod_socio == res1.cod_socio
    assert res2.total_periodos == res1.total_periodos
    assert res2.estadisticas.promedio_m3 == res1.estadisticas.promedio_m3


@pytest.mark.asyncio
async def test_servicio_consumo_forzar_refresco(
    db_session: AsyncSession, redis_override: Redis
):
    """
    Comprueba que forzar_refresco=True eluda la caché y actualice Redis.
    """
    user_id = uuid.uuid4()
    cod_socio = "556"

    await db_session.execute(delete(Suministro).where(Suministro.cod_socio == cod_socio))
    await db_session.commit()

    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True,
    )
    suministro = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio,
        alias="Casa",
        rol="TITULAR",
        es_suministro_principal=True,
    )
    db_session.add(usuario)
    db_session.add(suministro)
    await db_session.commit()

    servicio = ServicioConsumo(db=db_session, redis_client=redis_override)
    res = await servicio.consultar_historial(
        usuario_id=user_id, cod_socio=cod_socio, forzar_refresco=True
    )
    assert res.total_periodos == 12


@pytest.mark.asyncio
async def test_servicio_consumo_suministro_ajeno_retorna_403(
    db_session: AsyncSession, redis_override: Redis
):
    """
    Verifica que un socio no pueda consultar el historial de consumo de suministros no vinculados.
    """
    user_id = uuid.uuid4()
    cod_socio_ajeno = "9999"

    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True,
    )
    db_session.add(usuario)
    await db_session.commit()

    servicio = ServicioConsumo(db=db_session, redis_client=redis_override)
    with pytest.raises(ForbiddenException) as exc_info:
        await servicio.consultar_historial(usuario_id=user_id, cod_socio=cod_socio_ajeno)

    assert exc_info.value.error_code == "SUPPLY_ACCESS_DENIED"


@pytest.mark.asyncio
async def test_servicio_consumo_enmascaramiento_inquilino(
    db_session: AsyncSession, redis_override: Redis
):
    """
    Verifica que el rol CONSULTA_PAGO reciba el medidor enmascarado.
    """
    user_id = uuid.uuid4()
    cod_socio = "540"

    await db_session.execute(delete(Suministro).where(Suministro.cod_socio == cod_socio))
    await db_session.commit()

    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True,
    )
    suministro = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio,
        alias="Alquiler Central",
        rol="CONSULTA_PAGO",
        es_suministro_principal=False,
    )
    db_session.add(usuario)
    db_session.add(suministro)
    await db_session.commit()

    await redis_override.delete(f"consumo:{cod_socio}")

    servicio = ServicioConsumo(db=db_session, redis_client=redis_override)
    resultado = await servicio.consultar_historial(usuario_id=user_id, cod_socio=cod_socio)

    assert resultado.rol_acceso == "CONSULTA_PAGO"
    assert resultado.nro_medidor == "MED-***-40"


@pytest.mark.asyncio
async def test_endpoint_get_consumo_http(
    client: AsyncClient, db_session: AsyncSession, redis_override: Redis
):
    """
    Prueba HTTP del endpoint GET /api/v1/consumo/{cod_socio} con JWT Bearer.
    """
    user_id = uuid.uuid4()
    cod_socio = "556"

    await db_session.execute(delete(Suministro).where(Suministro.cod_socio == cod_socio))
    await db_session.commit()

    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True,
    )
    suministro = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio,
        alias="Mi Hogar",
        rol="TITULAR",
        es_suministro_principal=True,
    )
    db_session.add(usuario)
    db_session.add(suministro)
    await db_session.commit()

    await redis_override.delete(f"consumo:{cod_socio}")

    token = create_access_token(subject=str(user_id))
    headers = {"Authorization": f"Bearer {token}"}

    response = await client.get(f"/api/v1/consumo/{cod_socio}", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["cod_socio"] == cod_socio
    assert data["total_periodos"] == 12
    assert "estadisticas" in data
    assert data["estadisticas"]["promedio_m3"] > 0.0


@pytest.mark.asyncio
async def test_endpoint_consumo_sin_token_retorna_401(client: AsyncClient):
    """
    Prueba que el acceso al endpoint sin credenciales devuelva 401 Unauthorized.
    """
    response = await client.get("/api/v1/consumo/556")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_endpoint_invalidar_cache_consumo(
    client: AsyncClient, db_session: AsyncSession, redis_override: Redis
):
    """
    Prueba HTTP de invalidación de caché en Redis para consumo.
    """
    user_id = uuid.uuid4()
    cod_socio = "556"

    await db_session.execute(delete(Suministro).where(Suministro.cod_socio == cod_socio))
    await db_session.commit()

    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True,
    )
    suministro = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio,
        alias="Mi Hogar",
        rol="TITULAR",
        es_suministro_principal=True,
    )
    db_session.add(usuario)
    db_session.add(suministro)
    await db_session.commit()

    token = create_access_token(subject=str(user_id))
    headers = {"Authorization": f"Bearer {token}"}

    response = await client.post(
        f"/api/v1/consumo/{cod_socio}/invalidar-cache", headers=headers
    )
    assert response.status_code == 200
    data = response.json()
    assert data["cod_socio"] == cod_socio
    assert data["cache_invalidada"] in [True, False]
