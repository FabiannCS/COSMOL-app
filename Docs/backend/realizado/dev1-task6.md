# Entregables DEV 1: Configuración, Cliente HTTP Asíncrono y Tareas de Auditoría para COSMOL-Reportes

> **Fase:** Fase 6 — Auditoría a COSMOL-Reportes y Seguridad Avanzada  
> **Rol responsable:** DEV 1 (Aireyu) — Configuración Oficial, Cliente HTTP Asíncrono, Despacho en Segundo Plano y Pruebas Unitarias de Resiliencia  
> **Fecha de conclusión:** Septiembre 2026  
> **Documento de referencia:** `Docs/backend/pendiente/TASK-06-auditoria-reportes.md` y `AGENTS.md` (Secciones 6, 8, 12.2, 12.3)  
> **Estado:** COMPLETADO y certificado en Docker (7/7 tests propios y 118/118 tests totales de la suite pasando al 100%)

---

## 1. Resumen Ejecutivo

**DEV 1 (Aireyu)** ha completado e integrado la capa de infraestructura, configuración, cliente HTTP asíncrono y despacho en segundo plano para la **Tarea 06 (Auditoría a COSMOL-Reportes)**:

1. **Configuración Oficial Centralizada (`config.py` y `.env`):**
   - Incorporación de `REPORTES_API_URL`, `REPORTES_API_TOKEN` e `id_usuario = 3` (identificador exclusivo de la App Móvil).
   - Timeout estricto de 3.0s (`REPORTES_TIMEOUT_SECONDS`) y bandera de habilitación (`REPORTES_ENABLED = True`).
   - Si la URL está vacía (entorno local o testing), omite silenciosamente sin arrojar errores.

2. **Cliente HTTP Asíncrono Resiliente (`integrations/reportes_client.py`):**
   - Utiliza `httpx.AsyncClient` con pool de conexiones no bloqueante heredando de `BaseApiClient`.
   - Método `enviar_evento_auditoria`:
     - Despacha a `POST {REPORTES_API_URL}/api/consultas` con cabecera `X-Reportes-Token`.
     - Genera automáticamente `fecha_consulta` (`YYYY-MM-DD`) y `hora_consulta` (`HH:MM:SS`).
     - Inserta `id_usuario: 3` y `tipo_ubicacion: "APP_MOVIL"`.
     - **Resiliencia Total (Cero Crash):** Captura `httpx.TimeoutException`, `httpx.RequestError` y excepciones inesperadas emitiendo un `logger.warning`. Bajo ninguna circunstancia un fallo o desconexión del servidor de reportes propaga errores ni afecta al socio.

3. **Módulo de Despacho en Segundo Plano (`tasks/auditoria_reportes.py`):**
   - Función asíncrona `despachar_auditoria_reportes(...)` preparada para ejecutarse en `BackgroundTasks` de FastAPI, garantizando **0 ms de overhead** en la respuesta devuelta al socio.

4. **Certificación Total en Docker:**
   - 7/7 tests unitarios propios en `tests/test_auditoria_reportes.py` aprobados al 100%.
   - 118/118 tests de toda la suite global del backend aprobados en Docker en 48.75s (cero fallos, cero regresiones).

---

## 2. Inventario de Archivos Modificados y Creados

| Archivo | Acción | Responsabilidad Técnica |
| :--- | :---: | :--- |
| [`backend/app/core/config.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/app/core/config.py) | **MODIFICADO** | Parámetros oficiales de conexión a COSMOL-Reportes. |
| [`.env`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/.env) y [`.env.example`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/.env.example) | **MODIFICADO** | Documentación de variables para desarrollo y producción. |
| [`backend/app/integrations/reportes_client.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/app/integrations/reportes_client.py) | **NUEVO** | Cliente HTTP asíncrono resiliente con timeout de 3s y payload estandarizado. |
| [`backend/app/integrations/__init__.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/app/integrations/__init__.py) | **MODIFICADO** | Exportación de `ReportesApiClient`. |
| [`backend/app/tasks/auditoria_reportes.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/app/tasks/auditoria_reportes.py) | **NUEVO** | Tarea en segundo plano para FastAPI `BackgroundTasks`. |
| [`backend/app/tasks/__init__.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/app/tasks/__init__.py) | **MODIFICADO** | Exportación de `despachar_auditoria_reportes`. |
| [`backend/tests/test_auditoria_reportes.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/tests/test_auditoria_reportes.py) | **NUEVO** | Batería de 7 pruebas unitarias de validación y resiliencia. |

---

## 3. Contrato de Interfaz para DEV 2 (Eduardo)

DEV 2 puede consumir directamente la función en los endpoints de FastAPI:

```python
from fastapi import BackgroundTasks
from app.tasks import despachar_auditoria_reportes

@router.get("/deuda/{cod_socio}")
async def obtener_deuda(
    cod_socio: str,
    background_tasks: BackgroundTasks,
    ...
):
    # Lógica habitual del endpoint (<20 ms)
    ...
    # Encolar auditoría asíncrona hacia COSMOL-Reportes
    background_tasks.add_task(
        despachar_auditoria_reportes,
        codigo_socio=int(cod_socio),
        nombres=getattr(resumen.suministro, "nombre_titular", f"SOCIO {cod_socio}") if hasattr(resumen, "suministro") else f"SOCIO {cod_socio}",
        telefono=usuario.telefono,
        id_tipo=2,
        tipo_consulta="Consulta de Deuda",
        tipo_ubicacion="APP_MOVIL"
    )
    return resumen
```
