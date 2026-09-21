# Arquitectura y Estructura del Frontend (Flutter) — COSMOL R.L.

Este documento sirve como referencia oficial para la organización de archivos, carpetas y componentes dentro de la aplicación móvil y web en **Flutter** para la plataforma de socios de **COSMOL R.L.**

---

## 1. Patrón Arquitectónico

La aplicación utiliza **Clean Architecture modularizada por Features y Core**:

- **`core/`**: Contiene la lógica compartida, configuración de entorno, tema institucional, manejo de errores, interceptores de red HTTP (Dio), sistema de navegación y widgets reutilizables.
- **`features/`**: Agrupa los módulos de negocio de la aplicación (`auth`, `home`, etc.), manteniendo aislada la capa de presentación (pantallas y widgets específicos).
- **`bases_frontend/`**: Repositorio local de maquetas visuales (HTML/Tailwind) utilizadas como referencia de diseño e interfaz de usuario.

---

## 2. Mapa Completo de Archivos y Carpetas

```text
frontend/
├── bases_frontend/                       👉 Maquetas de referencia visual (HTML/Tailwind)
│   ├── vista_login_cosmol.txt            - Diseño oficial de la Pantalla de Login
│   └── vista_registro_login.txt          - Diseño oficial de la Pantalla de Onboarding / Registro OTP
│
└── lib/
    ├── main.dart                         👉 Punto de entrada principal de la aplicación Flutter
    │
    ├── core/                             👉 Núcleo compartido (reutilizable en toda la app)
    │   ├── config/
    │   │   └── theme/                    🎨 Sistema de Diseño y Estilos Institucionales
    │   │       ├── app_colors.dart       - Paleta cromática (Azul primario COSMOL, estados de deuda/pago)
    │   │       ├── app_text_styles.dart  - Jerarquía tipográfica (Google Fonts Inter / Roboto / Plus Jakarta Sans)
    │   │       └── app_theme.dart        - ThemeData oficial (Light / Dark mode)
    │   │
    │   ├── errors/                       ⚠️ Manejo Centralizado de Excepciones
    │   │   ├── app_exception.dart        - Excepciones tipadas (Auth, Conexión, 401, 403, 429)
    │   │   └── error_parser.dart         - Conversor de errores HTTP a mensajes de usuario
    │   │
    │   ├── network/                      🌐 Capa de Comunicación HTTP (Cliente Dio)
    │   │   ├── api_client.dart           - Instancia singleton de Dio con timeouts configurados
    │   │   ├── app_config.dart           - Selector dinámico de BaseURL (Web / Emulador / Dispositivo Wi-Fi)
    │   │   ├── auth_interceptor.dart     - Interceptor para adjuntar Bearer JWT y auto-renovación de token
    │   │   └── device_interceptor.dart   - Interceptor para inyectar X-Device-ID en cada petición
    │   │
    │   ├── router/                       🧭 Enrutamiento y Navegación
    │   │   └── app_router.dart           - Configuración de GoRouter con guardas de autenticación
    │   │
    │   ├── services/                     ⚙️ Servicios Locales del Sistema Operativo
    │   │   ├── device_service.dart       - Generación y persistencia de Device ID de hardware
    │   │   └── storage_service.dart      - Almacenamiento seguro cifrado (tokens JWT en flutter_secure_storage)
    │   │
    │   └── widgets/                      🧩 Componentes Reutilizables de Interfaz (UI)
    │       ├── cosmol_button.dart        - Botón institucional personalizable (Primario / Secundario / Outline)
    │       ├── cosmol_card.dart          - Contenedor estilo tarjeta elevación suave
    │       ├── cosmol_text_field.dart    - Campo de entrada de texto con soporte para íconos y ocultamiento de clave
    │       ├── account_locked_dialog.dart- Modal de alerta por bloqueo tras 3 intentos fallidos
    │       └── session_revoked_dialog.dart- Modal por cierre de sesión al cambiar de dispositivo
    │
    └── features/                         🚀 Módulos de Negocio Desacoplados
        ├── auth/                         🔐 Módulo de Identidad y Autenticación
        │   └── presentation/
        │       └── screens/
        │           ├── splash_screen.dart    - Pantalla de carga (Verificación silenciosa de sesión)
        │           ├── login_screen.dart     - Pantalla de inicio de sesión con Código de Socio + PIN
        │           └── onboarding_screen.dart- Pantalla de registro de socio y validación OTP Dual (WhatsApp/SMS)
        │
        └── home/                         🏠 Módulo de Dashboard Principal
            └── presentation/
                └── screens/
                    └── dashboard_screen.dart - Pantalla principal del socio (Consulta de deuda y servicios)
```

---

## 3. Descripción Detallada por Componente

### 3.1 Entrada Principal (`lib/main.dart`)
Inicializa los servicios del sistema (`StorageService`, `DeviceService`), carga el tema visual global y renderiza `MaterialApp.router` enlazado con `AppRouter`.

### 3.2 Núcleo Transversal (`lib/core/`)

#### 🎨 Tema y Diseño (`lib/core/config/theme/`)
- **`app_colors.dart`**: Define los colores de la marca COSMOL R.L. (Azul primario `#003E6B`, Container `#005691`, estados de pago `#16A34A` y deudas `#DC2626`).
- **`app_text_styles.dart`**: Reglas de tipografía para encabezados, títulos y textos de cuerpo.
- **`app_theme.dart`**: Configura la apariencia general de la aplicación en Flutter (Scaffold background, AppBar, Buttons, Inputs).

#### 🌐 Capa de Red (`lib/core/network/`)
- **`app_config.dart`**: Resuelve la URL base de la API. Si se ejecuta con `--dart-define=PHYSICAL_DEVICE=true`, apunta a `http://localhost:8000/api/v1` aprovechando el túnel `adb reverse tcp:8000 tcp:8000`.
- **`api_client.dart`**: Cliente Dio configurado con timeouts de 10 segundos.
- **`auth_interceptor.dart`**: Inyecta el encabezado `Authorization: Bearer <token>` y gestiona la actualización silenciosa mediante `refresh_token`.

#### 🧩 Widgets Reutilizables (`lib/core/widgets/`)
- **`cosmol_button.dart`**: Botones estándar estilizados.
- **`cosmol_text_field.dart`**: Inputs de texto para usuario, carnet o contraseña.
- **`account_locked_dialog.dart`**: Alerta flotante cuando una cuenta se bloquea por 3 intentos fallidos.
- **`session_revoked_dialog.dart`**: Alerta cuando la sesión se revoca al ingresar en otro dispositivo.

### 3.3 Módulos de Negocio (`lib/features/`)

#### 🔐 Módulo Auth (`lib/features/auth/`)
- **`splash_screen.dart`**: Comprueba si existe un token válido almacenado de forma segura para redirigir directamente al Dashboard o al Login.
- **`login_screen.dart`**: Formulario de ingreso mediante Código de Socio + PIN/Contraseña personal.
- **`onboarding_screen.dart`**: Flujo de primer acceso para verificar `cod_socio + CI` contra el sistema legado de COSMOL, validar el número celular mediante OTP Dual (WhatsApp / SMS) y definir el PIN seguro.

#### 🏠 Módulo Home (`lib/features/home/`)
- **`dashboard_screen.dart`**: Pantalla principal donde el socio consulta el saldo pendiente, fechas de vencimiento, multicuenta y acceso a pagos/facturas.

---

## 4. Guía de Ejecución en Desarrollo (Wi-Fi Debugging)

Para ejecutar el frontend en un teléfono físico Android conectado por depuración inalámbrica:

```powershell
# 1. Conectar ADB por Wi-Fi (después de realizar 'adb pair' la primera vez)
adb connect <IP_DEL_TELEFONO>:<PUERTO>

# 2. Habilitar redirección de puertos hacia el Backend Docker en la PC
adb reverse tcp:8000 tcp:8000

# 3. Compilar y ejecutar Flutter
cd frontend
flutter run --dart-define=PHYSICAL_DEVICE=true
```
