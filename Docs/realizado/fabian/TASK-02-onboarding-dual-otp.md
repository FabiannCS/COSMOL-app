# Tarea 02 (Fabian): Módulo de Onboarding Dual OTP (Primer Acceso y Vinculación)

> **Asignado a:** Desarrollador Frontend (Fabian)  
> **Estado:** COMPLETADO  
> **Fase:** Fase 1 — Identidad y Autenticación  
> **Fecha de finalización:** Septiembre 2026  
> **Documentos de referencia:** `AGENTS.md` (Sección 4.1), `Docs/HOJA_DE_RUTA_DESARROLLO.md` y `Docs/GUIA_INTEGRACION_FRONTEND.md`

> [!CAUTION]
> ### REGLA ESTRICTA DE GOBERNANZA VISUAL Y ARQUITECTÓNICA
> **Queda estrictamente prohibido modificar las vistas de Login (`login_screen.dart`), Registro Paso 1 (`onboarding_screen.dart`), Registro Paso 2 (`onboarding_step2_screen.dart`) y sus widgets segmentados sin la confirmación y autorización expresa del desarrollador / líder técnico (Fabian).** Cualquier refactorización o cambio de diseño debe consultarse y aprobarse previamente.

---

## 1. Objetivo

Implementar el flujo de **Primer Acceso / Onboarding de Saneamiento y Vinculación** en la aplicación Flutter. Este flujo permite a un socio ingresar, validar su número celular mediante verificación OTP dual (**WhatsApp Cloud API** / **SMS**), vincular su código de suministro y definir su **contraseña o PIN personal**, invalidando permanentemente el uso de la CI como clave.

---

## 2. Entregables Técnicos Completados

### 2.1 Capa de Datos y Dominio de Onboarding (`features/auth/`)
- [x] **Data Sources & DTOs:**
  - `auth_remote_datasource.dart`: Métodos `verificarSocio`, `solicitarOtp`, `verificarOtp`, `establecerPin` y `login` consumiendo los endpoints de FastAPI mediante Dio con interceptores de dispositivo y manejo de excepciones tipadas (`AppException`).
  - `verify_socio_response_model.dart`: Mapeo de `cod_socio`, `nombre_titular` y `mensaje`.
  - `otp_models.dart`: Mapeo de `OtpRequestModel`, `OtpResponseModel` (`canal`, `telefono_enmascarado`, `ttl_segundos`, `debug_codigo_otp`) y `VerifyOtpResponseModel` (`token_otp_valido`).
  - `register_credentials_model.dart`: Mapeo de `telefono`, `token_otp_valido`, `nuevo_pin`, `cod_socio`, `ci` y `username`.
  - `login_response_model.dart`: Mapeo de tokens JWT y lista de suministros multicuenta.
- [x] **Repositorio de Auth:** `auth_repository.dart` e implementación en `auth_repository_impl.dart`.

### 2.2 Gestión de Estado de Onboarding (`features/auth/presentation/providers/`)
- [x] `onboarding_provider.dart`: StateNotifier con Riverpod que centraliza el estado reactivo del wizard:
  - Paso 1: Validación y envío de OTP (`telefono`, `canal`, `secondsRemaining`, `canResend`, `debugCodigoOtp`).
  - Paso 2: Validación de código de verificación (`token_otp_valido`, `otpVerified`).
  - Paso 3: Vinculación de datos de suministro (`cod_socio`, `ci`, `username`, `password`).
  - Paso 4: Creación de credenciales con redirección exitosa a Login.

### 2.3 Pantallas y Widgets UI (`features/auth/presentation/`)
- [x] **Paso 1 — Teléfono y OTP (`onboarding_screen.dart`):**
  - Input telefónico formateado con código país `+591` ([phone_input_field.dart](file:///c:/Proyectos/cosmol-app/frontend/lib/features/auth/presentation/widgets/phone_input_field.dart)).
  - Botón interactivo para solicitar código por WhatsApp o SMS.
  - 4 casillas de código OTP con salto de foco automático y temporizador regresivo ([otp_verification_area.dart](file:///c:/Proyectos/cosmol-app/frontend/lib/features/auth/presentation/widgets/otp_verification_area.dart)).
  - Botón "Continuar" que valida el código y avanza al Paso 2.
- [x] **Paso 2 — Vinculación de Suministro (`onboarding_step2_screen.dart`):**
  - Stepper visual con Paso 1 completado (verde) y Paso 2 activo ([onboarding_step2_stepper.dart](file:///c:/Proyectos/cosmol-app/frontend/lib/features/auth/presentation/widgets/onboarding_step2_stepper.dart)).
  - Tarjeta de teléfono verificado dinámico ([verified_phone_card.dart](file:///c:/Proyectos/cosmol-app/frontend/lib/features/auth/presentation/widgets/verified_phone_card.dart)).
  - Guía visual interactiva de la factura COSMOL ([bill_guide_card.dart](file:///c:/Proyectos/cosmol-app/frontend/lib/features/auth/presentation/widgets/bill_guide_card.dart)).
  - Inputs: Código de Socio, C.I., Nombre de Usuario y Contraseña personal con alternador de visibilidad.
  - Botón "Completar Registro" con modal de confirmación y redirección a Login.
  - Botón "Volver al Paso 1" y soporte para botón físico de Android (`PopScope`).
- [x] **Enrutador (`app_router.dart`):**
  - Rutas `/login`, `/onboarding` y `/onboarding/step2` integradas y protegidas contra bloqueos de redirección.

---

## 3. Criterios de Aceptación Verificados
1. [x] El usuario completa los pasos secuenciales sin perder el estado del formulario.
2. [x] Si el código OTP ingresado es incorrecto, muestra la alerta descriptiva de error.
3. [x] Al finalizar el Paso 2, se presenta el modal informativo de éxito y se redirige a la pantalla de Login.
4. [x] `flutter analyze` reporta 0 errores y 0 advertencias en todo el código.
