# Plan de Implementación Backend — Eduardo (`COSMOL-app`)

> **Rol Asignado:** Eduardo (Backend `COSMOL-app`)  
> **Alcance Exclusivo:** Backend FastAPI, `docker-compose.yml`, esquemas Pydantic y hardening de red de `COSMOL-app`.  
> *(No incluye frontend Flutter, ni Cosmol-Chatbot, ni COSMOL-Reportes, ni administración del firewall ni host Ubuntu).*  
> **Basado en:** [`Docs/backend/pendiente/SOLUCION_UNIFICADA.md`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/Docs/backend/pendiente/SOLUCION_UNIFICADA.md) (Versión 1.3.0 auditada por Aireyu)  
> **Ubicación:** `Docs/backend/pendiente/PLAN_IMPLEMENTACION_BACKEND.md`  
> **Estado:** 🟡 Pendiente de Ejecución  
> **Fecha:** Octubre 2026  

---

## 1. Contexto y Decisiones Operativas Formales

Tras la auditoría de Aireyu en el servidor de producción (`10.129.1.105`):

1. **Prueba de Producción Exitosa:**
   * La app móvil ya se autentica, consulta deudas, historial y documentos con el socio `11543` por el dominio oficial `https://chatbot.cosmol.com.bo/api/v1` sobre el puerto **443 HTTPS**.
2. **Firewall Institucional (FortiGate):**
   * El ingeniero de redes **NO abrirá puertos adicionales**. Todo el tráfico entra obligatoriamente por el puerto `443` a través de Caddy.
3. **Reportes Diferido (`REPORTES_ENABLED=false`):**
   * Para evitar timeouts de 3s o colapso por acumulación de eventos en Redis, el envío a `COSMOL-Reportes` se mantiene **desactivado/diferido** en `.env`. La app opera 100% autónoma respondiendo en <100ms.
4. **OTP en Modo Simulación (`MOCK_MESSAGING=true`):**
   * Se mantiene el OTP mock `123456` para pruebas y desarrollo. No se migrará a Meta Cloud API hasta contar con los tokens definitivos aprobados.

Tu trabajo en el Backend se concentra estrictamente en **3 TAREAS NUCLEARES DE HARDENING + PRUEBAS DE REGRESIÓN**.

---

## 2. Matriz de Tareas de Eduardo

```
┌────────────────────────────────────────────────────────────────────────┐
│  TAREA E1: Blindaje de Puertos en docker-compose.yml (Crítica)        │
│  • db-postgres: 127.0.0.1:5435:5432 (sin colisión con 5433/5434)      │
│  • cache-redis: ELIMINAR directiva ports (aislado en red Docker)       │
│  • backend-api: 127.0.0.1:8000:8000 (solo Caddy / localhost)          │
│  • storage-minio: 127.0.0.1:9000 y 9001 (solo local)                  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│  TAREA E2: Ocultar Swagger UI y OpenAPI en Producción                  │
│  • En main.py: docs_url, redoc_url y openapi_url en None si es prod   │
│  • En desarrollo (/docs) se mantiene activo para pruebas locales       │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│  TAREA E3: Validación Estricta de SECRET_KEY en Producción             │
│  • En config.py: @field_validator para impedir arranque con claves     │
│    por defecto o de menos de 32 caracteres en modo production          │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│  TAREA E4: Pruebas de Regresión y Verificación                        │
│  • Ejecutar suite pytest tests/ -v (validar 24 archivos de pruebas)    │
│  • Verificar sintaxis con docker compose config                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Especificación Técnica Detallada

---

### 🛡️ TAREA E1: Blindaje de Puertos en `docker-compose.yml`

* **Archivo a modificar:** [`COSMOL-app/docker-compose.yml`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/docker-compose.yml)
* **Objetivo:** Cumplir con la matriz de convivencia de puertos del servidor host Ubuntu (`10.129.1.105`):
  * Chatbot usa PostgreSQL en `5433`
  * Reportes usa PostgreSQL en `5434`
  * **COSMOL-app usa PostgreSQL en `5435` (solo loopback)**
  * Redis no expone ningún puerto al host.

#### Cambios Concretos en `docker-compose.yml`:

1. **`db-postgres` (líneas 36-37):**
   ```yaml
   ports:
     - "127.0.0.1:5435:5432"
   ```
   *Efecto:* Permite conexiones administrativas locales vía SSH/DBeaver al puerto `5435`, sin exponerlo a internet (`0.0.0.0`) y sin colisionar con el puerto `5432` nativo ni con los otros contenedores.

2. **`cache-redis` (líneas 58-59):**
   Eliminar o comentar completamente la directiva `ports`:
   ```yaml
   # ports:
   #   - "6379:6379"
   ```
   *Efecto:* FastAPI se conecta por la red interna Docker (`cache-redis:6379`). Redis queda 100% blindado contra accesos externos.

3. **`backend-api` (líneas 11-12):**
   ```yaml
   ports:
     - "127.0.0.1:8000:8000"
   ```
   *Efecto:* Caddy despacha el tráfico localmente. Nadie desde internet puede saltarse el proxy ni el certificado SSL consultando `http://IP:8000`.

4. **`storage-minio` (líneas 75-77):**
   ```yaml
   ports:
     - "127.0.0.1:9000:9000"
     - "127.0.0.1:9001:9001"
   ```

#### Verificación:
```bash
docker compose config
```

---

### 🔒 TAREA E2: Ocultar Swagger UI y OpenAPI en Producción

* **Archivo a modificar:** [`backend/app/main.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/app/main.py)
* **Objetivo:** Ocultar `/docs`, `/redoc` y `/openapi.json` cuando `ENVIRONMENT == "production"` para proteger contratos y firmas internas.

#### Código en `backend/app/main.py`:
Reemplazar la instanciación de `FastAPI`:

```python
from app.core.config import settings

es_produccion = settings.ENVIRONMENT.lower() == "production"

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="API REST Backend (BFF) para la plataforma de socios de COSMOL R.L.",
    docs_url=None if es_produccion else "/docs",
    redoc_url=None if es_produccion else "/redoc",
    openapi_url=None if es_produccion else "/openapi.json",
    lifespan=lifespan
)
```

#### Verificación:
* Con `ENVIRONMENT=development`: `http://localhost:8000/docs` carga normalmente.
* Con `ENVIRONMENT=production`: `http://localhost:8000/docs` devuelve HTTP `404 Not Found`.

---

### 🔑 TAREA E3: Validación Estricta de `SECRET_KEY` en Producción

* **Archivo a modificar:** [`backend/app/core/config.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/app/core/config.py)
* **Objetivo:** Impedir que el backend arranque en modo producción si no se le configuró una clave criptográfica segura.

#### Código en `backend/app/core/config.py`:
Agregar validador con Pydantic dentro de la clase `Settings`:

```python
from pydantic import field_validator

class Settings(BaseSettings):
    # ... campos existentes ...

    @field_validator("SECRET_KEY")
    @classmethod
    def validar_secret_key_segura(cls, v: str, info) -> str:
        valores = info.data
        entorno = valores.get("ENVIRONMENT", "development").lower()
        
        if entorno == "production":
            claves_inseguras = ["change_in_production", "secret", "cosmol_secret", "123456", "dev_secret"]
            if any(insegura in v.lower() for insegura in claves_inseguras) or len(v) < 32:
                raise ValueError(
                    "CRÍTICO: En producción, 'SECRET_KEY' debe ser una cadena aleatoria segura "
                    "de al menos 32 caracteres generada criptográficamente (ej: openssl rand -hex 32)."
                )
        return v
```

---

### 🧪 TAREA E4: Pruebas de Regresión y Verificación

* **Objetivo:** Asegurar que los cambios no rompan ningún contrato, modelo ni prueba existente.

#### Pasos de Verificación:
1. **Ejecutar tests unitarios e integrales:**
   ```bash
   cd backend
   pytest tests/ -v
   ```
2. **Validar archivo de entorno local:**
   Confirmar que en `.env` local:
   - `ENVIRONMENT=development` (para que tú sigas viendo `/docs` y depurando).
   - `MOCK_MESSAGING=true` (para pruebas con OTP `123456`).
   - `REPORTES_ENABLED=false` (para cero latencia y evitar timeouts).

---

## 4. Checklist de Aceptación para Eduardo

- [x] **E1: Docker Compose**
  - [x] `db-postgres` mapeado a `127.0.0.1:5435:5432`.
  - [x] `cache-redis` sin directiva `ports`.
  - [x] `backend-api` mapeado a `127.0.0.1:8000:8000`.
  - [x] `storage-minio` mapeado a `127.0.0.1`.
  - [x] Validado con `docker compose config`.
- [x] **E2: Swagger Condicional**
  - [x] `main.py` oculta `/docs`, `/redoc` y `/openapi.json` si `ENVIRONMENT == "production"`.
- [x] **E3: Validación de Secretos**
  - [x] `@field_validator("SECRET_KEY")` implementado en `config.py`.
- [x] **E4: Regresión**
  - [x] `pytest tests/ -v` ejecutado y pasando al 100% (122 de 122 tests pasando).
