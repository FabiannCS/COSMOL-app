"""
Batería de pruebas unitarias para DEV 1 (Fase 5 - Pasarelas de Pago):
- Servicio de Caché en Redis para la Ventana de Verificación (servicio_cache_pagos.py)
- Idempotencia ante dobles clics con opción NX=True
- Invalidación de caché de deuda al iniciar pago
- Modelo de auditoría persistente en PostgreSQL (AuditoriaPagoRedireccion)
- Variables de configuración centralizadas (config.py)
"""
import uuid
import pytest
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.config import settings
from app.db.models.usuario import Usuario
from app.db.models.pago import AuditoriaPagoRedireccion
from app.services.servicio_cache_deuda import guardar_deuda_cache, obtener_deuda_cache
from app.services.servicio_cache_pagos import (
    activar_ventana_verificacion,
    esta_en_ventana_verificacion,
    cerrar_ventana_verificacion,
    obtener_tiempo_restante_ventana,
    construir_clave_pago_en_proceso,
)


@pytest.mark.asyncio
async def test_configuracion_pasarelas():
    """Verifica que las variables de configuración de las pasarelas oficiales estén presentes."""
    assert settings.URL_MULTIPAGO_COSMOL == "https://multipago.com/service/cosmol_payment/first"
    assert settings.URL_PAGO_AL_PASO_COSMOL == "https://red.pagoalpaso247.net/servicio/cosmol"
    assert settings.VENTANA_VERIFICACION_PAGO_SEGUNDOS == 900
    assert settings.COOLDOWN_VERIFICACION_PAGO_SEGUNDOS == 30


@pytest.mark.asyncio
async def test_activacion_ventana_verificacion(redis_override: Redis):
    """Verifica la activación exitosa de la ventana de verificación en Redis con TTL."""
    cod_socio = "TEST_PAGO_01"
    clave = construir_clave_pago_en_proceso(cod_socio)
    await redis_override.delete(clave)

    # Inicialmente no debe estar en ventana
    assert await esta_en_ventana_verificacion(redis_override, cod_socio) is False
    assert await obtener_tiempo_restante_ventana(redis_override, cod_socio) == -2

    # Activar ventana
    activado = await activar_ventana_verificacion(redis_override, cod_socio, ttl_seconds=600)
    assert activado is True

    # Comprobar estado en Redis
    assert await esta_en_ventana_verificacion(redis_override, cod_socio) is True
    ttl_restante = await obtener_tiempo_restante_ventana(redis_override, cod_socio)
    assert 580 <= ttl_restante <= 600

    # Limpieza
    await redis_override.delete(clave)


@pytest.mark.asyncio
async def test_idempotencia_doble_clic_ventana(redis_override: Redis):
    """
    Verifica que si el socio pulsa 2 o más veces consecutivas la URL de pago,
    Redis utiliza NX=True y no reinicia ni corrompe el temporizador original.
    """
    cod_socio = "TEST_PAGO_02"
    clave = construir_clave_pago_en_proceso(cod_socio)
    await redis_override.delete(clave)

    # Primer clic: activa la ventana exitosamente
    primer_clic = await activar_ventana_verificacion(redis_override, cod_socio, ttl_seconds=500)
    assert primer_clic is True

    ttl_inicial = await obtener_tiempo_restante_ventana(redis_override, cod_socio)
    assert 480 <= ttl_inicial <= 500

    # Segundo clic inmediato (simulando doble clic o reintento ansioso del socio)
    segundo_clic = await activar_ventana_verificacion(redis_override, cod_socio, ttl_seconds=900)
    # Debe retornar False indicando que ya existía (idempotente)
    assert segundo_clic is False

    # El TTL no debió haberse reiniciado a 900s
    ttl_posterior = await obtener_tiempo_restante_ventana(redis_override, cod_socio)
    assert ttl_posterior <= ttl_inicial

    # Limpieza
    await redis_override.delete(clave)


@pytest.mark.asyncio
async def test_cierre_ventana_verificacion(redis_override: Redis):
    """Verifica el cierre manual de la ventana cuando la deuda es saldada."""
    cod_socio = "TEST_PAGO_03"
    clave = construir_clave_pago_en_proceso(cod_socio)

    await activar_ventana_verificacion(redis_override, cod_socio, ttl_seconds=300)
    assert await esta_en_ventana_verificacion(redis_override, cod_socio) is True

    # Cerrar ventana
    cerrado = await cerrar_ventana_verificacion(redis_override, cod_socio)
    assert cerrado is True
    assert await esta_en_ventana_verificacion(redis_override, cod_socio) is False
    assert await obtener_tiempo_restante_ventana(redis_override, cod_socio) == -2

    # Intentar cerrar nuevamente una clave inexistente
    cerrado_reintento = await cerrar_ventana_verificacion(redis_override, cod_socio)
    assert cerrado_reintento is False


@pytest.mark.asyncio
async def test_purga_cache_deuda_al_activar_ventana(redis_override: Redis):
    """
    Verifica que al hacer clic en pagar (activar ventana), de inmediato se purgue
    la clave 'deuda:{cod_socio}' para que la próxima lectura no lea datos obsoletos.
    """
    cod_socio = "TEST_PAGO_04"
    datos_deuda_falsa = {"saldo_pendiente_bs": 150.0, "esta_vencido": True}

    # Pre-cargar deuda en caché
    await guardar_deuda_cache(redis_override, cod_socio, datos_deuda_falsa, ttl_seconds=300)
    cache_previa = await obtener_deuda_cache(redis_override, cod_socio)
    assert cache_previa is not None
    assert cache_previa["saldo_pendiente_bs"] == 150.0

    # Activar ventana de pago
    await activar_ventana_verificacion(redis_override, cod_socio)

    # La caché de deuda debe haber sido purgada
    cache_posterior = await obtener_deuda_cache(redis_override, cod_socio)
    assert cache_posterior is None

    # Limpieza
    await redis_override.delete(construir_clave_pago_en_proceso(cod_socio))


@pytest.mark.asyncio
async def test_persistencia_modelo_auditoria_pago(db_session: AsyncSession):
    """
    Verifica que el modelo AuditoriaPagoRedireccion se inserte correctamente
    en PostgreSQL con todas sus relaciones y campos.
    """
    # 1. Crear un usuario de prueba para la relación de foreign key
    telefono_test = f"+5917{uuid.uuid4().hex[:7]}"
    nuevo_usuario = Usuario(
        telefono=telefono_test,
        password_hash="$2b$12$e8Y5t1aZ8v2wP9r3k5m2Oe",
        esta_activo=True
    )
    db_session.add(nuevo_usuario)
    await db_session.commit()
    await db_session.refresh(nuevo_usuario)

    # 2. Registrar auditoría de redirección de pago
    cod_socio = "540"
    monto_deuda = 142.50
    canal = "multipago"

    auditoria = AuditoriaPagoRedireccion(
        usuario_id=nuevo_usuario.id,
        cod_socio=cod_socio,
        canal_id=canal,
        monto_deuda_bs=monto_deuda,
        ip_origen="192.168.1.50"
    )
    db_session.add(auditoria)
    await db_session.commit()
    await db_session.refresh(auditoria)

    assert auditoria.id is not None
    assert auditoria.usuario_id == nuevo_usuario.id
    assert auditoria.cod_socio == cod_socio
    assert auditoria.canal_id == canal
    assert float(auditoria.monto_deuda_bs) == monto_deuda
    assert auditoria.ip_origen == "192.168.1.50"
    assert auditoria.created_at is not None

    # 3. Recuperar registro desde la base de datos
    stmt = select(AuditoriaPagoRedireccion).where(AuditoriaPagoRedireccion.id == auditoria.id)
    resultado = await db_session.execute(stmt)
    registro_recuperado = resultado.scalar_one_or_none()

    assert registro_recuperado is not None
    assert registro_recuperado.canal_id == "multipago"
    assert f"<AuditoriaPagoRedireccion" in repr(registro_recuperado)

    # Limpieza
    await db_session.delete(auditoria)
    await db_session.delete(nuevo_usuario)
    await db_session.commit()
