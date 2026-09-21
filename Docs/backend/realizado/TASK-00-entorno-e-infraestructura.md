# Tarea 00: Configuración de Entorno, Infraestructura Docker y Scaffolding Base

> **Estado:** COMPLETADO  
> **Fase:** Fase 0 — Cimientos de Infraestructura  
> **Fecha de conclusión:** Septiembre 2026  
> **Documento de referencia:** `Docs/HOJA_DE_RUTA_DESARROLLO.md`  
> **Ubicación:** `Docs/backend/realizado/TASK-00-entorno-e-infraestructura.md`

---

## 1. Objetivo

Establecer la infraestructura base de contenedores Docker (`docker-compose.yml`) con exposición directa de puertos a localhost para desarrollo ágil (sin red aislada en dev), y crear la estructura inicial de código para el **Backend (FastAPI)** y el **Frontend (Flutter)**.

---

## 2. Alcance y Entregables

### 2.1 Orquestación Docker
- [x] Crear `docker-compose.yml` para el entorno de desarrollo local con los siguientes servicios y puertos expuestos:
  - `backend-api` (FastAPI en Python 3.12 con recarga en vivo en `:8000`)
  - `db-postgres` (PostgreSQL 16 en `:5432` con volumen persistente `postgres_data`)
  - `cache-redis` (Redis 7 en `:6379` con volumen persistente `redis_data`)
  - `storage-minio` (MinIO API en `:9000` y Consola Web en `:9001` con volumen `minio_data`)
  - `gateway-caddy` (Caddy v2 Gateway en `:80` para redirección, servido y pruebas de proxy con `Caddyfile`)
- [x] Mapeo directo de puertos a `localhost` para conexión cómoda desde herramientas locales (DBeaver, Redis Insight, MinIO Web). *Nota: La red aislada `cosmol_net` se pospone para el entorno de producción.*
- [x] Crear archivo `.env.example` con variables de entorno para desarrollo y staging.

### 2.2 Scaffolding Backend (`/backend`)
- [x] Inicializar entorno de FastAPI con Python 3.12+.
- [x] Configurar dependencias en `requirements.txt` (`fastapi`, `uvicorn[standard]`, `pydantic-settings`, `sqlalchemy[asyncio]`, `asyncpg`, `alembic`, `redis`, `httpx`, `pyjwt`, `passlib[bcrypt]`, `slowapi`).
- [x] Configurar conexión asíncrona a PostgreSQL con SQLAlchemy y soporte de migraciones con Alembic.
- [x] Configurar cliente de conexión a Redis.
- [x] Implementar endpoint de salud (`GET /api/v1/health`) para verificar estado de PostgreSQL y Redis.

### 2.3 Scaffolding Frontend (`/frontend`)
- [x] Inicializar la base de código de Flutter con soporte Android, iOS y Web.
- [x] Configurar paquetes base en `pubspec.yaml` (`flutter_riverpod`, `go_router`, `dio`, `flutter_secure_storage`, `freezed_annotation`, `json_annotation`).
- [x] Definir la estructura de carpetas por Clean Architecture (`core/`, `features/`).
- [x] Implementar el tema visual base con la paleta de colores institucional de COSMOL.

### 2.4 Entorno de Pruebas Móvil (Hardware Real vía USB)
- [x] Verificar que el Android SDK y `adb` detecten el smartphone físico conectado por cable USB (`adb devices`).
- [x] Configurar el túnel de comunicación con el backend Docker ejecutando:
  ```bash
  adb reverse tcp:8000 tcp:8000
  ```
- [x] Asegurar que `flutter devices` liste el teléfono físico como target activo para depuración.

---

## 3. Criterios de Aceptación

1. El comando `docker compose up -d` levanta los 5 contenedores sin errores.
2. `curl http://localhost:8000/api/v1/health` (o a través de Caddy en `http://localhost/api/v1/health`) responde `200 OK` con estado de base de datos y caché conectados.
3. La documentación interactiva de Swagger UI está accesible en `http://localhost:8000/docs`.
4. El proyecto Flutter compila y ejecuta su pantalla inicial en el **teléfono móvil físico conectado por cable USB** sin emuladores.
5. El smartphone físico se comunica exitosamente con el backend Docker local mediante `adb reverse`.

---

## 4. Bitácora de Validación y Cierre

* **Infraestructura Docker:** 5/5 contenedores activos (`backend-api`, `db-postgres`, `cache-redis`, `storage-minio`, `gateway-caddy`).
* **Health Check:** `GET /api/v1/health` responde `200 OK` validando conexiones activas a PostgreSQL y Redis.
* **Migraciones:** Alembic configurado y ejecutado en el contenedor.
* **MinIO:** Bucket `cosmol-docs` inicializado y configurado.
