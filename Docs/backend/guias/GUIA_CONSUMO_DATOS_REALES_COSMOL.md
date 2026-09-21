# Protocolo y Guía de Consumo de Datos Reales de COSMOL
> **Documento de Trabajo para Pruebas en Vivo (Rama: `PruebaAireyu`)**  
> **Fecha:** Septiembre 2026  
> **Autores:** Equipo Backend (DEV 1 Aireyu / DEV 2 Eduardo)  
> **Objetivo:** Guía operativa paso a paso para consumir datos reales desde el servidor oficial de COSMOL R.L. a través del backend FastAPI y la aplicación móvil Flutter en Android, validando las 4 fases desarrolladas.

---

## 1. Visión General y Reglas de la Rama `PruebaAireyu`

La rama **`PruebaAireyu`** está destinada a ser un **laboratorio de pruebas en vivo**. En ella se ejecutan peticiones hacia los servidores productivos/legados de COSMOL R.L. para validar cómo se comporta el sistema con datos reales de socios de Montero antes de pasar la versión final a la rama oficial de Fabián (`devFabian`).

```text
[ Servidor Real de COSMOL R.L. ]
       ▲
       │ (1) HTTP en vivo a api.cosmol.com.bo/api-consultas
[ Backend FastAPI en Docker (Puerto 8000) ]
       ▲
       │ (2) HTTP local / Wi-Fi
[ App Flutter en Android (Emulador o Celular Físico) ]
```

---

## 2. Preparación del Entorno (Bajar la Palanca del Modo Mock)

Para que el backend deje de usar datos inventados y se comunique con la API real de COSMOL, se debe ajustar el archivo `.env` en la raíz del proyecto backend:

### A. Variables de Entorno en el archivo `.env`:

```ini
# ==============================================================================
# INTEGRACIÓN EN VIVO CON LA API DE COSMOL
# ==============================================================================
COSMOL_LEGACY_URL=http://api.cosmol.com.bo/api-consultas
COSMOL_LEGACY_TIMEOUT_SECONDS=5.0

# Desactivar simulación: False obliga al cliente a conectarse a COSMOL
MOCK_COSMOL_LEGACY=False
MOCK_COSMOL_CONSUMO=False

# Configuración de Mensajería OTP
# Dejar en True si desean ver el código en el banner de la app o logs de Docker sin gastar saldo
# Cambiar a False si se cuenta con saldo y credenciales activas de Meta WhatsApp Cloud API
MOCK_MESSAGING=True
```

### B. Reiniciar los contenedores Docker para aplicar el cambio:

```bash
docker compose down
docker compose up -d
```

### C. Conexión desde el Celular o Emulador Android:

1. **Si pruebas con Emulador Android:**
   Compilar la app apuntando al localhost virtual:
   ```bash
   cd frontend
   flutter run --dart-define=EMULATOR=true
   ```
2. **Si pruebas con Celular Físico conectado por USB (Recomendado):**
   Mapear el puerto de la laptop al celular vía ADB:
   ```bash
   adb reverse tcp:8000 tcp:8000
   flutter run
   ```
3. **Si pruebas con Celular por Wi-Fi:**
   Obtén la IP local de tu laptop (ej: `192.168.1.15`) y compila con:
   ```bash
   flutter run --dart-define=BACKEND_IP=192.168.1.15
   ```

---

## 3. Socio Real de Prueba Certificado

Para las pruebas reales iniciales, utilizaremos el socio confirmado por Aireyu:

| Variable | Valor Real Confirmado |
| :--- | :--- |
| **Código de Socio:** | `23807` |
| **Nombre Oficial en COSMOL:** | `MISERICORDIA AGUANTA EDDY FRANCO` |
| **Meses de Historial Disponibles:** | Agosto 2026 (`15 m³`, `58.01 Bs`), Julio 2026 (`14 m³`, `54.22 Bs`) |

*(También pueden utilizar cualquier otro código de socio real que tengan en una factura impresa de agua).*

---

## 4. Batería de Pruebas de Consumo Real (Fase por Fase)

---

### FASE 1: Autenticación, Onboarding y Multicuenta con Datos Reales

#### Prueba 1.1: Validación de Credenciales con la Nueva API POST en Vivo
* **Objetivo:** Validar código de socio y carnet directamente contra el endpoint oficial de validación de COSMOL, sustituyendo la consulta masiva GET.
* **Endpoint Legado Oficial:** `POST http://api.cosmol.com.bo/api-consultas/socios/validar`
* **Body enviado a COSMOL:**
  ```json
  {
    "codigo": "23807",
    "ci": "6259185"
  }
  ```
* **Respuesta del Servidor de COSMOL (HTTP 200 OK):**
  ```json
  {
    "estado": "exito",
    "mensaje": "Identidad validada correctamente.",
    "datos": {
      "valido": true,
      "socio": {
        "CODIGO": "23807",
        "NROCIONIT": "6259185        ",
        "NOMBRE": "MISERICORDIA AGUANTA EDDY FRANCO        "
      }
    }
  }
  ```
* **Respuesta en caso de error o CI no coincidente (HTTP 401 Unauthorized):**
  ```json
  {
    "estado": "error",
    "mensaje": "Credenciales incorrectas. El código de socio o el CI no coinciden.",
    "datos": {
      "valido": false
    }
  }
  ```
* **Endpoint BFF de la App:** `POST /api/v1/autenticacion/verificar-socio`
* **Petición desde la App (Payload):**
  ```json
  {
    "cod_socio": "23807",
    "ci": "6259185"
  }
  ```
* **Resultado Esperado hacia Flutter:**  
  HTTP 200 OK con:
  ```json
  {
    "cod_socio": "23807",
    "nombre_titular": "MISERICORDIA AGUANTA EDDY FRANCO",
    "mensaje": "Socio verificado correctamente. Proceda a asociar su teléfono celular."
  }
  ```
* **Validación en Flutter:** La app muestra la tarjeta de Socio Verificado con el nombre oficial del titular (`MISERICORDIA AGUANTA EDDY FRANCO`) recuperado en tiempo real.

#### Prueba 1.2: Solicitud y Verificación de OTP (6 dígitos)
* **Objetivo:** Asociar el número de celular del tester y validar el código de seguridad.
* **Endpoint:** `POST /api/v1/autenticacion/solicitar-otp`
* **Petición:**
  ```json
  {
    "cod_socio": "23807",
    "telefono": "71234567",
    "canal": "WHATSAPP"
  }
  ```
* **Comportamiento en `PruebaAireyu`:**  
  La pantalla de Android mostrará el banner azul `MODO ALPHA — OTP GENERADO POR BACKEND` con el código de 6 dígitos. Ingresarlo en los 6 casilleros.

#### Prueba 1.3: Creación de PIN y Login Diario
* **Objetivo:** Registrar contraseña de 6 dígitos y acceder sin pedir CI nuevamente.
* **Endpoint:** `POST /api/v1/autenticacion/establecer-pin` y posterior `POST /api/v1/autenticacion/login`.
* **Resultado Esperado:** El backend emite `access_token` (JWT ~15 min) y `refresh_token` (~7 días). La app entra directamente al Dashboard.

---

### FASE 2: Consulta de Deuda y Dashboard con Datos Reales

#### Prueba 2.1: Consulta del Saldo y Facturas Reales
* **Objetivo:** Comprobar que los montos en Bolivianos y fechas de vencimiento provengan de la base de datos real de COSMOL.
* **Endpoint:** `GET /api/v1/deuda/23807`
* **Headers:** `Authorization: Bearer <TOKEN>`
* **Resultado Esperado:**
  - `saldo_pendiente_bs`: Monto real adeudado en Bs.
  - `esta_vencido`: Se enciende en `true` (y en rojo en Flutter) si la fecha de vencimiento ya expiró.
  - `alerta_corte`: Se enciende en `true` si adeuda 2 o más facturas en mora.
  - `origen_datos`: En la 1ª consulta responde `"COSMOL_LEGACY"`.

#### Prueba 2.2: Aceleración con Caché Redis (< 5 ms)
* **Objetivo:** Evitar saturar el servidor de COSMOL con consultas repetidas.
* **Acción:** Volver a refrescar la pantalla de deuda en los siguientes 10 minutos.
* **Resultado Esperado:**  
  La respuesta es idéntica pero responde en **< 5 milisegundos**, con el campo `"origen_datos": "CACHE"`.

---

### FASE 3: Repositorio Digital y Descarga de Facturas PDF (MinIO)

#### Prueba 3.1: Descarga de Factura con Datos Fiscales Reales
* **Objetivo:** Generar y descargar el documento PDF con datos oficiales de COSMOL.
* **Endpoint:** `GET /api/v1/documentos/23807` (listar) y `GET /api/v1/documentos/{doc_id}/descargar` (descargar).
* **Resultado Esperado:**
  - El archivo se descarga en el almacenamiento del celular en formato PDF.
  - El PDF contiene el membrete institucional de COSMOL R.L., el nombre real (`MISERICORDIA AGUANTA EDDY FRANCO`), el importe en Bs y el código de control digital.
  - En la consola de MinIO (`http://localhost:9001`, usuario `cosmol_minio_admin`), el PDF queda guardado en el bucket `cosmol-docs`.

#### Prueba 3.2: Privacidad del Inquilino
* **Objetivo:** Comprobar que si el suministro se vinculó como `CONSULTA_PAGO` (inquilino), el socio solo puede descargar avisos de cobranza y se le bloquea con **HTTP 403 Forbidden** la descarga de facturas fiscales del dueño.

---

### FASE 4: Analítica de Consumo y Detección de Fugas en Vivo

#### Prueba 4.1: Consulta del Historial Real
* **Objetivo:** Conectar en vivo a `GET /socios/23807/consumos` en el servidor de COSMOL.
* **Endpoint:** `GET /api/v1/consumo/23807`
* **Headers:** `Authorization: Bearer <TOKEN>`
* **Resultado Esperado:**
  El backend extrae y normaliza las claves reales (`CONSUMO`, `MONTO`, `FECHA`) devolviendo:
  ```json
  {
    "cod_socio": "23807",
    "total_periodos": 2,
    "periodos": [
      {
        "periodo": "07/2026",
        "mes": 7,
        "mes_nombre": "Julio 2026",
        "anio": 2026,
        "consumo_m3": 14.0,
        "monto_bs": 54.22,
        "estado_lectura": "NORMAL"
      },
      {
        "periodo": "08/2026",
        "mes": 8,
        "mes_nombre": "Agosto 2026",
        "anio": 2026,
        "consumo_m3": 15.0,
        "monto_bs": 58.01,
        "estado_lectura": "NORMAL"
      }
    ],
    "estadisticas": {
      "promedio_m3": 14.5,
      "consumo_ultimo_mes_m3": 15.0,
      "consumo_atipico": false,
      "tendencia": "SUBIENDO"
    }
  }
  ```

#### Prueba 4.2: Prueba de Alerta de Fuga (+30%)
* **Objetivo:** Validar la detección preventiva de fugas.
* **Criterio:** Si el último consumo supera en un 30% o más el promedio histórico, el payload activa:
  - `"consumo_atipico": true`
  - `"mensaje_alerta": "Detectamos un consumo superior a su promedio habitual. Le sugerimos revisar sus instalaciones internas para descartar fugas de agua no visibles."`

---

## 5. Tabla de Registro de Resultados de Prueba (Certificación en Vivo)

| ID | Fase Evaluada | Socio Probado | Acción Realizada | Resultado Esperado | Resultado en Pantalla | ¿Aprobado? (Sí/No) |
| :---: | :--- | :---: | :--- | :--- | :--- | :---: |
| **P-01** | Fase 1 - Onboarding | `23807` | Ingreso de Código `23807` + CI `6259185` (vía `POST /socios/validar`) | Muestra nombre oficial de COSMOL | Muestra `MISERICORDIA AGUANTA EDDY FRANCO` | **[x] Sí** |
| **P-02** | Fase 1 - OTP y PIN | `23807` | Verificación de código 6 dígitos (Redis) | Token validado y PIN creado | Insignia verde + PIN guardado con bcrypt en Postgres | **[x] Sí** |
| **P-03** | Fase 1 - Login | `23807` | Ingreso con Código + nuevo PIN | Emisión de JWT y entrada al Dashboard | Redirección exitosa al Dashboard | **[x] Sí** |
| **P-04** | Fase 2 - Deuda | `23807` | Consulta de saldo en Bs | Facturas y vencimientos reales | Saldo e importes oficiales en Bs | [ ] |
| **P-05** | Fase 2 - Caché Redis| `23807` | Refresco inmediato de pantalla | Respuesta en < 5 ms desde Redis | Latencia < 5 ms en cache-hit | [ ] |
| **P-06** | Fase 3 - Factura PDF| `23807` | Descarga de PDF legal | PDF abre en móvil con datos de COSMOL | Descarga en almacenamiento móvil | [ ] |
| **P-07** | Fase 4 - Consumos | `23807` | Consulta de historial de m³ | Gráfica de barras con 14 y 15 m³ | Retorno de periodos Julio y Agosto 2026 | [ ] |
| **P-08** | Fase 4 - Fugas | `23807` | Cálculo automático (+30%) | Bandera `consumo_atipico` coherente | Alerta calculada según promedio | [ ] |

---

## 6. Resolución de Problemas Frecuentes en Pruebas Reales

1. **Error de conexión con COSMOL (`HTTP 503` / `ServiceUnavailableException`):**  
   - Verificar que la laptop tenga acceso a internet y que el endpoint `http://api.cosmol.com.bo/api-consultas` responda ping o peticiones HTTP.
2. **La app en Android dice `Error de red / Connection Refused`:**  
   - Si usas cable USB, asegúrate de ejecutar: `adb reverse tcp:8000 tcp:8000`.
   - Si usas Wi-Fi, asegúrate de que el celular y la laptop estén conectados a la misma red y levantar la app con `--dart-define=BACKEND_IP=TU_IP`.
3. **El socio no se encuentra (`HTTP 401 SOCIO_NOT_FOUND`):**  
   - Verificar que el carnet de identidad ingresado sea el que está registrado en el padrón oficial de COSMOL para ese número de contrato.
