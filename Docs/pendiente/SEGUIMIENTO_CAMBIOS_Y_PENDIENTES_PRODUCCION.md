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

| Componente / Archivo | Cambio / Acción | Causa Raíz | Influencia / Impacto |
|---|---|---|---|
| **Base de Datos PostgreSQL** (`cosmol-db-postgres`) | Ejecución de `docker exec -it cosmol-backend-api alembic upgrade head` | El contenedor PostgreSQL se levantó limpio, pero nunca se habían ejecutado las migraciones iniciales de Alembic. | **Eliminó el error HTTP 500:** Se crearon las tablas `usuarios`, `suministros`, `dispositivos`, `otps`, `documentos` y `auditoria_pagos`. La app ya puede verificar socios (`11543`) y autenticarse. |
| [`backend/app/integrations/reportes_client.py`](file:///d:/COSMOL-app/backend/app/integrations/reportes_client.py#L48-L80) | Sanitización de URL en `_resolver_url_destino` y Circuit Breaker con cooldown de 15s | Error en producción: la URL configurada tenía `/api/v1`, produciendo `/api/v1/api/consultas` con timeout de 3s en ráfagas que congelaban las peticiones de la app móvil. | **Blindaje y Cero Latencia:** Sanea automáticamente `/api/v1` a `/api/consultas`. Si Reportes está offline, el cooldown de 15s descarta la espera de 3s y encola de inmediato en Redis sin congelar la app. |
| [`docker-compose.yml`](file:///d:/COSMOL-app/docker-compose.yml#L18) | Agregado `extra_hosts: ["host.docker.internal:host-gateway"]` a `backend-api` | En Linux, los contenedores Docker no resuelven `host.docker.internal` salvo que se declare explícitamente en el Compose. | **Conectividad Inter-Contenedores:** Permite que `cosmol-backend-api` alcance servicios en puertos del host como `cosmol_reportes_app:8082` de forma limpia. |

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

#### 2. Conflicto de CORS en FastAPI ([`COSMOL-app/backend/app/main.py`](file:///d:/COSMOL-app/backend/app/main.py#L55)) — ✅ RESUELTO
* **Resolución:** Se definió la lista explícita de orígenes en `config.py` (`https://chatbot.cosmol.com.bo`, `localhost`, etc.) y se implementó `allow_origin_regex` en `main.py` para cumplir estrictamente con la especificación W3C cuando `allow_credentials=True`.

#### 3. Migración Defensiva para `trabajo_seguimiento` en COSMOL-Reportes ([`app/Models/TrabajoSeguimiento.php`](file:///d:/COSMOL-Reportes/app/Models/TrabajoSeguimiento.php)) — ✅ RESUELTO
* **Resolución:** Se incorporó el constructor `__construct()` con `CREATE TABLE IF NOT EXISTS trabajo_seguimiento (...)` e índice, garantizando la creación de la tabla de forma automática e idempotente en cualquier entorno o volumen preexistente sin errores 500.

---

### 🟡 Prioridad Media

#### 4. Exportación CSV en Pantalla de App de Socios ([`COSMOL-Reportes`](file:///d:/COSMOL-Reportes)) — ✅ RESUELTO
* **Resolución:** Se implementó `getAllConsultasAppExport()` en `Reporte.php`, el método `exportarAppSocios()` en `ReporteController.php`, la ruta `/reportes/app-socios/exportar` en `routes.php` y el botón *"Exportar CSV"* con preservación de filtros en la vista `app_socios.php`.

#### 5. Riesgo de Colisión de Puerto PostgreSQL en Host (`COSMOL-app`)
* **Problema:** [`COSMOL-app/docker-compose.yml`](file:///d:/COSMOL-app/docker-compose.yml#L33) expone `5432:5432` en el host. Si en la máquina host o servidor corre otro PostgreSQL nativo, el contenedor no podrá iniciar.
* **Acción requerida:** Mapear a un puerto alternativo externo (ej. `5435:5432`), manteniendo el puerto 5432 dentro de la red interna de Docker.

#### 6. Activación Real de Mensajería WhatsApp OTP (`COSMOL-app`)
* **Problema:** En [`COSMOL-app/.env`](file:///d:/COSMOL-app/.env#L45) la variable `MOCK_MESSAGING` está en `true` y faltan `WHATSAPP_PHONE_NUMBER_ID` y `WHATSAPP_ACCESS_TOKEN`.
* **Acción requerida:** Para la salida a producción oficial con socios reales, copiar las credenciales oficiales de Meta Cloud API de `Cosmol-Chatbot` y verificar la plantilla `codigo_autenticacion_cosmol` en Meta Business Suite.

---

## 5. Diagnóstico de Incidencia en Vivo: Timeouts de Auditoría y Visualización en la App

### A. Causa Raíz de "Reportes aún no recibe los datos"
En los logs del servidor se detectó:
`[AUDITORIA TIMEOUT] Tiempo de espera agotado (3.0s) al enviar auditoría a http://chatbot.cosmol.com.bo:8082/api/v1/api/consultas.`

1. **Ruta con doble `/api` y sufijo `/v1`:**
   En el `.env` del servidor se configuró la URL con `/api/v1`. La lógica previa de `reportes_client.py` concatenó `/api/consultas` dando como resultado `/api/v1/api/consultas`. La API de COSMOL-Reportes solo expone `POST /api/consultas`.
2. **Puerto 8082 inaccesible por el dominio de Internet:**
   El puerto `8082` es el puerto de red interna de Docker en el servidor Ubuntu (`cosmol_reportes_app: 8082:80`). El dominio `chatbot.cosmol.com.bo` solo entra por Caddy (puertos 80, 443, 8081). Al consultar por el dominio externo, el firewall del servidor descarta la conexión y se produce el **timeout de 3 segundos**.
3. **Conexión interna correcta:**
   Como ambos servicios corren en el mismo servidor Ubuntu, la conexión debe ser directa sin salir a Internet:
   `REPORTES_API_URL=http://172.17.0.1:8082/api` (usando el host gateway del bridge Docker de Ubuntu).

### B. Causa de "Fue bien al comienzo hasta que colapsó y no vemos nada"
1. **Comportamiento del Socio 556:**
   Al consultar directamente la API comercial de COSMOL (`api.cosmol.com.bo`):
   - El socio **556** (Suárez Baltazar Víctor Hugo) tiene `deudas: []` (está 100% **al día**, saldo Bs 0.00).
   - Por esta razón, la app muestra legítimamente *Bs 0.00 / Al día con tus pagos* y 0 facturas pendientes. No es un error, es el estado real del socio.
   - Para validar pantallas con facturas activas, el socio **11543** tiene 2 facturas pendientes (Agosto y Septiembre 2026, total Bs 150.34).
2. **Degradación por cola de eventos acumulados:**
   Cada petición de la app móvil disparaba un background task que quedaba congelado 3 segundos esperando a Reportes. Esos eventos fallidos se acumularon en Redis (60 eventos en cola), y el worker periódico intentaba reintentarlos concurrentemente, agotando sockets y ralentizando las respuestas generales.

### C. Procedimiento Inmediato de Remediación en el Servidor Ubuntu (`10.129.1.105`)

```bash
# 1. En el archivo .env de COSMOL-app en el servidor, corregir la URL de reportes:
# Editar .env y colocar exactamente:
REPORTES_API_URL=http://172.17.0.1:8082/api

# 2. Purgar los 60 eventos atascados con timeout en Redis:
docker exec -it cosmol-cache-redis redis-cli del auditoria:cola_pendientes

# 3. Reiniciar el contenedor de FastAPI para aplicar cambios de entorno y de red:
docker compose restart backend-api
```

---

## 6. Control de Revisiones

| Versión | Fecha | Autor / Responsable | Descripción |
|---|---|---|---|
| **1.0.0** | 23/09/2026 | Equipo de Desarrollo / Antigravity | Creación de bitácora inicial: resolución de dependencias, compilación Android release, enrutamiento Caddy y tablas Alembic. |
| **1.1.0** | 23/09/2026 | Equipo de Desarrollo / Antigravity | Diagnóstico de colapso de auditoría: sanitización de URL `/api/consultas`, Circuit Breaker de 15s en `ReportesApiClient`, `extra_hosts` en Compose y guía de purga de Redis. |
| **1.2.0** | 01/10/2026 | Equipo de Desarrollo / Antigravity | Blindaje de lógica de negocio y estabilidad: admisión para desbloqueo/recuperación de PIN vía OTP, resolución de colisión multicuenta titular/inquilino, normalización telefónica, endpoint `POST /logout`, caché síncrona en memoria para `StorageService` (eliminando fallo post-logout en Android), desacoplamiento de generación pesada de PDFs en listado GET, aumento de timeout Informix a 8s, matcher Caddy `/api/v1*` y endpoint raíz `/api/v1/`. |

