from sqlalchemy import Boolean, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.models.base import BaseModel


class Otp(BaseModel):
    """
    Entidad para registro histórico y auditoría de códigos de seguridad OTP enviados.
    Nota: La validación rápida con TTL (5 min) se gestiona en Redis; esta tabla conserva
    el registro auditable de los despachos realizados vía WhatsApp Cloud API o SMS.
    """
    __tablename__ = "otps"

    telefono: Mapped[str] = mapped_column(
        String(20),
        index=True,
        nullable=False,
        doc="Número de teléfono celular al que se despachó el código"
    )

    canal: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        doc="Canal de mensajería utilizado: 'WHATSAPP' o 'SMS'"
    )

    proposito: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        doc="Motivo de emisión: 'ONBOARDING' (primer acceso), 'RECUPERACION' o 'DESBLOQUEO'"
    )

    fue_verificado: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
        doc="Indica si el socio completó la verificación del código en el tiempo de validez"
    )

    def __repr__(self) -> str:
        return f"<Otp(id={self.id}, telefono='{self.telefono}', canal='{self.canal}', proposito='{self.proposito}')>"
