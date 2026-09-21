# Tarea 03 (Fabian): Login Habitual, Control de Sesión y Bloqueo con PIN

> **Asignado a:** Desarrollador Frontend (Fabian)  
> **Estado:** COMPLETADO  
> **Fase:** Fase 1 — Identidad y Autenticación  
> **Fecha de creación:** Septiembre 2026  
> **Documentos de referencia:** `AGENTS.md` (Sección 4.1), `Docs/HOJA_DE_RUTA_DESARROLLO.md` y `Docs/GUIA_INTEGRACION_FRONTEND.md`

---

## 1. Objetivo

Implementar el flujo de **Login Diario Habitual (exclusivamente mediante PIN personal)**, la persistencia segura de tokens JWT, el refresco transparente de sesión, la gestión del cierre forzado por nuevo dispositivo (`SESSION_REVOKED_NEW_DEVICE`) y la presentación del modal de bloqueo progresivo tras 3 intentos fallidos consecutivos (`ACCOUNT_LOCKED`).

---

## 2. Entregables Técnicos

### 2.1 Persistencia y Servicios Local (`core/services/`)
- [x] `storage_service.dart`: Integración de `flutter_secure_storage` para guardar:
  - `access_token`
  - `refresh_token`
  - `ultimo_cod_socio` (para precargar en el input de login)
- [x] `device_service.dart`: Obtención del `device_id` único mediante `device_info_plus` y generación de UUID de hardware persistente.

### 2.2 Gestión de Estado de Autenticación (`features/auth/presentation/providers/`)
- [x] `auth_state.dart` / `auth_provider.dart`: Enum / Union State: `Initial`, `Unauthenticated`, `Authenticated`, `OnboardingRequired`, `Locked`.
- [x] `auth_notifier.dart` (`AuthNotifier`):
  - `checkAuthStatus()`: Verifica presencia de tokens al abrir la app.
  - `login(codSocio, password)`: Llama a `POST /api/v1/autenticacion/login` enviando `cod_socio`, `pin_password`, `device_id` y `modelo_dispositivo`.
  - `logout()`: Invalida almacenamiento local y navega a la pantalla de login.
  - `handleAccountLocked(seconds)`: Cambia el estado a `Locked` y dispara el modal.

### 2.3 Pantallas UI (`features/auth/presentation/screens/`)
- [x] **Splash Screen (`splash_screen.dart`):**
  - Muestra logo animado de COSMOL.
  - Verifica estado de autenticación inicial y redirige a `LoginScreen` o `DashboardScreen` mediante `GoRouter`.
- [x] **Login Screen (`login_screen.dart`):**
  - Inputs: Usuario / Código de Socio y Contraseña / PIN Personal (ocultable).
  - Precarga automática del último Código de Socio guardado.
  - Botón principal: "Ingresar a mi Cuenta" conectado a `authProvider`.
  - Enlaces secundarios:
    - *"Registrarse"* -> Redirige al Paso 1 del Onboarding.
    - *"¿Olvidaste tu contraseña?"* -> Enlace de asistencia WhatsApp oficial.
- [x] **Modal de Bloqueo Progresivo (`account_locked_dialog.dart`):**
  - Se activa automáticamente al recibir error `ACCOUNT_LOCKED` (`403 Forbidden`).
  - Muestra el temporizador regresivo de espera usando `bloqueado_segundos_restantes`.
  - Incluye botón "Desbloquear de inmediato vía OTP" que redirige al flujo OTP de verificación de celular.
- [x] **Modal de Sesión Revocada (`session_revoked_dialog.dart`):**
  - Se activa al recibir `SESSION_REVOKED_NEW_DEVICE`.
  - Mensaje claro: *"Se ha iniciado sesión en otro dispositivo. Tu sesión en este equipo ha sido cerrada."* (Estilo WhatsApp).

---

## 3. Criterios de Aceptación
1. [x] Un socio registrado ingresa exitosamente con su `cod_socio + PIN` y es redirigido al Dashboard.
2. [x] Tras 3 intentos fallidos consecutivos con PIN erróneo, la app bloquea los reintentos y muestra el modal con temporizador regresivo en segundos.
3. [x] Si el token de acceso vence (15 min), el interceptor lo renueva transparente usando el `refresh_token` sin interrumpir la navegación del usuario.
