# Guía de Integración y Seguridad: App Móvil hacia COSMOL-Reportes

> **Especificación técnica y contrato de API** para la integración entre la Aplicación Móvil de COSMOL y el sistema de auditoría y métricas **`COSMOL-Reportes`**.

---

## 1. Endpoint Receptor Oficial

Las solicitudes de auditoría emitidas por la App Móvil (o su backend) deben dirigirse exclusivamente al siguiente endpoint:

| Propiedad | Especificación |
|---|---|
| **Método HTTP** | `POST` |
| **Ruta del Endpoint** | **`/api/consultas`** |
| **URL Base en Producción** | `https://<DOMINIO_O_IP_REPORTES>/api/consultas` |
| **URL en Desarrollo Local** | `http://localhost:8082/api/consultas` (o puerto configurado) |
| **Controlador Receptor** | `app/Controllers/ConsultaApiController.php` (método `registrar()`) |
| **Tabla de Persistencia** | `consulta` (BD PostgreSQL `cosmol_reportes`) |

---

## 2. Arquitectura del Flujo de Datos

```text
┌───────────────────────────────────────┐
│ App Móvil COSMOL                      │
│ (Acción del Socio / Reconexión / etc) │
└──────────────────┬────────────────────┘
                   │
                   ▼
┌───────────────────────────────────────┐
│ Backend de la App Móvil (Recomendado) │
│ • Procesa negocio y registra en SAI   │
│ • Despacha auditoría con credencial   │
└──────────────────┬────────────────────┘
                   │
                   │ HTTPS POST /api/consultas
                   │ Header: X-Reportes-Token: <SECRET_TOKEN>
                   │ Header: Content-Type: application/json
                   ▼
┌────────────────────────────────────────────────────────┐
│ COSMOL-Reportes                                        │
│ 1. Valida token y canal ('APP_MOVIL')                  │
│ 2. Registra evento en BD local ('consulta')            │
│ 3. Alimenta en tiempo real /reportes/app-movil         │
└────────────────────────────────────────────────────────┘
```

---

## 3. Directrices y Medidas de Seguridad Obligatorias

### 3.1 Autenticación por Token Machine-to-Machine (M2M)
- La petición **debe incluir obligatoriamente** la cabecera:
  ```http
  X-Reportes-Token: <REPORTES_API_TOKEN>
  ```
- Si la cabecera falta, está vacía o el valor no coincide con el configurado en el archivo `.env` del servidor, el endpoint responderá de inmediato con **HTTP 401 Unauthorized**.

### 3.2 Protección del Secreto (Patrón BFF / Backend Intermedio)
> [!IMPORTANT]
> **No almacenar el token de reportes en texto plano dentro del código compilado de la App Móvil (APK/IPA).**
> Las aplicaciones cliente pueden descompilarse mediante ingeniería inversa.

- **Flujo Recomendado:** La App Móvil envía la acción al Backend central de la cooperativa; este backend autentica al socio y es el encargado de disparar la notificación a `COSMOL-Reportes` utilizando la credencial protegida en el servidor.
- **Flujo Directo (si no hay backend intermedio):** El token debe resguardarse mediante los mecanismos de almacenamiento seguro nativos del dispositivo (**Android Keystore** / **iOS Keychain**).

### 3.3 Transporte Cifrado Obligatorio (HTTPS / TLS 1.2+)
- En producción está **estrictamente prohibido** el uso de HTTP plano.
- La comunicación debe operar exclusivamente bajo **HTTPS con certificados TLS válidos**, garantizando el cifrado de datos en tránsito e impidiendo interceptaciones (*Man-in-the-Middle*).

### 3.4 Validación de Parámetros y Sanitización
- El endpoint valida estrictamente los tipos de datos:
  - `codigo_socio`: Entero positivo obligatorio (`> 0`).
  - `id_tipo`: Identificador numérico válido del catálogo.
  - `tipo_ubicacion`: Debe ser exactamente `'APP_MOVIL'`.
- La persistencia se realiza mediante sentencias preparadas con **PDO**, previniendo cualquier riesgo de inyección SQL.

### 3.5 Recomendación de Timeouts y Resiliencia
- Configurar un **timeout de conexión corto (máximo 2 a 3 segundos)**.
- El envío de la métrica debe ser un proceso asíncrono o secundario: un retraso o fallo en el servidor de reportes **nunca debe interrumpir ni bloquear la operación del socio** en la App Móvil.

---

## 4. Contrato de Entrada (Request)

### Cabeceras HTTP Requeridas
```http
POST /api/consultas HTTP/1.1
Host: <TU_DOMINIO_O_IP>
Content-Type: application/json
X-Reportes-Token: <REPORTES_API_TOKEN>
```

### Formato del Cuerpo JSON (Payload)
```json
{
  "codigo_socio": 267657,
  "nombres": "JUAN PEREZ FLORES",
  "telefono": "71234567",
  "id_tipo": 5,
  "tipo_ubicacion": "APP_MOVIL",
  "fecha_consulta": "2026-11-10",
  "hora_consulta": "18:15:30"
}
```

### Especificación de Campos
| Campo | Tipo | Obligatorio | Descripción |
|---|:---:|:---:|---|
| `codigo_socio` | `int` | **Sí** | Código de socio o código fijo en COSMOL. |
| `nombres` | `string` | No | Nombre completo del socio. |
| `telefono` | `string` | No | Teléfono de contacto registrado. |
| `id_tipo` | `int` | **Sí** | Identificador del evento según catálogo oficial. |
| `tipo_ubicacion`| `string` | **Sí** | Debe ser `"APP_MOVIL"` para asignarlo al módulo correspondiente. |
| `fecha_consulta`| `string` | No | Formato `YYYY-MM-DD` (por defecto la fecha del servidor). |
| `hora_consulta` | `string` | No | Formato `HH:MM:SS` (por defecto la hora del servidor). |

---

## 5. Catálogo de Tipos de Consulta para la App Móvil (`id_tipo`)

| `id_tipo` | Nombre Oficial del Tipo | Caso de Uso en la App Móvil |
|:---:|---|---|
| **1** | Autenticación / Acceso | Inicio de sesión o validación de credenciales del socio. |
| **2** | Consulta de Deuda | Consulta de facturas pendientes de pago y monto adeudado. |
| **3** | Historial de Consumo | Consulta de histórico de consumo en m³ y facturas pagadas. |
| **4** | Registro de Reclamo | Envío de reclamo técnico o comercial. |
| **5** | **Solicitud de Reconexión** | **Trámite de solicitud de reconexión completado.** |
| **9** | Descarga de Factura PDF | Descarga o visualización de factura en PDF. |
| **10**| Pago: Multipago | Intento o redirección a pasarela Multipago. |
| **11**| Pago: Pago al Paso | Intento o redirección a pasarela Pago al Paso. |
| **12**| Pago: Código QR | Generación de código QR para pago de servicio. |

---

## 6. Contrato de Salida (Respuestas del Servidor)

* **HTTP 201 Created (Éxito):**
  ```json
  {
    "status": "success",
    "message": "Consulta registrada exitosamente",
    "canal": "app_movil"
  }
  ```
* **HTTP 401 Unauthorized (Token inválido o ausente):**
  ```json
  {
    "status": "error",
    "message": "Token no autorizado"
  }
  ```
* **HTTP 400 Bad Request (Faltan campos obligatorios):**
  ```json
  {
    "status": "error",
    "message": "Parámetros obligatorios faltantes"
  }
  ```

---

## 7. Verificación en el Sistema de Reportes

Una vez emitidas las solicitudes desde la App Móvil:
1. Acceder al sistema web administrativo **COSMOL-Reportes**.
2. Ir a **Reportes > App Móvil** (`/reportes/app-movil`).
3. El evento aparecerá auditado bajo el socio correspondiente, mostrando el tipo de acción y canal `'APP_MOVIL'`.
