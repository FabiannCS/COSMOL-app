# Tarea 05: Redirección a Pagos, Generación de QR Interbancario y Conciliación

> **Estado:** PENDIENTE  
> **Fase:** Fase 5 — Redirección a Pagos y Conciliación  
> **Fecha de creación:** Septiembre 2026  
> **Entorno de ejecución:** Backend FastAPI en Docker (`cosmol-backend-api`, `cosmol-cache-redis`, `cosmol-db-postgres`)  
> **Documentos de referencia:** `AGENTS.md` (Secciones 4.3, 10.3, 12.4) y `HOJA_DE_RUTA_DESARROLLO.md` (Fase 5)

---

## 1. Objetivo

Implementar el módulo de **Redirección a Pagos, Generación de Código QR Interbancario y Conciliación Automática** para los asociados de COSMOL R.L. Este módulo da respuesta directa al requerimiento funcional oficial #10.3 y al objetivo central de la cooperativa: reducir la mora facilitando el pago digital 24/7 sin filas en oficinas ni bancos.

El sistema debe:
1. Recibir la solicitud de pago de una o más facturas pendientes en moneda nacional (**Bs**).
2. Generar una orden de pago ante la pasarela bancaria externa y retornar la cadena/imagen de **Código QR Interbancario (estándar Simple QR / BCB de Bolivia)** junto con Deep Links bancarios.
3. Garantizar que COSMOL **no capture ni procese datos de tarjetas** dentro de la app (cero alcance PCI-DSS).
4. Proveer un endpoint público seguro de **Webhook de Conciliación** para recibir la confirmación de pago del banco en tiempo real mediante firma criptográfica.
5. **Invalidar inmediatamente la caché de Redis (`deuda:{cod_socio}`)** al recibir la confirmación del pago para que el Dashboard de Flutter refleje el saldo actualizado en 0.00 Bs al instante.
6. Despachar el evento de auditoría `PAYMENT_COMPLETED` en segundo plano hacia la base de datos de `ChatbotReportes`.

---

## 2. Reglas de Negocio Oficiales (AGENTS.md)

1. **Cero Procesamiento Local de Tarjetas (Sección 4.3 y 12.4 AGENTS.md):**
   * La app y el backend de COSMOL no almacenan números de tarjeta, CVV ni cuentas bancarias. Todo el flujo financiero es canalizado a través de pasarelas bancarias autorizadas por ASFI/BCB.

2. **Formato Monetario y Códigos QR (Sección 10.3 AGENTS.md):**
   * Los importes siempre se expresan y calculan en Bolivianos (**Bs**) con 2 decimales exactos.
   * La cadena del QR debe cumplir con el formato interoperable estándar de la banca boliviana (Simple QR / QR Billetera Móvil).

3. **Ciclo de Conciliación y Actualización de Saldo (Sección 7.3 y 12.4 AGENTS.md):**
   * Al recibir la confirmación en el webhook:
     1. Se valida la firma digital (HMAC-SHA256 o token secreto de pasarela).
     2. Se actualiza el estado de la transacción en PostgreSQL a `PAGADO`.
     3. Se purga la memoria caché de Redis (`invalidar_deuda_cache(redis, cod_socio)`).
     4. Al volver el socio a la app, la deuda se recalcula en tiempo real contra COSMOL.

4. **Soporte Multicuenta y Roles (Sección 4.6 AGENTS.md):**
   * Tanto el usuario en **Modo Titular** como en **Modo Consulta y Pago (Inquilino)** pueden pagar las facturas del suministro. El pago de un inquilino es plenamente válido.

---

## 3. Asignación y División Modular de Trabajo

```
┌────────────────────────────────────────────────────────────────────────┐
│                   DIVISIÓN MODULAR FASE 5                              │
├───────────────────────────────────┬────────────────────────────────────┤
│       DEV 1 (Aireyu)              │       DEV 2 (Eduardo)              │
├───────────────────────────────────┼────────────────────────────────────┤
│ • Modelo PostgreSQL de Pagos      │ • Esquemas Pydantic v2             │
│   (`models/pago.py`)              │   (`schemas/pago.py`)              │
│ • Cliente de Pasarela Externa     │ • Servicio de Negocio Pagos        │
│   (`pasarela_client.py`)          │   (`servicio_pagos.py`)            │
│ • Generador/Mock de Simple QR     │ • Validación Criptográfica Webhook │
│   (Estándar interoperable Bolivia)│   (HMAC-SHA256 / Secret Header)    │
│ • Tests de integración DEV 1      │ • Endpoints REST (`pagos.py`)      │
│   (Modelo BD + Pasarela Externa)  │ • Purga de Caché e Integración E2E │
└───────────────────────────────────┴────────────────────────────────────┘
```

---

## 4. Detalle de Entregables Técnicos

### 4.1 Entregables de DEV 1: Modelos de Persistencia y Cliente de Pasarela

#### A. Modelo de Datos en PostgreSQL (`backend/app/db/models/pago.py`):
- [ ] Tabla `transacciones_pago`:
  - `id`: UUID (PK)
  - `usuario_id`: UUID (FK a `usuarios.id`)
  - `cod_socio`: String (indexado)
  - `nro_transaccion`: String único (código de orden de la pasarela)
  - `monto_bs`: Numeric(10, 2)
  - `facturas_incluidas`: JSONB (lista de NroFactura / periodos pagados)
  - `estado`: String (`"PENDIENTE"`, `"PAGADO"`, `"EXPIRADO"`, `"RECHAZADO"`)
  - `qr_cadena`: Text (cadena alfanumérica del Simple QR)
  - `url_pasarela`: Optional[String] (deep link bancario)
  - `creado_en`: DateTime(timezone=True)
  - `pagado_en`: Optional[DateTime(timezone=True)]
  - `firmado_por_pasarela`: Optional[String]

#### B. Cliente de Pasarela / Simulación QR (`backend/app/integrations/pasarela_client.py`):
- [ ] Implementar `PasarelaPagosClient(BaseApiClient)`:
  - `solicitar_orden_pago(cod_socio: str, monto_bs: float, facturas: List[str]) -> Dict[str, Any]`
  - Generación de cadena Simple QR interoperable (formato BCP/BNB/BCB).
  - Soporte para simulación determinista en desarrollo y conexión real a sandbox bancario.

#### C. Batería de Pruebas DEV 1 (`backend/tests/test_pasarela_pagos.py`):
- [ ] Prueba de generación de orden de pago y estructura de Simple QR.
- [ ] Prueba de persistencia del modelo `TransaccionPago` en PostgreSQL.

---

### 4.2 Entregables de DEV 2: Esquemas, Lógica de Conciliación y Endpoints REST

#### A. Esquemas Pydantic v2 (`backend/app/schemas/pago.py`):
- [ ] `GenerarPagoRequest`:
  - `cod_socio`: str
  - `nro_facturas`: List[str]
  - `monto_total_bs`: float
- [ ] `GenerarPagoResponse`:
  - `transaccion_id`: UUID
  - `cod_socio`: str
  - `monto_total_bs`: float
  - `qr_cadena`: str
  - `url_banca_movil`: Optional[str]
  - `tiempo_expiracion_minutos`: int (ej. 15 minutos)
  - `estado`: str
- [ ] `WebhookNotificacionPago`:
  - `nro_transaccion`: str
  - `cod_socio`: str
  - `monto_pagado_bs`: float
  - `estado_pago`: str
  - `firma_digital`: str
- [ ] `EstadoTransaccionResponse`:
  - `transaccion_id`: UUID
  - `estado`: str
  - `pagado_en`: Optional[datetime]

#### B. Servicio de Negocio (`backend/app/services/servicio_pagos.py`):
- [ ] Implementar `ServicioPagos`:
  - `iniciar_pago(...)`: Valida deuda real en COSMOL, verifica que el monto coincida y registra la orden en PostgreSQL.
  - `procesar_webhook_bancario(...)`: Verifica firma criptográfica (HMAC), transiciona estado a `PAGADO`, purga la clave `deuda:{cod_socio}` en Redis y despacha auditoría asíncrona.
  - `consultar_estado_pago(...)`: Permite polling ligero desde Flutter mientras el usuario escanea el QR.

#### C. Endpoints REST (`backend/app/api/v1/pagos.py`):
- [ ] `POST /api/v1/pagos/generar-qr`: Protegido con JWT Bearer.
- [ ] `POST /api/v1/pagos/webhook`: Endpoint público para el banco (protegido por firma HMAC en headers).
- [ ] `GET /api/v1/pagos/{transaccion_id}/estado`: Protegido con JWT Bearer.
- [ ] Registrar `pagos_router` en `backend/app/api/v1/router.py`.

#### D. Batería de Pruebas DEV 2 (`backend/tests/test_pagos.py`):
- [ ] Prueba de generación de orden y cálculo exacto de importes en Bs.
- [ ] Prueba de validación y rechazo ante firma de webhook inválida.
- [ ] Prueba de invalidación de caché de deuda en Redis tras pago exitoso.
- [ ] Prueba de control de acceso y consulta de estado.

---

## 5. Criterios de Aceptación y Validación

1. [ ] **Simple QR Funcional:** La API genera una cadena QR válida y decodificable con monto en Bs y número de orden.
2. [ ] **Conciliación en Tiempo Real:** Al impactar el webhook con firma válida, la deuda se invalida en Redis en menos de 20 ms.
3. [ ] **Cero Almacenamiento de Tarjetas:** Cumplimiento total de normativa de seguridad (cero datos sensibles bancarios en BD).
4. [ ] **Suite de Pruebas en Verde:** Todas las pruebas pasan al 100% en Docker integrándose a los 90 tests existentes sin regresiones.
