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

    async def request(
        self,
        method: str,
        endpoint: str,
        *,
        params: Optional[Dict[str, Any]] = None,
        json_data: Optional[Dict[str, Any]] = None,
        headers: Optional[Dict[str, str]] = None
    ) -> httpx.Response:
        """
        Ejecuta una petición HTTP asíncrona segura.
        """
        client = await self.get_client()
        url = endpoint if endpoint.startswith("http") else f"{self.base_url}/{endpoint.lstrip('/')}"
        
        try:
            response = await client.request(
                method=method,
                url=url,
                params=params,
                json=json_data,
                headers=headers
            )
            return response
        except httpx.TimeoutException as exc:
            logger.error(f"Timeout al conectar con servicio externo ({method} {url}): {exc}")
            raise
        except httpx.RequestError as exc:
            logger.error(f"Error de red al conectar con servicio externo ({method} {url}): {exc}")
            raise
