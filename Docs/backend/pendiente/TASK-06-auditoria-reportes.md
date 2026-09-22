# Tarea 06: Despacho Asíncrono de Eventos y Auditoría a COSMOL-Reportes

> **Estado:** PENDIENTE  
> **Fase:** Fase 6 — Auditoría a ChatbotReportes y Seguridad Avanzada  
> **Fecha de formulación:** Septiembre 2026  
> **Entorno de ejecución:** Backend FastAPI en Docker (`cosmol-backend-api`, `cosmol-cache-redis`, `cosmol-db-postgres`)  
> **Documentos de referencia:** `AGENTS.md` (Secciones 6, 8, 12.2, 12.3), `HOJA_DE_RUTA_DESARROLLO.md` (Fase 6) y [GUIA_VISTA_APP_SOCIOS_COSMOL_REPORTES.md](file:///d:/COSMOL-app/Docs/reportes/GUIA_VISTA_APP_SOCIOS_COSMOL_REPORTES.md)  
> **Asignación Modular:** DEV 1 (Aireyu) y DEV 2 (Eduardo)

---

## 1. Contexto y Principios de Integración

El proyecto **`COSMOL-app`** no cuenta con panel de administración propio (`AGENTS.md` Sección 6). Toda la analítica de movimientos, consultas y auditoría se centraliza en el proyecto hermano **`COSMOL-Reportes`**.

### 1.1 Principios Rectores:
1. **Integración Unidireccional por REST API:**  
   La App de Socios **es exclusivamente emisora** de eventos; nunca lee ni administra la base de datos de Reportes.
2. **Cero Afectación de Rendimiento (0 ms de overhead):**  
   El despacho de eventos hacia Reportes se ejecuta en **segundo plano (`BackgroundTasks`)**. El socio en Flutter recibe su respuesta HTTP en `< 20 ms` de inmediato.
3. **Resiliencia y Degradación Suave:**  
   Si el servidor de Reportes está apagado, en mantenimiento, o si las credenciales en `.env` no están configuradas en desarrollo, el despachador captura la excepción con `logger.warning`. **Bajo ninguna circunstancia un fallo en Reportes generará un error HTTP 500 al socio.**
4. **Identidad del Emisor:**  
   Todos los eventos despachados por la app llevan:
   * **`id_usuario = 3`**: Identificador asignado a la App Móvil de Socios (mientras que `id_usuario = 2` pertenece al Chatbot de WhatsApp).
   * **`tipo_ubicacion = "APP_MOVIL"`**: Canal de procedencia.

---

## 2. Contrato de Integración: Payload JSON hacia `POST /api/consultas`

El backend enviará peticiones HTTP asíncronas hacia el endpoint de `COSMOL-Reportes`:

* **URL:** `{REPORTES_API_URL}/api/consultas`
* **Método:** `POST`
* **Headers:**
  ```http
  Content-Type: application/json
  X-Reportes-Token: {REPORTES_API_TOKEN}
  ```
* **Estructura del Payload JSON:**
  ```json
  {
    "codigo_socio": 23807,
    "nombres": "MISERICORDIA AGUANTA EDDY FRANCO",
    "telefono": "+59171029384",
    "id_usuario": 3,
    "id_tipo": 2,
    "tipo_consulta": "Consulta de Deuda",
    "tipo_ubicacion": "APP_MOVIL",
    "fecha_consulta": "2026-09-22",
    "hora_consulta": "15:30:00"
  }
  ```

### 2.1 Mapeo de Eventos por Módulo de la App:

| Módulo de la App | Endpoint Disparador | `id_tipo` | `tipo_consulta` | Momento de Emisión |
| :--- | :--- | :---: | :--- | :--- |
| **Autenticación** | `POST /autenticacion/login` | `1` | `Autenticación / Acceso` | Login diario exitoso con PIN. |
| **Onboarding** | `POST /autenticacion/establecer-pin` | `1` | `Autenticación / Acceso` | Primer registro y vinculación de celular. |
| **Deuda** | `GET /deuda/{cod_socio}` | `2` | `Consulta de Deuda` | Socio abre o refresca su saldo en el Dashboard. |
| **Historial Consumo** | `GET /consumo/{cod_socio}` | `3` | `Historial de Facturas` | Socio consulta gráfica de 12 meses. |
| **Documentos PDF** | `GET /documentos/{doc_id}/descargar`| `9` | `Descarga de Documento PDF` | Socio descarga factura oficial o aviso. |
| **Pasarelas de Pago** | `POST /pagos/registrar-intento/...` | `10`| `Intento de Pago Pasarela` | Socio pulsa Multipago o Pago al Paso. |

---

## 3. Asignación y División Modular de Trabajo

```
┌────────────────────────────────────────────────────────────────────────┐
│                   DIVISIÓN MODULAR FASE 6 (AUDITORÍA)                  │
├───────────────────────────────────┬────────────────────────────────────┤
│       DEV 1 (Aireyu)              │       DEV 2 (Eduardo)              │
├───────────────────────────────────┼────────────────────────────────────┤
│ • Variables de Configuración      │ • Integración de `BackgroundTasks` │
│   en `core/config.py`             │   en endpoints de Auth y Onboard   │
│ • Cliente HTTP Asíncrono          │ • Integración en endpoints de      │
│   (`integrations/reportes_client`)│   Deuda, Consumos y Documentos     │
│ • Tarea en segundo plano          │ • Integración en endpoint de Pagos │
│   (`tasks/auditoria_reportes.py`) │ • Verificación de 0 ms overhead    │
│ • Tests Unitarios DEV 1           │ • Tests de Integración End-to-End  │
└───────────────────────────────────┴────────────────────────────────────┘
```

---

## 4. Detalle de Entregables Técnicos

### 4.1 Entregables de DEV 1 (Aireyu): Cliente HTTP, Configuración y Tareas Background

#### A. Variables de Configuración (`backend/app/core/config.py`):
- [x] Incorporar parámetros para la conexión con COSMOL-Reportes:
  ```python
  REPORTES_API_URL: str = ""       # Ej: "http://cosmol-reportes:80" o URL de producción
  REPORTES_API_TOKEN: str = ""     # Token validado por X-Reportes-Token
  REPORTES_ID_USUARIO_APP: int = 3 # Usuario 3 = App Móvil (Usuario 2 = Chatbot)
  REPORTES_TIMEOUT_SECONDS: float = 3.0
  REPORTES_ENABLED: bool = True
  ```

#### B. Cliente HTTP Asíncrono (`backend/app/integrations/reportes_client.py`):
- [x] Clase `ReportesApiClient`:
  - Utiliza `httpx.AsyncClient` con pool de conexiones y timeout estricto de 3.0s.
  - Método `enviar_evento_auditoria(codigo_socio: int, nombres: str, telefono: Optional[str], id_tipo: int, tipo_consulta: str, tipo_ubicacion: str = "APP_MOVIL") -> bool`:
    - Si `REPORTES_ENABLED is False` o `REPORTES_API_URL` está vacío: omite la llamada y retorna `False` sin error.
    - Envía el payload JSON con el header `X-Reportes-Token`.
    - Retorna `True` si el servidor respondió HTTP 200/201.
    - Captura excepciones de conexión, timeout o servidor caído con `logger.warning`, retornando `False` sin lanzar errores hacia arriba.

#### C. Módulo de Despacho en Segundo Plano (`backend/app/tasks/auditoria_reportes.py`):
- [x] Función `despachar_auditoria_reportes(codigo_socio, nombres, telefono, id_tipo, tipo_consulta, tipo_ubicacion="APP_MOVIL")`:
  - Función asíncrona preparada para ser inyectada en `background_tasks.add_task(...)`.
  - Asegura que la ejecución corra de forma completamente desacoplada de la respuesta HTTP devuelta al socio.

#### D. Batería de Pruebas DEV 1 (`backend/tests/test_auditoria_reportes.py`):
- [x] Prueba de envío exitoso con respuesta HTTP 201 y validación de `id_usuario: 3`.
- [x] Prueba de degradación suave cuando `REPORTES_API_URL` está vacío (omisión limpia).
- [x] Prueba de resiliencia ante servidor Reportes offline / timeout (cero excepciones no controladas).
- [x] Prueba de encabezado `X-Reportes-Token` y estructura del payload.

---

### 4.2 Entregables de DEV 2 (Eduardo): Enganche en Endpoints y Pruebas End-to-End

#### A. Integración en Endpoints de Autenticación (`backend/app/api/v1/autenticacion.py`):
- [ ] Inyectar `BackgroundTasks` en `POST /autenticacion/login`:
  - Tras validar PIN y emitir JWT, encolar evento `id_tipo = 1`, `tipo_consulta = "Autenticación / Acceso"`.
- [ ] Inyectar `BackgroundTasks` en `POST /autenticacion/establecer-pin`:
  - Tras registrar PIN y crear suministro, encolar evento de Onboarding con `id_tipo = 1`.

#### B. Integración en Endpoints de Consulta de Deuda (`backend/app/api/v1/deuda.py`):
- [ ] Inyectar `BackgroundTasks` en `GET /deuda/{cod_socio}`:
  - Al consultar el saldo del socio, encolar evento `id_tipo = 2`, `tipo_consulta = "Consulta de Deuda"`.

#### C. Integración en Endpoints de Consumo e Historial (`backend/app/api/v1/consumo.py`):
- [ ] Inyectar `BackgroundTasks` en `GET /consumo/{cod_socio}`:
  - Al consultar la gráfica de 12 meses, encolar evento `id_tipo = 3`, `tipo_consulta = "Historial de Facturas"`.

#### D. Integración en Endpoints de Documentos PDF (`backend/app/api/v1/documentos.py`):
- [ ] Inyectar `BackgroundTasks` en `GET /documentos/{doc_id}/descargar`:
  - Al iniciar la descarga del PDF en streaming, encolar evento `id_tipo = 9`, `tipo_consulta = "Descarga de Documento PDF"`.

#### E. Integración en Endpoints de Pagos (`backend/app/api/v1/pagos.py`):
- [ ] Inyectar `BackgroundTasks` en `POST /pagos/registrar-intento/{cod_socio}`:
  - Al seleccionar un canal de pago (Multipago o Pago al Paso), encolar evento `id_tipo = 10`, `tipo_consulta = "Intento de Pago Pasarela"`.

#### F. Batería de Pruebas de Integración DEV 2 (`backend/tests/test_auditoria_endpoints.py`):
- [ ] Prueba de que los endpoints agreguen la tarea a `BackgroundTasks` sin ralentizar la respuesta.
- [ ] Prueba de que las respuestas HTTP sigan siendo `< 20 ms` con la auditoría activa.
- [ ] Prueba de que una falla en Reportes no altere el código de respuesta (ej. 200 OK en deuda o 201 en login).

---

## 5. Criterios de Aceptación y Validación

1. [ ] **Payload Conforme:** Cada evento despachado contiene `id_usuario: 3`, `tipo_ubicacion: "APP_MOVIL"`, código de socio, nombres, teléfono y timestamp.
2. [ ] **Autenticación con Token:** Las peticiones viajan con la cabecera `X-Reportes-Token`.
3. [ ] **Rendimiento (<20 ms):** El tiempo de respuesta de los endpoints de la app no se ve afectado por el despacho a Reportes.
4. [ ] **Resiliencia Total:** La desconexión o fallo del servidor de Reportes no produce errores HTTP 500 ni bloqueos en la app de Flutter.
5. [ ] **Suite de Pruebas en Verde:** Todas las pruebas pasan al 100% en Docker sumándose a las 96 pruebas existentes sin regresiones.
