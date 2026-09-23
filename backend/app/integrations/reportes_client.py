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
            "ngrok-skip-browser-warning": "true",
        }
        if settings.REPORTES_API_TOKEN:
            default_headers["X-Reportes-Token"] = settings.REPORTES_API_TOKEN.strip()

        super().__init__(
            base_url=settings.REPORTES_API_URL or "http://localhost:8080",
            timeout_seconds=settings.REPORTES_TIMEOUT_SECONDS,
            default_headers=default_headers,
        )
        self.servidor_offline: bool = False

    def esta_servidor_offline(self) -> bool:
        """Indica si el último intento falló por desconexión de red o timeout."""
        return self.servidor_offline

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

    async def enviar_payload_directo(self, payload: Dict[str, Any]) -> bool:
        """
        Envía un payload preconstruido a COSMOL-Reportes.
        Utilizado tanto para envíos en tiempo real como para vaciado de eventos acumulados en Redis.
        """
        if not settings.REPORTES_ENABLED:
            return False

        url_destino = self._resolver_url_destino()
        if not url_destino:
            logger.debug("[AUDITORIA OMITIDA] Reportes sin URL configurada.")
            return False

        try:
            client = await self.get_client()
            headers = {
                "Content-Type": "application/json; charset=utf-8",
                "ngrok-skip-browser-warning": "true",
            }
            if settings.REPORTES_API_TOKEN:
                headers["X-Reportes-Token"] = settings.REPORTES_API_TOKEN.strip()

            response = await client.post(
                url_destino,
                json=payload,
                headers=headers,
                follow_redirects=True,
            )
            if response.status_code in (200, 201):
                self.servidor_offline = False
                logger.info(
                    f"[AUDITORIA EXITOSA] Evento '{payload.get('tipo_consulta')}' (id={payload.get('id_tipo')}) "
                    f"despachado para socio {payload.get('codigo_socio')} a {url_destino} (HTTP {response.status_code})"
                )
                return True
            else:
                self.servidor_offline = False
                logger.warning(
                    f"[AUDITORIA RESPUESTA NO ESPERADA] COSMOL-Reportes respondió HTTP {response.status_code}: "
                    f"{response.text[:200]}"
                )
                return False
        except httpx.TimeoutException:
            self.servidor_offline = True
            logger.warning(
                f"[AUDITORIA TIMEOUT] Tiempo de espera agotado ({settings.REPORTES_TIMEOUT_SECONDS}s) "
                f"al enviar auditoría a {url_destino}."
            )
            return False
        except httpx.RequestError as exc:
            self.servidor_offline = True
            logger.warning(
                f"[AUDITORIA RED OFFLINE] No se pudo conectar con COSMOL-Reportes en {url_destino} ({exc}). "
                f"Continuando ejecución normal sin afectar al socio."
            )
            return False
        except Exception as exc:
            self.servidor_offline = False
            logger.warning(
                f"[AUDITORIA ERROR INESPERADO] Excepción no crítica en despacho a Reportes: {exc}"
            )
            return False

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
        Construye el payload oficial y lo envía a COSMOL-Reportes.
        """
        if not settings.REPORTES_ENABLED:
            return False

        # 1. Normalización estricta de tipos de datos (Python -> PHP/PostgreSQL)
        try:
            cod_socio_int = int(str(codigo_socio).strip())
        except (ValueError, TypeError):
            logger.warning(f"[AUDITORIA] codigo_socio no numérico: '{codigo_socio}'. Usando 0.")
            cod_socio_int = 0

        tel_normalizado = str(telefono).strip() if telefono and str(telefono).strip() else None
        nombres_limpio = str(nombres or f"SOCIO {cod_socio_int}").strip()

        if not tipo_consulta:
            tipo_consulta = self.CATALOGO_EVENTOS.get(id_tipo, "Consulta General")

        # Zona horaria oficial de Montero, Bolivia (UTC-4)
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

        return await self.enviar_payload_directo(payload)
