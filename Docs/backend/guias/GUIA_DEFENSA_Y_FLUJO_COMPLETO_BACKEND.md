# Walkthrough Técnico: Flujos de Negocio, Autenticación y Arquitectura Backend
## Plataforma Omnicanal para Asociados — COSMOL R.L.

> **Documento de Estudio y Defensa Técnica**  
> **Fecha de consolidación:** Septiembre 2026  
> **Autores / Roles:** DEV 1 (Aireyu) y DEV 2 (Eduardo) — Backend FastAPI  
> **Estado de la Suite:** 90/90 tests aprobados en Docker al 100% (cero regresiones, cero mocks)  
> **Ubicación:** `Docs/backend/guias/GUIA_DEFENSA_Y_FLUJO_COMPLETO_BACKEND.md`  
> **Fases Implementadas:** Fase 1 (Autenticación/Multicuenta), Fase 2 (Deuda), Fase 3 (Documentos PDF), Fase 4 (Consumos e Histórico)

---

## 1. Visión General de la Arquitectura (BFF)

El backend actúa como un **BFF (Backend-for-Frontend)** desarrollado en **FastAPI (Python 3.12)**. Su propósito es desacoplar a la aplicación cliente (Flutter) del sistema comercial legado de COSMOL R.L., blindando la seguridad, absorbiendo picos de tráfico con Redis y exponiendo una API REST moderna con documentación OpenAPI/Swagger automática.

```mermaid
graph TD
    Client[App Flutter Móvil / Web] -->|HTTPS :443| Caddy[Gateway Caddy Proxy]
    Caddy -->|HTTP :8000| FastAPI[backend-api FastAPI ASGI]
    
    FastAPI -->|Async ORM :5432| Postgres[(PostgreSQL 16\nUsuarios, Suministros,\nDispositivos, Documentos)]
    FastAPI -->|In-Memory Cache :6379| Redis[(Redis 7\nCaché <20ms, OTPs,\nBloqueos, Sesiones)]
    FastAPI -->|S3 API :9000| MinIO[(MinIO S3\nBucket cosmol-docs\nPDFs de Facturas)]
    
    FastAPI -.->|HTTP Async Lectura| Legado[Sistema Comercial Legado COSMOL]
    FastAPI -.->|Eventos Background Solo Escritura| Chatbot[BD ChatbotReportes Auditoría]
    FastAPI -.->|REST API| MetaAPI[WhatsApp Cloud API / SMS Gateway]
```

---

## 2. Modelo de Identidad y Base de Datos (PostgreSQL)

Para resolver el problema de que el sistema legado no cuenta con teléfonos ni contraseñas, el backend implementa una **separación estricta entre el Usuario Digital y el Suministro**:

```
 ┌────────────────────────────────┐         ┌────────────────────────────────┐
 │           USUARIOS             │         │          SUMINISTROS           │
 ├────────────────────────────────┤         ├────────────────────────────────┤
 │ id: UUID (PK)                  │1       N│ id: UUID (PK)                  │
 │ telefono: String (+591...)     ├─────────┤ usuario_id: UUID (FK)          │
 │ password_hash: String (bcrypt) │         │ cod_socio: String (Indexado)   │
 │ esta_activo: Boolean           │         │ rol: TITULAR / CONSULTA_PAGO   │
 │ intentos_fallidos: Integer     │         │ alias: String ("Mi Casa")      │
 │ bloqueado_hasta: Timestamp     │         │ es_suministro_principal: Bool  │
 └────────────────┬───────────────┘         └────────────────────────────────┘
                  │1
                  │N
 ┌────────────────┴───────────────┐
 │          DISPOSITIVOS          │
 ├────────────────────────────────┤
 │ id: UUID (PK)                  │
 │ usuario_id: UUID (FK)          │
 │ device_id: String (Hardware ID)│
 │ modelo_dispositivo: String     │
 │ ultimo_acceso: Timestamp       │
 └────────────────────────────────┘
```

---

## 3. Flujo Completo de Primer Ingreso (Onboarding de Saneamiento)

Dado que COSMOL no tiene teléfonos en su base de datos, el primer acceso es un **asistente seguro en 4 pasos**:

```mermaid
sequenceDiagram
    autonumber
    actor Socio as Socio (Flutter)
    participant API as FastAPI (:8000)
    participant Legado as Sistema Legado
    participant Redis as Redis (:6379)
    participant Meta as WhatsApp / SMS
    participant BD as PostgreSQL

    Note over Socio,API: PASO 1: Validación de Titularidad
    Socio->>API: POST /api/v1/autenticacion/verificar-socio {cod_socio, ci}
    API->>Legado: POST /socios/validar {codigo, ci}
    Legado-->>API: 200 OK {valido: true, socio: {CODIGO, NOMBRE, NROCIONIT}}
    API-->>Socio: 200 OK {cod_socio, nombre_titular}

    Note over Socio,API: PASO 2: Asociación de Celular y Canal
    Socio->>API: POST /api/v1/autenticacion/solicitar-otp {cod_socio, telefono, canal: "WHATSAPP"}
    API->>Redis: Guarda OTP 6 dígitos (TTL 5 min) clave: "otp:+591...:codigo"
    API->>Meta: Despacha código vía WhatsApp Cloud API o SMS
    API-->>Socio: 200 OK {mensaje: "Código enviado"}

    Note over Socio,API: PASO 3: Validación del OTP
    Socio->>API: POST /api/v1/autenticacion/verificar-otp {telefono, codigo: "6 dígitos"}
    API->>Redis: Valida código y lo elimina (un solo uso)
    API->>Redis: Genera token temporal criptográfico (TTL 10 min)
    API-->>Socio: 200 OK {token_otp_valido: "token_seguro..."}

    Note over Socio,API: PASO 4: Blindaje (Creación de PIN)
    Socio->>API: POST /api/v1/autenticacion/establecer-pin {telefono, token_otp_valido, nuevo_pin}
    API->>API: Hashea PIN con bcrypt (salt seguro)
    API->>BD: Crea Usuario y Suministro (Titular) en PostgreSQL
    API-->>Socio: 201 Created (CI invalidada como clave para siempre)
```

---

## 4. Flujo de Login Diario y Emisión de Tokens JWT

Cuando el socio ya completó el onboarding, su acceso habitual es rápido y seguro:

### Endpoint: `POST /api/v1/autenticacion/login`
**Payload de Entrada:**
```json
{
  "cod_socio": "23807",
  "pin_password": "mi_pin_seguro",
  "device_id": "uuid-hardware-telefono",
  "modelo_dispositivo": "Samsung Galaxy A54"
}
```

### Ejecución Interna en el Backend:
1. **Comprobación de Bloqueo en Redis:**
   Verifica la clave `bloqueado:{cod_socio}`. Si existe, lanza `403 Forbidden` (`ACCOUNT_LOCKED`) con los segundos restantes.
2. **Localización de Credenciales:**
   Busca el `cod_socio` en la tabla `suministros` y carga al `Usuario` asociado.
3. **Verificación Bcrypt:**
   Ejecuta `bcrypt.checkpw(pin_password, password_hash)`.
   * *Si es erróneo:* Incrementa `intentos_fallidos:{cod_socio}` en Redis. Al llegar a 3 fallos consecutivos, bloquea la cuenta (1 min -> 5 min -> 15 min -> 1 hora) y retorna `401/403`.
   * *Si es correcto:* Limpia contadores de fallos y bloqueos en Redis.
4. **Control de Sesión Única por Hardware:**
   Actualiza la tabla `dispositivos` y guarda en Redis:  
   `SET sesion_activa:{user_id} "{device_id}"`.  
   *(Si el socio inicia sesión en otro teléfono, la sesión anterior queda revocada al renovar token).*
5. **Emisión de Tokens Criptográficos (JWT):**
   * **`access_token` (Vida corta: 15 minutos):** Firmado con clave secreta y algoritmo HS256. Lleva en el payload el `sub` (User ID), `cod_socio`, `device_id` y `type: "access"`.
   * **`refresh_token` (Vida larga: 7 días):** Token de renovación silenciosa con `type: "refresh"`.
   * **Respuesta:** Objeto `TokenResponse` con tokens y lista de suministros vinculados.

---

## 5. Protección de Endpoints y Renovación Silenciosa

### ¿Cómo se protegen los endpoints?
Cualquier endpoint privado (deuda, documentos, consumos) requiere la dependencia FastAPI `Depends(get_token_payload)` o `Depends(get_current_user_id)`:
```http
Authorization: Bearer <access_token>
```
1. Decodifica el token con `jwt.decode()`.
2. Verifica la firma criptográfica (rechaza si fue alterado con `401 AUTH_TOKEN_INVALID`).
3. Verifica la expiración (`exp`). Si pasaron más de 15 minutos, rechaza con `401 AUTH_TOKEN_EXPIRED`.
4. Extrae el `user_id` del payload sin consultar la base de datos (Stateless).

### Renovación Silenciosa (`POST /api/v1/autenticacion/renovar-token`):
Cuando el `access_token` expira a los 15 minutos:
1. Flutter intercepta el 401 y envía `refresh_token` + `device_id`.
2. El backend verifica en Redis:
   ```python
   device_activo = await redis.get(f"sesion_activa:{user_id}")
   if device_activo != device_id:
       raise UnauthorizedException("Sesión cerrada: se inició sesión en otro dispositivo.")
   ```
3. Si el dispositivo coincide, emite un nuevo `access_token` de 15 minutos sin pedir credenciales al usuario.

---

## 6. Consulta de Deuda y Caching Redis (Fase 2)

### Endpoint: `GET /api/v1/deuda/{cod_socio}`
* **Estrategia Redis (<20 ms):**  
  Clave: `deuda:{cod_socio}` con TTL de 10 minutos (600 segundos).
  * **Cache-Hit:** Si la clave existe en Redis, responde en **< 20 milisegundos**.
  * **Cache-Miss:** Consulta asíncrona (`httpx`) al endpoint `GET /socios/{codigo}/deudas` de COSMOL, normaliza los datos en moneda local (**Bs**), guarda en Redis y responde.
* **Semaforización:**
  * Si la fecha límite expiró: `esta_vencido = True` (Flutter renderiza en rojo).
  * Si adeuda $\ge 2$ facturas: `alerta_corte = True` (banner preventivo de suspensión).
* **Invalidación Forzada:** `POST /api/v1/deuda/{cod_socio}/invalidar-cache`.

---

## 7. Repositorio Digital de Documentos y Streaming PDF (Fase 3)

### Endpoint: `GET /api/v1/documentos/{doc_id}/descargar`
* **Almacenamiento de Objetos en MinIO (S3):** Bucket privado `cosmol-docs`.
* **Motor Generador Vectorial (`generador_pdf.py` con ReportLab):**  
  Si el PDF no existe en MinIO, lo dibuja on-demand con membrete institucional de COSMOL R.L., NIT, código SIAT, detalle en Bs y códigos de barra.
* **Descarga en Streaming Binario:**  
  Usa `StreamingResponse` con `media_type="application/pdf"`. No satura la memoria RAM del servidor porque transmite el archivo por fragmentos.
* **Privacidad Multicuenta:**
  * **TITULAR:** Puede ver y descargar Facturas con valor legal, Avisos de Cobranza y Avisos de Corte.
  * **INQUILINO (`CONSULTA_PAGO`):** **Solo puede ver y descargar Avisos de Cobranza**. Si intenta acceder a facturas oficiales o avisos de corte, el backend responde con **`403 Forbidden` (`DOCUMENT_ACCESS_DENIED`)**.
* **Auditoría:** Cada descarga despacha un evento `DOCUMENT_DOWNLOADED` en segundo plano hacia `ChatbotReportes`.

---

## 8. Analítica e Historial de Consumo Mensual (Fase 4)

### Endpoint: `GET /api/v1/consumo/{cod_socio}`

```mermaid
sequenceDiagram
    autonumber
    actor Socio as Socio (Flutter fl_chart)
    participant API as FastAPI (:8000)
    participant Redis as Redis (:6379)
    participant BD as PostgreSQL
    participant Legado as Informix COSMOL R.L.

    Socio->>API: GET /api/v1/consumo/{cod_socio} [Bearer JWT]
    API->>BD: Valida que el cod_socio pertenezca al usuario autenticado
    alt Suministro Ajeno
        API-->>Socio: 403 Forbidden (FORBIDDEN_SUPPLY_ACCESS)
    end
    
    API->>Redis: GET consumo:{cod_socio}
    alt Cache-Hit (< 20 ms)
        Redis-->>API: JSON con historial y estadísticas cacheadas
        API-->>Socio: 200 OK {periodos: 12 meses, estadisticas, origen: "CACHE"}
    else Cache-Miss
        API->>Legado: GET /socios/{cod_socio}/historial-facturas
        Legado-->>API: 200 OK con array de facturas (CONSUMO en m³, MONTO en Bs)
        API->>API: Extrae 12 meses, normaliza fechas MM/YYYY y calcula estadísticas
        API->>API: ¿Consumo último mes >= 1.30 * Promedio? -> consumo_atipico = True
        API->>Redis: SET consumo:{cod_socio} (TTL 900s / 15 min)
        API-->>Socio: 200 OK {periodos: 12 meses, estadisticas, origen: "COSMOL_LEGACY"}
    end
```

### Reglas de Negocio Implementadas:
1. **Consumo de Datos Reales en Vivo:**
   Se conecta directamente a `GET /socios/{codigo}/historial-facturas` en el servidor oficial de COSMOL. Cada periodo entrega el atributo `"CONSUMO"` ($m^3$) y `"MONTO"` (Bs).
2. **Cálculo de Consumo Atípico / Alerta de Fuga:**
   El backend computa el promedio de los 12 meses. Si el último mes supera en un 30% o más dicho promedio:
   ```json
   {
     "consumo_atipico": true,
     "mensaje_alerta": "Detectamos un consumo superior a su promedio habitual. Le sugerimos revisar sus instalaciones internas para descartar fugas de agua no visibles."
   }
   ```
3. **Privacidad Multicuenta:**
   Si el socio ingresa con rol `CONSULTA_PAGO` (inquilino), el número de medidor y lecturas confidenciales se devuelven como `null`/enmascaradas, permitiendo únicamente visualizar el volumen en $m^3$ y el importe en Bs para el control de gastos del hogar.
4. **Invalidación de Caché:**  
   `POST /api/v1/consumo/{cod_socio}/invalidar-cache` elimina la clave de Redis para forzar una recarga fresca desde Informix en la siguiente petición.

---

## 9. Matriz Consolidada de Endpoints REST del Backend

| Método | Endpoint | Módulo / Fase | Rol Mínimo | Descripción |
| :---: | :--- | :--- | :---: | :--- |
| `GET` | `/api/v1/health` | Infraestructura | Público | Chequeo de salud de FastAPI, PostgreSQL y Redis |
| `POST`| `/api/v1/autenticacion/verificar-socio` | Fase 1 | Público | Valida código y CI en Informix (`/socios/validar`) |
| `POST`| `/api/v1/autenticacion/solicitar-otp` | Fase 1 | Público | Envía código de 6 dígitos por WhatsApp o SMS |
| `POST`| `/api/v1/autenticacion/verificar-otp` | Fase 1 | Público | Valida OTP y emite token temporal (TTL 10 min) |
| `POST`| `/api/v1/autenticacion/establecer-pin` | Fase 1 | Token OTP | Guarda PIN con bcrypt y crea usuario/suministro |
| `POST`| `/api/v1/autenticacion/login` | Fase 1 | Público | Login con PIN, rate-limit y control de sesión única |
| `POST`| `/api/v1/autenticacion/renovar-token` | Fase 1 | Bearer Ref. | Renueva access token si coincide el hardware ID |
| `GET` | `/api/v1/autenticacion/suministros` | Fase 1 | Autenticado | Lista suministros vinculados al socio |
| `POST`| `/api/v1/autenticacion/suministros/vincular`| Fase 1 | Autenticado | Vincula suministro como TITULAR o CONSULTA_PAGO |
| `GET` | `/api/v1/deuda/{cod_socio}` | Fase 2 | Autenticado | Saldo, vencimientos y avisos (<20 ms con Redis) |
| `POST`| `/api/v1/deuda/{cod_socio}/invalidar-cache`| Fase 2 | Autenticado | Invalida clave Redis de deuda |
| `GET` | `/api/v1/documentos/{cod_socio}` | Fase 3 | Autenticado | Lista facturas y avisos disponibles |
| `GET` | `/api/v1/documentos/{doc_id}/descargar`| Fase 3 | Autenticado | Streaming binario de PDF (bloqueo 403 a inquilinos) |
| `GET` | `/api/v1/consumo/{cod_socio}` | Fase 4 | Autenticado | 12 meses históricos en m³ y Bs con alerta de fuga |
| `POST`| `/api/v1/consumo/{cod_socio}/invalidar-cache`| Fase 4 | Autenticado | Invalida clave Redis de consumo |
