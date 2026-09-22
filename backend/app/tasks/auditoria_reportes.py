import logging
from typing import Optional
from app.integrations.reportes_client import ReportesApiClient

logger = logging.getLogger(__name__)


async def despachar_auditoria_reportes(
    codigo_socio: int,
    nombres: str,
    telefono: Optional[str] = None,
    id_tipo: int = 2,
    tipo_consulta: Optional[str] = None,
    tipo_ubicacion: str = "APP_MOVIL",
) -> None:
    """
    Función asíncrona para ser inyectada en FastAPI BackgroundTasks.
    Despacha el evento hacia COSMOL-Reportes de forma 100% aislada.
    """
    try:
        client = ReportesApiClient()
        await client.enviar_evento_auditoria(
            codigo_socio=codigo_socio,
            nombres=nombres,
            telefono=telefono,
            id_tipo=id_tipo,
            tipo_consulta=tipo_consulta,
            tipo_ubicacion=tipo_ubicacion,
        )
    except Exception as exc:
        logger.warning(
            f"[BACKGROUND TASK AUDITORIA] Error inesperado en background task: {exc}. "
            f"El error no afecta la respuesta al socio."
        )
