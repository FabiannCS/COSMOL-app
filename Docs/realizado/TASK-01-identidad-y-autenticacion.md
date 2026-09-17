# Tarea 01: Identidad, Onboarding Dual OTP y Autenticación Multicuenta

> **Estado:** COMPLETADO (100% Empalme Dev 1 + Dev 2)  
> **Fase:** Fase 1 — Identidad y Autenticación  
> **Fecha de creación:** Septiembre 2026  
> **Fecha de finalización y empalme:** Septiembre 2026  
> **Documentos de referencia:** `AGENTS.md` (Secciones 4.1, 4.6, 10.1 y 11) y `Docs/HOJA_DE_RUTA_DESARROLLO.md`  
> **Evidencia:** 29/29 tests unitarios y de integración pasando al 100% en Docker (`backend-api`)

---

## 1. Objetivo

Implementar el sistema central de identidad y autenticación para los socios de COSMOL R.L. Esto incluye el modelo de datos multicuenta, el flujo de saneamiento y enrolamiento de celular mediante OTP dual (WhatsApp Cloud API o SMS), la creación de PIN/contraseña personal para blindar la privacidad del socio, el control de sesiones únicas por dispositivo y la emisión de tokens JWT seguros.

Todo el desarrollo, ejecución de migraciones y pruebas se validó al 100% en el **entorno local con Docker**, asegurando la estabilidad de la lógica de negocio antes de considerar despliegues remotos.

---

## 2. Reglas de Negocio y Decisiones Aprobadas (AGENTS.md)

1. **Separación de Identidad:**
   * **Usuario Digital:** Persona que opera la app, identificada unívocamente por su número de celular verificado.
   * **Suministro / Código de Socio:** Contrato de servicio en COSMOL (`cod_socio`). Un mismo Usuario Digital puede administrar múltiples suministros (*Multicuenta*).
2. **Flujo Híbrido de Primer Acceso (Onboarding):**
   * El socio ingresa por primera vez con `cod_socio + CI`.
   * El sistema valida la coincidencia con el sistema legado y exige asociar un número de teléfono celular.
   * El socio elige el canal OTP: **WhatsApp Cloud API** (canal prioritario/económico) o **SMS tradicional** (canal alternativo).
   * Verificado el código de 6 dígitos (TTL 5 min en Redis), el socio crea una **Contraseña o PIN personal**.
   * A partir de ese momento, la CI queda **permanentemente invalidada** como contraseña para evitar que terceros con una factura física vulneren la cuenta.
3. **Login Diario Habitual:**
   * Acceso con `cod_socio + Contraseña/PIN personal` o Biometría en la app.
   * Emisión de JWT: **Access Token (15 min)** + **Refresh Token (7 días)**.
4. **Política de Bloqueo Progresivo:**
   * **3 intentos fallidos consecutivos** bloquean la cuenta temporalmente (1 min → 5 min → 15 min → 30 min → 1 hora).
   * Desbloqueo inmediato completando verificación OTP al celular registrado.
5. **Sesión Única por Dispositivo (Estilo WhatsApp):**
   * Al iniciar sesión en un nuevo `device_id`, se revoca la sesión previa activa en el equipo anterior.
6. **Multicuenta y Roles por Suministro:**
   * **Modo Titular:** Requiere CI o número de medidor del titular. Permite ver facturas oficiales con valor legal, históricos confidenciales y avisos de corte.
   * **Modo Consulta y Pago (Inquilino / Tercero):** Solo requiere el `cod_socio`. Permite consultar deuda y pagar con QR, pero **enmascara datos sensibles** del titular.

---

## 3. Asignación y División de Trabajo

Para maximizar el paralelismo y evitar conflictos en Git, el trabajo se dividió entre **Dev 1** (Infraestructura, Modelado de Datos y Conectividad) y **Dev 2** (Lógica de Negocio, Esquemas y Endpoints):

```
┌─────────────────────────────────────────────────────────────┐
│                 DIVISIÓN MODULAR DE TRABAJO                 │
├──────────────────────────────┬──────────────────────────────┤
│     DEV 1 (Líder / Core)     │     DEV 2 (Backend Dev)      │
├──────────────────────────────┼──────────────────────────────┤
│ • Modelos ORM (SQLAlchemy)   │ • Esquemas Pydantic v2       │
│ • Migraciones Alembic        │ • Servicios de Negocio       │
│ • Cliente WhatsApp/SMS (OTP) │ • Endpoints API REST (/v1)   │
│ • Rate Limiting en Redis     │ • Pruebas Unitarias Endpoint │
└──────────────────────────────┴──────────────────────────────┘
```

---

## 4. Detalle de Entregables Técnicos

### 4.1 Entregables de DEV 1: Capa de Datos, Seguridad y Mensajería

#### A. Modelos ORM en `app/db/models/` (heredando de `BaseModel`):
* [x] **`usuario.py` (Tabla `usuarios`):**
  * `id`: UUID (PK).
  * `telefono`: `VARCHAR(20)`, unique, index, nullable=False.
  * `password_hash`: `VARCHAR(255)`, nullable=False.
  * `esta_activo`: `BOOLEAN`, default=True.
  * `intentos_fallidos`: `INTEGER`, default=0.
  * `bloqueado_hasta`: `TIMESTAMP WITH TIME ZONE`, nullable=True.
* [x] **`suministro.py` (Tabla `suministros`):**
  * `id`: UUID (PK).
  * `usuario_id`: UUID (FK -> `usuarios.id`, index, nullable=False).
  * `cod_socio`: `VARCHAR(20)`, index, nullable=False.
  * `alias`: `VARCHAR(50)`, default="Mi Suministro" (ej: *"Casa"*, *"Alquiler"*).
  * `rol`: `VARCHAR(20)`, nullable=False (`"TITULAR"` o `"CONSULTA_PAGO"`).
  * `es_suministro_principal`: `BOOLEAN`, default=False.
* [x] **`dispositivo.py` (Tabla `dispositivos`):**
  * `id`: UUID (PK).
  * `usuario_id`: UUID (FK -> `usuarios.id`, index, nullable=False).
  * `device_id`: `VARCHAR(100)`, nullable=False.
  * `modelo_dispositivo`: `VARCHAR(100)`, nullable=True (ej: *"Samsung A54"*).
  * `fcm_token`: `TEXT`, nullable=True (para notificaciones push).
  * `ultimo_acceso`: `TIMESTAMP WITH TIME ZONE`.
* [x] **`otp.py` (Tabla `otps` — registro de auditoría de envíos):**
  * `id`: UUID (PK).
  * `telefono`: `VARCHAR(20)`, index, nullable=False.
  * `canal`: `VARCHAR(20)` (`"WHATSAPP"` o `"SMS"`).
  * `proposito`: `VARCHAR(30)` (`"ONBOARDING"`, `"RECUPERACION"`, `"DESBLOQUEO"`).
  * `fue_verificado`: `BOOLEAN`, default=False.
  * `created_at`: `TIMESTAMP WITH TIME ZONE` (heredado de `BaseModel`).

#### B. Migración Inicial de Alembic:
* [x] Registrar los 4 modelos en `app/db/models/__init__.py`.
* [x] Generar revisión: `alembic revision --autogenerate -m "crear_tablas_identidad_y_auth"`.
* [x] Aplicar migración exitosa con `alembic upgrade head`.

#### C. Integración OTP y Redis en `app/integrations/` y `app/core/`:
* [x] **`whatsapp_client.py`:** Cliente especializado heredando de `BaseApiClient` para enviar plantillas OTP mediante Meta WhatsApp Cloud API (reutilizando WABA y token de COSMOL, con soporte de simulación mock).
* [x] **`sms_client.py`:** Cliente stub/adaptador para Gateway SMS nacional de respaldo.
* [x] **Gestión de OTP en Redis (`servicio_otp.py`):**
  * Almacenamiento de clave temporal `otp:{telefono}` con código y TTL de 300 segundos (5 minutos).
  * Contador de reintentos por teléfono y rate-limit de solicitudes (máximo 3 envíos por hora).
  * Principio de un solo uso (*consume-once*) con autodestrucción tras verificación exitosa o 3 fallos.
* [x] **Lógica de Bloqueo por Intentos (`servicio_bloqueo.py`):**
  * Función para registrar fallo, calcular bloqueo progresivo (3=1m, 4=5m, 5=15m, 6=30m, 7+=1h) y registrar `bloqueo:{identificador}` en Redis.

---

### 4.2 Entregables de DEV 2: Esquemas, Lógica de Negocio y Endpoints

#### A. Esquemas Pydantic v2 en `app/schemas/`:
* [x] **`usuario.py`:**
  * `VerificarSocioRequest`: `cod_socio: str`, `ci: str`.
  * `SolicitarOtpRequest`: `cod_socio: str`, `telefono: str`, `canal: Literal["WHATSAPP", "SMS"]`.
  * `VerificarOtpRequest`: `telefono: str`, `codigo: str`.
  * `CrearPinPasswordRequest`: `telefono: str`, `token_otp_valido: str`, `nuevo_pin: str`.
  * `LoginRequest`: `cod_socio: str`, `pin_password: str`, `device_id: str`, `modelo_dispositivo: Optional[str]`.
  * `TokenResponse`: `access_token: str`, `refresh_token: str`, `token_type: str = "bearer"`, `suministros: List[SuministroResponse]`.
  * `RenovarTokenRequest`: `refresh_token: str`, `device_id: str`.
* [x] **`suministro.py`:**
  * `VincularSuministroRequest`: `cod_socio: str`, `ci_o_medidor: Optional[str]`, `alias: str`.
  * `SuministroResponse`: `id: UUID`, `cod_socio: str`, `alias: str`, `rol: str`, `es_suministro_principal: bool`.

#### B. Servicios de Negocio en `app/services/`:
* [x] **`servicio_autenticacion.py`:**
  * `verificar_primer_acceso(cod_socio, ci)`: Valida en PostgreSQL si ya existe cuenta activa y compara contra registros comerciales oficiales de COSMOL.
  * `solicitar_otp(cod_socio, telefono, canal)`: Valida límite de 3 solicitudes/hora en Redis, genera OTP de 6 dígitos seguro y despacha vía Meta WhatsApp Cloud API o SMS Gateway.
  * `verificar_otp(telefono, codigo)`: Valida contra Redis, invalida el OTP de un solo uso y emite token temporal criptográfico para creación de PIN.
  * `establecer_pin(telefono, token_otp_valido, nuevo_pin)`: Crea el `Usuario` y su primer `Suministro` (TITULAR) en PostgreSQL, persistiendo la contraseña hasheada en bcrypt.
  * `autenticar_socio(cod_socio, pin_password, device_id)`:
    * Valida bloqueos activos en Redis.
    * Valida contraseña hasheada con bcrypt.
    * En caso de éxito: limpia contadores de fallos, registra/actualiza `Dispositivo` en PostgreSQL, impone sesión única por hardware y emite JWT (Access 15m, Refresh 7d).
    * En caso de fallo: incrementa contador y aplica bloqueo progresivo automático al llegar a 3 fallos consecutivos.
  * `renovar_token(refresh_token, device_id)`: Valida token, confirma vigencia del dispositivo y emite nuevo access token.
* [x] **`servicio_suministros.py`:**
  * `vincular_suministro`: Agrega suministros adicionales al usuario autenticado persistiendo en PostgreSQL (`TITULAR` si valida CI/medidor, `CONSULTA_PAGO` si solo ingresa el código).
  * `listar_suministros`: Retorna todos los contratos asociados directamente desde la base de datos PostgreSQL.

#### C. Endpoints API REST en `app/api/v1/autenticacion.py`:
* [x] `POST /api/v1/autenticacion/verificar-socio` (Paso 1 Onboarding).
* [x] `POST /api/v1/autenticacion/solicitar-otp` (Paso 2 Selección canal WhatsApp/SMS).
* [x] `POST /api/v1/autenticacion/verificar-otp` (Paso 3 Validación del código).
* [x] `POST /api/v1/autenticacion/establecer-pin` (Paso 4 Creación de PIN y cuenta).
* [x] `POST /api/v1/autenticacion/login` (Login diario con cod_socio + PIN).
* [x] `POST /api/v1/autenticacion/renovar-token` (Renovación silenciosa con refresh token).
* [x] `POST /api/v1/autenticacion/suministros/vincular` (Protegido con `Depends(get_token_payload)` y `db: AsyncSession`).
* [x] `GET /api/v1/autenticacion/suministros` (Protegido con `Depends(get_token_payload)` y `db: AsyncSession`).
* [x] Registrar el router en `app/api/v1/router.py`.

---

## 5. Criterios de Aceptación y Validación (100% CUMPLIDOS)

1. [x] **Migración Exitosa:** La base de datos local PostgreSQL tiene creadas las tablas `usuarios`, `suministros`, `dispositivos` y `otps`.
2. [x] **Prueba de Flujo Completo de Onboarding (Postman / Pytest):**
   * Validación con `cod_socio + CI`.
   * Solicitud de OTP genera registro temporal en Redis (TTL 5 min).
   * Creación de PIN genera registro en `usuarios` con contraseña hasheada en bcrypt (nunca texto plano) y la CI queda deshabilitada como credencial.
3. [x] **Prueba de Login y Bloqueo:**
   * Login correcto devuelve `access_token` (expira en 15 min) y `refresh_token` (expira en 7 días).
   * 3 intentos fallidos bloquean la cuenta y retornan `HTTP 403 / 429` con el tiempo de espera restante (`bloqueado_hasta`).
4. [x] **Prueba Multicuenta:**
   * Un usuario autenticado puede vincular un segundo `cod_socio` y alternar entre modo Titular y Consulta.
5. [x] **Cobertura de Pruebas:**
   * 29 pruebas automatizadas ejecutándose con `docker compose exec backend-api pytest -v` con 100% de éxito.

---

## 6. Bitácora de Validación y Empalme 100%

### Resumen del Empalme Técnico:
- **Inyección de Dependencia `AsyncSession`:** Los 8 endpoints de `app/api/v1/autenticacion.py` ahora reciben la sesión asíncrona de PostgreSQL (`db: AsyncSession = Depends(get_db)`) y se la transmiten a `ServicioAutenticacion` y `ServicioSuministros`.
- **Persistencia Física en PostgreSQL:** Los flujos de registro de usuarios, creación de PIN, auditoría de dispositivos y vinculación multicuenta escriben directamente en las tablas físicas `usuarios`, `suministros` y `dispositivos` mediante SQLAlchemy 2.0.
- **Canales de Mensajería Reales/Mock:** `solicitar_otp` activa la integración con `whatsapp_client.py` (Meta Cloud API con número boliviano normalizado) y `sms_client.py` (Gateway SMS).
- **Seguridad en Redis:** `servicio_bloqueo` y `servicio_otp` administran bloqueos progresivos tras 3 intentos fallidos, tasa máxima de 3 envíos/hora y caducidad de códigos OTP a 300 segundos.
- **Swagger / OpenAPI:** Todos los endpoints están documentados y disponibles en `http://localhost:8000/docs` para consumo inmediato por el desarrollador frontend.
