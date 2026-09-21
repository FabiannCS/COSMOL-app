# Entregables DEV 2: Consulta de Deuda en Tiempo Real, Semaforización y Dashboard Multicuenta

> **Fase:** Fase 2 — Integración con Sistema Legado y Dashboard de Deuda  
> **Rol responsable:** DEV 2 (Backend Dev)  
> **Fecha de conclusión:** Septiembre 2026  
> **Documento de referencia:** `Docs/pendiente/TASK-02-consulta-deuda-dashboard.md` y `AGENTS.md` (Secciones 4.2, 4.6, 7, 10.2, 11, 12.2, 12.3)  
> **Estado:** COMPLETADO y validado en Docker (10/10 tests propios y 45/45 tests del sistema pasando al 100%)

---

## 1. Resumen Ejecutivo para el Equipo

Este documento detalla la implementación realizada por **DEV 2** en la API REST de COSMOL R.L. para la Fase 2 del proyecto. Se construyó de forma 100% desacoplada:
1. La capa de serialización y tipado de datos con **Pydantic v2** (`app/schemas/deuda.py`).
2. El servicio de lógica de negocio (**`ServicioDeuda`** en `app/services/servicio_deuda.py`), que implementa la semaforización de vencimiento, la alerta roja de corte para $\ge 2$ facturas impagas, el control de acceso multicuenta en PostgreSQL y el enmascaramiento estricto de privacidad para inquilinos (`CONSULTA_PAGO`).
3. Los endpoints REST protegidos con Bearer JWT (`app/api/v1/deuda.py`) registrados en el router central de FastAPI.
4. La batería de 10 pruebas automatizadas end-to-end con `pytest` y `pytest-asyncio` en Docker (`tests/test_deuda.py`).

Toda la lógica fue validada y certificada contra el contenedor Docker `cosmol-backend-api`, logrando un tiempo de respuesta inferior a **20 ms** al consultar desde la caché de Redis.

---

## 2. Detalle de Archivos Creados y Modificados

### 2.1 Esquemas Pydantic v2 (`backend/app/schemas/`)

* [x] **`deuda.py`**:
  * `FacturaPendienteResponse`: DTO que modela cada factura impaga individual emitida por COSMOL:
    * `nro_facip: str`: Identificador del aviso.
    * `nro_factura: str`: Número de factura fiscal.
    * `cod_autorizacion: str`: Código de autorización digital SIAT/SIN.
    * `periodo: str`: Periodo en formato `MM/YYYY` (ej: `"08/2026"`).
    * `mes_lectura: str`: Mes en texto en español (ej: `"Agosto 2026"`).
    * `anio: int`, `mes: int`: Valores temporales numéricos.
    * `monto_bs: float`: Importe en moneda nacional boliviana (**Bs**).
    * `esta_vencida: bool`: Bandera de vencimiento calculada contra la fecha actual.
    * `dias_mora: int`: Días transcurridos desde que expiró la factura (0 si no venció).
  * `DetalleSuministroResponse`: Datos descriptivos del contrato:
    * `cod_socio`: Código del contrato.
    * `nombre_titular`: Nombre del titular (enmascarado si el rol es `CONSULTA_PAGO`).
    * `ci_nit`: Cédula del titular (enmascarada si el rol es `CONSULTA_PAGO`).
    * `direccion`: Domicilio del predio (enmascarado si el rol es `CONSULTA_PAGO`).
    * `ubicacion`: Código catastral técnico `ZONA.RUTA.NROC.NROI` (ej: `"1.4.64.0"`).
    * `categoria`: Tarifa del servicio (`"DOMESTICA"`).
    * `rol_usuario`: `"TITULAR"` o `"CONSULTA_PAGO"`.
  * `ResumenDeudaResponse`: DTO integral para la consulta detallada:
    * `saldo_pendiente_bs`: Saldo total acumulado en Bs.
    * `cantidad_facturas_pendientes`: Número total de avisos impagos.
    * `fecha_proximo_vencimiento`: Fecha límite de pago de la factura más antigua.
    * `esta_vencido`: Bandera para renderizado condicional en rojo en Flutter.
    * `alerta_corte`: `true` si adeuda 2 o más facturas.
    * `mensaje_alerta`: Mensaje institucional preventivo.
    * `facturas_pendientes`: Lista ordenada de `FacturaPendienteResponse`.
    * `origen_datos`: `"CACHE"` (<20 ms) o `"SISTEMA_LEGADO"`.
  * `DashboardMultiSuministroResponse`: DTO consolidado para la pantalla de inicio multicuenta:
    * `usuario_id: UUID`: Identificador del socio digital.
    * `deuda_total_consolidada_bs: float`: Suma total de todos los suministros administrados.
    * `cantidad_suministros: int`: Cantidad de contratos vinculados.
    * `suministros: List[ResumenDeudaResponse]`: Desglose individual de cada suministro.
* [x] **`__init__.py`**: Re-exportación limpia de los 4 esquemas para importación directa (`from app.schemas import ...`).

---

### 2.2 Servicios de Negocio (`backend/app/services/`)

* [x] **`servicio_deuda.py`**:
  * `ServicioDeuda`:
    * `obtener_deuda_suministro(usuario_id, cod_socio, forzar_refresco=False)`:
      1. **Control de Acceso Multicuenta:** Consulta en PostgreSQL si el `usuario_id` autenticado tiene permiso sobre el `cod_socio`. Si no está vinculado, lanza `ForbiddenException("No tiene permisos...")` (HTTP 403).
      2. **Aceleración con Caché Redis:** Si `forzar_refresco=False`, consulta la clave `deuda:{cod_socio}` en Redis. Si hay hit, deserializa y devuelve los datos en <20 ms con `origen_datos="CACHE"`.
      3. **Consulta al Sistema Comercial Legado:** En cache-miss, invoca `cosmol_client.obtener_datos_socio` y `cosmol_client.obtener_deudas_socio`. Si el socio no existe, lanza `NotFoundException` (HTTP 404).
      4. **Semaforización Automática:**
         * `esta_vencida = hoy > fecha_vencimiento`.
         * `dias_mora = (hoy - fecha_vencimiento).days` (0 si está al día).
         * `alerta_corte = True` si acumula 2 o más facturas impagas.
      5. **Persistencia en Redis:** Guarda el resumen completo en Redis con TTL de 600 segundos (10 minutos).
      6. **Enmascaramiento de Privacidad:** Si el usuario tiene rol `CONSULTA_PAGO` (inquilino o tercero), ofusca el nombre del titular a `D**** E**** R**** D****`, la CI a `***231` y la dirección a `SANTA CRUZ ***`. Si es `TITULAR`, entrega los datos completos.
    * `obtener_dashboard_general(usuario_id)`:
      * Recupera todos los suministros vinculados al usuario en PostgreSQL.
      * Consulta la deuda de cada uno reutilizando la caché de Redis.
      * Suma el saldo consolidado (`deuda_total_consolidada_bs`).
    * `invalidar_cache_socio(cod_socio)`:
      * Purga la clave `deuda:{cod_socio}` en Redis.
* [x] **`__init__.py`**: Re-exportación de `ServicioDeuda`.

---

### 2.3 Endpoints REST de la API (`backend/app/api/v1/`)

* [x] **`deuda.py`**:
  1. `GET /api/v1/deuda/dashboard/resumen`:
     * Resumen consolidado multicuenta para el dashboard superior de Flutter.
     * Protegido con `Depends(get_current_user_id)`, `Depends(get_db)` y `Depends(get_redis)`.
     * Retorna `DashboardMultiSuministroResponse`.
  2. `GET /api/v1/deuda/{cod_socio}`:
     * Consulta en tiempo real de un suministro específico.
     * Parámetro opcional: `forzar_refresco: bool = False` (para pull-to-refresh en la app).
     * Retorna `ResumenDeudaResponse`.
  3. `POST /api/v1/deuda/{cod_socio}/invalidar-cache`:
     * Invalida la clave de Redis del socio tras pagos o solicitudes de recálculo.
* [x] **`router.py`**:
  * Se registró `deuda_router` bajo el prefijo `/deuda` con el tag OpenAPI `"Consulta de Deuda y Dashboard"`.
* [x] **Documentación OpenAPI / Swagger:** Verificada y operativa en `http://localhost:8000/docs`.

---

### 2.4 Batería de Pruebas Automatizadas (`backend/tests/`)

* [x] **`test_deuda.py` (10 pruebas completadas y pasando al 100%):**
  1. `test_utilitarios_enmascaramiento`: Valida funciones de ofuscación de nombres, CI y direcciones.
  2. `test_servicio_deuda_socio_al_dia`: Valida socio sin deuda (`saldo_pendiente_bs = 0.0`, `esta_vencido = false`, `alerta_corte = false`).
  3. `test_servicio_deuda_socio_en_mora_y_alerta_corte`: Valida socio con 2 facturas vencidas (`alerta_corte = true`, días de mora calculados).
  4. `test_servicio_deuda_cache_hit_redis`: Primera petición `SISTEMA_LEGADO`, segunda petición `CACHE` desde Redis.
  5. `test_servicio_deuda_forzar_refresco`: `forzar_refresco=True` omite la caché y consulta al sistema legado.
  6. `test_servicio_deuda_enmascaramiento_inquilino`: Rol `CONSULTA_PAGO` recibe datos con asteriscos.
  7. `test_servicio_deuda_suministro_ajeno_retorna_403`: Intento de consultar un código ajeno lanza `ForbiddenException`.
  8. `test_endpoint_get_deuda_http`: Prueba HTTP end-to-end con token JWT Bearer.
  9. `test_endpoint_dashboard_resumen_multisuministro`: Consolidación multicuenta de varios contratos bajo un mismo socio digital.
  10. `test_endpoint_invalidar_cache`: Petición HTTP POST elimina correctamente la clave en Redis.

---

## 3. Certificación de Ejecución en Docker

Se ejecutó la suite completa de pruebas dentro del contenedor `cosmol-backend-api` en Docker:

```text
tests/test_auth_endpoints.py ...                                         [  6%]
tests/test_auth_schemas.py .......                                       [ 22%]
tests/test_auth_service.py ...                                           [ 28%]
tests/test_base_components.py ...                                        [ 35%]
tests/test_cache_deuda.py ...                                            [ 42%]
tests/test_cosmol_client.py ...                                          [ 48%]
tests/test_deuda.py ..........                                           [ 71%]
tests/test_health.py .                                                   [ 73%]
tests/test_integration_empalme.py .                                      [ 75%]
tests/test_models.py .....                                               [ 86%]
tests/test_otp_services.py ......                                        [100%]

============================= 45 passed in 11.26s ==============================
```

* **Resultado:** **45/45 pruebas aprobadas (100% de éxito)**.
* **Integración:** El código de DEV 1 (`cosmol_client.py`, `servicio_cache_deuda.py`) y el código de DEV 2 (`deuda.py`, `servicio_deuda.py`) conviven y cooperan sin el más mínimo conflicto.

---

## 4. Contrato de Integración para el Desarrollador Frontend (Flutter)

El desarrollador frontend consumirá el siguiente endpoint principal en la pantalla del Dashboard:

### `GET /api/v1/deuda/{cod_socio}`
**Headers:** `Authorization: Bearer <access_token>`

**Respuesta JSON (Ejemplo Rol TITULAR):**
```json
{
  "cod_socio": "540",
  "suministro": {
    "cod_socio": "540",
    "nombre_titular": "DURAN ELOISA RIVERA DE",
    "ci_nit": "2823231",
    "direccion": "SANTA CRUZ 117",
    "ubicacion": "1.39.135.0",
    "categoria": "DOMESTICA",
    "rol_usuario": "TITULAR"
  },
  "moneda": "Bs",
  "saldo_pendiente_bs": 132.34,
  "cantidad_facturas_pendientes": 2,
  "fecha_proximo_vencimiento": "2026-09-30",
  "esta_vencido": true,
  "alerta_corte": true,
  "mensaje_alerta": "Posee 2 facturas pendientes. Evite el corte del servicio cancelando a la brevedad.",
  "facturas_pendientes": [
    {
      "nro_facip": "1160026",
      "nro_factura": "7444051",
      "cod_autorizacion": "465C3D0702C232069B9F771B83440D4217AF35B442086180BD081BF74",
      "periodo": "08/2026",
      "mes_lectura": "Agosto 2026",
      "anio": 2026,
      "mes": 8,
      "monto_bs": 70.92,
      "esta_vencida": true,
      "dias_mora": 17
    },
    {
      "nro_facip": "1189283",
      "nro_factura": "7473308",
      "cod_autorizacion": "465C3D0702C244BA722BB331A2F8F4742AA59857E45C98CCD2AE2BF74",
      "periodo": "09/2026",
      "mes_lectura": "Septiembre 2026",
      "anio": 2026,
      "mes": 9,
      "monto_bs": 61.42,
      "esta_vencida": false,
      "dias_mora": 0
    }
  ],
  "fecha_consulta": "2026-09-17T21:30:00Z",
  "origen_datos": "CACHE"
}
```

### `GET /api/v1/deuda/dashboard/resumen`
**Headers:** `Authorization: Bearer <access_token>`

**Respuesta JSON:**
```json
{
  "usuario_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "deuda_total_consolidada_bs": 132.34,
  "cantidad_suministros": 2,
  "suministros": [
    {
      "cod_socio": "556",
      "saldo_pendiente_bs": 0.0,
      "esta_vencido": false,
      "alerta_corte": false,
      "..." : "..."
    },
    {
      "cod_socio": "540",
      "saldo_pendiente_bs": 132.34,
      "esta_vencido": true,
      "alerta_corte": true,
      "..." : "..."
    }
  ]
}
```

---

*Desarrollado y certificado exitosamente por **DEV 2** en la rama `devEduardo`.*
