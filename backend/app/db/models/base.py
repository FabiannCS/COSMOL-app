import uuid
from datetime import datetime
from sqlalchemy import DateTime, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.db.session import Base


class BaseModel(Base):
    """
    Modelo base abstracto para todas las entidades del sistema COSMOL R.L.
    Provee estandarización de clave primaria UUID v4 y marcas temporales auditables.
    """
    __abstract__ = True

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        index=True,
        doc="Identificador único universal (UUID v4)"
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        doc="Fecha y hora de creación con zona horaria"
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
        doc="Fecha y hora de última actualización con zona horaria"
    )

    def __repr__(self) -> str:
        return f"<{self.__class__.__name__}(id={self.id})>"
