"""
Modelo SQLAlchemy para Auditoría de Clics y Redirección a Pasarelas de Pago.
COSMOL R.L. - App de Socios (Fase 5).
"""
import uuid
from typing import Optional
from sqlalchemy import ForeignKey, Numeric, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.models.base import BaseModel


class AuditoriaPagosRedireccion(BaseModel):
    """
    Tabla de registro y trazabilidad interna para intenciones de pago
    y clics hacia pasarelas externas (Multipago y Pago al Paso).
    """
    __tablename__ = "auditoria_pagos_redireccion"

    usuario_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        doc="ID del usuario que inició la redirección"
    )
    cod_socio: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        index=True,
        doc="Código de socio asociado a la deuda a pagar"
    )
    canal_id: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        doc="Identificador del canal seleccionado ('multipago' o 'pago_al_paso')"
    )
    monto_deuda_bs: Mapped[Optional[float]] = mapped_column(
        Numeric(10, 2),
        nullable=True,
        doc="Monto de la deuda pendiente al momento del clic"
    )
    ip_origen: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
        doc="Dirección IP de la petición del cliente"
    )

    # Relación inversa
    usuario = relationship("Usuario", backref="auditoria_pagos")
