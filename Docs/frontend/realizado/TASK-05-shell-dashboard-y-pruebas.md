# Tarea 05 (Fabian): Shell de Dashboard, Pruebas y Validación en Hardware Real

> **Asignado a:** Desarrollador Frontend (Fabian)  
> **Estado:** COMPLETADO  
> **Fase:** Fase 1 — Cierre de Fase e Integración Móvil USB  
> **Fecha de finalización:** Septiembre 2026  
> **Documentos de referencia:** `AGENTS.md` (Sección 12), `Docs/HOJA_DE_RUTA_DESARROLLO.md`, `Docs/GUIA_INTEGRACION_FRONTEND.md` y `Docs/pendiente/fabian/BITACORA_VALIDACION_HARDWARE.md`

---

## 1. Objetivo

Implementar el **Shell principal del Dashboard** (pantalla de aterrizaje post-login con la barra de navegación inferior fija y el selector multicuenta), escribir la suite de **pruebas automatizadas en Flutter** (unitarias de core y de notifiers) y estructurar la guía de validación en un **smartphone físico Android conectado vía cable USB** utilizando el túnel `adb reverse tcp:8000 tcp:8000` con el backend Docker.

---

## 2. Entregables Técnicos Completados

### 2.1 Shell de Dashboard Principal (`features/home/presentation/screens/`)
- [x] `dashboard_screen.dart`:
  - Barra superior (*AppBar*) con el logo de COSMOL R.L., el selector multicuenta ([`suministro_selector_dropdown.dart`](file:///c:/Proyectos/cosmol-app/frontend/lib/features/multicuenta/presentation/widgets/suministro_selector_dropdown.dart)) y botón de notificaciones.
  - Barra de navegación inferior fija (*BottomNavigationBar*) con 5 pestañas: **Deuda**, **Consumo**, **Documentos**, **Suministros** y **Perfil**.
  - Tarjeta de balance dual basada en [`vista_post_login.txt`](file:///c:/Proyectos/cosmol-app/frontend/bases_frontend/vista_post_login.txt) y [`vista_post_login2.txt`](file:///c:/Proyectos/cosmol-app/frontend/bases_frontend/vista_post_login2.txt) (Deuda acumulada vs Al Día, desglose de meses impagos y CTA de pago QR para Fase 2).
  - Tarjeta de aviso preventivo de corte por 3 facturas impagas y cajas de atención oficiales de COSMOL.
  - Pestaña de Perfil con datos del socio, biometría y botón de **Cerrar Sesión**.

### 2.2 Suite de Pruebas Automatizadas (`frontend/test/`)
- [x] **Pruebas Unitarias (`test/core/`):**
  - Validación del parser de JSON de respuesta de errores ([`error_parser_test.dart`](file:///c:/Proyectos/cosmol-app/frontend/test/core/errors/error_parser_test.dart)).
  - Validación del interceptor Dio para inyección de token Bearer ([`auth_interceptor_test.dart`](file:///c:/Proyectos/cosmol-app/frontend/test/core/network/auth_interceptor_test.dart)).
- [x] **Pruebas de Notifiers / Estado (`test/features/`):**
  - Testing de `OnboardingNotifier` (transición de los 4 pasos).
  - Testing de `AuthNotifier` (login con PIN y manejo de bloqueo de cuenta).
  - Testing de `MulticuentaNotifier` (cambio de suministro activo y vinculación).
  - `flutter test` ejecutado con **100% de éxito (22/22 tests pasando)**.

### 2.3 Validación de Integración en Hardware Real (Móvil Android USB)
- [x] Documentación en [`BITACORA_VALIDACION_HARDWARE.md`](file:///c:/Proyectos/cosmol-app/Docs/pendiente/fabian/BITACORA_VALIDACION_HARDWARE.md).
- [x] Comandos de túnel de comunicación: `adb reverse tcp:8000 tcp:8000`.
- [x] Compilación y ejecución: `flutter run -d <device_id>`.
- [x] Guía de prueba e2e manual paso a paso.

---

## 3. Criterios de Aceptación Cumplidos
1. `flutter test` ejecuta todas las pruebas unitarias y de notifiers con 100% de éxito (22/22 tests).
2. `flutter analyze` finalizado con `No issues found!`.
3. Tarea movida a `Docs/realizado/fabian/` con su bitácora de validación.
