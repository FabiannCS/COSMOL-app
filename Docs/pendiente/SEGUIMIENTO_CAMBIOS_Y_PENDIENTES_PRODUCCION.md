# Bitácora de Seguimiento de Cambios y Pendientes de Producción

> **Ecosistema Integrado:** COSMOL-app (App de Socios) · Cosmol-Chatbot (WhatsApp Bot & Caddy Proxy) · COSMOL-Reportes (Dashboard Operativo)  
> **Servidor Central de Despliegue:** Ubuntu Server (`10.129.1.105`)  
> **Dominio Oficial:** `https://chatbot.cosmol.com.bo`  
> **Fecha de Inicio de Seguimiento:** 23 de Septiembre de 2026  
> **Estado General:** Fase de Estabilización de Conectividad, Compilación y Producción

---

## 1. Resumen Ejecutivo de la Situación

Al iniciar la unificación del ecosistema, los tres proyectos operaban con silos de configuración independientes:
1. La aplicación móvil de socios fallaba al compilar localmente debido a discrepancias en el SDK de Dart y bloqueos de Gradle en Windows.
2. Al intentar conectarse al servidor en producción, la app recibía primero un error **HTTP 404** (Caddy enrutaba a n8n en lugar de FastAPI) y luego un error **HTTP 500** (tablas relacionales no creadas en PostgreSQL).
3. Existían diferencias en puertos, variables de red y configuraciones de seguridad entre los tres repositorios.

A continuación se detalla cada cambio aplicado, su impacto directo en el sistema y los pendientes críticos restantes.

---

## 2. Cambios Realizados por Proyecto y su Influencia

### A. Proyecto: `COSMOL-app` (Frontend Flutter)

| Archivo Modificado | Cambio Realizado | Justificación Técnica | Influencia / Impacto |
|---|---|---|---|
| [`frontend/pubspec.yaml`](file:///d:/COSMOL-app/frontend/pubspec.yaml#L22) | `sdk: ^3.13.3` ➔ `sdk: '>=3.3.0 <4.0.0'` | La versión `^3.13.3` fue colocada por confusión con la versión de Flutter. En Dart la versión actual instalada es `3.10.4`. | **Eliminó el error de dependencias:** `flutter pub get` resolvió al 100% todos los paquetes sin advertencias. |
| [`supplies_list_screen.dart`](file:///d:/COSMOL-app/frontend/lib/features/multicuenta/presentation/screens/supplies_list_screen.dart#L74) | Parámetro `(_, _)` ➔ `(_, __)` en `separatorBuilder` | En Dart, dos identificadores idénticos `_` en la misma firma generan error de nombre duplicado. | **Solucionó error de compilación estática** detectado por el analizador de Dart. |
| [`suministro_selector_dropdown.dart`](file:///d:/COSMOL-app/frontend/lib/features/multicuenta/presentation/widgets/suministro_selector_dropdown.dart#L199) | Parámetro `(_, _)` ➔ `(_, __)` en `separatorBuilder` | Mismo conflicto de parámetros anónimos en el constructor de lista. | **Solucionó el segundo error de análisis.** |
| [`app_config.dart`](file:///d:/COSMOL-app/frontend/lib/core/network/app_config.dart#L1-L25) | Eliminado `import 'dart:io'` y ajustado `if (kIsWeb && kDebugMode)` | Si `kIsWeb` no valida `kDebugMode`, una compilación Web para producción apuntaba a `localhost:8000` en lugar de la URL oficial. | **Protege las compilaciones web:** La app web en producción siempre usará `https://chatbot.cosmol.com.bo/api/v1`. |
| Git Tracking (`.git`) | `git rm --cached` de `.dart_tool/` y `.flutter-plugins-dependencies` | Esos archivos contenían rutas absolutas de la máquina del desarrollador anterior (`C:/Users/Lenovo/...`). | **Repositorio limpio:** Evita conflictos de merge entre desarrolladores con nombres de usuario distintos (`Lenovo` vs `airey`). |
| [`android/app/build.gradle.kts`](file:///d:/COSMOL-app/frontend/android/app/build.gradle.kts#L2) | Agregado `id("kotlin-android")` en `plugins` | El script incluía `kotlin { compilerOptions }` pero el plugin de Kotlin no estaba aplicado al módulo. | **Gradle reconoció las opciones de Kotlin:** Eliminó los errores `Unresolved reference 'compilerOptions'` y `jvmTarget`. |
| [`android/gradle.properties`](file:///d:/COSMOL-app/frontend/android/gradle.properties#L7) | Agregado `kotlin.incremental=false` | En Windows con Gradle 9 y Kotlin 2, la compilación paralela de plugins (`device_info_plus`, `share_plus`) colisionaba al bloquear la caché `PersistentHashMap`. | **Compilación paralela exitosa:** Eliminó las excepciones `Storage is already registered` y `Could not close incremental caches`. |
| [`android/app/proguard-rules.pro`](file:///d:/COSMOL-app/frontend/android/app/proguard-rules.pro) | Creación del archivo con reglas estándar de Flutter | AGP 9.1 con R8 exige obligatoriamente este archivo para optimizar en modo release. | **Permitió compilar el APK de producción:** `flutter build apk --release` generó exitosamente `app-release.apk` (64 MB). |
| Dispositivo Móvil USB / ADB | Ejecución de `adb uninstall bo.cosmol.app.cosmol_app` | Error `INSTALL_FAILED_UPDATE_INCOMPATIBLE`: el smartphone tenía instalada una compilación firmada con la clave debug de la máquina anterior. | **Instalación limpia en hardware:** Permitió instalar y ejecutar el nuevo APK generado localmente sin errores de firma. |

---

### B. Proyecto: `COSMOL-app` (Backend FastAPI y Base de Datos)

| Componente | Acción Ejecutada | Causa Raíz | Influencia / Impacto |
|---|---|---|---|
| **Base de Datos PostgreSQL** (`cosmol-db-postgres`) | Ejecución de `docker exec -it cosmol-backend-api alembic upgrade head` | El contenedor PostgreSQL se levantó limpio, pero nunca se habían ejecutado las migraciones iniciales de Alembic. | **Eliminó el error HTTP 500:** Se crearon las tablas `usuarios`, `suministros`, `dispositivos`, `otps`, `documentos` y `auditoria_pagos`. La app ya puede verificar socios (`11543`) y autenticarse. |

---

### C. Proyecto: `Cosmol-Chatbot` (Proxy Inverso Caddy e Infraestructura)

| Componente / Archivo | Cambio Realizado | Causa Raíz | Influencia / Impacto |
|---|---|---|---|
| [`Caddyfile`](file:///d:/Cosmol-Chatbot/Caddyfile#L8-L19) y reinicio de Caddy | Configurado bloque `/api/v1/*`, `/docs*`, `/openapi.json` hacia `host.docker.internal:8000` | Caddy recibía las peticiones del celular pero las enviaba a **n8n** (puerto 5678) porque no conocía la ruta `/api/v1/*`. n8n respondía 404. | **Eliminó el error HTTP 404:** El tráfico de la app móvil ahora entra de forma transparente por el puerto seguro 443 estándar sin requerir apertura de puertos en el firewall FortiGate. |

---

## 3. Estado Actual de la Conectividad

```
  [ Celular del Socio / App Flutter ]
                  │
                  ▼ HTTPS :443 (Certificado TLS Oficial)
        https://chatbot.cosmol.com.bo/api/v1
                  │
                  ▼
         [ Caddy Proxy Inverso ]
                  │
                  ▼ host.docker.internal:8000
    [ cosmol-backend-api (FastAPI) ] ───► Conexión interna ───► [ cosmol-db-postgres ] (Tablas listas)
                  │
                  ├───► Conexión interna ───► [ cosmol-cache-redis ] (Sesiones y rate limit)
                  │
                  └───► HTTP Asíncrono ───► [ cosmol_reportes_app:8082 ] (Auditoría de eventos)
```

* **Compilación Móvil:** Genera ejecutables listos para distribución y pruebas:
  - **APK Debug (Pruebas USB/Emulador):** `frontend/build/app/outputs/flutter-apk/app-debug.apk` (~170 MB)
  - **APK Release (Producción Optimizada R8):** `frontend/build/app/outputs/flutter-apk/app-release.apk` (~64 MB)
* **Enrutamiento Web:** Operativo con SSL en puerto 443 estándar (`https://chatbot.cosmol.com.bo/api/v1`).
* **Persistencia:** Tablas relacionales creadas y activas en PostgreSQL (`cosmol-db-postgres`).

---

## 4. Inconsistencias y Pendientes Críticos por Resolver

A partir de este punto, se deben abordar los siguientes elementos identificados durante la auditoría arquitectónica:

### 🔴 Prioridad Alta

#### 1. Puerto de Respaldo 8083 en Docker ([`Cosmol-Chatbot/docker-compose.yml`](file:///d:/Cosmol-Chatbot/docker-compose.yml#L64))
* **Problema:** En [`Cosmol-Chatbot/Caddyfile`](file:///d:/Cosmol-Chatbot/Caddyfile#L33) está configurado el puerto 8083 como respaldo para la API de la app, pero en su `docker-compose.yml` el contenedor `caddy` no tiene mapeado el puerto `8083:8083`.
* **Acción requerida:** Decidir si se expone `"8083:8083"` en `docker-compose.yml` para habilitar el respaldo, o si se retira ese bloque de Caddy manteniendo exclusivamente el puerto estándar 443.

#### 2. Conflicto de CORS en FastAPI ([`COSMOL-app/backend/app/main.py`](file:///d:/COSMOL-app/backend/app/main.py#L55))
* **Problema:** `BACKEND_CORS_ORIGINS` tiene como valor por defecto `["*"]` y `CORSMiddleware` se inicializa con `allow_credentials=True`. La especificación W3C prohíbe el comodín `*` cuando se habilitan credenciales, lo cual bloqueará peticiones web cross-origin desde navegadores en producción.
* **Acción requerida:** Definir la lista explícita de orígenes permitidos (ej. `https://chatbot.cosmol.com.bo`, orígenes locales de desarrollo) en `BACKEND_CORS_ORIGINS`.

#### 3. Falta de Migración Defensiva para `trabajo_seguimiento` en COSMOL-Reportes
* **Problema:** La tabla `trabajo_seguimiento` (usada en `OperadorController` y `AdministradorController` para marcar trabajos como `NO CONCLUIDO` o `NO PROCEDENTE`) solo existe en `init.sql`. En bases de datos que ya tienen su volumen Docker creado, `init.sql` no se reejecuta, lo que provocará un error 500 (`relation "trabajo_seguimiento" does not exist`) al acceder al módulo de operadores.
* **Acción requerida:** Incorporar en [`TrabajoSeguimiento.php`](file:///d:/COSMOL-Reportes/app/Models/TrabajoSeguimiento.php) un bloque de creación defensiva idempotente (`CREATE TABLE IF NOT EXISTS trabajo_seguimiento ...`), idéntico al que ya tiene `Reporte.php`.

---

### 🟡 Prioridad Media

#### 4. Ausencia de Exportación CSV en Pantalla de App de Socios ([`COSMOL-Reportes`](file:///d:/COSMOL-Reportes))
* **Problema:** El endpoint `/reportes/exportar` excluye explícitamente los registros de la App Móvil (`id_usuario != 3`). En la vista [`/reportes/app-socios`](file:///d:/COSMOL-Reportes/app/Views/reportes/app_socios.php) no existe botón ni método para descargar los registros de auditoría de los socios en formato CSV/Excel.
* **Acción requerida:** Crear el método `exportarAppSocios()` en `ReporteController.php` y agregar el botón de descarga en la cabecera de la vista `app_socios.php`.

#### 5. Riesgo de Colisión de Puerto PostgreSQL en Host (`COSMOL-app`)
* **Problema:** [`COSMOL-app/docker-compose.yml`](file:///d:/COSMOL-app/docker-compose.yml#L33) expone `5432:5432` en el host. Si en la máquina host o servidor corre otro PostgreSQL nativo, el contenedor no podrá iniciar.
* **Acción requerida:** Mapear a un puerto alternativo externo (ej. `5435:5432`), manteniendo el puerto 5432 dentro de la red interna de Docker.

#### 6. Activación Real de Mensajería WhatsApp OTP (`COSMOL-app`)
* **Problema:** En [`COSMOL-app/.env`](file:///d:/COSMOL-app/.env#L45) la variable `MOCK_MESSAGING` está en `true` y faltan `WHATSAPP_PHONE_NUMBER_ID` y `WHATSAPP_ACCESS_TOKEN`.
* **Acción requerida:** Para la salida a producción oficial con socios reales, copiar las credenciales oficiales de Meta Cloud API de `Cosmol-Chatbot` y verificar la plantilla `codigo_autenticacion_cosmol` en Meta Business Suite.

---

## 5. Control de Revisiones

| Versión | Fecha | Autor / Responsable | Descripción |
|---|---|---|---|
| **1.0.0** | 23/09/2026 | Equipo de Desarrollo / Antigravity | Creación de bitácora inicial: resolución de dependencias, compilación Android release, enrutamiento Caddy y tablas Alembic. |
