# Guía de Integración Frontend: Desvinculación, Migración de Celular y Estado de Entrega

> **Módulos:** Autenticación, Onboarding, Multicuenta y Seguridad (`features/auth`, `features/multicuenta`, `core/network`)  
> **Proyecto:** COSMOL RL — Plataforma Web y Móvil (Flutter Clean Architecture)  
> **Fecha de Actualización:** Octubre 2026  
> **Ubicación:** `Docs/frontend/guias/GUIA_INTEGRACION_MIGRACION_Y_DESVINCULACION.md`  
> **Estado:** ✅ **100% IMPLEMENTADO, VALIDADO CON 65/65 TESTS Y 0 LINT ISSUES**

---

## 1. Estado de la API Backend y Contratos de Integración

Todos los endpoints necesarios bajo el prefijo unificado `/api/v1/autenticacion/*` se encuentran desplegados, funcionales en el backend FastAPI y completamente consumidos por el cliente Flutter:

| Endpoint Backend | Método | Auth Requerida | Estado Frontend | Propósito |
|---|---|---|---|---|
| `/api/v1/autenticacion/suministros/{cod_socio}` | `DELETE` | Sí (Bearer JWT) | ✅ Conectado | Desvinculación persistente de suministro secundario en PostgreSQL. |
| `/api/v1/autenticacion/verificar-socio` | `POST` | No | ✅ Conectado | Paso 1 Onboarding: devuelve `cuenta_existente: bool` y `telefono_enmascarado`. |
| `/api/v1/autenticacion/migrar-telefono/iniciar` | `POST` | No | ✅ Conectado | Inicia cambio de celular con validación previa de PIN titular. Despacha OTP al nuevo número. |
| `/api/v1/autenticacion/migrar-telefono/confirmar` | `POST` | No | ✅ Conectado | Valida OTP del nuevo celular, actualiza BD, revoca sesiones previas y emite nuevos JWTs. |
| `/api/v1/autenticacion/recuperar-password/validar-titular` | `POST` | No | ✅ Conectado | Paso 1 Recuperar PIN: valida identidad y devuelve celular enmascarado. |
| `/api/v1/autenticacion/recuperar-password/solicitar-otp` | `POST` | No | ✅ Conectado | Paso 2 Recuperar PIN: despacha OTP al celular registrado. |
| `/api/v1/autenticacion/recuperar-password/verificar-otp` | `POST` | No | ✅ Conectado | Paso 3 Recuperar PIN: entrega `token_recuperacion`. |
| `/api/v1/autenticacion/recuperar-password/cambiar-pin` | `POST` | No | ✅ Conectado | Paso 4 Recuperar PIN: actualiza contraseña con bcrypt y resetea bloqueos. |

---

## 2. Resumen de Tareas Implementadas en Frontend

---

### ✅ Tarea F1: Desvinculación Real de Suministros Secundarios (Multicuenta)
- **Archivo:** `frontend/lib/features/multicuenta/presentation/providers/multicuenta_provider.dart`
- **Implementación:**
  1. `MulticuentaNotifier.desvincularSuministro(codSocio)` ejecuta la llamada HTTP `DELETE /api/v1/autenticacion/suministros/{cod_socio}`.
  2. Si la API responde con éxito, actualiza la lista in-memory y reasigna el suministro principal si el eliminado era el activo.
  3. Maneja excepciones tipadas `AppException` con rollback seguro en caso de fallo de red.

---

### ✅ Tarea F2: Guardas Anti-401 y Estabilidad de Sesión
- **Archivos:**
  - `frontend/lib/features/multicuenta/presentation/providers/multicuenta_provider.dart`
  - `frontend/lib/core/network/auth_interceptor.dart`
  - `frontend/lib/features/auth/presentation/providers/auth_provider.dart`
- **Implementación:**
  1. Comprobación temprana de token en `cargarSuministros()`: si el usuario no tiene token guardado (pantalla de Splash o Login), la petición no se despacha.
  2. En `AuthInterceptor`, se añadió el guard `hadToken`: las peticiones anónimas que reciban 401 nunca disparan el callback de desautenticación ni cierran sesiones activas.
  3. `AuthNotifier.checkAuthStatus()` no sobreescribe el estado si la sesión ya fue marcada como `AuthStatus.authenticated` durante el login.

---

### ✅ Tarea F3: Modal "Cuenta Ya Registrada" en Onboarding Paso 1
- **Archivos:**
  - `frontend/lib/features/auth/data/models/verify_socio_response_model.dart`
  - `frontend/lib/features/auth/presentation/providers/onboarding_provider.dart`
  - `frontend/lib/features/auth/presentation/screens/onboarding_screen.dart`
- **Implementación:**
  1. El modelo `VerifySocioResponseModel` captura `cuentaExistente: bool` y `telefonoEnmascarado: String?`.
  2. `OnboardingNotifier.verificarSocio` mantiene `currentStep: 1` si `cuentaExistente == true`.
  3. `OnboardingScreen` despliega un `ModalBottomSheet` institucional con estilo COSMOL que informa al socio:
     - Nombre del titular y código de socio.
     - Teléfono enmascarado registrado (`+591 7*** **384`).
     - **3 Botones de acción directa:**
       - **Iniciar Sesión:** Redirige a `/login`.
       - **¿Cambiaste de número? Migrar Celular:** Redirige a `/migrar-celular` precargando `cod_socio`, `ci` y `nombre_titular`.
       - **¿Olvidaste tu contraseña? Recuperar PIN:** Redirige a `/recuperar-password`.

---

### ✅ Tarea F4: Módulo Completo de Migración de Celular (Celular Nuevo)
- **Archivos Creados e Integrados:**
  - `frontend/lib/features/auth/data/models/migrar_telefono_models.dart`: Modelos de petición y respuesta para `iniciar` y `confirmar`.
  - `frontend/lib/features/auth/presentation/providers/migrar_celular_provider.dart`: Máquina de estados Riverpod para validación titular, temporizador de 90s, reenvío y confirmación OTP.
  - `frontend/lib/features/auth/presentation/screens/migrar_celular_screen.dart`: UI institucional en 2 pasos:
    - **Paso 1:** Validación de titularidad (Código de Socio, CI, PIN actual, nuevo teléfono de 8 dígitos y selector WhatsApp/SMS).
    - **Paso 2:** Entrada de código OTP de 6 dígitos, temporizador regresivo de reenvío y banner de debug en desarrollo.
  - `frontend/lib/core/router/app_router.dart`: Ruta `/migrar-celular` registrada con guards de acceso.
  - `frontend/lib/features/auth/presentation/providers/auth_provider.dart`: Método `setAuthenticatedSession` para bootstrapping automático de sesión al finalizar la migración.
  - `frontend/test/features/auth/migrar_celular_test.dart`: Suite completa de 8 pruebas unitarias validando modelos, errores de validación, temporizador y auto-login.

---

### ✅ Tarea F5: Recuperación Segura de Contraseña / PIN (Zero-Trust)
- **Archivos:**
  - `frontend/lib/features/auth/presentation/screens/recuperar_password_screen.dart`
  - `frontend/lib/features/auth/presentation/providers/recuperar_password_provider.dart`
  - `frontend/lib/features/auth/presentation/screens/login_screen.dart` (enlace "¿Olvidaste tu contraseña?" y botón "Contactar Soporte" oficial `+59161555507`).
- **Implementación:**
  - Flujo de 4 pasos certificados contra backend: Validar titular → Solicitar OTP → Verificar OTP → Cambiar PIN.

---

### ✅ Tarea F6: Ajuste de Red a Puerto 443 en `app_config.dart`
- **Archivo:** `frontend/lib/core/network/app_config.dart`
- **Implementación:**
  - Puerto por defecto configurado en `'443'`.
  - `remoteBaseUrl` construye `https://$_envDomain/api/v1` sin puerto explícito cuando `port == 443`, evitando bloqueos de firewall y adaptándose a producción con TLS de Caddy.

---

## 3. Estado de Certificación y Calidad de Código

| Métrica | Resultado |
|---|---|
| **Pruebas Unitarias (`flutter test`)** | **65 / 65 pruebas superadas exitosamente (100% pass)** |
| **Análisis Estático (`flutter analyze`)** | **0 errores, 0 advertencias, 0 sugerencias (Clean Code)** |
| **Cumplimiento de Arquitectura** | Clean Architecture estricta (Data, Domain, Presentation con Riverpod) |

---

## 4. Aspectos Pendientes por Analizar e Implementar (Roadmap Futuro)

| Componente | Estado Actual | Pendiente por Analizar / Implementar | Responsable |
|---|---|---|---|
| **Auditoría hacia COSMOL-Reportes** | Deshabilitada (`REPORTES_ENABLED=false`) para evitar sobrecarga de red en la app móvil. | Conectar worker asíncrono en segundo plano (`BackgroundTasks`) para sincronizar logs de auditoría sin bloquear la respuesta al usuario. | Backend / DevOps |
| **Pasarelas de Pago Oficiales** | Redirección por URL a portales bancarios y QR interbancario estático. | Integración formal con los contratos bancarios de Multipago y Pago al Paso para QR interbancario dinámico y Webhook de conciliación en tiempo real. | Backend / Entidades Bancarias |
| **Meta Cloud API Oficial** | Operando en modo `MOCK_MESSAGING=true`. | Al obtener la verificación empresarial de Meta para COSMOL R.L., cambiar la bandera a `false` e inyectar el Access Token definitivo de WhatsApp Cloud API. | Backend / Meta Business |
| **Pruebas en Dispositivos Físicos** | Código verificado y probado localmente. | Compilar APK de Release o ejecutar `flutter run -d <device_id>` en teléfono Android físico para validar UX con teclado virtual y notificaciones. | Frontend / QA |
