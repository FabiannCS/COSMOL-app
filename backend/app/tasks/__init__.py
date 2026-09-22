"""
Tareas en segundo plano (BackgroundTasks):
- Despacho asíncrono de eventos de auditoría hacia la API de COSMOL-Reportes.
"""
from app.tasks.auditoria_reportes import despachar_auditoria_reportes

__all__ = ["despachar_auditoria_reportes"]

