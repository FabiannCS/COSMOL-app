# Contrato Técnico de Integración: App Móvil de Socios → COSMOL-Reportes

> **Destinatario:** Equipo de Backend de la App Móvil (`COSMOL-app`) y Equipo de `COSMOL-Reportes`  
> **Ubicación del Documento:** `Docs/CONTRATO_INTEGRACION_APP_A_REPORTES.md`  
> **Fecha:** Septiembre 2026  
> **Versión:** 1.0.0 (Oficial)  
> **Objetivo:** Definir el contrato de comunicación HTTP, estructura de datos, catálogo de eventos y buenas prácticas de resiliencia para el envío asíncrono de movimientos y auditoría desde la App Móvil hacia el sistema central `COSMOL-Reportes`.

---

## 1. Visión General y Arquitectura

Cada vez que un socio realiza una acción relevante en la aplicación móvil (inicio de sesión, consulta de saldo, descarga de factura o clic para pagar), el backend de la App Móvil despacha un evento HTTP POST en **segundo plano (background task)** hacia `COSMOL-Reportes`.

```
┌─────────────────────────────────────────────────────────────┐
│                 App Móvil (Flutter / Mobile)                │
│       [Login, Deuda, Facturas, Descargas PDF, Pagos]        │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│             Backend App de Socios (FastAPI / Python)        │
│  • Procesa la solicitud del socio                           │
│  • Responde de inmediato a la App Móvil                     │
│  • Despacha evento en BackgroundTask (No bloqueante)        │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               │ HTTP POST /api/consultas
                               │ Header: X-Reportes-Token: {TOKEN}
                               │ Body: { "id_usuario": 3, "tipo_ubicacion": "APP_MOVIL", ... }
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                 COSMOL-Reportes (Sistema Central)           │
│  • Valida X-Reportes-Token                                  │
│  • Registra el evento en la tabla `consulta`                │
│  • Se visualiza en vivo en `/reportes/app-socios`           │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Especificación del Endpoint

* **Método:** `POST`
* **Ruta:** `/api/consultas`
* **URLs según el entorno:**
  * **Pruebas Locales (vía ngrok):** `https://{tunel-ngrok}.ngrok-free.app/api/consultas`
  * **Servidor de Pruebas (Red Local):** `http://10.129.1.105:8080/api/consultas`
  * **Producción / Dominio Oficial:** `https://chatbot.cosmol.com.bo:8081/api/consultas`

### 2.1 Cabeceras Obligatorias (Headers)

| Cabecera | Tipo | Valor / Descripción |
|---|---|---|
| `Content-Type` | String | `application/json; charset=utf-8` |
| `X-Reportes-Token` | String | Token de autenticación pactado. Debe coincidir con la variable de entorno `REPORTES_API_TOKEN`. |

---

## 3. Estructura del Payload JSON

### 3.1 Diccionario de Campos

| Campo | Tipo | Requerido | Descripción / Regla |
|---|---|:---:|---|
| **`codigo_socio`** | `int` | **Sí** | Código fijo del socio titular que realiza la consulta (ej. `23807`). |
| **`nombres`** | `string` | **Sí** | Nombre completo o razón social del titular (ej. `"MISERICORDIA AGUANTA EDDY FRANCO"`). |
| **`telefono`** | `string` / `null` | No | Número de teléfono de contacto en formato internacional (ej. `"+59171029384"`). Si no se tiene, enviar `null`. |
| **`id_usuario`** | `int` | **Sí** | **Siempre debe ser `3`** (Identificador asignado al canal App Móvil en `COSMOL-Reportes`). |
| **`id_tipo`** | `int` | **Sí** | Código numérico del evento según el catálogo oficial (§ 4). |
| **`tipo_consulta`** | `string` | **Sí** | Nombre legible del evento (ej. `"Consulta de Deuda"`). |
| **`tipo_ubicacion`** | `string` | **Sí** | **Siempre debe ser `"APP_MOVIL"`** (Garantiza el filtrado correcto en el dashboard). |
| **`fecha_consulta`** | `string` | No | Fecha en formato `YYYY-MM-DD` (ej. `"2026-09-22"`). Si se omite, Reportes asigna la fecha actual del servidor. |
| **`hora_consulta`** | `string` | No | Hora en formato `HH:MM:SS` (ej. `"15:30:00"`). Si se omite, Reportes asigna la hora actual del servidor. |

---

## 4. Catálogo Oficial de Eventos para la App Móvil

| `id_tipo` | `tipo_consulta` | Momento en que debe enviarse |
|:---:|---|---|
| **`1`** | `Autenticación / Acceso` | El socio inicia sesión correctamente con su código y PIN / contraseña en la App Móvil. |
| **`2`** | `Consulta de Deuda` | El socio entra a la pantalla de facturación o visualiza el saldo de sus facturas pendientes. |
| **`3`** | `Historial de Facturas` | El socio consulta el historial de sus facturas pagadas anteriormente. |
| **`9`** | `Descarga de Factura PDF` | El socio pulsa el botón para descargar o visualizar el documento PDF de una factura. |
| **`10`** | `Intento de Pago` | El socio presiona el botón "Pagar" y la app genera el enlace hacia la pasarela (Multipago o Pago al Paso). |

---

## 5. Ejemplos de Payloads Listos para Usar

### 5.1 Evento de Login exitoso (`id_tipo: 1`)
```json
{
  "codigo_socio": 23807,
  "nombres": "MISERICORDIA AGUANTA EDDY FRANCO",
  "telefono": "+59171029384",
  "id_usuario": 3,
  "id_tipo": 1,
  "tipo_consulta": "Autenticación / Acceso",
  "tipo_ubicacion": "APP_MOVIL",
  "fecha_consulta": "2026-09-22",
  "hora_consulta": "10:15:20"
}
```

### 5.2 Evento de Consulta de Deuda (`id_tipo: 2`)
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
  "hora_consulta": "10:16:05"
}
```

### 5.3 Evento de Descarga de Factura PDF (`id_tipo: 9`)
```json
{
  "codigo_socio": 23807,
  "nombres": "MISERICORDIA AGUANTA EDDY FRANCO",
  "telefono": "+59171029384",
  "id_usuario": 3,
  "id_tipo": 9,
  "tipo_consulta": "Descarga de Factura PDF",
  "tipo_ubicacion": "APP_MOVIL",
  "fecha_consulta": "2026-09-22",
  "hora_consulta": "10:17:30"
}
```

### 5.4 Evento de Intento de Pago (`id_tipo: 10`)
```json
{
  "codigo_socio": 23807,
  "nombres": "MISERICORDIA AGUANTA EDDY FRANCO",
  "telefono": "+59171029384",
  "id_usuario": 3,
  "id_tipo": 10,
  "tipo_consulta": "Intento de Pago",
  "tipo_ubicacion": "APP_MOVIL",
  "fecha_consulta": "2026-09-22",
  "hora_consulta": "10:18:45"
}
```

---

## 6. Respuestas del Servidor

* **Éxito (`HTTP 201 Created`):**
  ```json
  {
    "status": "success",
    "message": "Consulta registrada"
  }
  ```
* **Error de Autenticación (`HTTP 401 Unauthorized`):**
  ```json
  {
    "status": "error",
    "message": "Token no autorizado"
  }
  ```
* **Error de Validación (`HTTP 400 Bad Request`):**
  ```json
  {
    "status": "error",
    "message": "Parámetros obligatorios faltantes"
  }
  ```

---

## 7. Implementación Recomendada en el Backend de la App (Python / FastAPI)

Para garantizar que ningún retardo de red afecte la velocidad percibida por el socio en la aplicación móvil, **el despacho debe realizarse en segundo plano con un timeout corto**:

```python
# Ejemplo en FastAPI / Python con httpx y BackgroundTasks
import os
import httpx
from fastapi import BackgroundTasks
import logging

logger = logging.getLogger(__name__)

REPORTES_API_URL = os.getenv("REPORTES_API_URL", "http://10.129.1.105:8080/api/consultas")
REPORTES_API_TOKEN = os.getenv("REPORTES_API_TOKEN", "cosmol_reportes_secret_token")

def despachar_evento_reportes_sync(payload: dict):
    """Envío en segundo plano con timeout estricto para no colgar el proceso."""
    headers = {
        "Content-Type": "application/json",
        "X-Reportes-Token": REPORTES_API_TOKEN
    }
    try:
        with httpx.Client(timeout=3.0) as client:
            response = client.post(REPORTES_API_URL, json=payload, headers=headers)
            if response.status_code != 201:
                logger.warning(f"[Reportes] Servidor devolvió status {response.status_code}: {response.text}")
    except Exception as e:
        # En caso de corte de red, solo se registra log para no afectar al socio móvil
        logger.error(f"[Reportes] Contingencia de red al enviar evento: {e}")

def registrar_movimiento_socio(
    background_tasks: BackgroundTasks,
    codigo_socio: int,
    nombres: str,
    id_tipo: int,
    tipo_consulta: str,
    telefono: str = None
):
    payload = {
        "codigo_socio": codigo_socio,
        "nombres": nombres,
        "telefono": telefono,
        "id_usuario": 3,
        "id_tipo": id_tipo,
        "tipo_consulta": tipo_consulta,
        "tipo_ubicacion": "APP_MOVIL"
    }
    background_tasks.add_task(despachar_evento_reportes_sync, payload)
```

---

## 8. Guía de Pruebas Pre-finales con ngrok

Durante la fase de desarrollo, dado que la App Móvil corre de forma local y `COSMOL-Reportes` se encuentra en el servidor (o en otra máquina local), se utiliza **ngrok** para crear un puente seguro:

### Paso 1: Levantar el túnel en la máquina donde corre COSMOL-Reportes
```bash
# Si COSMOL-Reportes corre en el puerto 8080 (o el puerto expuesto de docker)
ngrok http 8080
```
ngrok generará una URL pública segura, por ejemplo:
`https://a1b2-181-115-20-5.ngrok-free.app`

### Paso 2: Prueba sintética con cURL desde la máquina del compañero
El compañero puede ejecutar este comando en su terminal para validar la llegada antes de tocar código:

```bash
curl -X POST "https://{TUNEL_NGROK}.ngrok-free.app/api/consultas" \
     -H "Content-Type: application/json" \
     -H "X-Reportes-Token: {TU_TOKEN_CONFIGURADO}" \
     -d '{
       "codigo_socio": 23807,
       "nombres": "PRUEBA ENLACE NGROK",
       "telefono": "+59170000000",
       "id_usuario": 3,
       "id_tipo": 2,
       "tipo_consulta": "Consulta de Deuda",
       "tipo_ubicacion": "APP_MOVIL"
     }'
```

**Resultado esperado:**
```json
{"status":"success","message":"Consulta registrada"}
```

### Paso 3: Verificación visual en tiempo real
Inmediatamente después de recibir `status: success`:
1. Abrir en el navegador: `http://localhost:8080/reportes/app-socios` (o en el servidor de reportes).
2. Verificar que aparezca el registro `PRUEBA ENLACE NGROK` con la insignia **APP_MOVIL** y sume a la tarjeta de **Consulta de Deuda**.
