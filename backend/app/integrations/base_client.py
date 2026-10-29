import logging
from typing import Any, Dict, Optional
import httpx

logger = logging.getLogger(__name__)


class BaseApiClient:
    """
    Cliente HTTP asíncrono base para integraciones externas (COSMOL legado, WhatsApp API, SMS Gateway, ChatbotReportes).
    Gestiona pools de conexión, timeouts estrictos y control uniforme de errores.
    """
    def __init__(
        self,
        base_url: str = "",
        timeout_seconds: float = 10.0,
        default_headers: Optional[Dict[str, str]] = None
    ):
        self.base_url = base_url.rstrip("/")
        self.timeout = httpx.Timeout(timeout_seconds, connect=5.0)
        self.default_headers = default_headers or {}
        self._client: Optional[httpx.AsyncClient] = None

    async def get_client(self) -> httpx.AsyncClient:
        """
        Retorna o inicializa el cliente asíncrono persistente con connection pooling.
        Verifica que pertenezca al event loop activo actual.
        """
        import asyncio
        try:
            current_loop = asyncio.get_running_loop()
        except RuntimeError:
            current_loop = None

        if (
            self._client is None
            or self._client.is_closed
            or getattr(self, "_loop", None) is not current_loop
        ):
            self._loop = current_loop
            self._client = httpx.AsyncClient(
                base_url=self.base_url,
                timeout=self.timeout,
                headers=self.default_headers
            )
        return self._client

    async def close(self) -> None:
        """
        Cierra las conexiones activas del cliente HTTP.
        """
        if self._client and not self._client.is_closed:
            await self._client.aclose()

    @staticmethod
    def _normalizar_url(base_url: str, endpoint: str) -> str:
        """
        Normaliza la URL combinando base_url y endpoint:
        - Asegura protocolo (http:// si no se especificó).
        - Elimina barras duplicadas accidentales (//).
        - Evita duplicación de prefijos de ruta si base_url y endpoint comparten segmento (ej: /api-consultas).
        """
        import re
        b = base_url.strip().rstrip("/")
        e = endpoint.strip().lstrip("/")

        if e.startswith("http://") or e.startswith("https://"):
            full = e
        else:
            if not b.startswith("http://") and not b.startswith("https://"):
                b = f"http://{b}"
            proto, sep, path = b.partition("://")
            base_segments = [s for s in path.split("/") if s]
            if base_segments:
                last = base_segments[-1]
                if e.startswith(f"{last}/"):
                    e = e[len(last) + 1:].lstrip("/")
            full = f"{b}/{e}"

        proto, sep, path = full.partition("://")
        if sep:
            clean_path = re.sub(r"/+", "/", path)
            return f"{proto}://{clean_path}"
        return re.sub(r"/+", "/", full)

    async def request(
        self,
        method: str,
        endpoint: str,
        *,
        params: Optional[Dict[str, Any]] = None,
        json_data: Optional[Dict[str, Any]] = None,
        json: Optional[Dict[str, Any]] = None,
        headers: Optional[Dict[str, str]] = None
    ) -> httpx.Response:
        """
        Ejecuta una petición HTTP asíncrona segura.
        """
        client = await self.get_client()
        url = self._normalizar_url(self.base_url, endpoint)
        payload = json if json is not None else json_data
        
        try:
            response = await client.request(
                method=method,
                url=url,
                params=params,
                json=payload,
                headers=headers
            )
            return response
        except httpx.TimeoutException as exc:
            logger.error(f"Timeout al conectar con servicio externo ({method} {url}): {exc}")
            raise
        except httpx.RequestError as exc:
            logger.error(f"Error de red al conectar con servicio externo ({method} {url}): {exc}")
            raise
