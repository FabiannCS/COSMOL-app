import logging
from typing import Any, Dict, Optional
from app.core.config import settings
from app.integrations.base_client import BaseApiClient

logger = logging.getLogger(__name__)


class WhatsAppClient(BaseApiClient):
    """
    Cliente especializado para interactuar con Meta WhatsApp Cloud API.
    Permite enviar plantillas de autenticación (OTP) reutilizando la WABA y número de COSMOL R.L.
    """
    def __init__(self):
        default_headers = {}
        if settings.WHATSAPP_ACCESS_TOKEN:
            default_headers["Authorization"] = f"Bearer {settings.WHATSAPP_ACCESS_TOKEN}"

        super().__init__(
            base_url=settings.WHATSAPP_API_URL,
            timeout_seconds=8.0,
            default_headers=default_headers
        )

    def _normalizar_telefono(self, telefono: str) -> str:
        """
        Normaliza el número telefónico para el formato internacional sin '+' ni espacios.
        Ej: '+591 70011223' -> '59170011223'.
        Si viene sin código de país (8 dígitos en Bolivia), antepone '591'.
        """
        limpio = "".join(filter(str.isdigit, telefono))
        if len(limpio) == 8:
            limpio = f"591{limpio}"
        return limpio

    async def enviar_otp(self, telefono: str, codigo: str) -> bool:
        """
        Envía una plantilla oficial de autenticación OTP vía WhatsApp.
        En modo desarrollo (MOCK_MESSAGING=True) simula el envío registrándolo en logs.
        """
        numero_normalizado = self._normalizar_telefono(telefono)

        # Modo Simulación en Desarrollo
        if settings.MOCK_MESSAGING or not settings.WHATSAPP_ACCESS_TOKEN:
            logger.info(
                f"[DEV MOCK WHATSAPP] Despachando OTP '{codigo}' al número '+{numero_normalizado}' "
                f"(Plantilla: '{settings.WHATSAPP_OTP_TEMPLATE_NAME}', Expira: {settings.OTP_EXPIRE_SECONDS}s)"
            )
            return True

        # Modo Real (Meta Cloud API)
        endpoint = f"/{settings.WHATSAPP_PHONE_NUMBER_ID}/messages"
        payload: Dict[str, Any] = {
            "messaging_product": "whatsapp",
            "recipient_type": "individual",
            "to": numero_normalizado,
            "type": "template",
            "template": {
                "name": settings.WHATSAPP_OTP_TEMPLATE_NAME,
                "language": {"code": "es"},
                "components": [
                    {
                        "type": "body",
                        "parameters": [{"type": "text", "text": codigo}]
                    },
                    {
                        "type": "button",
                        "sub_type": "url",
                        "index": "0",
                        "parameters": [{"type": "text", "text": codigo}]
                    }
                ]
            }
        }

        try:
            response = await self.request("POST", endpoint, json_data=payload)
            if response.status_code in (200, 201):
                logger.info(f"OTP de WhatsApp enviado exitosamente a '+{numero_normalizado}'")
                return True
            else:
                logger.error(f"Error de Meta API al enviar WhatsApp ({response.status_code}): {response.text}")
                return False
        except Exception as exc:
            logger.error(f"Fallo al conectar con Meta WhatsApp API: {exc}")
            return False


# Instancia única reutilizable
whatsapp_client = WhatsAppClient()
