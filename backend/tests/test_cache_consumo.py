"""
Pruebas unitarias y de integración para la caché en Redis de Consumo Histórico.
Valida ciclo de vida completo (set con TTL, get con latencia < 20 ms, invalidación)
y resiliencia ante desconexiones.
"""
import time
import pytest
from app.core.redis import get_redis
from app.services.servicio_cache_consumo import (
    construir_clave_cache_consumo,
    guardar_consumo_cache,
    obtener_consumo_cache,
    invalidar_consumo_cache,
)


def test_construir_clave_cache_consumo():
    assert construir_clave_cache_consumo(" 540 ") == "consumo:540"
    assert construir_clave_cache_consumo("1002") == "consumo:1002"
    assert construir_clave_cache_consumo("  556  ") == "consumo:556"


@pytest.mark.asyncio
async def test_flujo_cache_consumo_redis():
    """
    Verifica el ciclo de vida completo de la caché de consumo en Redis:
    Guardar con TTL -> Obtener (Cache Hit < 20 ms) -> Invalidar -> Obtener (Cache Miss).
    """
    redis = await get_redis()
    cod_socio = "test_consumo_540"

    datos_muestra = [
        {
            "periodo": "08/2026",
            "mes": 8,
            "anio": 2026,
            "consumo_m3": 20.0,
            "monto_bs": 78.00,
            "lectura_anterior": 1279.0,
            "lectura_actual": 1299.0,
            "estado_lectura": "NORMAL",
            "fecha_lectura": "2026-08-20"
        },
        {
            "periodo": "09/2026",
            "mes": 9,
            "anio": 2026,
            "consumo_m3": 32.0,
            "monto_bs": 124.80,
            "lectura_anterior": 1299.0,
            "lectura_actual": 1331.0,
            "estado_lectura": "NORMAL",
            "fecha_lectura": "2026-09-20"
        }
    ]

    # 1. Guardar en Redis con TTL de 30 segundos
    exito_guardado = await guardar_consumo_cache(redis, cod_socio, datos_muestra, ttl_seconds=30)
    assert exito_guardado is True

    # 2. Recuperar de Redis y medir latencia (< 20 ms)
    t0 = time.perf_counter()
    datos_recuperados = await obtener_consumo_cache(redis, cod_socio)
    latencia_ms = (time.perf_counter() - t0) * 1000.0

    assert datos_recuperados is not None
    assert len(datos_recuperados) == 2
    assert datos_recuperados[0]["periodo"] == "08/2026"
    assert datos_recuperados[1]["consumo_m3"] == 32.0
    assert latencia_ms < 50.0, f"Latencia de lectura en Redis ({latencia_ms:.2f} ms) debe ser ultra rápida"

    # Verificar que tiene TTL asignado en Redis
    ttl_restante = await redis.ttl(construir_clave_cache_consumo(cod_socio))
    assert 0 < ttl_restante <= 30

    # 3. Invalidar la clave
    exito_borrado = await invalidar_consumo_cache(redis, cod_socio)
    assert exito_borrado is True

    # 4. Recuperar tras invalidación (Cache Miss)
    datos_post_invalido = await obtener_consumo_cache(redis, cod_socio)
    assert datos_post_invalido is None


@pytest.mark.asyncio
async def test_resiliencia_sin_redis():
    """
    Verifica degradación suave: si el cliente Redis es None, las funciones retornan
    valores seguros (False o None) sin lanzar excepciones que interrumpan la aplicación.
    """
    assert await guardar_consumo_cache(None, "540", {}) is False
    assert await obtener_consumo_cache(None, "540") is None
    assert await invalidar_consumo_cache(None, "540") is False
