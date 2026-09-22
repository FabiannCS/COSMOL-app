import logging
from datetime import datetime
from typing import Any, Dict, Optional
import httpx

from app.core.config import settings
from app.integrations.base_client import BaseApiClient

logger = logging.getLogger(__name__)


class ReportesApiClient(BaseApiClient):
    """
    Cliente HTTP asíncrono para despachar eventos de auditoría y consultas
    hacia la API REST de COSMOL-Reportes (POST /api/consultas).
    Diseñado para operar en segundo plano con resiliencia total (cero crash).
    """

    def __init__(self):
        default_headers = {
            "Content-Type": "application/json",
        }
        if settings.REPORTES_API_TOKEN:
            default_headers["X-Reportes-Token"] = settings.REPORTES_API_TOKEN

        super().__init__(
            base_url=settings.REPORTES_API_URL or "http://localhost:8080",
            timeout_seconds=settings.REPORTES_TIMEOUT_SECONDS,
            default_headers=default_headers,
        )

    async def enviar_evento_auditoria(
        self,
        codigo_socio: int,
        nombres: str,
        telefono: Optional[str] = None,
        id_tipo: int = 2,
        tipo_consulta: str = "Consulta de Deuda",
        tipo_ubicacion: str = "APP_MOVIL",
    ) -> bool:
        """
        Envía un registro de evento en formato JSON a COSMOL-Reportes.
        Si la URL está vacía o el servicio está deshabilitado, omite el envío limpiamente.
        Si el servidor está apagado o falla, captura la excepción y retorna False sin romper nada.
        """
        if not settings.REPORTES_ENABLED or not settings.REPORTES_API_URL:
            logger.debug(
                f"[AUDITORIA OMITIDA] Reportes deshabilitado o sin URL configurada. "
                f"Socio: {codigo_socio}, Tipo: {id_tipo} ({tipo_consulta})"
            )
            return False

        ahora = datetime.now()
        fecha_consulta = ahora.strftime("%Y-%m-%d")
        hora_consulta = ahora.strftime("%H:%M:%S")

        payload: Dict[str, Any] = {
            "codigo_socio": codigo_socio,
            "nombres": nombres or f"SOCIO {codigo_socio}",
            "telefono": telefono or "",
            "id_usuario": settings.REPORTES_ID_USUARIO_APP,  # 3 = App Móvil
            "id_tipo": id_tipo,
            "tipo_consulta": tipo_consulta,
            "tipo_ubicacion": tipo_ubicacion,
            "fecha_consulta": fecha_consulta,
            "hora_consulta": hora_consulta,
        }

        try:
            client = await self.get_client()
            headers = {"Content-Type": "application/json"}
            if settings.REPORTES_API_TOKEN:
                headers["X-Reportes-Token"] = settings.REPORTES_API_TOKEN

            response = await client.post("/api/consultas", json=payload, headers=headers)
            if response.status_code in (200, 201):
                logger.info(
                    f"[AUDITORIA EXITOSA] Evento '{tipo_consulta}' despachado para socio {codigo_socio} "
                    f"(HTTP {response.status_code})"
                )
                return True
            else:
                logger.warning(
                    f"[AUDITORIA RESPUESTA NO ESPERADA] COSMOL-Reportes respondió HTTP {response.status_code}: "
                    f"{response.text[:200]}"
                )
                return False
        except httpx.TimeoutException:
            logger.warning(
                f"[AUDITORIA TIMEOUT] Tiempo de espera agotado ({settings.REPORTES_TIMEOUT_SECONDS}s) "
                f"al enviar auditoría a COSMOL-Reportes."
            )
            return False
        except httpx.RequestError as exc:
            logger.warning(
                f"[AUDITORIA RED OFFLINE] No se pudo conectar con COSMOL-Reportes ({exc}). "
                f"Continuando ejecución normal sin afectar al socio."
            )
            return False
        except Exception as exc:
            logger.warning(
                f"[AUDITORIA ERROR INESPERADO] Excepción no crítica en despacho a Reportes: {exc}"
            )
            return False
