# Tarea 05: Pasarelas de Pago Externas (Multipago / Pago al Paso) y Actualización Dinámica de Deuda

> **Estado:** PENDIENTE  
> **Fase:** Fase 5 — Redirección a Pasarelas de Pago y Actualización de Deuda  
> **Fecha de actualización:** Septiembre 2026  
> **Entorno de ejecución:** Backend FastAPI en Docker (`cosmol-backend-api`, `cosmol-cache-redis`, `cosmol-db-postgres`)  
> **Documentos de referencia:** `AGENTS.md` (Secciones 4.3, 10.3, 12.4), `HOJA_DE_RUTA_DESARROLLO.md` (Fase 5) y Arquitectura de Producción de `Cosmol-Chatbot`.

---

## 1. Realidad Operativa y Arquitectura de Pagos de COSMOL

A partir del mensaje de producción del Chatbot oficial de COSMOL y el análisis de su arquitectura, se establece la realidad operativa de recaudación de la cooperativa:

```
💳 Canales de pago seguro oficiales de COSMOL R.L.:
• Multipago Bolivia: https://multipago.com/service/cosmol_payment/first
• Pago al Paso:     https://red.pagoalpaso247.net/servicio/cosmol
```

### 1.1 Modelo Conceptual: Pasarelas de Pago por Redirección (Hosted Checkout)
1. **Sí son Pasarelas de Pago:**
   * **Multipago Bolivia** y **Pago al Paso** son pasarelas y recaudadoras financieras autorizadas por la ASFI y el Banco Central de Bolivia (BCB).
   * En sus respectivos portales web, ellas se encargan de generar el **Simple QR interoperable**, procesar tarjetas Visa/Mastercard y conectar con la banca por internet.
2. **Cero Procesamiento Local de Tarjetas (AGENTS.md Sección 4.3 y 12.4):**
   * COSMOL **no procesa pagos ni captura tarjetas dentro de la app móvil ni en el backend**, evitando a la cooperativa el costo y la responsabilidad de certificación PCI-DSS.
3. **Inexistencia de Webhooks hacia la App (Conciliación Delegada B2B):**
   * Ni Multipago ni Pago al Paso envían webhooks a la app de socios ni al Chatbot.
   * La conciliación y liquidación del dinero ocurre de forma delegada y directa entre las pasarelas y el sistema comercial central **SAI (IBM Informix)** de COSMOL.
4. **Rol del Backend FastAPI (BFF):**
   * **Catálogo Dinámico de Canales:** Expone `GET /api/v1/pagos/canales/{cod_socio}` para entregar las URLs oficiales preconfiguradas con el código del socio. Si COSMOL cambia un dominio o suma un nuevo canal de pago, no es necesario recompilar ni republicar la app móvil en Google Play / App Store.
   * **Actualización de Saldo (Pull-to-Refresh):** Como no existe un webhook push, cuando el socio paga en la web de Multipago y regresa a la app de Flutter, el endpoint `GET /api/v1/deuda/{cod_socio}?force_refresh=true` purga la clave en Redis (`deuda:{cod_socio}`) y consulta al sistema central de COSMOL para reflejar la deuda saldada.
   * **Auditoría Asíncrona:** Despacho de eventos `PAYMENT_CHANNEL_SELECTED` hacia `ChatbotReportes` sin bloquear la experiencia del socio.

---

## 2. Objetivos Técnicos de la Tarea

1. Exponer el endpoint `GET /api/v1/pagos/canales/{cod_socio}` que devuelva la deuda total en Bs y los canales de pago disponibles (**Multipago** y **Pago al Paso**) con sus URLs oficiales listas para abrir.
2. Añadir el parámetro opcional `force_refresh: bool = False` en el endpoint de deuda `GET /api/v1/deuda/{cod_socio}` para invalidar inmediatamente la caché de Redis al hacer pull-to-refresh en Flutter.
3. Registrar la intención de pago en PostgreSQL local para estadísticas internas (`auditoria_pagos_redireccion`).
4. Despachar el evento de auditoría asíncrono `PAYMENT_CHANNEL_SELECTED` hacia `ChatbotReportes` con `BackgroundTasks`.

---

## 3. Asignación y División Modular de Trabajo

```
┌────────────────────────────────────────────────────────────────────────┐
│                   DIVISIÓN MODULAR FASE 5                              │
├───────────────────────────────────┬────────────────────────────────────┤
│       DEV 1 (Aireyu)              │       DEV 2 (Eduardo)              │
├───────────────────────────────────┼────────────────────────────────────┤
│ • Modelo PostgreSQL de Auditoría  │ • Esquemas Pydantic v2             │
│   de Clics a Pasarelas            │   (`schemas/pago.py`)              │
│   (`models/pago.py`)              │ • Servicio de Canales de Pago      │
│ • Configuración centralizada de   │   (`servicio_pagos.py`)            │
│   URLs oficiales de Multipago     │ • Endpoints REST (`pagos.py`)      │
│   y Pago al Paso en               │ • Soporte `force_refresh` en       │
│   (`core/config.py`)              │   `/deuda/{cod_socio}` (Redis)     │
│ • Tests de modelo y config DEV 1  │ • Tests de integración DEV 2       │
└───────────────────────────────────┴────────────────────────────────────┘
```

---

## 4. Detalle de Entregables Técnicos

### 4.1 Entregables de DEV 1 (Aireyu): Persistencia y Configuración

#### A. Modelo en PostgreSQL (`backend/app/db/models/pago.py`):
- [ ] Tabla `auditoria_pagos_redireccion`:
  - `id`: UUID (PK)
  - `usuario_id`: UUID (FK a `usuarios.id`)
  - `cod_socio`: String (indexado)
  - `canal_id`: String (`"multipago"`, `"pago_al_paso"`)
  - `monto_deuda_bs`: Numeric(10, 2)
  - `creado_en`: DateTime(timezone=True, default=utcnow)

#### B. Variables de Configuración Oficiales (`backend/app/core/config.py`):
- [ ] Settings para URLs base de recaudación (idénticas a producción):
  - `URL_MULTIPAGO_COSMOL: str = "https://multipago.com/service/cosmol_payment/first"`
  - `URL_PAGO_AL_PASO_COSMOL: str = "https://red.pagoalpaso247.net/servicio/cosmol"`

---

### 4.2 Entregables de DEV 2 (Eduardo): Esquemas, Servicio y Endpoints

#### A. Esquemas Pydantic v2 (`backend/app/schemas/pago.py`):
- [ ] `CanalPagoItem`:
  - `id`: str (`"multipago"` | `"pago_al_paso"`)
  - `nombre`: str (ej. `"Multipago Bolivia"`, `"Pago al Paso"`)
  - `descripcion`: str (ej. `"Pago con Simple QR, Tarjeta de Débito/Crédito y Banca Móvil"`)
  - `url_redireccion`: str (URL oficial de la pasarela)
  - `icono`: str (`"qr_code"`, `"storefront"`)
  - `soporta_qr`: bool
- [ ] `CanalesPagoResponse`:
  - `cod_socio`: str
  - `total_deuda_bs`: float
  - `canales`: List[CanalPagoItem]

#### B. Servicio de Negocio (`backend/app/services/servicio_pagos.py`):
- [ ] Implementar `ServicioPagos`:
  - `obtener_canales_pago(cod_socio: str, usuario_id: UUID, db: AsyncSession, background_tasks: BackgroundTasks) -> CanalesPagoResponse`:
    - Consulta la deuda actual del socio desde la integración de COSMOL.
    - Genera la lista de canales con las URLs oficiales configuradas.
    - Registra el registro de intención en PostgreSQL (`auditoria_pagos_redireccion`).
    - Encola el despacho de auditoría `PAYMENT_CHANNEL_SELECTED` a `ChatbotReportes`.

#### C. Endpoints REST:
- [ ] **`GET /api/v1/pagos/canales/{cod_socio}`** (`backend/app/api/v1/pagos.py`):
  - Protegido con `current_user` (JWT Bearer).
  - Retorna `CanalesPagoResponse`.
- [ ] **Soporte de Refresco en Deuda** (`backend/app/api/v1/deuda.py`):
  - Añadir el parámetro query opcional: `force_refresh: bool = Query(default=False)`.
  - Si `force_refresh is True`: ejecuta `await redis_client.delete(f"deuda:{cod_socio}")` antes de consultar al cliente de COSMOL.
- [ ] Registrar `pagos.router` en [`backend/app/api/v1/router.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/app/api/v1/router.py).

#### D. Batería de Pruebas DEV 2 (`backend/tests/test_pagos.py`):
- [ ] Prueba de obtención de canales con URLs oficiales de Multipago y Pago al Paso.
- [ ] Prueba de validación de no exposición de datos financieros sensibles (cero tarjetas/claves).
- [ ] Prueba de invalidación de caché de Redis con `force_refresh=True` en `/deuda/{cod_socio}`.
- [ ] Prueba de control de acceso JWT Bearer (401 si no está autenticado).

---

## 5. Integración con el Frontend Flutter (Fabian)

1. En [`balance_card_widget.dart`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/frontend/lib/features/home/presentation/widgets/balance_card_widget.dart), al presionar el botón **"Pagar Ahora"**:
   - Flutter realiza `GET /api/v1/pagos/canales/{cod_socio}`.
   - Despliega un Modal / Bottom Sheet con los canales oficiales:
     * **Multipago Bolivia (Simple QR / Tarjetas / Banca)**
     * **Pago al Paso**
   - Al seleccionar una opción, ejecuta `launchUrl(Uri.parse(canal.urlRedireccion), mode: LaunchMode.externalApplication)` con el paquete `url_launcher`.
2. Al regresar a la app, el gesto de **Pull-to-Refresh** en el Dashboard ejecuta `GET /api/v1/deuda/{cod_socio}?force_refresh=true` para actualizar el saldo en pantalla.

---

## 6. Criterios de Aceptación

1. [ ] `GET /api/v1/pagos/canales/{cod_socio}` responde HTTP 200 con la información de Multipago y Pago al Paso.
2. [ ] Las URLs entregadas apuntan exactamente a los servicios oficiales de recaudación de COSMOL.
3. [ ] `GET /api/v1/deuda/{cod_socio}?force_refresh=true` purga la caché de Redis y refresca la deuda en tiempo real.
4. [ ] La suite de pruebas de FastAPI pasa al 100% en Docker sin regresiones.
