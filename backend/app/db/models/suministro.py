import uuid
from typing import TYPE_CHECKING
from sqlalchemy import Boolean, ForeignKey, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.models.base import BaseModel

if TYPE_CHECKING:
    from app.db.models.usuario import Usuario


class Suministro(BaseModel):
    """
    Entidad que representa un Código de Socio / Contrato de Suministro de agua vinculado a un Usuario Digital.
    Permite la arquitectura multicuenta (1 usuario administra N suministros, y 1 suministro puede ser pagado/consultado por N usuarios).
    """
    __tablename__ = "suministros"
    __table_args__ = (
        UniqueConstraint("usuario_id", "cod_socio", name="uq_usuario_cod_socio"),
    )

    usuario_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("usuarios.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
        doc="Clave foránea hacia el usuario digital propietario de la vinculación"
    )

    cod_socio: Mapped[str] = mapped_column(
        String(20),
        index=True,
        nullable=False,
        doc="Código de socio en el sistema comercial de COSMOL"
    )

    alias: Mapped[str] = mapped_column(
        String(50),
        default="Mi Suministro",
        nullable=False,
        doc="Nombre personalizado asignado por el socio (ej: 'Mi Casa', 'Alquiler Bolívar')"
    )

    rol: Mapped[str] = mapped_column(
        String(20),
        default="TITULAR",
        nullable=False,
        doc="Nivel de acceso: 'TITULAR' (acceso legal y facturas) o 'CONSULTA_PAGO' (inquilinos con datos sensibles enmascarados)"
    )

    es_suministro_principal: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
        doc="Indica si este medidor/suministro se muestra por defecto al abrir la aplicación"
    )

    # Relación inversa hacia Usuario
    usuario: Mapped["Usuario"] = relationship(
        "Usuario",
        back_populates="suministros"
    )

    def __repr__(self) -> str:
        return f"<Suministro(id={self.id}, cod_socio='{self.cod_socio}', alias='{self.alias}', rol='{self.rol}')>"
