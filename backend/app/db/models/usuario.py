from datetime import datetime
from typing import List, Optional
from sqlalchemy import Boolean, DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.models.base import BaseModel


class Usuario(BaseModel):
    """
    Entidad que representa al Usuario Digital (persona que opera la aplicación móvil o web).
    Identificado unívocamente por su número de teléfono celular personal verificado.
    """
    __tablename__ = "usuarios"

    telefono: Mapped[str] = mapped_column(
        String(20),
        unique=True,
        index=True,
        nullable=False,
        doc="Número de teléfono celular personal verificado"
    )

    password_hash: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        doc="Hash seguro (bcrypt) de la contraseña o PIN personal del socio"
    )

    esta_activo: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
        doc="Indica si la cuenta se encuentra activa en el sistema"
    )

    intentos_fallidos: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
        doc="Contador de intentos de acceso fallidos consecutivos"
    )

    bloqueado_hasta: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        doc="Marca temporal hasta la cual la cuenta permanece bloqueada por intentos fallidos"
    )

    # Relaciones
    suministros: Mapped[List["Suministro"]] = relationship(
        "Suministro",
        back_populates="usuario",
        cascade="all, delete-orphan",
        lazy="selectin"
    )

    dispositivos: Mapped[List["Dispositivo"]] = relationship(
        "Dispositivo",
        back_populates="usuario",
        cascade="all, delete-orphan",
        lazy="selectin"
    )

    def __init__(self, **kwargs):
        kwargs.setdefault("esta_activo", True)
        kwargs.setdefault("intentos_fallidos", 0)
        super().__init__(**kwargs)

    def __repr__(self) -> str:
        return f"<Usuario(id={self.id}, telefono='{self.telefono}', activo={self.esta_activo})>"
