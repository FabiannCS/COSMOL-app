# Entregables DEV 2: Identidad, Onboarding Dual OTP y Autenticación Multicuenta

> **Fase:** Fase 1 — Identidad y Autenticación  
> **Rol responsable:** DEV 2 (Backend Dev)  
> **Fecha de conclusión:** Septiembre 2026  
> **Documento de referencia:** `Docs/pendiente/TASK-01-identidad-y-autenticacion.md` y `AGENTS.md` (Secciones 4.1, 4.6, 10.1 y 11)  
> **Estado:** Completado y validado en local (17/17 tests pasando en Docker)

---

## 1. Resumen Ejecutivo para el Equipo

Este documento detalla la implementación realizada por **DEV 2** en la API REST de COSMOL R.L. Se construyó de forma 100% desacoplada toda la capa de validación de datos (Pydantic v2), la lógica de negocio (Servicios), la integración con Redis (gestión de OTPs, rate-limiting y bloqueo de cuentas), y los endpoints públicos y protegidos expuestos para el cliente Frontend (Flutter).

Toda la lógica fue probada y verificada dentro del contenedor Docker `cosmol-backend-api` con una cobertura del 100% de éxito.

---

## 2. Detalle de Archivos Creados y Modificados

### 2.1 Esquemas Pydantic v2 (`backend/app/schemas/`)

* [x] **`suministro.py`**:
  * `VincularSuministroRequest`: Esquema de entrada para que un socio agregue suministros a su cuenta. Soporta campo opcional `ci_o_medidor` para elevar privilegios al rol `TITULAR` o asignar rol `CONSULTA_PAGO` si solo se envía el `cod_socio`.
  * `SuministroResponse`: DTO serializado con `id`, `cod_socio`, `alias`, `rol` y `es_suministro_principal`.
* [x] **`usuario.py`**:
  * `VerificarSocioRequest`: Validador de entrada con limpieza automática de espacios en blanco (`cod_socio`, `ci`).
  * `SolicitarOtpRequest`: Validador con normalización automática de celulares al formato nacional boliviano (ej. `71029384` -> `+59171029384`) y restricción de canal a `WHATSAPP` o `SMS`.
  * `VerificarOtpRequest`: Validador que exige de forma estricta un código de **exactamente 6 dígitos numéricos**.
  * `CrearPinPasswordRequest`: Validador de longitud de PIN (mínimo 4 caracteres) y recepción del `token_otp_valido`.
  * `LoginRequest`: Validador para login diario (`cod_socio`, `pin_password`, `device_id`, `modelo_dispositivo`).
  * `TokenResponse`: Esquema de salida con `access_token` (15 min), `refresh_token` (7 días), `token_type: "bearer"` y lista de suministros asociados.
  * `RenovarTokenRequest`: Esquema para refresh silencioso desde la app con validación de hardware.
* [x] **`__init__.py`**: Re-exportación limpia de todos los esquemas para imports directos (`from app.schemas import ...`).

---

### 2.2 Servicios de Negocio (`backend/app/services/`)

* [x] **`servicio_autenticacion.py`**:
  * `verificar_primer_acceso(cod_socio, ci)`: Compara contra los registros del sistema comercial legado de COSMOL (`SOCIOS_MOCK_LEGADO`). Si ya existe cuenta con PIN, rechaza con `ACCOUNT_ALREADY_EXISTS`.
  * `solicitar_otp(cod_socio, telefono, canal)`:
    * **Rate Limiting Preventivo en Redis:** Clave `rate_otp:{telefono}` limitada a un máximo de 3 solicitudes por hora.
    * **Generación segura:** Código de 6 dígitos numéricos criptográficamente seguro con `secrets.randbelow`.
    * **Persistencia en Redis:** Clave `otp:{telefono}` con TTL estricto de 300 segundos (5 minutos).
    * **Enmascaramiento de celular:** Retorna el teléfono ofuscado (ej. `+591 7***9384`) para seguridad en la app móvil.
  * `verificar_otp(telefono, codigo)`:
    * Comprueba el código contra Redis. Al coincidir, **invalida el código de inmediato (un solo uso)** para prevenir ataques de repetición.
    * Emite un pase temporal criptográfico `token_otp_valido` con TTL de 10 minutos para autorizar el paso 4.
  * `establecer_pin(telefono, token_otp_valido, nuevo_pin)`:
    * Valida la legitimidad del pase temporal.
    * Genera hash unidireccional seguro mediante `bcrypt` (`security.get_password_hash`).
    * Registra al usuario y crea su primer suministro como `TITULAR`. **A partir de este momento, la CI queda invalidada permanentemente como credencial.**
  * `autenticar_socio(cod_socio, pin_password, device_id, modelo_dispositivo)`:
    * **Control de Bloqueo Progresivo en Redis:** Si la cuenta acumula **3 intentos fallidos consecutivos**, se bloquea temporalmente aplicando la escala progresiva (1 min, 5 min, 15 min, 1 hora) con código de error `ACCOUNT_LOCKED`.
    * **Verificación de credenciales:** Valida hash bcrypt con `security.verify_password`.
    * **Sesión Única por Hardware (Estilo WhatsApp):** Registra el `device_id` activo en Redis (`sesion_activa:{user_id}`). Inicios de sesión en nuevos dispositivos invalidan las peticiones del anterior.
    * **Emisión JWT:** Retorna Access Token firmado (15 min) y Refresh Token (7 días).
  * `renovar_token(refresh_token, device_id)`: Decodifica JWT, comprueba vigencia del dispositivo y emite un nuevo Access Token.
* [x] **`servicio_suministros.py`**:
  * `vincular_suministro(cod_socio_principal, datos)`: Agrega contratos secundarios. Si coincide el CI o número de medidor con el registro comercial, otorga rol `TITULAR`; de lo contrario, asigna `CONSULTA_PAGO` (modo inquilino donde datos sensibles del titular se enmascaran).
  * `listar_suministros(cod_socio_principal)`: Retorna todos los contratos asociados para el selector multicuenta de Flutter.
* [x] **`__init__.py`**: Exportación centralizada de `ServicioAutenticacion` y `ServicioSuministros`.

---

### 2.3 Endpoints REST de la API (`backend/app/api/v1/`)

* [x] **`autenticacion.py`**:
  1. `POST /api/v1/autenticacion/verificar-socio`: Paso 1 del onboarding.
  2. `POST /api/v1/autenticacion/solicitar-otp`: Paso 2 con selección de canal WhatsApp / SMS.
  3. `POST /api/v1/autenticacion/verificar-otp`: Paso 3 de validación del código de 6 dígitos.
  4. `POST /api/v1/autenticacion/establecer-pin`: Paso 4 de creación de PIN personal.
  5. `POST /api/v1/autenticacion/login`: Login diario habitual con control de 3 intentos fallidos.
  6. `POST /api/v1/autenticacion/renovar-token`: Renovación de Access Token en segundo plano.
  7. `POST /api/v1/autenticacion/suministros/vincular`: Vinculación multicuenta (requiere `Authorization: Bearer <token>`).
  8. `GET /api/v1/autenticacion/suministros`: Listado de contratos vinculados (requiere `Authorization: Bearer <token>`).
* [x] **`router.py`**: Router registrado bajo el prefijo `/autenticacion` con el tag OpenAPI `"Identidad, Onboarding OTP y Multicuenta"`.
* [x] Documentación interactiva Swagger UI disponible y verificada en: **`http://localhost:8000/docs`**.

---

### 2.4 Batería de Pruebas Automatizadas (`backend/tests/`)

* [x] **`test_auth_schemas.py` (7 tests):** Validación de limpieza de espacios, normalización de celulares bolivianos, longitud de PIN, formato estricto de 6 dígitos para OTP y estructuras de login.
* [x] **`test_auth_service.py` (3 tests):** Pruebas de integración del flujo de servicios con Redis vivo en Docker, comprobación de la política de bloqueo progresivo tras 3 fallos y vinculación multicuenta.
* [x] **`test_auth_endpoints.py` (3 tests):** Pruebas HTTP end-to-end con `httpx.AsyncClient` sobre el onboarding completo, control de credenciales erróneas y endpoints protegidos por Bearer JWT.
* [x] **`conftest.py`**: Fixture `redis_override` con `autouse=True` que provee clientes Redis independientes por event loop de pytest, eliminando fugas de conexiones y garantizando aislamiento total entre pruebas.

---

## 3. Instrucciones de Integración para DEV 1 (Modelos ORM)

Para cuando **DEV 1** tenga listas las tablas en SQLAlchemy (`Usuario`, `Suministro`, `Dispositivo` y `Otp`) y sus migraciones de Alembic:

1. **Persistencia en Base de Datos:**
   En `app/services/servicio_autenticacion.py` y `servicio_suministros.py`, los métodos actualmente utilizan la estructura temporal en memoria `USUARIOS_REGISTRADOS_DB` como puente para desacoplar el desarrollo.
2. **Conexión directa:**
   Basta con inyectar la sesión asíncrona de base de datos `db: AsyncSession = Depends(get_db)` y sustituir las lecturas/escrituras de `USUARIOS_REGISTRADOS_DB` por las consultas SQLAlchemy:
   * `select(Usuario).where(Usuario.telefono == ...)`
   * `session.add(nuevo_usuario)`
   * `session.commit()`
3. **Cero impacto en el Frontend:**
   Los contratos de la API (Esquemas Pydantic, nombres de campos, códigos de error HTTP y endpoints en Swagger) ya están 100% estables y definitivos. El desarrollador Frontend ya puede conectarse y consumir la API sin esperar cambios futuros de estructura.

---

## 4. Evidencia de Validación en Local

Ejecución de la suite completa de pruebas:
```bash
docker compose exec backend-api pytest
```

**Resultado obtenido:**
```text
tests/test_auth_endpoints.py ...                                         [ 17%]
tests/test_auth_schemas.py .......                                       [ 58%]
tests/test_auth_service.py ...                                           [ 76%]
tests/test_base_components.py ...                                        [ 94%]
tests/test_health.py .                                                   [100%]

============================= 17 passed in 10.36s =============================
```
