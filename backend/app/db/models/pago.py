import uuid
from typing import Optional, TYPE_CHECKING
from sqlalchemy import ForeignKey, Numeric, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.models.base import BaseModel

if TYPE_CHECKING:
    from app.db.models.usuario import Usuario


class AuditoriaPagoRedireccion(BaseModel):
    """
    Registro de auditoría persistente cuando un socio hace clic en un canal de pago externo
    (Multipago Bolivia o Pago al Paso). Almacena la intención de pago para estadísticas y conciliación.
    """
    __tablename__ = "auditoria_pagos_redireccion"

    usuario_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
        doc="ID del usuario digital que inició la redirección"
    )

    cod_socio: Mapped[str] = mapped_column(
        String(20),
        index=True,
        nullable=False,
        doc="Código del socio o suministro a pagar"
    )

    canal_id: Mapped[str] = mapped_column(
        String(30),
        index=True,
        nullable=False,
        doc="Identificador del canal: 'multipago' o 'pago_al_paso'"
    )

    monto_deuda_bs: Mapped[float] = mapped_column(
        Numeric(10, 2),
        nullable=False,
        doc="Monto de la deuda pendiente en Bolivianos al momento de la redirección"
    )

    ip_origen: Mapped[Optional[str]] = mapped_column(
        String(50),
        nullable=True,
        doc="Dirección IP del cliente que solicitó la redirección"
    )

    usuario: Mapped[Optional["Usuario"]] = relationship("Usuario")

    def __repr__(self) -> str:
        return (
            f"<AuditoriaPagoRedireccion(id={self.id}, cod_socio='{self.cod_socio}', "
            f"canal='{self.canal_id}', monto_bs={self.monto_deuda_bs})>"
        )
