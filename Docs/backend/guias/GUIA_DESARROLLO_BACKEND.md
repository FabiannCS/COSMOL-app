# Guía de Desarrollo Backend — COSMOL R.L.
> **Destinatario:** Desarrollador Backend (Dev 2) y Equipo de Desarrollo  
> **Fecha:** Septiembre 2026  
> **Ubicación:** `Docs/GUIA_DESARROLLO_BACKEND.md`  
> **Documentos de referencia:** `AGENTS.md` y `Docs/HOJA_DE_RUTA_DESARROLLO.md`

---

## 1. Visión General del Backend

El backend actúa como un **BFF (Backend-for-Frontend)** asíncrono desarrollado con **FastAPI (Python 3.12+)**, desacoplando la aplicación cliente (Flutter) de los sistemas legados de COSMOL y de la base de datos de auditoría de `ChatbotReportes`.

### Componentes de Infraestructura (Docker):
* **`backend-api`**: FastAPI corriendo con Uvicorn en `:8000` (con hot-reload en desarrollo montando `./backend:/app`).
* **`db-postgres`**: PostgreSQL 16 expuesto en `:5432` con volumen persistente `cosmol_postgres_data`.
* **`cache-redis`**: Redis 7 expuesto en `:6379` con volumen persistente `cosmol_redis_data`.
* **`storage-minio`**: Object Storage S3 expuesto en `:9000` (API) y `:9001` (Consola Web con imagen `quay.io/minio/minio:latest`).
* **`gateway-caddy`**: Reverse Proxy Caddy v2 (Comentado/Desactivado en `docker-compose.yml`; no se levanta en desarrollo, reservado para la etapa final).

---

## 2. Estructura del Código y Responsabilidades

```text
backend/
├── alembic/                    # Entorno de migraciones asíncronas
│   ├── env.py                  # Configuración asyncpg + Base.metadata
│   ├── script.py.mako          # Plantilla para generar revisiones
│   └── versions/               # Historial de migraciones SQL
├── alembic.ini                 # Configuración principal de Alembic
├── app/
│   ├── api/
│   │   ├── deps.py             # Dependencias centrales (get_db, get_redis, auth JWT)
│   │   └── v1/                 # Versión 1 de la API REST pública
│   │       ├── health.py       # Endpoint de verificación de salud del sistema
│   │       └── router.py       # [ROUTER MAESTRO] Agregador de todos los submódulos
│   ├── core/
│   │   ├── config.py           # Variables de entorno tipadas con Pydantic Settings
│   │   ├── exceptions.py       # Jerarquía AppException y manejador JSON estándar
│   │   ├── redis.py            # Pool y cliente asíncrono de Redis
│   │   └── security.py         # Criptografía bcrypt nativa y tokens JWT (access/refresh)
│   ├── db/
│   │   ├── models/             # Modelos ORM de SQLAlchemy (en español)
│   │   │   └── base.py         # BaseModel abstracto (UUID, created_at, updated_at)
│   │   └── session.py          # Motor asíncrono (asyncpg), sesiones y dependencia get_db
│   ├── integrations/           # Clientes HTTP externos (COSMOL legado, WhatsApp API, SMS)
│   │   └── base_client.py      # BaseApiClient asíncrono con pool y control de timeouts
│   ├── schemas/                # DTOs y validación de esquemas con Pydantic v2 (en español)
│   ├── services/               # Lógica de negocio desacoplada (en español)
│   ├── tasks/                  # BackgroundTasks (Auditoría hacia ChatbotReportes)
│   └── main.py                 # Instancia principal de FastAPI, CORS y ciclo de vida
├── tests/                      # Suite de pruebas automatizadas con pytest
│   ├── conftest.py             # Fixtures globales (cliente HTTP asíncrono)
│   ├── test_base_components.py # Pruebas de seguridad, tokens y excepciones
│   └── test_health.py          # Prueba básica de conectividad de servicios
├── Dockerfile                  # Contenedor de desarrollo Python 3.12-slim
├── pytest.ini                  # Configuración de pytest (asyncio_mode = auto)
└── requirements.txt            # Dependencias del proyecto
```

---

## 3. Convenciones de Nombres y Estilo (Inglés vs. Español)

Para mantener la máxima compatibilidad técnica con las herramientas del ecosistema Python sin sacrificar la claridad del negocio de COSMOL, se adopta la siguiente **regla de oro**:

> **"Inglés para el armazón técnico del framework — Español para la lógica de negocio y módulos de COSMOL".**

### 3.1 ¿Por qué la carpeta `v1`?
* `v1` significa **Versión 1 (Version 1)**.
* Es una práctica estándar obligatoria en APIs que alimentan aplicaciones móviles (Flutter). Cuando la app se publique en producción, los socios la tendrán instalada en sus teléfonos. Si dentro de un año se requiere un cambio estructural drástico, se creará `/api/v2/` en paralelo sin romper la aplicación instalada de los usuarios que aún no hayan actualizado.
* Por ello, todos los endpoints de negocio inician con el prefijo `/api/v1/...`.

### 3.2 Qué NO renombrar (Estándar Técnico / Framework)
Estas carpetas y archivos son reconocidos automáticamente por herramientas externas (Python, Docker, Pytest, Alembic). Alterarlas genera errores o exige configuraciones manuales propensas a fallos:

| Directorio / Archivo | Justificación Técnica |
| :--- | :--- |
| `backend/` | Convención universal para aislar el backend de la raíz del repo. |
| `alembic/` y `alembic.ini` | Nombre y archivo de configuración que busca el CLI de Alembic por defecto. |
| `tests/` | Directorio que `pytest` descubre automáticamente para ejecutar pruebas. |
| `app/core/` | Término estándar para configuración, variables y utilitarios transversales. |
| `app/api/v1/` | Estándar REST mundial de versionado de endpoints. |
| `app/db/` | Estándar para configuración y conexión a la base de datos (*database*). |

### 3.3 Qué SÍ nombrar en Español (Dominio y Lógica de Negocio COSMOL)
Todos los archivos, módulos y tablas que representen **conceptos de COSMOL y requerimientos funcionales** se nombrarán en **español**:

1. **Rutas y Endpoints (`app/api/v1/`):**
   * `autenticacion.py` ➔ Prefijo `/autenticacion` (ej: `/login`, `/verificar-otp`, `/recuperar-pin`)
   * `deuda.py` ➔ Prefijo `/deuda` (ej: `/resumen`, `/detallada`)
   * `pagos.py` ➔ Prefijo `/pagos` (ej: `/generar-qr`, `/estado-pago`)
   * `documentos.py` ➔ Prefijo `/documentos` (ej: `/facturas`, `/avisos-cobranza`, `/avisos-corte`)
   * `consumo.py` ➔ Prefijo `/consumo` (ej: `/historial-grafica`)

2. **Modelos de Base de Datos (`app/db/models/`):**
   * `usuario.py` (Tabla `usuarios` — usuario digital y credenciales)
   * `suministro.py` (Tabla `suministros` — contratos/códigos de socio enlazados, rol titular/inquilino)
   * `dispositivo.py` (Tabla `dispositivos` — sesiones únicas, device_id y tokens FCM)
   * `otp.py` (Tabla `otps` — registro de códigos enviados por WhatsApp o SMS)

3. **Lógica de Negocio y Servicios (`app/services/`):**
   * `servicio_autenticacion.py`
   * `servicio_deuda.py`
   * `servicio_pagos.py`
   * `servicio_documentos.py`

4. **Esquemas de Validación Pydantic (`app/schemas/`):**
   * `usuario.py`, `deuda.py`, `pago.py`, `documento.py`, `consumo.py`

5. **Columnas de Base de Datos y Variables:**
   * Usar los términos propios de la cooperativa: `cod_socio`, `ci`, `telefono`, `monto_bs`, `saldo_pendiente`, `fecha_vencimiento`, `mes_consumo`, `metros_cubicos`.

---

## 4. Componentes Base Transversales Listos para Usar

Antes de crear módulos de negocio, los desarrolladores ya cuentan con utilitarios probados que deben reutilizar:

1. **Seguridad y Criptografía (`app/core/security.py`):**
   * `get_password_hash(password: str) -> str`: Genera hash bcrypt nativo.
   * `verify_password(plain: str, hashed: str) -> bool`: Valida contraseñas.
   * `create_access_token(subject, extra_claims)`: Emite token JWT de 15 min.
   * `create_refresh_token(subject)`: Emite token JWT de 7 días.
   * `decode_token(token: str) -> dict`: Valida y decodifica tokens.

2. **Inyector de Dependencias (`app/api/deps.py`):**
   * `Depends(get_db)`: Inyecta la sesión asíncrona de PostgreSQL.
   * `Depends(get_redis)`: Inyecta el cliente asíncrono de Redis.
   * `Depends(get_current_user_id)`: Extrae y valida el Bearer JWT Token, retornando el UUID del usuario autenticado. Lanza `UnauthorizedException` automáticamente si el token es inválido o expiró.

3. **Excepciones y Respuestas de Error Estándar (`app/core/exceptions.py`):**
   * Usar `raise NotFoundException(...)`, `raise UnauthorizedException(...)`, `raise BadRequestException(...)`, etc.
   * Generan automáticamente una respuesta HTTP con formato uniforme para Flutter:
     ```json
     {
       "success": false,
       "error": {
         "code": "CODIGO_ERROR",
         "message": "Mensaje legible",
         "details": null
       }
     }
     ```

4. **Cliente HTTP Base para Integraciones (`app/integrations/base_client.py`):**
   * `BaseApiClient`: Administra `httpx.AsyncClient` persistente con pool de conexiones y timeouts estrictos. Base para consumir el sistema legado de COSMOL y la WhatsApp Cloud API.

---

## 5. Inicio Rápido (Quickstart con Docker)

Desde la raíz del repositorio (`d:\COSMOL-app`):

```bash
# 1. Levantar todos los servicios en segundo plano
docker compose up -d

# 2. Ver logs en tiempo real del backend
docker compose logs -f backend-api

# 3. Verificar salud del backend
curl http://localhost:8000/api/v1/health
```

* **Documentación Interactiva (Swagger UI):** `http://localhost:8000/docs`
* **Especificación OpenAPI:** `http://localhost:8000/openapi.json`
* **Consola Web de MinIO:** `http://localhost:9001` (Usuario: `cosmol_minio_admin`, Clave: `cosmol_minio_secret_pass`)

---

## 6. Guía para Crear Modelos y Migraciones con Alembic

Todas las entidades de base de datos deben heredar de **`BaseModel`** (`app/db/models/base.py`), lo que les otorga automáticamente:
* `id`: Clave primaria UUID v4 generada automáticamente.
* `created_at`: Fecha y hora con zona horaria al crearse.
* `updated_at`: Fecha y hora con zona horaria que se actualiza en cada modificación.

### Paso 1: Definir el Modelo ORM
Crea el modelo en `app/db/models/` siguiendo la convención en español (ejemplo `app/db/models/usuario.py`):

```python
from datetime import datetime
from sqlalchemy import String, Boolean, Integer, DateTime
from sqlalchemy.orm import Mapped, mapped_column
from app.db.models.base import BaseModel

class Usuario(BaseModel):
    __tablename__ = "usuarios"

    telefono: Mapped[str] = mapped_column(String(20), unique=True, index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    esta_activo: Mapped[bool] = mapped_column(Boolean, default=True)
    intentos_fallidos: Mapped[int] = mapped_column(Integer, default=0)
    bloqueado_hasta: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
```

### Paso 2: Exportarlo en `app/db/models/__init__.py`
Asegúrate de importar tu nuevo modelo en `app/db/models/__init__.py` para que Alembic lo detecte automáticamente:

```python
from app.db.models.base import BaseModel
from app.db.models.usuario import Usuario

__all__ = ["BaseModel", "Usuario"]
```

### Paso 3: Generar y Aplicar la Migración
Desde dentro del contenedor Docker:

```bash
# Generar revisión automática comparando modelos vs base de datos:
docker compose exec backend-api alembic revision --autogenerate -m "crear_tabla_usuarios"

# Aplicar migración:
docker compose exec backend-api alembic upgrade head
```

---

## 7. Guía para Agregar Nuevos Módulos y Endpoints

Para no modificar `app/main.py` constantemente y evitar conflictos de Git entre desarrolladores:

1. **Crea tus endpoints:** En `app/api/v1/autenticacion.py`:
   ```python
   from fastapi import APIRouter, Depends
   from app.api.deps import get_db

   router = APIRouter()

   @router.post("/verificar-socio")
   async def verificar_socio():
       return {"success": True, "mensaje": "Socio verificado correctamente"}
   ```

2. **Engánchalo en `app/api/v1/router.py`:**
   ```python
   from app.api.v1.autenticacion import router as auth_router

   api_router.include_router(auth_router, prefix="/autenticacion", tags=["Autenticación"])
   ```
   *¡Listo! Automáticamente estará disponible en `/api/v1/autenticacion/verificar-socio` y documentado en Swagger UI.*

---

## 8. Ejecución de Pruebas Automatizadas (Suite de 90 Tests)

El entorno está configurado con `pytest` y soporte asíncrono nativo (`pytest-asyncio` con `asyncio_mode = auto`). Toda la suite (90 pruebas) se ejecuta en Docker garantizando cero regresiones:

```bash
# Ejecutar toda la suite de pruebas (90 tests) dentro del contenedor:
docker compose exec backend-api pytest

# Ejecutar con detalles y tiempos por prueba (-v):
docker compose exec backend-api pytest -v
```

### 8.1 Política de Cero Mocks y Datos Reales
A partir de la consolidación de la Fase 4, el backend opera con `MOCK_COSMOL_LEGACY=False` y `MOCK_COSMOL_CONSUMO=False`:
* Todas las peticiones a socios consultan los endpoints oficiales de Informix (`http://api.cosmol.com.bo/api-consultas`).
* Las pruebas utilizan socios reales de Montero (`23807`, `556`, `540`, `1001`) para validar respuestas y casos de borde (deuda pendiente, consumo atípico, etc.).
* El servicio de caché en Redis (`cache-redis`) garantiza tiempos de respuesta `< 20 ms` en consultas subsecuentes de deudas y consumos.

