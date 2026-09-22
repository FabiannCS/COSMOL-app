# Tarea 05: Redirección a Pasarelas de Pago Externas (Multipago / Pago al Paso) y Actualización de Deuda

> **Estado:** PENDIENTE  
> **Fase:** Fase 5 — Redirección a Pagos Externos y Actualización de Deuda  
> **Fecha de actualización:** Septiembre 2026  
> **Entorno de ejecución:** Backend FastAPI en Docker (`cosmol-backend-api`, `cosmol-cache-redis`, `cosmol-db-postgres`)  
> **Documentos de referencia:** `AGENTS.md` (Secciones 4.3, 10.3, 12.4), `HOJA_DE_RUTA_DESARROLLO.md` (Fase 5) y Arquitectura de `Cosmol-Chatbot` (Multipago / Al Paso).

---

## 1. Contexto de Negocio y Realidad Operativa de COSMOL

A partir de la auditoría y análisis de la solución productiva existente (**`Cosmol-Chatbot`**), se constata la realidad operativa de recaudación de la Cooperativa COSMOL R.L.:

1. **Pasarelas de Recaudación Activas:**
   * **Multipago Bolivia:** Servicio oficial web (`https://multipago.com/service/cosmol_payment/first`) habilitado para cobro de facturas de COSMOL mediante **Simple QR interoperable, tarjeta de débito/crédito y banca por internet**.
   * **Pago Al Paso:** Red de cobranza autorizada para pagos presenciales y digitales en Montero y Santa Cruz.

2. **Inexistencia de Webhooks Entrantes hacia la App:**
   * Ni Multipago ni Pago Al Paso emiten webhooks HTTP en tiempo real hacia aplicaciones satélites o al Chatbot.
   * La conciliación y liquidación se ejecuta directamente entre las empresas de recaudación y el sistema central legado **SAI (IBM Informix)** de COSMOL.

3. **Cero Procesamiento de Tarjetas (AGENTS.md Sección 4.3 y 12.4):**
   * COSMOL **no procesa pagos dentro de la app móvil ni en el backend**, eliminando al 100% el alcance de cumplimiento PCI-DSS.
   * La app redirige al socio a los canales autorizados, cumpliendo con la exigencia de proveer pago por QR Simple y canales interbancarios.

4. **El Rol Clave del Backend (FastAPI BFF):**
   * **Evitar quemar URLs en el APK de Flutter:** El backend entrega dinámicamente las pasarelas activas y las URLs prellenadas con el código de socio (`?codigo={cod_socio}`). Si COSMOL cambia un dominio o agrega una nueva pasarela, no requiere republicar la app en Google Play.
   * **Invalidación de Caché (Actualización de Saldo):** Al pagar en Multipago y volver a la app, el socio requiere ver su saldo actualizado. El backend debe soportar refresco forzado (`?force_refresh=true` o endpoint de invalidación) para purgar la caché de Redis y consultar al sistema de COSMOL.
   * **Auditoría Externa:** Despachar en segundo plano el evento `PAYMENT_CLICKED` hacia la base de datos de `ChatbotReportes`.

---

## 2. Objetivos de la Tarea

1. Exponer el endpoint `GET /api/v1/pagos/canales/{cod_socio}` para proveer a Flutter la lista de canales externos habilitados (Multipago Bolivia con QR/Tarjeta y Pago Al Paso) con sus respectivas URLs de redirección.
2. Permitir el parámetro `force_refresh=true` en el endpoint de consulta de deuda `GET /api/v1/deuda/{cod_socio}` para que la acción de Pull-to-Refresh en Flutter invalide la caché de Redis (`deuda:{cod_socio}`) y obtenga el saldo actualizado en tiempo real.
3. Registrar la intención de pago en PostgreSQL local para métricas internas (`RegistroRedireccionPago`).
4. Despachar el evento de auditoría asíncrono `PAYMENT_REDIRECTED` hacia `ChatbotReportes` con `BackgroundTasks`.

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
│   Pasarelas y URLs base en        │ • Endpoints REST (`pagos.py`)      │
│   (`core/config.py`)              │ • Invalidación Forzada de Caché    │
│ • Tests de modelo y config DEV 1  │   en `/deuda/{cod_socio}`          │
│                                   │ • Tests de integración DEV 2       │
└───────────────────────────────────┴────────────────────────────────────┘
```

---

## 4. Detalle de Entregables Técnicos

### 4.1 Entregables de DEV 1: Persistencia y Configuración

#### A. Modelo en PostgreSQL (`backend/app/db/models/pago.py`):
- [ ] Tabla `auditoria_pagos_redireccion`:
  - `id`: UUID (PK)
  - `usuario_id`: UUID (FK a `usuarios.id`)
  - `cod_socio`: String (indexado)
  - `canal_id`: String (`"multipago"`, `"al_paso"`)
  - `monto_deuda_bs`: Numeric(10, 2)
  - `creado_en`: DateTime(timezone=True, default=utcnow)

#### B. Variables de Configuración (`backend/app/core/config.py`):
- [ ] Settings para URLs base de recaudación:
  - `URL_MULTIPAGO_COSMOL: str = "https://multipago.com/service/cosmol_payment/first"`
  - `URL_AL_PASO_COSMOL: str = "https://alpaso.com.bo/cosmol"`

---

### 4.2 Entregables de DEV 2: Esquemas, Lógica de Negocio y Endpoints

#### A. Esquemas Pydantic v2 (`backend/app/schemas/pago.py`):
- [ ] `CanalPagoItem`:
  - `id`: str (`"multipago"` | `"al_paso"`)
  - `nombre`: str (ej. `"Multipago Bolivia"`)
  - `descripcion`: str (ej. `"Pago seguro con Simple QR, Tarjeta de Débito/Crédito y Banca Móvil"`)
  - `url_redireccion`: str (URL completa formateada con el código de socio)
  - `icono`: str (`"qr_code"`, `"storefront"`)
  - `soporta_qr`: bool
- [ ] `CanalesPagoResponse`:
  - `cod_socio`: str
  - `total_deuda_bs`: float
  - `canales`: List[CanalPagoItem]

#### B. Servicio de Negocio (`backend/app/services/servicio_pagos.py`):
- [ ] Implementar `ServicioPagos`:
  - `obtener_canales_pago(cod_socio: str, usuario_id: UUID) -> CanalesPagoResponse`:
    - Consulta la deuda actual del socio (vía cliente COSMOL).
    - Construye las URLs parametrizadas.
    - Registra el log de intención de pago en PostgreSQL.
    - Despacha en background la auditoría a `ChatbotReportes`.

#### C. Endpoints REST:
- [ ] **`GET /api/v1/pagos/canales/{cod_socio}`** (`backend/app/api/v1/pagos.py`):
  - Protegido con `current_user` (JWT Bearer).
  - Retorna los canales disponibles con URLs formateadas.
- [ ] **Refresco Forzado en Deuda** (`backend/app/api/v1/deuda.py`):
  - Añadir soporte para parámetro opcional `force_refresh: bool = False`.
  - Si `force_refresh=True`: purga de inmediato la clave `deuda:{cod_socio}` en Redis y consulta al servicio de COSMOL.

#### D. Batería de Pruebas DEV 2 (`backend/tests/test_pagos.py`):
- [ ] Prueba de obtención de canales con URLs formateadas para el socio.
- [ ] Prueba de verificación de que no expone datos bancarios sensibles.
- [ ] Prueba de invalidación forzada de caché (`force_refresh=True`) en el endpoint de deuda.
- [ ] Prueba de protección de endpoint con JWT Bearer.

---

## 5. Integración con el Frontend Flutter (Fabian)

1. En [`balance_card_widget.dart`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/frontend/lib/features/home/presentation/widgets/balance_card_widget.dart), al presionar el botón **"Pagar Ahora"**:
   - Flutter realiza `GET /api/v1/pagos/canales/{cod_socio}`.
   - Despliega un Modal / Bottom Sheet moderno con las opciones:
     - **Multipago Bolivia (Pago con QR Simple / Tarjetas)**
     - **Pago Al Paso**
   - Al seleccionar una opción, ejecuta `launchUrl(Uri.parse(canal.urlRedireccion))` mediante el paquete `url_launcher`.
2. Al regresar a la app, el gesto de **Pull-to-Refresh** en el Dashboard ejecuta la recarga con refresco de saldo.

---

## 6. Criterios de Aceptación

1. [ ] El endpoint `GET /api/v1/pagos/canales/{cod_socio}` retorna HTTP 200 con las opciones oficiales de Multipago y Al Paso.
2. [ ] Las URLs entregadas incluyen los parámetros necesarios para que el socio no deba redigitar su código en Multipago.
3. [ ] El parámetro `force_refresh=True` en `/api/v1/deuda/{cod_socio}` limpia la caché en Redis y devuelve el estado actualizado.
4. [ ] 100% de la suite de pruebas pasando sin regresiones en el entorno Docker.
