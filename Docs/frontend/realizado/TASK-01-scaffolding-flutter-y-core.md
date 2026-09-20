# Tarea 01 (Fabian): Scaffolding de Flutter, Sistema de Diseño y Capa de Red Core

> **Asignado a:** Desarrollador Frontend (Fabian)  
> **Estado:** REALIZADO  
> **Fase:** Fase 1 — Inicialización y Cimientos de Frontend  
> **Fecha de creación:** Septiembre 2026  
> **Documentos de referencia:** `AGENTS.md`, `Docs/HOJA_DE_RUTA_DESARROLLO.md` y `Docs/GUIA_INTEGRACION_FRONTEND.md`

---

## 1. Objetivo

Inicializar la aplicación cliente **Flutter** (Android, iOS y Web) en la carpeta `/frontend`, estructurar la arquitectura limpia (**Clean Architecture / Feature-First**), configurar el sistema de diseño visual institucional de **COSMOL R.L.** y construir la capa de red con **Dio**, interceptores JWT de autenticación, renovación transparente de token y manejo unificado de errores.

---

## 2. Entregables Técnicos

### 2.1 Inicialización de Proyecto y Dependencias (`/frontend/pubspec.yaml`)
- [x] Ejecutar la creación del proyecto: `flutter create --org bo.cosmol.app --project-name cosmol_app frontend`.
- [x] Configurar las dependencias en `pubspec.yaml`:
  - `flutter_riverpod: ^2.5.1` (gestión de estado inmutable)
  - `go_router: ^14.2.0` (enrutamiento declarativo)
  - `dio: ^5.4.3+1` (cliente HTTP con interceptores)
  - `flutter_secure_storage: ^9.2.2` (persistencia segura de tokens JWT)
  - `shared_preferences: ^2.2.3` (persistencia local de preferencias)
  - `device_info_plus: ^10.1.0` (obtención de `device_id` e info de hardware)
  - `google_fonts: ^6.2.1` y `font_awesome_flutter: ^10.7.0` (tipografía e iconos)
  - `pinput: ^5.0.0` (inputs numéricos limpios para PIN y OTP)
  - `intl: ^0.19.0` y `uuid: ^4.4.0`
- [x] Habilitar permisos de red en `android/app/src/main/AndroidManifest.xml` (`INTERNET`, `ACCESS_NETWORK_STATE`).

### 2.2 Estructura de Carpetas (Clean Architecture / Feature-First)
- [x] Crear la estructura bajo `frontend/lib/`:
  - `core/config/theme/` (colores, fuentes, ThemeData)
  - `core/errors/` (jerarquía de excepciones tipadas y parser de errores)
  - `core/network/` (Dio client, interceptores auth, device y logger)
  - `core/router/` (GoRouter con auth guards)
  - `core/services/` (StorageService, DeviceService)
  - `core/widgets/` (componentes UI institucionales reutilizables)
  - `features/auth/`
  - `features/multicuenta/`
  - `features/home/`

### 2.3 Tema Visual e Identidad Corporativa COSMOL (`core/config/theme/`)
- [x] `app_colors.dart`:
  - Azul COSMOL Principal: `Color(0xFF0D5C96)`
  - Azul Marino Oscuro: `Color(0xFF072B4A)`
  - Acento Turquesa: `Color(0xFF00A8B5)`
  - Fondo Claro: `Color(0xFFF4F7FA)`
  - Semáforos y Alertas: Verde `Color(0xFF2E7D32)`, Rojo `Color(0xFFE53935)`, Naranja `Color(0xFFF57C00)`
- [x] `app_text_styles.dart`: Tipografía Inter/Roboto con jerarquías claras de encabezados, subtítulos y cuerpo.
- [x] `app_theme.dart`: Configuración de `ThemeData` institucional para botones, campos de texto, tarjetas y barras de navegación.

### 2.4 Capa de Red e Interceptores (`core/network/`)
- [x] `app_config.dart`: Configuración de URL base dinámica (`http://localhost:8000/api/v1` por defecto con soporte `adb reverse` en dispositivo físico USB).
- [x] `api_client.dart`: Instancia singleton/provider de `Dio` con timeouts de 10 segundos.
- [x] `auth_interceptor.dart`:
  - Inyección automática del header `Authorization: Bearer <access_token>`.
  - Intercepción de errores `401 Unauthorized` para ejecutar el refresco silencioso mediante `POST /api/v1/autenticacion/renovar-token`.
  - Reintento transparente de la petición fallida si el refresh token es exitoso.
  - Detección de error `SESSION_REVOKED_NEW_DEVICE` para forzar cierre de sesión local.
  - Detección de error `ACCOUNT_LOCKED` para invocar el modal de temporizador de bloqueo.
- [x] `device_interceptor.dart`: Inyección automática del header `X-Device-Id`.

### 2.5 Componentes UI Base Reutilizables (`core/widgets/`)
- [x] `cosmol_button.dart`: Botón primario y secundario con indicador de carga (*loading spinner*).
- [x] `cosmol_text_field.dart`: Campo de texto estilizado con soporte de ocultar contraseña/PIN, iconos y mensajes de validación.
- [x] `cosmol_card.dart`: Tarjeta contenedora con elevación suave y bordes redondeados.
- [x] `account_locked_dialog.dart`: Diálogo modal con temporizador regresivo de bloqueo en segundos (`bloqueado_segundos_restantes`) y botón de desbloqueo vía OTP.
- [x] `session_revoked_dialog.dart`: Diálogo de alerta cuando se revoca la sesión por inicio en un nuevo dispositivo.

---

## 3. Criterios de Aceptación
1. `flutter pub get` se ejecuta sin advertencias ni conflictos de dependencias. (COMPLETADO)
2. El proyecto compila y ejecuta en Android y Flutter Web mostrando la estructura inicial limpia. (COMPLETADO)
3. El cliente `Dio` añade los headers necesarios y gestiona la interceptación de respuestas `401` y errores tipados. (COMPLETADO)
