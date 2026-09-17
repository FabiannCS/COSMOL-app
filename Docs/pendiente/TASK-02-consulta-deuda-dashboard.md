# Tarea 02: Integración con Sistema Legado y Dashboard de Deuda (MVP de Consulta)

> **Estado:** PENDIENTE  
> **Fase:** Fase 2 — Integración con Sistema Legado y Dashboard de Deuda  
> **Fecha de creación:** Septiembre 2026  
> **Documentos de referencia:** `AGENTS.md` (Secciones 4.2, 4.6, 7, 10.2, 11, 12.2, 12.3) y `Docs/HOJA_DE_RUTA_DESARROLLO.md`  
> **Entorno de ejecución:** Backend FastAPI en Docker (`cosmol-backend-api`, `cosmol-cache-redis`, `cosmol-db-postgres`)

---

## 1. Objetivo

Implementar el módulo central de **Consulta de Deuda en Tiempo Real y Dashboard Principal** para los asociados de COSMOL R.L. Este módulo constituye la pantalla de aterrizaje posterior al login y resuelve el problema prioritario #1 de la cooperativa: la pérdida de tiempo y saturación en ventanillas/teléfono por consultas de saldo y avisos de cobranza.

El sistema debe:
1. Actuar como capa intermedia (**BFF - Backend-for-Frontend**) desacoplando a la aplicación cliente del sistema comercial legado de facturación de COSMOL.
2. Implementar una estrategia de **caché de alta velocidad en Redis (<20 ms)** con TTL de 10 minutos para proteger los servidores legados contra picos de concurrencia.
3. Respetar la arquitectura **Multicuenta** y aplicar **enmascaramiento estricto de datos confidenciales** si el usuario consulta un suministro en rol `CONSULTA_PAGO` (inquilino o pagador externo), preservando el acceso completo para el `TITULAR`.
4. Exponer datos normalizados en moneda nacional (**Bs**) con banderas claras de semaforización de vencimiento y riesgo de corte para renderizado condicional en Flutter.

---

## 2. Reglas de Negocio Oficiales (AGENTS.md)

1. **Moneda Local Oficial (Sección 10.2 AGENTS.md):**
   * Todos los montos deben expresarse en **Bolivianos (`Bs`)** con dos decimales de precisión.
   * Se debe informar tanto el saldo pendiente total (`monto_total_bs`) como el desglose de cada factura/mes impago.

2. **Semaforización de Vencimiento (Secciones 4.2 y 10.2 AGENTS.md):**
   * La API debe calcular y entregar el estado de vencimiento:
     * `esta_vencido: bool`: `true` si la fecha límite de pago es anterior a la fecha actual (`hoy > fecha_vencimiento`).
     * `dias_mora: int`: Cantidad de días transcurridos desde el vencimiento (0 si está al día).
     * `aviso_corte_inminente: bool`: `true` si acumula 2 o más facturas impagas o si existe orden de corte activa en el sistema comercial.

3. **Multicuenta y Niveles de Privacidad (Sección 4.6 AGENTS.md):**
   * **Modo Titular:** Retorna información completa: nombre y apellidos del socio titular, dirección física del suministro, categoría de servicio (Doméstica, Comercial, etc.), número de medidor, desglose de meses de deuda y avisos de corte.
   * **Modo Consulta y Pago (Inquilino / Tercero):** Retorna el saldo y periodos a pagar, pero **enmascara automáticamente** los datos sensibles del titular:
     * Nombre: ej. `J**** P**** M****`
     * Medidor: ej. `***789`
     * Dirección: ej. `Barrio Los Tajibos, C/ *******`

4. **Caché y Rendimiento (<20 ms) (Secciones 7 y 12.2 AGENTS.md):**
   * Clave Redis: `deuda:{cod_socio}`.
   * TTL por defecto: **600 segundos (10 minutos)**.
   * **Cache Hit:** Si la clave existe en Redis, responde en menos de 20 ms sin conectar al sistema legado.
   * **Cache Miss:** Consulta al sistema legado asíncronamente con `httpx`, normaliza el modelo Pydantic, almacena en Redis con TTL y retorna al cliente.
   * Soporte de parámetro `forzar_refresco=true` (acción pull-to-refresh en la app) para invalidar la caché y consultar en vivo.

5. **Aislamiento y Modo Mock de Facturación:**
   * Variable `MOCK_COSMOL_LEGACY=true` en `.env` para desarrollo local y pruebas automatizadas: simula respuestas consistentes para códigos de prueba predeterminados (socio al día, socio con 1 mes, socio en mora con orden de corte, socio inexistente).

---

## 3. Asignación y División Modular de Trabajo

```
┌─────────────────────────────────────────────────────────────────┐
│                   DIVISIÓN MODULAR FASE 2                       │
├───────────────────────────────┬─────────────────────────────────┤
│    DEV 1 (Asignado / Activo)  │       DEV 2 (Backend Dev)       │
├───────────────────────────────┼─────────────────────────────────┤
│ • Variables en config.py      │ • Esquemas Pydantic v2          │
│ • Cliente Legacy COSMOL       │   (`app/schemas/deuda.py`)      │
│   (`cosmol_client.py` real)   │ • Servicio de Negocio           │
│ • Fallback y Mocks Locales    │   (`servicio_deuda.py`)         │
│ • Utilitarios Caché Redis     │ • Endpoints REST (`deuda.py`)   │
│   (lectura, TTL e invalidate) │ • Tests pytest (`test_deuda.py`)│
└───────────────────────────────┴─────────────────────────────────┘
```

> **Rol Activo en este Turno:** **DEV 1 (Infraestructura, Configuración, Adaptador Legado y Caché Redis)**.

---

## 4. Detalle de Entregables Técnicos

### 4.1 Entregables de DEV 1: Configuración, Conectividad Legada y Redis (EN CURSO)

#### A. Configuración en `backend/app/core/config.py` y `.env` (COMPLETADO):
* [x] Agregar parámetros para la conexión al sistema legado de COSMOL:
  * `COSMOL_LEGACY_URL: str = "http://api.cosmol.com.bo/api-consultas"`
  * `COSMOL_LEGACY_TIMEOUT_SECONDS: float = 4.0`
  * `MOCK_COSMOL_LEGACY: bool = False` (conectado a la API real; con fallback automático ante desconexión)
  * `DEBT_CACHE_TTL_SECONDS: int = 600` (10 minutos)

#### B. Cliente de Integración en `backend/app/integrations/cosmol_client.py` (COMPLETADO):
* [x] Crear clase `CosmolLegacyClient(BaseApiClient)`:
  * Implementar método async `obtener_datos_socio(cod_socio: str) -> Optional[Dict[str, Any]]`:
    * Consulta `GET /socios/{cod_socio}` (retorna `CODIGO`, `NOMBRE`, `DIRECCION`, `NROCIONIT`, `ZONA`, `RUTA`, `NROC`, `NROI`).
    * Aplica `.strip()` a todos los valores de texto para eliminar el relleno de espacios en blanco fijo del sistema legado.
  * Implementar método async `obtener_deudas_socio(cod_socio: str) -> List[Dict[str, Any]]`:
    * Consulta `GET /socios/{cod_socio}/deudas` (retorna lista de facturas pendientes con `NROFACIP`, `NROFACTURA`, `CODAUTORIZACION`, `RAZONSOCIAL`, `TIPODOCUMENTO`, `NRODOCUMENTO`, `ANIO`, `NMES`, `MONTOTOTAL`).
  * Implementar soporte `MOCK_COSMOL_LEGACY=True` (fallback offline con datos sintéticos deterministas para tests).
  * Manejo robusto de errores: capturar `httpx.TimeoutException` y `httpx.RequestError` lanzando excepciones de dominio (`ServiceUnavailableException`).

#### C. Utilitarios de Caché Redis para Deuda en `backend/app/services/servicio_cache_deuda.py` (COMPLETADO):
* [x] Función `obtener_deuda_cache(redis_client, cod_socio) -> Optional[dict]`
* [x] Función `guardar_deuda_cache(redis_client, cod_socio, data_dict, ttl_seconds)`
* [x] Función `invalidar_deuda_cache(redis_client, cod_socio) -> bool`

---

### 4.2 Entregables de DEV 2: Esquemas, Lógica de Negocio y Endpoints (PENDIENTE PARA DEV 2)

#### A. Esquemas Pydantic v2 en `backend/app/schemas/deuda.py`:
* [ ] **`FacturaPendienteResponse` (Alineado con API real de COSMOL):**
  * `nro_facip`: str (ej: `"1160026"`)
  * `nro_factura`: str (ej: `"7444051"`)
  * `cod_autorizacion`: str (código digital SIAT/SIN)
  * `periodo`: str (ej: `"08/2026"`)
  * `mes_lectura`: str (ej: `"Agosto 2026"`)
  * `anio`: int (ej: `2026`)
  * `mes`: int (ej: `8`)
  * `monto_bs`: float (ej: `70.92`, mapeado desde `MONTOTOTAL`)
  * `esta_vencida`: bool
  * `dias_mora`: int
* [ ] **`DetalleSuministroResponse` (Alineado con API real de COSMOL):**
  * `cod_socio`: str
  * `nombre_titular`: str (enmascarado si el rol es `CONSULTA_PAGO`)
  * `ci_nit`: str (enmascarado si el rol es `CONSULTA_PAGO`, mapeado desde `NROCIONIT`)
  * `direccion`: str (enmascarada si el rol es `CONSULTA_PAGO`)
  * `ubicacion`: str (ej: `"1.4.64.0"`, mapeado desde `ZONA.RUTA.NROC.NROI`)
  * `categoria`: str = "DOMESTICA"
  * `rol_usuario`: str (`"TITULAR"` o `"CONSULTA_PAGO"`)
* [ ] **`ResumenDeudaResponse`:**
  * `cod_socio`: str
  * `suministro`: DetalleSuministroResponse
  * `moneda`: str = "Bs"
  * `saldo_pendiente_bs`: float
  * `cantidad_facturas_pendientes`: int
  * `fecha_proximo_vencimiento`: Optional[date]
  * `esta_vencido`: bool
  * `alerta_corte`: bool
  * `mensaje_alerta`: Optional[str]
  * `facturas_pendientes`: List[FacturaPendienteResponse]
  * `fecha_consulta`: datetime
  * `origen_datos`: Literal["CACHE", "SISTEMA_LEGADO"]
* [ ] **`DashboardMultiSuministroResponse`:**
  * `usuario_id`: UUID
  * `deuda_total_consolidada_bs`: float
  * `cantidad_suministros`: int
  * `suministros`: List[ResumenDeudaResponse]

#### B. Lógica de Negocio en `backend/app/services/servicio_deuda.py`:
* [ ] Clase `ServicioDeuda`:
  * Inyección de `db: AsyncSession`, `redis: Redis`, `cosmol_client: CosmolLegacyClient`.
  * Método `obtener_deuda_suministro(usuario_id: UUID, cod_socio: str, forzar_refresco: bool = False) -> ResumenDeudaResponse`:
    1. Validar en PostgreSQL que el `usuario_id` tenga vinculado el `cod_socio`. Si no, lanzar `ForbiddenException` ("No tiene permisos sobre este suministro").
    2. Obtener el `rol` (`TITULAR` o `CONSULTA_PAGO`) y el `alias` asignado.
    3. Si `forzar_refresco is False`, consultar Redis. Si existe, retornar con `origen_datos="CACHE"`.
    4. Si hay *cache miss* o refresco forzado:
       - Invocar `cosmol_client.obtener_deudas_socio(cod_socio)`.
       - Si el socio no existe en el sistema legado, lanzar `NotFoundException`.
       - Normalizar datos, calcular fechas, `esta_vencida`, `dias_mora` y `alerta_corte`.
       - Guardar en Redis con TTL de 10 minutos (600 s).
    5. Aplicar enmascaramiento si `rol == "CONSULTA_PAGO"`:
       - Ocultar CI, enmascarar nombre del titular (`D**** E****`), enmascarar medidor y dirección.
    6. Retornar el `ResumenDeudaResponse`.
  * Método `obtener_dashboard_general(usuario_id: UUID) -> DashboardMultiSuministroResponse`:
    - Obtener todos los suministros del usuario en PostgreSQL y compilar la deuda de cada uno (aprovechando la caché de Redis para cada uno).
    - Calcular el saldo total consolidado en Bs de todos los suministros del hogar/empresa.

#### C. Endpoints API REST en `backend/app/api/v1/deuda.py`:
* [ ] `GET /api/v1/deuda/{cod_socio}`
  * Parámetro opcional de query: `forzar_refresco: bool = False`.
  * Protegido con `Depends(get_current_user_id)` y `Depends(get_db)`, `Depends(get_redis)`.
  * Retorna `ResumenDeudaResponse`.
* [ ] `GET /api/v1/deuda/dashboard/resumen`
  * Retorna el resumen consolidado multicuenta `DashboardMultiSuministroResponse`.
* [ ] `POST /api/v1/deuda/{cod_socio}/invalidar-cache`
  * Permite invalidar explícitamente la caché (útil para cuando se confirma un pago o se solicita recálculo).
* [ ] Registrar el router en `backend/app/api/v1/router.py`:
  * `api_router.include_router(deuda_router, prefix="/deuda", tags=["Consulta de Deuda y Dashboard"])`

---

## 5. Criterios de Aceptación y Validación

1. [ ] **Respuesta en Moneda Local:**
   * La respuesta JSON incluye los campos monetarios con precisión decimal y la unidad `"moneda": "Bs"`.
2. [ ] **Semaforización Correcta:**
   * Si una factura tiene fecha de vencimiento anterior a la fecha actual, `esta_vencido` es `true` y `dias_mora` refleja la diferencia exacta en días.
   * Si tiene 2 o más facturas impagas, `alerta_corte` se marca en `true`.
3. [ ] **Rendimiento de Caché (<20 ms):**
   * Primera petición: `origen_datos: "SISTEMA_LEGADO"` (guarda en Redis).
   * Segunda petición consecutiva: `origen_datos: "CACHE"` con tiempo de respuesta < 20 ms.
   * Petición con `forzar_refresco=true` invalida la caché y consulta nuevamente al sistema legado.
4. [ ] **Enmascaramiento de Datos (Privacidad):**
   * Al consultar como `TITULAR`: datos visibles al 100%.
   * Al consultar como `CONSULTA_PAGO`: datos confidenciales enmascarados con asteriscos (`J**** P****`).
5. [ ] **Control de Acceso Multicuenta:**
   * Si un usuario intenta consultar un `cod_socio` que no tiene vinculado a su cuenta, recibe `403 Forbidden`.
6. [ ] **Cobertura de Pruebas Automatizadas:**
   * Tests en `backend/tests/test_deuda.py` cubriendo:
     - Socio al día (deuda 0).
     - Socio con facturas vencidas (semaforización roja).
     - Cache Hit vs Cache Miss en Redis.
     - Enmascaramiento de datos para inquilinos (`CONSULTA_PAGO`).
     - Refresco forzado.
     - Bloqueo de acceso no autorizado a suministros ajenos.
   * Ejecución exitosa con `docker compose exec backend-api pytest -v tests/test_deuda.py`.

---

## 6. Contrato de Integración para el Desarrollador Frontend (Flutter)

A ser consumido por el módulo `features/dashboard/`:

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
  "fecha_consulta": "2026-09-17T15:00:00Z",
  "origen_datos": "CACHE"
}
```

*Regla visual en Flutter:*
- Si `esta_vencido == true`: Renderizar fecha de vencimiento y recuadro en color rojo `#D32F2F` con icono de alerta.
- Si `alerta_corte == true`: Mostrar banner superior de advertencia: *"Aviso de corte inminente por facturas pendientes"*.
- Si `suministro.rol_usuario == "CONSULTA_PAGO"`: El encabezado indicará el alias asignado y no mostrará la cédula de identidad ni el medidor completo.
