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
* **`storage-minio`**: Object Storage S3 expuesto en `:9000` (API) y `:9001` (Consola Web).
* **`gateway-caddy`**: Caddy v2 Reverse Proxy expuesto en `:80` enrutando hacia FastAPI.

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
│   │   └── v1/
│   │       ├── health.py       # Endpoint de verificación de salud del sistema
│   │       └── router.py       # [ROUTER MAESTRO] Agregador de todos los submódulos
│   ├── core/
│   │   ├── config.py           # Variables de entorno tipadas con Pydantic Settings
│   │   └── redis.py            # Pool y cliente asíncrono de Redis
│   ├── db/
│   │   ├── models/             # Modelos ORM de SQLAlchemy
│   │   │   └── base.py         # BaseModel abstracto (UUID, created_at, updated_at)
│   │   └── session.py          # Motor asíncrono (asyncpg), sesiones y dependencia get_db
│   ├── integrations/           # Clientes HTTP (COSMOL legado, WhatsApp Cloud API, SMS)
│   ├── schemas/                # DTOs y validación de esquemas con Pydantic v2
│   ├── services/               # Lógica de negocio desacoplada (Auth, Deuda, Facturas)
│   ├── tasks/                  # BackgroundTasks (Auditoría hacia ChatbotReportes)
│   └── main.py                 # Instancia principal de FastAPI, CORS y ciclo de vida
├── tests/                      # Suite de pruebas automatizadas con pytest
│   ├── conftest.py             # Fixtures globales (cliente HTTP asíncrono)
│   └── test_health.py          # Prueba básica de conectividad
├── Dockerfile                  # Contenedor de desarrollo Python 3.12-slim
├── pytest.ini                  # Configuración de pytest (asyncio_mode = auto)
└── requirements.txt            # Dependencias del proyecto
```

---

## 3. Inicio Rápido (Quickstart)

### Opción A: Levantar Todo con Docker (Recomendada)
Desde la raíz del repositorio (`d:\COSMOL-app`):

```bash
# 1. Asegúrate de tener copiado el archivo de variables (ya generado)
# docker-compose leerá automáticamente .env

# 2. Levantar todos los servicios en segundo plano
docker compose up -d

# 3. Ver logs en tiempo real del backend
docker compose logs -f backend-api

# 4. Verificar salud del backend
curl http://localhost:8000/api/v1/health
```

* **Documentación Interactiva (Swagger UI):** `http://localhost:8000/docs`
* **Especificación OpenAPI:** `http://localhost:8000/openapi.json`
* **Consola Web de MinIO:** `http://localhost:9001` (Usuario: `cosmol_minio_admin`, Clave: `cosmol_minio_secret_pass`)

---

## 4. Guía para Crear Modelos y Migraciones con Alembic

Todas las entidades de base de datos deben heredar de **`BaseModel`** (`app/db/models/base.py`), lo que les otorga automáticamente:
* `id`: Clave primaria UUID v4 generada automáticamente.
* `created_at`: Fecha y hora con zona horaria al crearse.
* `updated_at`: Fecha y hora con zona horaria que se actualiza en cada modificación.

### Paso 1: Definir el Modelo ORM
Crea el modelo en `app/db/models/` (ejemplo `app/db/models/user.py`):

```python
from sqlalchemy import String, Boolean, Integer, DateTime
from sqlalchemy.orm import Mapped, mapped_column
from app.db.models.base import BaseModel

class User(BaseModel):
    __tablename__ = "users"

    phone_number: Mapped[str] = mapped_column(String(20), unique=True, index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    failed_login_attempts: Mapped[int] = mapped_column(Integer, default=0)
    locked_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
```

### Paso 2: Exportarlo en `app/db/models/__init__.py`
Asegúrate de importar tu nuevo modelo en `app/db/models/__init__.py` para que Alembic lo detecte automáticamente:

```python
from app.db.models.base import BaseModel
from app.db.models.user import User

__all__ = ["BaseModel", "User"]
```

### Paso 3: Generar y Aplicar la Migración
Desde dentro del contenedor o en local con la base de datos levantada:

```bash
# Dentro del contenedor Docker:
docker compose exec backend-api alembic revision --autogenerate -m "create_users_table"
docker compose exec backend-api alembic upgrade head

# O desde tu terminal local (si tienes el venv activo):
cd backend
alembic revision --autogenerate -m "create_users_table"
alembic upgrade head
```

---

## 5. Guía para Agregar Nuevos Módulos y Endpoints

Para no modificar `app/main.py` constantemente y evitar conflictos de Git:

1. **Crea tus endpoints:** En `app/api/v1/auth.py` (o la subcarpeta correspondiente):
   ```python
   from fastapi import APIRouter

   router = APIRouter()

   @router.post("/verify-socio")
   async def verify_socio():
       return {"status": "ok"}
   ```

2. **Engánchalo en `app/api/v1/router.py`:**
   ```python
   from app.api.v1.auth import router as auth_router

   api_router.include_router(auth_router, prefix="/auth", tags=["Autenticación"])
   ```
   *¡Listo! Automáticamente estará disponible en `/api/v1/auth/verify-socio` y en Swagger UI.*

---

## 6. Ejecución de Pruebas Automatizadas

El entorno está configurado con `pytest` y soporte asíncrono nativo (`pytest-asyncio` con `asyncio_mode = auto`):

```bash
# Dentro del contenedor Docker:
docker compose exec backend-api pytest

# O desde la terminal local:
cd backend
pytest
```

Para escribir una prueba de endpoint, usa el fixture `client` disponible en `conftest.py`:

```python
import pytest
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_endpoint(client: AsyncClient):
    response = await client.get("/api/v1/health")
    assert response.status_code == 200
```
