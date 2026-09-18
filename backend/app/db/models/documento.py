import uuid
from datetime import date
from typing import Optional, TYPE_CHECKING
from sqlalchemy import Date, ForeignKey, Integer, Numeric, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.models.base import BaseModel

if TYPE_CHECKING:
    from app.db.models.suministro import Suministro


class Documento(BaseModel):
    """
    Entidad que almacena los metadatos de documentos digitales emitidos por COSMOL R.L.
    (Facturas fiscales con valor legal, Avisos de Cobranza y Avisos de Corte),
    indexando la ubicación del archivo binario PDF en MinIO S3 ('s3_key').
    """
    __tablename__ = "documentos"
    __table_args__ = (
        UniqueConstraint("cod_socio", "tipo_documento", "periodo", name="uq_socio_tipo_periodo"),
    )

    cod_socio: Mapped[str] = mapped_column(
        String(20),
        index=True,
        nullable=False,
        doc="Código del socio o suministro al que pertenece el documento"
    )

    tipo_documento: Mapped[str] = mapped_column(
        String(30),
        index=True,
        nullable=False,
        doc="Tipo de documento: 'FACTURA', 'AVISO_COBRANZA' o 'AVISO_CORTE'"
    )

    nro_factura: Mapped[Optional[str]] = mapped_column(
        String(50),
        nullable=True,
        index=True,
        doc="Número de factura fiscal oficial SIAT"
    )

    nro_facip: Mapped[Optional[str]] = mapped_column(
        String(50),
        nullable=True,
        doc="Número de aviso interno de cobranza FACIP"
    )

    cod_autorizacion: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
        doc="Código de autorización digital fiscal de Impuestos Nacionales"
    )

    periodo: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        doc="Periodo facturado en formato MM/YYYY (ej: '08/2026')"
    )

    anio: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        doc="Año de facturación"
    )

    mes: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        doc="Mes numérico de facturación (1-12)"
    )

    monto_bs: Mapped[float] = mapped_column(
        Numeric(10, 2),
        nullable=False,
        doc="Monto total expresado en Bolivianos (Bs)"
    )

    s3_key: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        doc="Ruta de almacenamiento del objeto PDF dentro del bucket de MinIO"
    )

    fecha_emision: Mapped[date] = mapped_column(
        Date,
        default=date.today,
        nullable=False,
        doc="Fecha en que fue emitido el documento"
    )

    fecha_vencimiento: Mapped[Optional[date]] = mapped_column(
        Date,
        nullable=True,
        doc="Fecha límite reglamentaria de pago"
    )

    estado_pago: Mapped[str] = mapped_column(
        String(20),
        default="PENDIENTE",
        nullable=False,
        doc="Estado: 'PENDIENTE' o 'PAGADO'"
    )

    suministro_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("suministros.id", ondelete="SET NULL"),
        index=True,
        nullable=True,
        doc="Referencia opcional al suministro en la base de datos local"
    )

    suministro: Mapped[Optional["Suministro"]] = relationship(
        "Suministro"
    )

    def __repr__(self) -> str:
        return (
            f"<Documento(id={self.id}, cod_socio='{self.cod_socio}', "
            f"tipo='{self.tipo_documento}', periodo='{self.periodo}', monto_bs={self.monto_bs})>"
        )
