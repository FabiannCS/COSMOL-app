"""
Capa de integración externa:
- Cliente asíncrono para el sistema comercial y de facturación de COSMOL.
- Cliente para Meta WhatsApp Cloud API (envío de plantillas OTP).
- Cliente para Gateway SMS (canal de respaldo).
"""
from app.integrations.base_client import BaseApiClient
from app.integrations.cosmol_client import CosmolLegacyClient, cosmol_client
from app.integrations.whatsapp_client import WhatsAppClient, whatsapp_client
from app.integrations.sms_client import SmsClient, sms_client

__all__ = [
    "BaseApiClient",
    "CosmolLegacyClient",
    "cosmol_client",
    "WhatsAppClient",
    "whatsapp_client",
    "SmsClient",
    "sms_client",
]
