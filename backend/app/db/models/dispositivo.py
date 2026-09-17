from datetime import datetime
from typing import Optional, TYPE_CHECKING
import uuid
from sqlalchemy import DateTime, ForeignKey, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.models.base import BaseModel

if TYPE_CHECKING:
    from app.db.models.usuario import Usuario


class Dispositivo(BaseModel):
    """
    Entidad que registra los dispositivos móviles/web autorizados por el usuario.
    Permite implementar el modelo de sesión única estilo WhatsApp (revocando sesiones antiguas al detectar nuevo device_id)
    y almacenar el token de Firebase Cloud Messaging (FCM) para notificaciones push.
    """
    __tablename__ = "dispositivos"

    usuario_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
        doc="Clave foránea hacia el usuario propietario del dispositivo"
    )

    device_id: Mapped[str] = mapped_column(
        String(100),
        index=True,
        nullable=False,
        doc="Identificador unívoco del hardware/instalación de la app móvil"
    )

    modelo_dispositivo: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
        doc="Nombre descriptivo del dispositivo (ej: 'Samsung Galaxy S23', 'iPhone 15 Pro')"
    )

    fcm_token: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
        doc="Token de Firebase Cloud Messaging para despacho de notificaciones push de vencimiento o corte"
    )

    ultimo_acceso: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
        doc="Marca temporal de la última petición o login desde este dispositivo"
    )

    # Relación inversa hacia Usuario
    usuario: Mapped["Usuario"] = relationship(
        "Usuario",
        back_populates="dispositivos"
    )

    def __repr__(self) -> str:
        return f"<Dispositivo(id={self.id}, device_id='{self.device_id}', modelo='{self.modelo_dispositivo}')>"
