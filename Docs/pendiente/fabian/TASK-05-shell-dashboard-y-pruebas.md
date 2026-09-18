# Tarea 05 (Fabian): Shell de Dashboard, Pruebas y Validación en Hardware Real

> **Asignado a:** Desarrollador Frontend (Fabian)
> **Estado:** PENDIENTE
> **Fase:** Fase 1 — Cierre de Fase e Integración Móvil USB
> **Fecha de creación:** Septiembre 2026
> **Documentos de referencia:** `AGENTS.md` (Sección 12), `Docs/HOJA_DE_RUTA_DESARROLLO.md` y `Docs/GUIA_INTEGRACION_FRONTEND.md`

---

## 1. Objetivo

Implementar el **Shell principal del Dashboard** (pantalla de aterrizaje post-login con la barra de navegación y el selector multicuenta), escribir la suite de **pruebas automatizadas en Flutter** (unitarias y de notifiers) y validar el comportamiento de la aplicación en un **smartphone físico Android conectado vía cable USB** utilizando el túnel `adb reverse tcp:8000 tcp:8000` con el backend Docker.

---

## 2. Entregables Técnicos

### 2.1 Shell de Dashboard Principal (`features/home/presentation/screens/`)
- [ ] `home_shell_screen.dart`:
  - Barra superior (*AppBar*) con el logo de COSMOL R.L. y el selector multicuenta (`suministro_selector_dropdown.dart`).
  - Tarjeta resumen con el socio autenticado y el contrato activo.
  - Estructura base preparada para alojar los módulos de la Fase 2 (Deuda en Bs, avisos y botón de pago).
  - Menú lateral o inferior para navegar a: Suministros, Ajustes de Cuenta y Cerrar Sesión.

### 2.2 Suite de Pruebas Automatizadas (`frontend/test/`)
- [ ] **Pruebas Unitarias (`test/core/`):**
  - Validación del parser de JSON de respuesta de errores (`error_handler_test.dart`).
  - Validación del interceptor Dio para inyección de token Bearer (`auth_interceptor_test.dart`).
- [ ] **Pruebas de Notifiers / Estado (`test/features/`):**
  - Testing de `OnboardingNotifier` (transición de los 4 pasos).
  - Testing de `AuthNotifier` (login con PIN y manejo de bloqueo de cuenta).
  - Testing de `MulticuentaNotifier` (cambio de suministro activo y vinculación).

### 2.3 Validación de Integración en Hardware Real (Móvil Android USB)
- [ ] Verificar que `adb devices` reconozca el smartphone físico.
- [ ] Ejecutar el túnel de comunicación: `adb reverse tcp:8000 tcp:8000`.
- [ ] Compilar y ejecutar la app en el dispositivo real: `flutter run -d <device_id>`.
- [ ] Ejecutar prueba e2e manual:
  1. Onboarding completo con socio `104523` + `8392019` -> OTP -> PIN `4455`.
  2. Login con `104523` + PIN `4455`.
  3. Probar 3 intentos fallidos con PIN erróneo para forzar el modal `ACCOUNT_LOCKED` con temporizador regresivo.
  4. Vincular segundo suministro multicuenta.

---

## 3. Criterios de Aceptación
1. `flutter test` ejecuta todas las pruebas unitarias y de notifiers con 100% de éxito.
2. La app corre fluidamente en el smartphone físico Android conectado vía USB y se comunica transparente con FastAPI en Docker a través de `adb reverse`.
3. Al finalizar, mover las tareas completadas a `Docs/realizado/fabian/` con la bitácora de validación.
