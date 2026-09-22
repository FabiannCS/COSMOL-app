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

    # Catálogo Oficial de Eventos pactado en el Contrato (§ 4)
    CATALOGO_EVENTOS = {
        1: "Autenticación / Acceso",
        2: "Consulta de Deuda",
        3: "Historial de Facturas",
        9: "Descarga de Factura PDF",
        10: "Intento de Pago",
    }

    def __init__(self):
        default_headers = {
            "Content-Type": "application/json; charset=utf-8",
        }
        if settings.REPORTES_API_TOKEN:
            default_headers["X-Reportes-Token"] = settings.REPORTES_API_TOKEN.strip()

        super().__init__(
            base_url=settings.REPORTES_API_URL or "http://localhost:8080",
            timeout_seconds=settings.REPORTES_TIMEOUT_SECONDS,
            default_headers=default_headers,
        )

    def _resolver_url_destino(self) -> Optional[str]:
        """
        Resuelve la URL destino previniendo discrepancias entre entornos:
        Soporta tanto URLs base ("http://host:8080") como URLs completas ("http://host:8080/api/consultas").
        """
        raw_url = (settings.REPORTES_API_URL or "").strip().rstrip("/")
        if not raw_url:
            return None
        if raw_url.endswith("/api/consultas"):
            return raw_url
        return f"{raw_url}/api/consultas"

    async def enviar_evento_auditoria(
        self,
        codigo_socio: int,
        nombres: str,
        telefono: Optional[str] = None,
        id_tipo: int = 2,
        tipo_consulta: Optional[str] = None,
        tipo_ubicacion: str = "APP_MOVIL",
    ) -> bool:
        """
        Envía un registro de evento en formato JSON a COSMOL-Reportes cumpliendo el Contrato Oficial.
        - Si REPORTES_API_URL está vacía o REPORTES_ENABLED=False, omite limpiamente.
        - Si el servidor falla, captura la excepción y retorna False sin romper nada.
        """
        if not settings.REPORTES_ENABLED:
            return False

        url_destino = self._resolver_url_destino()
        if not url_destino:
            logger.debug(
                f"[AUDITORIA OMITIDA] Reportes sin URL configurada. "
                f"Socio: {codigo_socio}, Tipo: {id_tipo}"
            )
            return False

        # 1. Normalización estricta de tipos de datos (Python -> PHP/PostgreSQL)
        try:
            cod_socio_int = int(str(codigo_socio).strip())
        except (ValueError, TypeError):
            logger.warning(f"[AUDITORIA] codigo_socio no numérico: '{codigo_socio}'. Usando 0.")
            cod_socio_int = 0

        # En PHP/Postgres, si no hay teléfono debe ser null (no string vacío "")
        tel_normalizado = str(telefono).strip() if telefono and str(telefono).strip() else None

        # Nombres obligatorio
        nombres_limpio = str(nombres or f"SOCIO {cod_socio_int}").strip()

        # Tipo de consulta según catálogo oficial (§ 4)
        if not tipo_consulta:
            tipo_consulta = self.CATALOGO_EVENTOS.get(id_tipo, "Consulta General")

        # Zona horaria oficial de Montero, Bolivia (UTC-4) para evitar desfases con servidores en UTC
        from datetime import timezone, timedelta
        tz_bolivia = timezone(timedelta(hours=-4))
        ahora = datetime.now(tz_bolivia)
        fecha_consulta = ahora.strftime("%Y-%m-%d")
        hora_consulta = ahora.strftime("%H:%M:%S")

        payload: Dict[str, Any] = {
            "codigo_socio": cod_socio_int,
            "nombres": nombres_limpio,
            "telefono": tel_normalizado,
            "id_usuario": int(settings.REPORTES_ID_USUARIO_APP),  # 3 = App Móvil
            "id_tipo": int(id_tipo),
            "tipo_consulta": tipo_consulta,
            "tipo_ubicacion": "APP_MOVIL",
            "fecha_consulta": fecha_consulta,
            "hora_consulta": hora_consulta,
        }

        try:
            client = await self.get_client()
            headers = {
                "Content-Type": "application/json; charset=utf-8",
            }
            if settings.REPORTES_API_TOKEN:
                headers["X-Reportes-Token"] = settings.REPORTES_API_TOKEN.strip()

            # follow_redirects=True previene caídas si Apache/Nginx en PHP redirige 301/308 por trailing slash
            response = await client.post(
                url_destino,
                json=payload,
                headers=headers,
                follow_redirects=True,
            )
            if response.status_code in (200, 201):
                logger.info(
                    f"[AUDITORIA EXITOSA] Evento '{tipo_consulta}' (id={id_tipo}) despachado para socio {cod_socio_int} "
                    f"a {url_destino} (HTTP {response.status_code})"
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
                f"al enviar auditoría a {url_destino}."
            )
            return False
        except httpx.RequestError as exc:
            logger.warning(
                f"[AUDITORIA RED OFFLINE] No se pudo conectar con COSMOL-Reportes en {url_destino} ({exc}). "
                f"Continuando ejecución normal sin afectar al socio."
            )
            return False
        except Exception as exc:
            logger.warning(
                f"[AUDITORIA ERROR INESPERADO] Excepción no crítica en despacho a Reportes: {exc}"
            )
            return False
