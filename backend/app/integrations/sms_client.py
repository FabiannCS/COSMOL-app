import logging
from typing import Any, Dict
from app.core.config import settings
from app.integrations.base_client import BaseApiClient

logger = logging.getLogger(__name__)


class SmsClient(BaseApiClient):
    """
    Cliente adaptador para Gateway SMS nacional de respaldo.
    Utilizado como canal alternativo cuando el socio no tiene acceso a WhatsApp.
    """
    def __init__(self):
        default_headers = {}
        if settings.SMS_GATEWAY_API_KEY:
            default_headers["Authorization"] = f"Bearer {settings.SMS_GATEWAY_API_KEY}"

        super().__init__(
            base_url=settings.SMS_GATEWAY_URL or "https://sms-gateway.cosmol.com.bo",
            timeout_seconds=8.0,
            default_headers=default_headers
        )

    def _normalizar_telefono(self, telefono: str) -> str:
        limpio = "".join(filter(str.isdigit, telefono))
        if len(limpio) == 8:
            limpio = f"591{limpio}"
        return limpio

    async def enviar_sms_otp(self, telefono: str, codigo: str) -> bool:
        """
        Envía un SMS con el código de verificación al número del socio.
        En modo desarrollo (MOCK_MESSAGING=True) simula el envío registrándolo en logs.
        """
        numero_normalizado = self._normalizar_telefono(telefono)
        mensaje = f"{codigo} es tu codigo de seguridad de COSMOL R.L. Valido por 5 minutos."

        # Modo Simulación en Desarrollo
        if settings.MOCK_MESSAGING or not settings.SMS_GATEWAY_URL:
            logger.info(
                f"[DEV MOCK SMS] Despachando SMS al número '+{numero_normalizado}': \"{mensaje}\""
            )
            return True

        # Modo Real Gateway SMS
        payload: Dict[str, Any] = {
            "destino": numero_normalizado,
            "mensaje": mensaje
        }

        try:
            response = await self.request("POST", "/api/v1/send-sms", json_data=payload)
            if response.status_code in (200, 201):
                logger.info(f"SMS enviado exitosamente a '+{numero_normalizado}'")
                return True
            else:
                logger.error(f"Error del Gateway SMS ({response.status_code}): {response.text}")
                return False
        except Exception as exc:
            logger.error(f"Fallo al conectar con Gateway SMS: {exc}")
            return False


# Instancia única reutilizable
sms_client = SmsClient()
