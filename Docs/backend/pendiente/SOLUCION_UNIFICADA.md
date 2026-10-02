# Plan Maestro de Solución Unificada: Seguridad, Red y Estabilización de Producción

> **Ecosistema Integrado:** `COSMOL-app` (App de Socios) · `Cosmol-Chatbot` (Proxy Caddy & Bot WhatsApp) · `COSMOL-Reportes` (Dashboard de Auditoría y Operaciones)  
> **Servidor Central de Despliegue:** Ubuntu Server (`10.129.1.105`)  
> **Dominio Oficial:** `https://chatbot.cosmol.com.bo`  
> **Fecha:** Octubre 2026 (Versión 1.3.0 - Guía Definitiva de Implementación de Seguridad)  
> **Estado de Producción:** ✅ **Prueba en Producción con ÉXITO:** Autenticación de socios, consulta de deudas, historial y documentos 100% operativos.  
> **Estrategia sobre Reportes:** ⏸️ **Envío a COSMOL-Reportes DIFERIDO (`REPORTES_ENABLED=false`):** La app opera de forma completamente autónoma para maximizar rendimiento y velocidad (<300ms). Se abordará en una fase posterior.  
> **Estrategia sobre OTP:** 🧪 **OTP en Modo Prueba (`MOCK_MESSAGING=true`):** Se mantiene el código mock `123456` para pruebas y desarrollo. No se migrará a Meta WABA hasta contar con credenciales definitivas.  
> **Objetivo de este Documento:** Proporcionar a **Eduardo** la guía exacta de implementación técnica para el **Hardening y Seguridad del Backend (`COSMOL-app`)**.

---

## 1. División Estricta de Responsabilidades y Límites de Código

> [!IMPORTANT]
> **Principio de Aislamiento Exclusivo de Repositorio:**  
> **Eduardo trabaja EXCLUSIVAMENTE dentro del repositorio `COSMOL-app`.**  
> Eduardo **NO debe modificar, configurar ni alterar** ningún archivo de `Cosmol-Chatbot` (Caddyfile, n8n, proxy), de `COSMOL-Reportes` (API PHP, base de datos de reportes) ni del sistema operativo host Ubuntu. Todas las configuraciones perimetrales de Caddy, certificados SSL y ajustes en los otros contenedores del servidor son gestionadas directamente por **Aireyu**.

| Responsable | Repositorio Exclusivo | Alcance de Modificaciones de Código | Lo que NO debe tocar |
|---|---|---|---|
| **Eduardo** | **`COSMOL-app`** | • `docker-compose.yml`<br>• `backend/app/main.py`<br>• `backend/app/core/config.py`<br>• `.env.example` | ❌ `Cosmol-Chatbot` (Caddyfile)<br>❌ `COSMOL-Reportes`<br>❌ Servidor Ubuntu / Firewall |
| **Aireyu** | **`Cosmol-Chatbot`**, **`COSMOL-Reportes`** y Servidor | • Proxy Caddy (puertos 80, 443, 8081)<br>• Certificados SSL y enrutamiento<br>• Host Ubuntu `10.129.1.105` | N/A (Administración perimetral y coordinación) |

---

## 2. El Dilema de los Puertos y la Realidad del Firewall

### 2.1 La Restricción Real
El ingeniero de redes **NO otorgará permisos de apertura de puertos adicionales en el firewall institucional (FortiGate)**. El sistema debe operar con la infraestructura y reglas existentes.

### 2.2 Por qué NO se Necesitan Puertos Nuevos en el Firewall
La confusión común consiste en creer que cada contenedor Docker necesita un puerto abierto hacia internet. Esto es falso:
- El firewall institucional **solo tiene y solo debe tener abiertos los puertos `80` (HTTP) y `443` (HTTPS)**.
- La aplicación móvil de socios (Flutter) **NUNCA** se conecta directamente a PostgreSQL, a Redis, ni al puerto 8000.
- La app móvil se comunica exclusivamente vía:
  $$\text{https://chatbot.cosmol.com.bo/api/v1}$$
  Esto viaja por el puerto **443 (HTTPS) estándar**, que **ya está 100% habilitado en el firewall**.

```
[ INTERNET / USUARIOS MÓVILES ]
              │  (Solo pasan puertos 80 y 443 por FortiGate)
              ▼
    ╔═══════════════════════════════════════════════╗
    ║       FIREWALL INSTITUCIONAL (FortiGate)      ║  <-- Cero puertos nuevos requeridos
    ╚═══════════════════════════════════════════════╝
              │  (Tráfico seguro HTTPS por puerto 443)
              ▼
   ┌─────────────────────────────────────────────────┐
   │            PROXY INVERSO CENTRAL (Caddy)        │  <-- Escucha en 443 y despacha internamente
   └───────┬─────────────────┬───────────────────────┘
           │                 │
     (handle /api/v1*)       (handle /uploads, n8n)
           │                 │
           ▼                 ▼
   ┌───────────────┐ ┌───────────────┐
   │ FastAPI (8000)│ │  n8n (5678)   │
   └───────┬───────┘ └───────────────┘
           │ (Red interna Docker privada / 127.0.0.1)
     ┌─────┴────────┐
     ▼              ▼
┌──────────┐  ┌──────────┐
│ PostgreSQL│  │  Redis   │
│  (5432)  │  │  (6379)  │
└──────────┘  └──────────┘
```

---

## 3. Matriz de Convivencia de Puertos en el Servidor (Cero Colisiones)

Para evitar que los servicios choquen entre sí en el host Ubuntu (`10.129.1.105`):

| Proyecto | Contenedor | Puerto Interno | Mapeo en el Host | Justificación Técnica |
|---|---|---|---|---|
| **Cosmol-Chatbot** | `cosmol_caddy` | 80, 443, 8081 | `80:80`, `443:443`, `8081:8081` | Único punto de entrada perimetral con SSL. |
| **Cosmol-Chatbot** | `cosmol_postgres` | 5432 | `127.0.0.1:5433:5432` | BD del Chatbot. Escucha en puerto **5433** solo local. |
| **COSMOL-Reportes**| `cosmol_reportes_app` | 80 | `8082:80` | Backend PHP de Reportes. Escucha en puerto **8082**. |
| **COSMOL-Reportes**| `cosmol_reportes_db` | 5432 | `5434:5432` | BD de Reportes. Escucha en puerto **5434**. |
| **COSMOL-app** | `cosmol-backend-api` | 8000 | `127.0.0.1:8000:8000` | FastAPI. Solo Caddy puede alcanzarlo localmente. |
| **COSMOL-app** | `cosmol-db-postgres` | 5432 | `127.0.0.1:5435:5432` | BD App Socios. Escucha en puerto **5435** solo local. |
| **COSMOL-app** | `cosmol-cache-redis` | 6379 | **SIN MAPEO** | Solo accesible por FastAPI dentro de la red Docker. |
| **COSMOL-app** | `cosmol-storage-minio`| 9000, 9001 | `127.0.0.1:9000`, `9001` | Almacenamiento S3. Solo local para administración. |

> [!IMPORTANT]
> **Armonía perfecta de bases de datos PostgreSQL:**
> - Chatbot: puerto **`5433`**
> - Reportes: puerto **`5434`**
> - App de Socios: puerto **`5435`**
> Ninguna usa `0.0.0.0:5432`. Cero colisiones con el sistema operativo host.
>
> *Nota para Eduardo:* Esta matriz es informativa para entender la convivencia en el host Ubuntu. **Tú únicamente debes modificar tu propio archivo [`docker-compose.yml`](../../../docker-compose.yml) de `COSMOL-app`.** Los demás servicios ya se encuentran administrados por Aireyu.

---

## 4. Guía de Implementación para Eduardo (Backend `COSMOL-app`)

Eduardo ejecutará las siguientes tareas de seguridad **exclusivamente dentro de los archivos del repositorio `COSMOL-app`** (sin tocar ningún archivo de Chatbot, Reportes ni el host).

---

### Tarea E1: Blindaje de Puertos en `docker-compose.yml`

* **Archivo a modificar:** [`docker-compose.yml`](../../../docker-compose.yml)
* **Objetivo:** Eliminar la exposición pública de bases de datos y servicios auxiliares hacia `0.0.0.0`, vinculándolos exclusivamente a `127.0.0.1` (loopback) o eliminando el mapeo donde no sea necesario.

#### Especificación de Cambios:

1. **`db-postgres`:**
   Cambiar `ports: - "5432:5432"` por:
   ```yaml
   ports:
     - "127.0.0.1:5435:5432"
   ```
   *Razón:* Permite que un administrador se conecte vía SSH/DBeaver al puerto 5435, sin exponerlo a la red y sin colisionar con el puerto 5432.

2. **`cache-redis`:**
   Eliminar completamente la directiva `ports`:
   ```yaml
   # ELIMINAR O COMENTAR:
   # ports:
   #   - "6379:6379"
   ```
   *Razón:* FastAPI se comunica directamente con Redis mediante el nombre interno del contenedor (`cache-redis:6379`). Nadie fuera de Docker necesita acceder a Redis.

3. **`backend-api`:**
   Vincular el puerto 8000 a la interfaz local:
   ```yaml
   ports:
     - "127.0.0.1:8000:8000"
   ```
   *Razón:* Caddy se comunica con FastAPI localmente. Nadie en la red local o externa podrá saltarse el proxy ni el certificado SSL consultando `http://IP:8000`.

4. **`storage-minio`:**
   Vincular MinIO a la interfaz local:
   ```yaml
   ports:
     - "127.0.0.1:9000:9000"
     - "127.0.0.1:9001:9001"
   ```

---

### Tarea E2: Ocultar Swagger UI y OpenAPI en Producción

* **Archivos a modificar:** [`backend/app/main.py`](../../../../backend/app/main.py) y [`backend/app/core/config.py`](../../../../backend/app/core/config.py)
* **Objetivo:** En entornos de producción (`ENVIRONMENT == "production"`), las rutas `/docs`, `/redoc` y `/openapi.json` deben devolver 404 para no exponer contratos ni firmas de la API.

#### Código en `backend/app/main.py`:

```python
from app.core.config import settings

# En la instanciación de FastAPI, condicionar la documentación:
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

---

### Tarea E3: Validación Estricta de `SECRET_KEY` en Producción

* **Archivo a modificar:** [`backend/app/core/config.py`](../../../../backend/app/core/config.py)
* **Objetivo:** Evitar que el backend inicie en producción si no se ha configurado una clave criptográfica segura en `.env`.

#### Código en `backend/app/core/config.py`:

```python
from pydantic import field_validator

class Settings(BaseSettings):
    # ... campos existentes ...

    @field_validator("SECRET_KEY")
    @classmethod
    def validar_secret_key_segura(cls, v: str, info) -> str:
        # Si el entorno es producción, rechazar claves por defecto o cortas
        valores = info.data
        entorno = valores.get("ENVIRONMENT", "development").lower()
        
        if entorno == "production":
            claves_inseguras = ["change_in_production", "secret", "cosmol_secret", "123456"]
            if any(insegura in v.lower() for insegura in claves_inseguras) or len(v) < 32:
                raise ValueError(
                    "CRÍTICO: En producción, 'SECRET_KEY' debe ser una cadena aleatoria segura "
                    "de al menos 32 caracteres generada criptográficamente (ej: openssl rand -hex 32)."
                )
        return v
```

---

## 5. Decisiones Operativas Formales

1. **COSMOL-Reportes Diferido:**
   - La variable `REPORTES_ENABLED` en `.env` debe permanecer en `false`.
   - El worker de fondo en [`backend/app/tasks/auditoria_reportes.py`](../../../../backend/app/tasks/auditoria_reportes.py) no despachará peticiones que puedan generar timeouts.
   - La app responde en <100ms de forma autónoma.
2. **OTP Mock Mantenido:**
   - La variable `MOCK_MESSAGING` en `.env` debe permanecer en `true`.
   - El código para verificar teléfonos en pruebas seguirá siendo `123456`.
   - La integración con Meta WABA se ejecutará cuando se entreguen tokens definitivos aprobados.

---

## 6. Checklist de Aceptación para Eduardo

- [ ] **Puertos Blindados:** `docker-compose.yml` tiene `db-postgres` en `127.0.0.1:5435:5432`, `cache-redis` sin puerto expuesto, y `backend-api` en `127.0.0.1:8000:8000`.
- [ ] **Sin Colisiones en Host:** Al ejecutar `docker compose up -d`, ningún puerto colisiona con Chatbot (`5433`) ni Reportes (`5434` / `8082`).
- [ ] **Swagger Oculto:** Al consultar `https://chatbot.cosmol.com.bo/docs` en producción, devuelve `404 Not Found`. En desarrollo sigue disponible.
- [ ] **Secretos Validados:** Si se prueba levantar en producción con una clave débil, la aplicación se detiene con error explicativo de validación.
- [ ] **Pruebas de Regresión:** La app Flutter sigue funcionando al 100% (login de socio `11543`, visualización de facturas, cierre de sesión y reingreso).
