# Entregables DEV 1: Pasarelas de Pago Externas, Ventana de Verificación Redis y Auditoría

> **Fase:** Fase 5 — Redirección a Pasarelas de Pago y Actualización Dinámica de Deuda  
> **Rol responsable:** DEV 1 (Aireyu) — Configuración Oficial, Caché Atómica e Idempotente en Redis y Persistencia PostgreSQL  
> **Fecha de conclusión:** Septiembre 2026  
> **Documento de referencia:** `Docs/backend/pendiente/TASK-05-pagos-qr-y-conciliacion.md` y `AGENTS.md` (Secciones 4.3, 10.3, 12.4)  
> **Estado:** COMPLETADO y certificado en Docker (6/6 tests propios y 96/96 tests totales de la suite pasando al 100%)

---

## 1. Resumen Ejecutivo

**DEV 1 (Aireyu)** ha completado e integrado la capa de infraestructura, configuración, persistencia y caché de Redis para la **Tarea 5 (Pasarelas de Pago y Conciliación)**, dejando los cimientos 100% listos para que **DEV 2 (Eduardo)** implemente los esquemas DTO, el servicio de negocio y los endpoints REST:

1. **Configuración Oficial Centralizada (`config.py`):**
   - Incorporación de las URLs de recaudación en producción para **Multipago Bolivia** y **Pago al Paso**.
   - Configuración de la ventana temporal de verificación (`VENTANA_VERIFICACION_PAGO_SEGUNDOS = 900` / 15 min).
   - Configuración del micro-TTL anti-saturación de Informix (`COOLDOWN_VERIFICACION_PAGO_SEGUNDOS = 30`).
2. **Servicio de Caché Atómico e Idempotente en Redis (`servicio_cache_pagos.py`):**
   - **Idempotencia nativa con `SET NX`:** Si el usuario realiza dobles clics o múltiples peticiones al botón de pago, Redis no reinicia el temporizador ni se bugea; preserva la ventana original intacta.
   - **Purga de Deuda Inmediata:** Al activarse la ventana de verificación, se elimina la clave `deuda:{cod_socio}` en Redis para garantizar que la próxima lectura consulte directamente al sistema central de COSMOL.
   - **Funciones de control:** `activar_ventana_verificacion`, `esta_en_ventana_verificacion`, `cerrar_ventana_verificacion` y `obtener_tiempo_restante_ventana`.
3. **Modelo de Persistencia en PostgreSQL (`models/pago.py`):**
   - Tabla `auditoria_pagos_redireccion` con clave foránea hacia `usuarios.id`, código de socio, canal (`multipago`/`pago_al_paso`), monto adeudado en Bs, IP de origen y timestamp de auditoría.
   - Migración de base de datos generada y aplicada con Alembic (`add_auditoria_pagos_redireccion_table`).
4. **Certificación Total en Docker:**
   - 6 tests unitarios específicos de DEV 1 en `test_cache_pagos.py` pasando en 1.18s.
   - 96/96 tests de toda la suite del backend aprobados al 100% en Docker en 31.06s (cero regresiones, cero mocks).

---

## 2. Inventario de Archivos Modificados y Creados

### 2.1 Configuración (`backend/app/core/config.py`)
```python
URL_MULTIPAGO_COSMOL: str = "https://multipago.com/service/cosmol_payment/first"
URL_PAGO_AL_PASO_COSMOL: str = "https://red.pagoalpaso247.net/servicio/cosmol"
VENTANA_VERIFICACION_PAGO_SEGUNDOS: int = 900  # 15 minutos
COOLDOWN_VERIFICACION_PAGO_SEGUNDOS: int = 30  # Micro-TTL anti-saturación Informix
```

### 2.2 Servicio de Caché Redis (`backend/app/services/servicio_cache_pagos.py`) [NUEVO]
- `construir_clave_pago_en_proceso(cod_socio: str) -> str`
- `activar_ventana_verificacion(redis_client, cod_socio, ttl_seconds) -> bool` (Uso de `SET NX=True`)
- `esta_en_ventana_verificacion(redis_client, cod_socio) -> bool`
- `cerrar_ventana_verificacion(redis_client, cod_socio) -> bool`
- `obtener_tiempo_restante_ventana(redis_client, cod_socio) -> int`

### 2.3 Modelo de Base de Datos (`backend/app/db/models/pago.py` y `__init__.py`) [NUEVO]
- `AuditoriaPagoRedireccion`: Modelo ORM mapeado a `auditoria_pagos_redireccion`.
- Migración Alembic `2026_09_22_1447-204a5f9f8fef_add_auditoria_pagos_redireccion_table.py`.

### 2.4 Batería de Pruebas Unitarias (`backend/tests/test_cache_pagos.py`) [NUEVO]
- `test_configuracion_pasarelas`: Valida que las variables de configuración estén presentes y correctas.
- `test_activacion_ventana_verificacion`: Valida activación con TTL en Redis.
- `test_idempotencia_doble_clic_ventana`: Valida comportamiento ante doble clic con `NX=True`.
- `test_cierre_ventana_verificacion`: Valida eliminación de clave al constatar pago.
- `test_purga_cache_deuda_al_activar_ventana`: Valida eliminación de `deuda:{cod_socio}` al pagar.
- `test_persistencia_modelo_auditoria_pago`: Valida inserción y recuperación en PostgreSQL.

---

## 3. Contrato de Interfaz para DEV 2 (Eduardo)

DEV 2 puede consumir directamente estas funciones para construir el servicio de negocio y los endpoints REST:

### 3.1 Activar Ventana de Verificación (Al seleccionar canal de pago):
```python
from app.services.servicio_cache_pagos import activar_ventana_verificacion

# Activa ventana de 15 minutos de forma idempotente y purga la caché de deuda vieja
fue_primera_vez = await activar_ventana_verificacion(redis, cod_socio)
```

### 3.2 Comprobar si está en Ventana de Verificación:
```python
from app.services.servicio_cache_pagos import esta_en_ventana_verificacion

en_proceso = await esta_en_ventana_verificacion(redis, cod_socio)
if en_proceso:
    # Aplicar micro-TTL de 30s (settings.COOLDOWN_VERIFICACION_PAGO_SEGUNDOS)
    # o consultar directamente a Informix
    ...
```

### 3.3 Cerrar Ventana al confirmar Deuda Bs 0.00:
```python
from app.services.servicio_cache_pagos import cerrar_ventana_verificacion

if saldo_actual_bs == 0.0:
    await cerrar_ventana_verificacion(redis, cod_socio)
```

### 3.4 Persistir Registro de Auditoría en PostgreSQL:
```python
from app.db.models.pago import AuditoriaPagoRedireccion

auditoria = AuditoriaPagoRedireccion(
    usuario_id=usuario_id,
    cod_socio=cod_socio,
    canal_id=canal_id,
    monto_deuda_bs=total_deuda_bs,
    ip_origen=request.client.host if request.client else None
)
db.add(auditoria)
await db.commit()
```

---

## 4. Certificación en Docker

```bash
docker compose exec backend-api pytest -v tests/test_cache_pagos.py
============================== 6 passed in 1.18s ===============================

docker compose exec backend-api pytest
============================= 96 passed in 31.06s ==============================
```
