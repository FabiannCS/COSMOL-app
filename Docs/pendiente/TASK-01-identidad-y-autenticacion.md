# Tarea 01: Identidad, Onboarding Dual OTP y Autenticación Multicuenta

> **Estado:** Pendiente  
> **Fase:** Fase 1 — Identidad y Autenticación  
> **Fecha de creación:** Septiembre 2026  
> **Documentos de referencia:** `AGENTS.md` (Secciones 4.1, 4.6, 10.1 y 11) y `Docs/HOJA_DE_RUTA_DESARROLLO.md`

---

## 1. Objetivo

Implementar el sistema central de identidad y autenticación para los socios de COSMOL R.L. Esto incluye el modelo de datos multicuenta, el flujo de saneamiento y enrolamiento de celular mediante OTP dual (WhatsApp Cloud API o SMS), la creación de PIN/contraseña personal para blindar la privacidad del socio, el control de sesiones únicas por dispositivo y la emisión de tokens JWT seguros.

Todo el desarrollo, ejecución de migraciones y pruebas se validará al 100% en el **entorno local con Docker**, asegurando la estabilidad de la lógica de negocio antes de considerar despliegues remotos.

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

Para maximizar el paralelismo y evitar conflictos en Git, el trabajo se divide entre **Dev 1** (Infraestructura, Modelado de Datos y Conectividad) y **Dev 2** (Lógica de Negocio, Esquemas y Endpoints):

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
* [ ] **`usuario.py` (Tabla `usuarios`):**
  * `id`: UUID (PK).
  * `telefono`: `VARCHAR(20)`, unique, index, nullable=False.
  * `password_hash`: `VARCHAR(255)`, nullable=False.
  * `esta_activo`: `BOOLEAN`, default=True.
  * `intentos_fallidos`: `INTEGER`, default=0.
  * `bloqueado_hasta`: `TIMESTAMP WITH TIME ZONE`, nullable=True.
* [ ] **`suministro.py` (Tabla `suministros`):**
  * `id`: UUID (PK).
  * `usuario_id`: UUID (FK -> `usuarios.id`, index, nullable=False).
  * `cod_socio`: `VARCHAR(20)`, index, nullable=False.
  * `alias`: `VARCHAR(50)`, default="Mi Suministro" (ej: *"Casa"*, *"Alquiler"*).
  * `rol`: `VARCHAR(20)`, nullable=False (`"TITULAR"` o `"CONSULTA_PAGO"`).
  * `es_suministro_principal`: `BOOLEAN`, default=False.
* [ ] **`dispositivo.py` (Tabla `dispositivos`):**
  * `id`: UUID (PK).
  * `usuario_id`: UUID (FK -> `usuarios.id`, index, nullable=False).
  * `device_id`: `VARCHAR(100)`, nullable=False.
  * `modelo_dispositivo`: `VARCHAR(100)`, nullable=True (ej: *"Samsung A54"*).
  * `fcm_token`: `TEXT`, nullable=True (para notificaciones push).
  * `ultimo_acceso`: `TIMESTAMP WITH TIME ZONE`.
* [ ] **`otp.py` (Tabla `otps` — registro de auditoría de envíos):**
  * `id`: UUID (PK).
  * `telefono`: `VARCHAR(20)`, index, nullable=False.
  * `canal`: `VARCHAR(20)` (`"WHATSAPP"` o `"SMS"`).
  * `proposito`: `VARCHAR(30)` (`"ONBOARDING"`, `"RECUPERACION"`, `"DESBLOQUEO"`).
  * `fue_verificado`: `BOOLEAN`, default=False.
  * `creado_en`: `TIMESTAMP WITH TIME ZONE`.

#### B. Migración Inicial de Alembic:
* [ ] Registrar los 4 modelos en `app/db/models/__init__.py`.
* [ ] Generar revisión: `alembic revision --autogenerate -m "crear_tablas_identidad_y_auth"`.
* [ ] Aplicar migración exitosa con `alembic upgrade head`.

#### C. Integración OTP y Redis en `app/integrations/` y `app/core/`:
* [ ] **`whatsapp_client.py`:** Cliente especializado heredando de `BaseApiClient` para enviar plantillas OTP mediante Meta WhatsApp Cloud API (reutilizando WABA y token de COSMOL).
* [ ] **`sms_client.py`:** Cliente stub/adaptador para Gateway SMS nacional de respaldo.
* [ ] **Gestión de OTP en Redis:**
  * Almacenamiento de clave temporal `otp:{telefono}` con código hasheado y TTL de 300 segundos (5 minutos).
  * Contador de reintentos por teléfono y rate-limit de solicitudes (máximo 3 envíos por hora).
* [ ] **Lógica de Bloqueo por Intentos:**
  * Función para registrar fallo, calcular bloqueo progresivo (1m, 5m, 15m, 30m, 1h) y registrar `bloqueado_hasta` en la base de datos y Redis.

---

### 4.2 Entregables de DEV 2: Esquemas, Lógica de Negocio y Endpoints

#### A. Esquemas Pydantic v2 en `app/schemas/`:
* [ ] **`usuario.py`:**
  * `VerificarSocioRequest`: `cod_socio: str`, `ci: str`.
  * `SolicitarOtpRequest`: `cod_socio: str`, `telefono: str`, `canal: Literal["WHATSAPP", "SMS"]`.
  * `VerificarOtpRequest`: `telefono: str`, `codigo: str`.
  * `CrearPinPasswordRequest`: `telefono: str`, `token_otp_valido: str`, `nuevo_pin: str`.
  * `LoginRequest`: `cod_socio: str`, `pin_password: str`, `device_id: str`, `modelo_dispositivo: Optional[str]`.
  * `TokenResponse`: `access_token: str`, `refresh_token: str`, `token_type: str = "bearer"`, `suministros: List[SuministroResponse]`.
  * `RenovarTokenRequest`: `refresh_token: str`, `device_id: str`.
* [ ] **`suministro.py`:**
  * `VincularSuministroRequest`: `cod_socio: str`, `ci_o_medidor: Optional[str]`, `alias: str`.
  * `SuministroResponse`: `id: UUID`, `cod_socio: str`, `alias: str`, `rol: str`, `es_suministro_principal: bool`.

#### B. Servicios de Negocio en `app/services/`:
* [ ] **`servicio_autenticacion.py`:**
  * `verificar_primer_acceso(cod_socio, ci)`: Compara contra mock/integración legada.
  * `enviar_codigo_otp(telefono, canal, proposito)`: Genera código de 6 dígitos seguro, lo guarda en Redis y despacha al cliente de mensajería.
  * `validar_codigo_otp(telefono, codigo)`: Valida contra Redis e invalida el código tras uso exitoso.
  * `registrar_credencial_inicial(telefono, nuevo_pin)`: Crea el `Usuario`, genera hash bcrypt con `security.get_password_hash` y asocia el primer `Suministro` como TITULAR.
  * `autenticar_socio(cod_socio, pin_password, device_id)`:
    * Valida bloqueos temporales por intentos fallidos.
    * Valida contraseña con `security.verify_password`.
    * En caso de éxito: limpia contador de fallos, registra/actualiza `Dispositivo` (revocando sesiones previas) y emite tokens JWT.
    * En caso de fallo: incrementa contador y aplica bloqueo progresivo si llega a 3.
  * `renovar_sesion(refresh_token, device_id)`: Valida token, confirma vigencia del dispositivo y emite nuevo access token.
* [ ] **`servicio_suministros.py`:**
  * Lógica para agregar suministros adicionales al usuario autenticado (`TITULAR` si valida CI/medidor, `CONSULTA_PAGO` si solo ingresa el código).

#### C. Endpoints API REST en `app/api/v1/autenticacion.py`:
* [ ] `POST /api/v1/autenticacion/verificar-socio` (Paso 1 Onboarding).
* [ ] `POST /api/v1/autenticacion/solicitar-otp` (Paso 2 Selección canal WhatsApp/SMS).
* [ ] `POST /api/v1/autenticacion/verificar-otp` (Paso 3 Validación del código).
* [ ] `POST /api/v1/autenticacion/establecer-pin` (Paso 4 Creación de PIN y cuenta).
* [ ] `POST /api/v1/autenticacion/login` (Login diario con cod_socio + PIN).
* [ ] `POST /api/v1/autenticacion/renovar-token` (Renovación silenciosa con refresh token).
* [ ] `POST /api/v1/autenticacion/recuperar-pin/solicitar` y `/confirmar`.
* [ ] `POST /api/v1/autenticacion/suministros/vincular` (Protegido con `Depends(get_current_user_id)`).
* [ ] Registrar el router en `app/api/v1/router.py`.

---

## 5. Criterios de Aceptación y Validación

1. **Migración Exitosa:** La base de datos local PostgreSQL tiene creadas las tablas `usuarios`, `suministros`, `dispositivos` y `otps`.
2. **Prueba de Flujo Completo de Onboarding (Postman / Pytest):**
   * Validación con `cod_socio + CI`.
   * Solicitud de OTP genera registro temporal en Redis (TTL 5 min).
   * Creación de PIN genera registro en `usuarios` con contraseña hasheada en bcrypt (nunca texto plano) y la CI queda deshabilitada como credencial.
3. **Prueba de Login y Bloqueo:**
   * Login correcto devuelve `access_token` (expira en 15 min) y `refresh_token` (expira en 7 días).
   * 3 intentos fallidos bloquean la cuenta y retornan `HTTP 403 / 429` con el tiempo de espera restante (`bloqueado_hasta`).
4. **Prueba Multicuenta:**
   * Un usuario autenticado puede vincular un segundo `cod_socio` y alternar entre modo Titular y Consulta.
5. **Cobertura de Pruebas:**
   * Pruebas automatizadas en `backend/tests/test_auth.py` ejecutándose con `docker compose exec backend-api pytest` con 100% de éxito.

---

## 6. Hito de Cierre y Validación Local (Postergación de Caddy y Servidor)
 
De acuerdo con la directiva del proyecto:
1. **Se ignora el despliegue en servidor y pruebas de Caddy por el momento:** No se realizarán configuraciones remotas ni despliegues en el servidor hasta que los módulos centrales estén maduros y justifiquen una prueba integral.
2. **Validación exclusiva en Local:**
   * La base de datos, caché y endpoints se probarán íntegramente en `http://localhost:8000`.
   * Verificación de Swagger UI en `http://localhost:8000/docs`.
   * Batería de pruebas automatizadas con `docker compose exec backend-api pytest`.
3. **Cierre de Tarea:** Una vez cumplidos todos los criterios de aceptación en local, la tarea se dará por aprobada y se moverá a `Docs/realizado/`, habilitando el inicio de la siguiente fase (Fase 2: Deuda y Dashboard).
