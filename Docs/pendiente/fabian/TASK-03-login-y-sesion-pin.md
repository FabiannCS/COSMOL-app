# Tarea 03 (Fabian): Login Habitual, Control de Sesión y Bloqueo con PIN

> **Asignado a:** Desarrollador Frontend (Fabian)  
> **Estado:** PENDIENTE  
> **Fase:** Fase 1 — Identidad y Autenticación  
> **Fecha de creación:** Septiembre 2026  
> **Documentos de referencia:** `AGENTS.md` (Sección 4.1), `Docs/HOJA_DE_RUTA_DESARROLLO.md` y `Docs/GUIA_INTEGRACION_FRONTEND.md`

---

## 1. Objetivo

Implementar el flujo de **Login Diario Habitual (exclusivamente mediante PIN personal)**, la persistencia segura de tokens JWT, el refresco transparente de sesión, la gestión del cierre forzado por nuevo dispositivo (`SESSION_REVOKED_NEW_DEVICE`) y la presentación del modal de bloqueo progresivo tras 3 intentos fallidos consecutivos (`ACCOUNT_LOCKED`).

---

## 2. Entregables Técnicos

### 2.1 Persistencia y Servicios Local (`core/services/`)
- [ ] `storage_service.dart`: Integración de `flutter_secure_storage` para guardar:
  - `access_token`
  - `refresh_token`
  - `ultimo_cod_socio` (para precargar en el input de login)
- [ ] `device_service.dart`: Obtención del `device_id` único mediante `device_info_plus` y generación de UUID de hardware persistente.

### 2.2 Gestión de Estado de Autenticación (`features/auth/presentation/providers/`)
- [ ] `auth_state.dart`: Enum / Union State: `Initial`, `Unauthenticated`, `Authenticating`, `Authenticated`, `Locked`.
- [ ] `auth_notifier.dart`:
  - `checkAuthStatus()`: Verifica presencia de tokens al abrir la app.
  - `loginWithPin(codSocio, pin)`: Llama a `POST /api/v1/autenticacion/login` enviando `cod_socio`, `pin_password`, `device_id` y `modelo_dispositivo`.
  - `logout()`: Invalida almacenamiento local y navega a la pantalla de login.
  - `handleAccountLocked(seconds)`: Cambia el estado a `Locked` y dispara el modal.

### 2.3 Pantallas UI (`features/auth/presentation/screens/`)
- [ ] **Splash Screen (`splash_screen.dart`):**
  - Muestra logo animado de COSMOL.
  - Verifica estado de autenticación inicial y redirige a `LoginScreen` o `HomeScreen` mediante `GoRouter`.
- [ ] **Login Screen (`login_screen.dart`):**
  - Inputs: Código de Socio y PIN Personal (ocultable).
  - Opción "Recordar Código de Socio".
  - Botón principal: "Iniciar Sesión".
  - Enlaces secundarios:
    - *"¿Es tu primer ingreso? Registra tu cuenta"* -> Redirige al Paso 1 del Onboarding.
    - *"¿Olvidaste tu PIN?"* -> Inicia flujo de recuperación mediante OTP.
- [ ] **Modal de Bloqueo Progresivo (`account_locked_dialog.dart`):**
  - Se activa automáticamente al recibir error `ACCOUNT_LOCKED` (`403 Forbidden`).
  - Muestra el temporizador regresivo de espera usando `details.bloqueado_segundos_restantes`.
  - Incluye botón "Desbloquear de inmediato con OTP" que redirige al flujo OTP de verificación de celular.
- [ ] **Modal de Sesión Revocada (`session_revoked_dialog.dart`):**
  - Se activa al recibir `SESSION_REVOKED_NEW_DEVICE`.
  - Mensaje claro: *"Se ha iniciado sesión en otro dispositivo. Tu sesión en este equipo ha sido cerrada."* (Estilo WhatsApp).

---

## 3. Criterios de Aceptación
1. Un socio registrado ingresa exitosamente con su `cod_socio + PIN` y es redirigido al Dashboard.
2. Tras 3 intentos fallidos consecutivos con PIN erróneo, la app bloquea los reintentos y muestra el modal con temporizador regresivo en segundos.
3. Si el token de acceso vence (15 min), el interceptor lo renueva transparente usando el `refresh_token` sin interrumpir la navegación del usuario.
