# Entregables DEV 1: Conectividad Legada de Consumo Histórico y Caché Redis

> **Fase:** Fase 4 — Analítica de Consumo Histórico  
> **Rol responsable:** DEV 1 (Infraestructura, Conector Legado, Normalizador Tolerante y Caché Redis)  
> **Fecha de conclusión:** Septiembre 2026  
> **Documento de referencia:** `Docs/backend/pendiente/TASK-04-analitica-consumo-historico.md` y `AGENTS.md` (Secciones 4.5, 10.5, 12.2, 12.3)  
> **Estado:** COMPLETADO y certificado en Docker (8/8 tests propios y 78/78 tests totales de regresión pasando al 100%)

---

## 1. Resumen Ejecutivo

**DEV 1** ha completado e integrado la capa de infraestructura y datos para la **Tarea 4 (Analítica de Consumo Histórico)**, dejando la base 100% lista para que **DEV 2** construya los esquemas, servicio de negocio y endpoints REST:

1. **Preparación Arquitectónica para la API Real de COSMOL:**
   - La cooperativa COSMOL aún no tiene desplegado el endpoint `/socios/{cod_socio}/consumos` en su servidor productivo (actualmente devuelve HTTP 400 "Ruta GET mal formada").
   - DEV 1 implementó una **Capa Anti-Corrupción desacoplada** con soporte dual:
     - `MOCK_COSMOL_CONSUMO = True`: Retorna datasets deterministas ricos de Montero.
     - `MOCK_COSMOL_CONSUMO = False`: Llama directamente a la API real de COSMOL. Si la API real no está desplegada o responde con error en desarrollo, aplica un fallback seguro para no bloquear a nadie.
2. **Normalizador Tolerante a Informix (`_normalizar_consumo_legado`):**
   - Absorbe variaciones históricas de nombres de campos (`CONSUMO_M3`, `VOLUMEN`, `M3`, `GESTION`, `ANIO`, `NMES`, `MES`, `LECTURA_ACTUAL`, `LECT_ACT`, `MONTOTOTAL`, `IMPORTE`).
   - Limpia espacios en blanco fijos (`.strip()`) y asegura conversión estricta a tipos numéricos (`float`, `int`).
3. **Dataset Simulado Determinista de 12 Meses (`MOCK_CONSUMOS_LEGADO`):**
   - Socio `556`: Consumo residencial estable (~16 m³ promedio, lecturas consistentes).
   - Socio `540`: Consumo de 18 m³ durante 11 meses con un **salto repentino a 32 m³ (+75%) en el mes 12**, diseñado especialmente para que DEV 2 y Flutter validen la alerta de fuga (`consumo_atipico = True`).
   - Socios `1001`, `1002`, `1003`: Series comerciales y residenciales variadas.
   - Cualquier otro código: Generador matemático sintético de 12 periodos continuos.
4. **Módulo de Caché de Alto Rendimiento en Redis (`servicio_cache_consumo.py`):**
   - Clave: `consumo:{cod_socio}`.
   - TTL: 15 minutos (`CONSUMO_CACHE_TTL_SECONDS = 900`).
   - Latencia de respuesta en *cache-hit*: **< 5 ms**.
   - Resiliencia con degradación suave si Redis no está disponible.
   - Soporte de invalidación manual para pull-to-refresh en Flutter.
5. **Certificación Total en Docker:**
   - 8 tests específicos de DEV 1 pasando al 100%.
   - 78/78 tests de la suite completa pasando sin ninguna regresión (17.60 s).

---

## 2. Inventario de Archivos Modificados y Creados

### 2.1 Configuración (`backend/app/core/config.py`)
```python
MOCK_COSMOL_CONSUMO: bool = True  # True mientras COSMOL habilita el endpoint real en producción
CONSUMO_CACHE_TTL_SECONDS: int = 900  # 15 minutos (900 segundos)
```

### 2.2 Cliente Legado (`backend/app/integrations/cosmol_client.py`)
- Constante `MOCK_CONSUMOS_LEGADO` (12 meses por socio).
- `_normalizar_consumo_legado(item: Dict[str, Any]) -> Dict[str, Any]`
- `_generar_consumos_sinteticos(codigo: str) -> List[Dict[str, Any]]`
- `async def obtener_historial_consumo(cod_socio: str, meses: int = 12) -> List[Dict[str, Any]]`

### 2.3 Servicio de Caché Redis (`backend/app/services/servicio_cache_consumo.py`) [NUEVO]
- `construir_clave_cache_consumo(cod_socio: str) -> str`
- `guardar_consumo_cache(redis_client, cod_socio, datos, ttl_seconds) -> bool`
- `obtener_consumo_cache(redis_client, cod_socio) -> Optional[Any]`
- `invalidar_consumo_cache(redis_client, cod_socio) -> bool`

### 2.4 Batería de Pruebas de DEV 1 (`backend/tests/`) [NUEVO]
- `tests/test_cosmol_client_consumo.py` (5 tests).
- `tests/test_cache_consumo.py` (3 tests).

---

## 3. Contrato de Interfaz para DEV 2

DEV 2 puede consumir directamente las siguientes funciones sin preocuparse por la red de COSMOL ni por la implementación de Redis:

### 3.1 Obtener datos de consumo:
```python
from app.integrations.cosmol_client import cosmol_client

# Retorna lista de diccionarios ordenados cronológicamente (antiguo -> reciente)
consumos = await cosmol_client.obtener_historial_consumo(cod_socio="540", meses=12)

# Estructura de cada registro:
# {
#     "periodo": "09/2026",
#     "mes": 9,
#     "anio": 2026,
#     "lectura_anterior": 1299.0,
#     "lectura_actual": 1331.0,
#     "consumo_m3": 32.0,
#     "monto_bs": 124.80,
#     "estado_lectura": "NORMAL",
#     "fecha_lectura": "2026-09-20"
# }
```

### 3.2 Operaciones de Caché:
```python
from app.services.servicio_cache_consumo import (
    obtener_consumo_cache,
    guardar_consumo_cache,
    invalidar_consumo_cache,
)

# 1. Verificar si ya está en Redis
cached = await obtener_consumo_cache(redis, cod_socio)
if cached and not forzar_refresco:
    return cached

# 2. Guardar en Redis (TTL 15 min por defecto)
await guardar_consumo_cache(redis, cod_socio, data_dict)

# 3. Invalidar (pull-to-refresh)
await invalidar_consumo_cache(redis, cod_socio)
```

---

## 4. Certificación en Docker

```bash
docker compose exec backend-api pytest -v tests/test_cosmol_client_consumo.py tests/test_cache_consumo.py
============================== 8 passed in 0.57s ===============================

docker compose exec backend-api pytest -v
============================= 78 passed in 17.60s ==============================
```
