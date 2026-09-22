"""
Modelos ORM de SQLAlchemy para PostgreSQL:
- BaseModel: Clase base abstracta con UUID v4, created_at y updated_at.
- Usuario: Cuenta digital asociada al número de celular verificado.
- Suministro: Contratos / códigos de socio vinculados (Multicuenta).
- Dispositivo: Hardware y tokens de sesión única y notificaciones push.
- Otp: Registro de auditoría de códigos de verificación WhatsApp y SMS.
"""
from app.db.models.base import BaseModel
from app.db.models.usuario import Usuario
from app.db.models.suministro import Suministro
from app.db.models.dispositivo import Dispositivo
from app.db.models.otp import Otp
from app.db.models.documento import Documento
from app.db.models.pago import AuditoriaPagoRedireccion

__all__ = [
    "BaseModel",
    "Usuario",
    "Suministro",
    "Dispositivo",
    "Otp",
    "Documento",
    "AuditoriaPagoRedireccion"
]

