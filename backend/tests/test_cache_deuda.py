import pytest
from app.core.redis import get_redis
from app.services.servicio_cache_deuda import (
    construir_clave_cache_deuda,
    guardar_deuda_cache,
    obtener_deuda_cache,
    invalidar_deuda_cache,
)


def test_construir_clave_cache_deuda():
    assert construir_clave_cache_deuda(" 540 ") == "deuda:540"
    assert construir_clave_cache_deuda("1002") == "deuda:1002"


@pytest.mark.asyncio
async def test_flujo_cache_deuda_redis():
    """
    Verifica el ciclo de vida completo de la caché de deuda en Redis:
    Guardar con TTL -> Obtener (Cache Hit < 20 ms) -> Invalidar -> Obtener (Cache Miss).
    """
    redis = await get_redis()
    cod_socio = "test_540"

    datos_muestra = {
        "cod_socio": "test_540",
        "saldo_pendiente_bs": 132.34,
        "cantidad_facturas_pendientes": 2,
        "esta_vencido": True,
        "facturas": [
            {"nro_factura": "7444051", "monto_bs": 70.92},
            {"nro_factura": "7473308", "monto_bs": 61.42},
        ]
    }

    # 1. Guardar en Redis con TTL de 30 segundos para la prueba
    exito_guardado = await guardar_deuda_cache(redis, cod_socio, datos_muestra, ttl_seconds=30)
    assert exito_guardado is True

    # 2. Recuperar de Redis (Cache Hit)
    datos_recuperados = await obtener_deuda_cache(redis, cod_socio)
    assert datos_recuperados is not None
    assert datos_recuperados["cod_socio"] == "test_540"
    assert datos_recuperados["saldo_pendiente_bs"] == 132.34
    assert datos_recuperados["esta_vencido"] is True
    assert len(datos_recuperados["facturas"]) == 2

    # Verificar que tiene TTL asignado en Redis
    ttl_restante = await redis.ttl(construir_clave_cache_deuda(cod_socio))
    assert ttl_restante > 0 and ttl_restante <= 30

    # 3. Invalidar la clave
    exito_borrado = await invalidar_deuda_cache(redis, cod_socio)
    assert exito_borrado is True

    # 4. Recuperar tras invalidación (Cache Miss)
    datos_post_invalido = await obtener_deuda_cache(redis, cod_socio)
    assert datos_post_invalido is None


@pytest.mark.asyncio
async def test_cache_miss_socio_no_existente():
    """
    Verifica que consultar un socio que nunca fue cacheado retorne None sin fallar.
    """
    redis = await get_redis()
    resultado = await obtener_deuda_cache(redis, "socio_nunca_cacheado_99999")
    assert resultado is None
