# Contexto de Proyecto — App de Socios COSMOL RL
> Documento de referencia arquitectónica, funcional y técnica para agentes de IA y desarrolladores. Contiene el funcionamiento detallado de cada módulo, contratos, flujos lógicos y decisiones para evitar errores durante el desarrollo de la plataforma web y móvil de COSMOL RL (Montero, Bolivia).

> [!CAUTION]
> ### REGLA ESTRICTA DE MODIFICACIÓN Y GOBERNANZA
> **Este archivo constituye la BASE ARQUITECTÓNICA Y CONCEPTUAL DEL PROYECTO.**
> **Queda estrictamente prohibido modificar este archivo o alterar su lógica sin la confirmación y autorización expresa del desarrollador / líder técnico.** Cualquier cambio, ajuste o refactorización de requerimientos debe ser consultado previamente y aprobado antes de editar este documento.

---

## 1. Resumen Ejecutivo y Metas

| **Parámetro** | **Definición** |
|---|---|
| **Proyecto** | Plataforma Web y Móvil para Asociados de COSMOL RL |
| **Cliente** | COSMOL RL — Cooperativa de Servicios Públicos Montero R.L. |
| **Usuario Final** | Socios y usuarios de suministros de agua potable y alcantarillado |
| **Frontend** | Flutter 3.x (Base de código única para Android, iOS y Web) |
| **Backend** | FastAPI (Python 3.12+) — Arquitectura BFF Asíncrona |
| **Bases de Datos & Caché** | PostgreSQL 16 + Redis 7 + MinIO (S3 Storage para PDFs) |
| **Infraestructura** | Docker Compose + Caddy v2 (Reverse Proxy con TLS automático) |
| **Tipo de Entregable** | Plataforma omnicanal 24/7 |

### Objetivos Principales:
1. **Descongestionar Atención Presencial:** Reducir filas en oficinas físicas mediante consultas 24/7 desde la app.
2. **Reducción de Mora:** Facilitar el conocimiento inmediato de la deuda y agilizar el pago mediante redirección a banca y QR interbancario.
3. **Ahorro Operativo y Ambiental:** Digitalizar facturas con valor legal, avisos de cobranza y avisos de corte en formato PDF.

---

## 2. Arquitectura de Software y Organización de Código

### 2.1 Frontend (Flutter Clean Architecture)
El frontend se organiza bajo principios de Clean Architecture con separación estricta en tres capas por cada feature:

```
frontend/lib/
├── core/
│   ├── config/          # Tema, constantes de entorno y configuración global
│   ├── errors/          # Clases de fallos y excepciones personalizadas
│   ├── network/         # Cliente Dio con interceptores JWT y caché
│   ├── router/          # AppRouter (go_router) con guards de autenticación
│   ├── services/        # Secure storage, local_auth (biometría), notificaciones
│   └── widgets/         # Componentes UI transversales (botones, tarjetas, appbars)
└── features/
    ├── auth/            # Onboarding, login, OTP, biometría, PIN
    ├── deuda/           # Dashboard de saldo, avisos de cobranza, detalle de deuda
    ├── consumo/         # Historial y gráficos de consumo analítico (fl_chart)
    ├── documentos/      # Listado y visor PDF (flutter_pdfview, open_filex)
    ├── multicuenta/     # Vinculación y gestión de múltiples suministros
    ├── perfil/          # Datos del socio, seguridad, cambio de PIN y sesión
    └── home/            # Shell y DashboardScreen contenedor
```

**Estructura interna de cada feature:**
- `data/`: Modelos (`models/`), Fuentes de datos remotas/locales (`datasources/`) e Implementación de repositorios (`repositories/`).
- `domain/`: Entidades del negocio (`entities/`) y Casos de uso (`usecases/`).
- `presentation/`: Manejo de estado con Riverpod (`providers/`), Pantallas (`screens/`) y Widgets locales (`widgets/`).

### 2.2 Backend (FastAPI BFF Asíncrono)
El backend actúa como un *Backend-For-Frontend* (BFF), desacoplando a Flutter del sistema legado de COSMOL:

```
backend/app/
├── api/
│   ├── deps.py          # Inyección de dependencias (DB session, usuario autenticado)
│   └── v1/
│       ├── autenticacion.py  # Endpoints login, onboarding, OTP, refresh token
│       ├── deuda.py          # Consulta de deuda y facturas pendientes
│       ├── consumo.py        # Histórico de consumo en m³
│       ├── documentos.py     # Metadatos y descarga/stream de PDFs
│       ├── pagos.py          # Generación QR y conciliación/webhooks
│       └── router.py         # Router central v1
├── core/                # Configuración (.env), seguridad (JWT/bcrypt), redis
├── db/
│   ├── session.py       # Engine asíncrono SQLAlchemy + asyncpg
│   └── models/          # Modelos (Usuario, Suministro, Dispositivo, Documento, OTP, Pago)
├── integrations/        # Clientes httpx hacia COSMOL Legado y Meta Cloud API
├── schemas/             # Esquemas Pydantic v2 (I/O validation)
├── services/            # Lógica de negocio (AuthService, DeudaService, etc.)
└── tasks/               # BackgroundTasks para auditoría a ChatbotReportes
```

---

## 3. Funcionamiento Detallado por Módulos

### 3.1 Módulo de Autenticación e Identidad (`features/auth`)
- **Separación de Identidades:** 
  - *Usuario Digital:* Persona física identificada por su número de celular verificado.
  - *Código de Socio:* Identificador del contrato/suministro en COSMOL.
- **Estados de Sesión (GoRouter Guard):**
  - `initial`: Muestra `SplashScreen` mientras valida tokens locales en `flutter_secure_storage`.
  - `unauthenticated` / `locked`: Redirige a `LoginScreen`.
  - `onboardingRequired`: Redirige a `OnboardingScreen`.
  - `authenticated`: Redirige a `DashboardScreen`.
- **Flujo de Primer Acceso (Onboarding):**
  1. `OnboardingScreen`: El socio ingresa `cod_socio` + CI. El backend valida contra el sistema legado de COSMOL.
  2. `OnboardingStep2Screen`: El socio asocia su número de celular y elige el canal OTP: **WhatsApp Cloud API** (canal principal) o **SMS tradicional** (alternativo).
  3. Validación de OTP de 6 dígitos (Redis TTL: 5 min).
  4. Creación obligatoria de **Contraseña / PIN personal**. La CI queda invalidada permanentemente como contraseña, eliminando la vulnerabilidad de acceso con facturas físicas ajenas.
- **Login Habitual:**
  - Acceso con `cod_socio` + Contraseña/PIN personal, o mediante Biometría (`local_auth`: Huella dactilar / Face ID).
  - Emisión de Access Token JWT (~15 min) y Refresh Token (~7 días).
- **Control de Fuerza Bruta y Bloqueo:**
  - Rate limiting por IP en backend (`slowapi`).
  - Bloqueo progresivo tras **3 intentos fallidos consecutivos** (1 min → 5 min → 15 min → 30 min → 1 hora), desbloqueable inmediatamente completando verificación OTP al celular.
  - Sesión única por dispositivo (revocación al detectar nuevo Device ID).

### 3.2 Módulo de Deuda y Facturación (`features/deuda`)
- **Dashboard Principal:**
  - Muestra el saldo total acumulado en **Bs** del suministro seleccionado.
  - **Alerta visual:** La fecha de vencimiento se renderiza en **color rojo** destacado si la factura ya expiró.
  - Desglose de meses en mora y avisos de cobranza pendientes.
- **Optimización de Lectura:** Respuestas cacheadas en Redis (<20 ms) con TTL corto para mitigar sobrecarga en el sistema legado.

### 3.3 Módulo de Pagos y Redirección (`features/deuda` / `pagos`)
- **Botón "Pagar Ahora":**
  - Generación de **código QR interbancario válido y escaneable** mediante `qr_flutter`.
  - Redirección externa a aplicaciones de banca móvil o pasarelas web vía `url_launcher`.
- **Regla de Negocio Crítica:** COSMOL **no procesa pagos directamente** (cero alcance PCI-DSS).
- **Actualización de Saldo:** El backend recibe notificaciones vía Webhook o conciliación asíncrona y refresca el saldo.

### 3.4 Módulo de Documentos y Facturas PDF (`features/documentos`)
- Repositorio digital con historial de:
  - Facturas con valor legal.
  - Avisos de cobranza.
  - Avisos de corte.
- **Visualización y Descarga:**
  - Visualización integrada con `PdfViewerScreen` (`flutter_pdfview`).
  - Descarga al almacenamiento local del dispositivo (`path_provider` + `open_filex`).
  - Backend sirve documentos desde MinIO (Object Storage) mediante streams autenticados o URLs firmadas temporales.

### 3.5 Módulo de Historial de Consumo Analítico (`features/consumo`)
- Visualización de consumo en $m^3$ de los últimos **6 meses mínimo**.
- Gráficos interactivos de barras o líneas con `fl_chart`.
- Ejes claros: Meses vs. Volumen consumido ($m^3$).

### 3.6 Módulo Multicuenta (`features/multicuenta`)
- Permite que un único usuario verificado gestione múltiples suministros (`cod_socio`).
- **Pantallas:** `SuppliesListScreen` (listado y cambio de suministro activo) y `BindSupplyScreen` (vincular nuevo suministro).
- Selector rápido en el header del Dashboard con soporte de alias personalizados (*"Mi Casa"*, *"Alquiler Bolívar"*).
- **Matriz de Roles y Privilegios por Suministro:**
  - **Modo Titular:** Requiere validación de `cod_socio` + CI del titular. Acceso irrestricto: histórico completo, facturas con valor legal en PDF y avisos de corte.
  - **Modo Consulta y Pago (Inquilino / Tercero):** Requiere únicamente `cod_socio`. Permite consultar saldo adeudado y generar QR de pago, **enmascarando y ocultando datos sensibles del titular** (CI, nombre completo confidencial, histórico detallado).

### 3.7 Módulo de Perfil y Configuración (`features/perfil`)
- Datos del perfil digital asociado al número de celular.
- Configuración de biometría (habilitar/deshabilitar huella o Face ID).
- Cambio de Contraseña / PIN personal.
- Gestión de dispositivos vinculados y cierre de sesión seguro (limpieza de `flutter_secure_storage` y revocación de refresh token).

---

## 4. Puntos de Integración Externa y Flujo de Auditoría

1. **Sistema Legado COSMOL:**
   - Comunicación saliente exclusiva desde `backend-api` mediante peticiones asíncronas HTTP (`httpx`) con connection pooling y timeouts controlados.
   - El cliente Flutter **nunca** interactúa directamente con el sistema legado.
2. **Base de Datos ChatbotReportes (Auditoría de un solo sentido):**
   - El backend despacha eventos de auditoría (login exitoso/fallido, inicio de pago, descarga de facturas) hacia la base de datos de ChatbotReportes en segundo plano (`BackgroundTasks`).
   - Integración unidireccional (solo `INSERT`): esta app nunca lee ni gestiona datos de ChatbotReportes.
3. **Servicio OTP Dual (Meta WhatsApp Cloud API / Pasarela SMS):**
   - Integración directa desde `backend-api` para el envío de códigos OTP de 6 dígitos.
4. **Pasarelas Bancarias y de Pago:**
   - Generación de payload para QR y recepción de Webhooks de confirmación.

---

## 5. Fuera de Alcance (Límites Explícitos)

- **Procesamiento directo de tarjetas/pagos dentro de la app:** Solo redirección externa y generación de QR interbancario.
- **Módulo de reclamos técnicos y averías:** Se gestiona exclusivamente por el canal oficial existente (Chatbot de WhatsApp de COSMOL).
- **Panel administrativo propio:** La app no cuenta con interfaz de administración interna. Los reportes y la reportería se consultan en el proyecto **ChatbotReportes**.

---

## 6. Stack Tecnológico Consolidado

| Capa / Módulo | Tecnología / Librería | Rol y Justificación |
|---|---|---|
| **Frontend Base** | Flutter 3.x + Dart | Base unificada omnicanal (Android, iOS, Web). |
| **Arquitectura Frontend** | Clean Architecture | Separación en capas: Presentación, Dominio y Datos. |
| **Gestión de Estado** | Riverpod | Manejo reactivo y desacoplado del estado global y de sesión. |
| **Enrutamiento** | `go_router` | Rutas declarativas y redirecciones por guards de autenticación. |
| **Cliente HTTP** | `dio` + interceptores | Inyección de JWT, manejo de refresh token silencioso y reintentos. |
| **Almacenamiento Local** | `flutter_secure_storage` + `hive_flutter` | Cifrado hardware de tokens (KeyStore/KeyChain) y caché offline de saldos. |
| **Visualización & Gráficos** | `fl_chart` + `qr_flutter` + `flutter_pdfview` | Renderizado de consumo analítico, códigos QR y visor de PDFs. |
| **Backend Framework** | FastAPI (Python 3.12+) | BFF asíncrono de alto rendimiento con ASGI `uvicorn[standard]`. |
| **Base de Datos Propia** | PostgreSQL 16 + `alembic` | Almacén de usuarios, suministros, bloqueos, tokens y auditoría local. |
| **Driver BD** | `asyncpg` + `sqlalchemy[asyncio]` | Conexión no bloqueante a PostgreSQL. |
| **Caché y Throttling** | Redis 7 + `slowapi` | Respuestas de deuda en caché (<20 ms), rate limit y control de fuerza bruta. |
| **Almacenamiento de PDFs** | MinIO (S3-compatible) + `boto3` | Almacenamiento eficiente de objetos desacoplado de la BD relacional. |
| **Reverse Proxy & TLS** | Caddy v2 | Terminación SSL automática, proxy pass a FastAPI y hosting estático Flutter Web. |
| **Auditoría Externa** | `BackgroundTasks` (FastAPI) | Despacho asíncrono de eventos a la BD de `ChatbotReportes`. |
| **Notificaciones** | Firebase Cloud Messaging (FCM) | Recordatorios de vencimiento, avisos de corte y pagos. |
| **Contenedores** | Docker + Docker Compose | Orquestación reproducible de microservicios backend. |

---

## 7. Topología de Red e Infraestructura Docker

```
                              [ INTERNET ]
                                   │
                ┌──────────────────┴──────────────────┐
                │      HTTPS (443) / HTTP (80)        │
                ▼                                     ▼
    [ App Móvil Flutter ]                     [ Navegador Web ]
  (Android / iOS vía API)                    (Build Flutter Web)
                │                                     │
                └──────────────────┬──────────────────┘
                                   │
                                   ▼
                   ╔═══════════════════════════════════╗
                   ║       gateway-caddy (Docker)      ║
                   ║   - Terminación SSL Automática    ║
                   ║   - Servidor estático Flutter Web ║
                   ╚═════════════════╤═════════════════╝
                                     │ Proxy Pass interno (HTTP :8000)
╔════════════════════════════════════╪════════════════════════════════════╗
║ RED INTERNA DOCKER (`cosmol_net` - Aislada de internet público)          ║
║                                    ▼                                     ║
║                         ╔═════════════════════╗                          ║
║                         ║ backend-api (FastAPI║                          ║
║                         ║   Puerto 8000)      ║                          ║
║                         ╚═══╤═════════╤═════╤═╝                          ║
║      SQL Async (:5432)      │         │     │     S3 API (:9000)         ║
║   ┌─────────────────────────┘         │     └────────────────────────┐   ║
║   ▼                                   ▼                              ▼   ║
║ ╔═══════════════╗           ╔═══════════════╗              ╔═══════════╗ ║
║ ║  db-postgres  ║           ║  cache-redis  ║              ║ storage-  ║ ║
║ ║  (Port 5432)  ║           ║  (Port 6379)  ║              ║ minio:9000║ ║
║ ╚═══════════════╝           ╚═══════════════╝              ╚═══════════╝ ║
╚════════════════════════════════════╪════════════════════════════════════╝
                                     │
                Salida saliente (Egress) desde backend-api:
                ├────► Sistema Legado COSMOL (API/BD Lectura async con httpx)
                ├────► BD ChatbotReportes (Auditoría en segundo plano)
                └────► Pasarelas de Pago / Meta API WhatsApp / SMS
```

- **Aislamiento de Red:** `db-postgres`, `cache-redis` y `storage-minio` operan dentro de la red privada `cosmol_net` sin exponer puertos directos a internet.
- **Acceso Centralizado:** Solo `gateway-caddy` expone los puertos estándar `80` y `443`.

---

## 8. Principios de Desarrollo y Reglas de Calidad

1. **Flutter como Cliente Ligero:** Toda validación crítica, regla de negocio, verificación de roles (Titular vs Inquilino) y rate limiting reside en el backend FastAPI.
2. **Desacoplamiento Estricto:** Flutter nunca conoce la estructura de base de datos interna ni del sistema legado.
3. **Manejo Seguro de Secretos y Sesiones:** Tokens en `flutter_secure_storage`, contraseñas con hash bcrypt en PostgreSQL, HTTPS obligatorio y revisión contra lineamientos **OWASP MASVS**.
4. **Resiliencia Offline:** Flutter mantendrá caché local con `hive_flutter` de la última consulta válida para operar en condiciones de baja conectividad.
