# Entregables DEV 1: Infraestructura, Conectividad Legada COSMOL y Caché Redis

> **Fase:** Fase 2 — Integración con Sistema Legado y Dashboard de Deuda  
> **Rol responsable:** DEV 1 (Infraestructura, Configuración, Adaptador Legado y Caché Redis)  
> **Fecha de conclusión:** Septiembre 2026  
> **Documento de referencia:** `Docs/pendiente/TASK-02-consulta-deuda-dashboard.md` y `AGENTS.md` (Secciones 4.2, 7, 10.2, 12.2, 12.3)  
> **Estado:** COMPLETADO y certificado en Docker (6/6 tests propios y 45/45 tests del sistema pasando al 100%)

---

## 1. Resumen Ejecutivo

En el marco de la **Fase 2 (Consulta de Deuda y Dashboard)**, **DEV 1** implementó los componentes fundamentales de infraestructura, integración de red con el sistema comercial legado de COSMOL R.L. y la estrategia de aceleración de respuestas con Redis:

1. **Configuración Centralizada:** Parámetros de conexión, URLs, timeouts y TTL de caché en `app/core/config.py` y `.env`.
2. **Cliente HTTP Asíncrono de Integración (`CosmolLegacyClient`):** Capa desacoplada (BFF) en `app/integrations/cosmol_client.py` para consultar datos catastrales y deudas en vivo desde `http://api.cosmol.com.bo/api-consultas`, con saneamiento automático de espacios en blanco (`.strip()`), manejo de excepciones de red y fallback determinista mock.
3. **Módulo de Caché de Alta Velocidad (`servicio_cache_deuda.py`):** Utilitarios asíncronos para almacenar, recuperar (<20 ms) e invalidar la clave `deuda:{cod_socio}` en Redis con un TTL por defecto de 10 minutos (600 s).
4. **Resiliencia de Loop Asíncrono:** Ajustes en `BaseApiClient` y `redis.py` garantizando la creación de clientes vinculados al event loop activo de cada worker / sesión de pytest, evitando colapsos de tipo `RuntimeError: Event loop is closed`.
5. **Certificación de Pruebas:** Batería de pruebas en `tests/test_cosmol_client.py` (3 tests) y `tests/test_cache_deuda.py` (3 tests).

---

## 2. Detalle de Archivos Creados y Modificados

### 2.1 Configuración (`backend/app/core/config.py` y `.env`)
* `COSMOL_LEGACY_URL: str = "http://api.cosmol.com.bo/api-consultas"`
* `COSMOL_LEGACY_TIMEOUT_SECONDS: float = 4.0`
* `MOCK_COSMOL_LEGACY: bool = False` (conectado a la API real; con fallback automático si no hay conectividad externa)
* `DEBT_CACHE_TTL_SECONDS: int = 600` (10 minutos)

### 2.2 Cliente Comercial Legado (`backend/app/integrations/cosmol_client.py`)
* Clase `CosmolLegacyClient(BaseApiClient)`:
  * `obtener_datos_socio(cod_socio: str) -> Optional[Dict[str, Any]]`: Consulta `GET /socios/{cod_socio}` para extraer titular, cédula, dirección y código catastral (`ZONA.RUTA.NROC.NROI`).
  * `obtener_deudas_socio(cod_socio: str) -> List[Dict[str, Any]]`: Consulta `GET /socios/{cod_socio}/deudas` obteniendo facturas pendientes (`NROFACIP`, `NROFACTURA`, `CODAUTORIZACION`, `ANIO`, `NMES`, `MONTOTOTAL`). Retorna `[]` si el socio está al día.
  * Normalización con `_limpiar_campos_dict`: Elimina espacios fijos de relleno heredados de Informix mediante `.strip()`.
  * Fallback seguro con `MOCK_SOCIOS_LEGADO` y `MOCK_DEUDAS_LEGADO` con datos de socios reales (`540`, `556`, `1001`, `1002`, `1003`).
  * Instancia singleton `cosmol_client` expuesta para toda la aplicación.

### 2.3 Utilitarios de Caché Redis (`backend/app/services/servicio_cache_deuda.py`)
* `obtener_deuda_cache(redis_client, cod_socio) -> Optional[dict]`: Recupera el resumen JSON almacenado en Redis bajo la clave `deuda:{cod_socio}`.
* `guardar_deuda_cache(redis_client, cod_socio, data_dict, ttl_seconds) -> bool`: Almacena el resumen de deuda serializado con TTL de 600 segundos.
* `invalidar_deuda_cache(redis_client, cod_socio) -> bool`: Elimina la clave de caché para forzar consulta fresca (útil tras pagos o pull-to-refresh).

### 2.4 Batería de Pruebas Automatizadas (`backend/tests/`)
* **`test_cosmol_client.py`:**
  1. `test_cosmol_client_socio_al_dia`: Valida socio sin deuda (código `556`).
  2. `test_cosmol_client_socio_con_deuda`: Valida socio con facturas pendientes (código `540`).
  3. `test_cosmol_client_socio_inexistente`: Valida respuesta `None` para códigos no registrados.
* **`test_cache_deuda.py`:**
  1. `test_construir_clave_cache_deuda`: Verifica convención de clave `deuda:{cod_socio}`.
  2. `test_flujo_cache_deuda_redis`: Ciclo completo de guardado, lectura e invalidación en Redis.
  3. `test_cache_miss_socio_no_existente`: Valida retorno `None` ante cache-miss.

---

## 3. Certificación en Docker

```bash
docker compose exec backend-api pytest -v tests/test_cosmol_client.py tests/test_cache_deuda.py
============================== 6 passed in 1.45s ===============================
```

Todas las pruebas se ejecutaron y certificaron exitosamente en el entorno oficial Docker de desarrollo.
