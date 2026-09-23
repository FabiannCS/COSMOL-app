"""
Tareas en segundo plano (BackgroundTasks) y Colas de Resiliencia:
- Despacho asíncrono de eventos de auditoría hacia la API de COSMOL-Reportes.
- Buffer y cola persistente en Redis con flusher automático de reintentos.
"""
from app.tasks.auditoria_reportes import (
    despachar_auditoria_reportes,
    vaciar_cola_pendientes,
    encolar_evento_en_redis,
    worker_flusher_auditoria,
    REDIS_KEY_COLA_PENDIENTES,
)

__all__ = [
    "despachar_auditoria_reportes",
    "vaciar_cola_pendientes",
    "encolar_evento_en_redis",
    "worker_flusher_auditoria",
    "REDIS_KEY_COLA_PENDIENTES",
]
