"""
Servicio de almacenamiento y recuperación de documentos digitales (COSMOL R.L. - DEV 1).
Orquesta la generación on-demand de PDFs con ReportLab, su persistencia en MinIO Object Storage
y el registro de metadatos en la tabla 'documentos' de PostgreSQL.
"""
from datetime import date
import logging
from typing import Any, Dict, List, Optional
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Documento, Suministro
from app.integrations.minio_client import CosmolMinioClient, minio_client
from app.services.generador_pdf import GeneradorPdfDocumento, generador_pdf

logger = logging.getLogger(__name__)


class ServicioStorageDocumentos:
    """
    Controlador de infraestructura para persistencia y generación de documentos en MinIO S3.
    """

    def __init__(
        self,
        db: AsyncSession,
        s3_client: Optional[CosmolMinioClient] = None,
        pdf_engine: Optional[GeneradorPdfDocumento] = None
    ):
        self.db = db
        self.s3 = s3_client or minio_client
        self.pdf = pdf_engine or generador_pdf

    def construir_s3_key(
        self,
        cod_socio: str,
        tipo_documento: str,
        periodo: str,
        identificador: str
    ) -> str:
        """
        Construye la clave canónica de almacenamiento en MinIO según el tipo de documento:
        - Facturas: facturas/{cod_socio}/{periodo_slug}_{identificador}.pdf
        - Avisos de Cobranza: avisos_cobranza/{cod_socio}/{periodo_slug}_{identificador}.pdf
        - Avisos de Corte: avisos_corte/{cod_socio}/{periodo_slug}_{identificador}.pdf
        """
        periodo_slug = periodo.replace("/", "_")
        carpeta = {
            "FACTURA": "facturas",
            "AVISO_COBRANZA": "avisos_cobranza",
            "AVISO_CORTE": "avisos_corte",
        }.get(tipo_documento, "otros")

        return f"{carpeta}/{cod_socio}/{periodo_slug}_{identificador}.pdf"

    async def guardar_documento(
        self,
        cod_socio: str,
        tipo_documento: str,
        periodo: str,
        anio: int,
        mes: int,
        monto_bs: float,
        pdf_bytes: bytes,
        nro_factura: Optional[str] = None,
        nro_facip: Optional[str] = None,
        cod_autorizacion: Optional[str] = None,
        fecha_emision: Optional[date] = None,
        fecha_vencimiento: Optional[date] = None,
        suministro_id: Optional[uuid.UUID] = None
    ) -> Documento:
        """
        Sube el archivo binario a MinIO S3 e inserta o actualiza el registro en PostgreSQL.
        """
        identificador = nro_factura or nro_facip or uuid.uuid4().hex[:8]
        s3_key = self.construir_s3_key(cod_socio, tipo_documento, periodo, identificador)

        # 1. Almacenar en MinIO S3
        self.s3.subir_archivo_bytes(
            object_name=s3_key,
            data_bytes=pdf_bytes,
            content_type="application/pdf"
        )

        # 2. Si no se especificó suministro_id, buscarlo en PostgreSQL
        if not suministro_id:
            stmt_sum = select(Suministro.id).where(Suministro.cod_socio == cod_socio)
            res_sum = await self.db.execute(stmt_sum)
            suministro_id = res_sum.scalar_one_or_none()

        # 3. Comprobar si ya existe registro en la tabla 'documentos'
        stmt_doc = select(Documento).where(
            Documento.cod_socio == cod_socio,
            Documento.tipo_documento == tipo_documento,
            Documento.periodo == periodo
        )
        res_doc = await self.db.execute(stmt_doc)
        doc_db = res_doc.scalar_one_or_none()

        if doc_db:
            doc_db.monto_bs = monto_bs
            doc_db.s3_key = s3_key
            doc_db.nro_factura = nro_factura or doc_db.nro_factura
            doc_db.nro_facip = nro_facip or doc_db.nro_facip
            doc_db.cod_autorizacion = cod_autorizacion or doc_db.cod_autorizacion
            doc_db.fecha_vencimiento = fecha_vencimiento or doc_db.fecha_vencimiento
            if suministro_id:
                doc_db.suministro_id = suministro_id
        else:
            doc_db = Documento(
                cod_socio=cod_socio,
                tipo_documento=tipo_documento,
                nro_factura=nro_factura,
                nro_facip=nro_facip,
                cod_autorizacion=cod_autorizacion,
                periodo=periodo,
                anio=anio,
                mes=mes,
                monto_bs=monto_bs,
                s3_key=s3_key,
                fecha_emision=fecha_emision or date.today(),
                fecha_vencimiento=fecha_vencimiento,
                estado_pago="PENDIENTE",
                suministro_id=suministro_id
            )
            self.db.add(doc_db)

        await self.db.commit()
        await self.db.refresh(doc_db)
        return doc_db

    async def obtener_o_generar_pdf_factura(
        self,
        cod_socio: str,
        datos_factura: Dict[str, Any],
        datos_socio: Dict[str, Any]
    ) -> bytes:
        """
        Recupera el PDF de la factura desde MinIO si ya existe; si no existe,
        lo genera con ReportLab, lo almacena en MinIO y en la BD, y retorna los bytes.
        """
        nro_factura = str(datos_factura.get("NROFACTURA") or datos_factura.get("nro_factura") or "").strip()
        nmes = int(datos_factura.get("NMES") or datos_factura.get("mes") or 0)
        anio = int(datos_factura.get("ANIO") or datos_factura.get("anio") or 0)
        periodo = str(datos_factura.get("periodo") or f"{nmes:02d}/{anio}").strip()
        s3_key = self.construir_s3_key(cod_socio, "FACTURA", periodo, nro_factura)

        # 1. Comprobar si ya existe en MinIO
        if self.s3.existe_archivo(s3_key):
            try:
                pdf_bytes = self.s3.obtener_archivo_bytes(s3_key)
                # Asegurar que también exista en PostgreSQL
                stmt = select(Documento).where(
                    Documento.cod_socio == cod_socio,
                    Documento.tipo_documento == "FACTURA",
                    Documento.periodo == periodo
                )
                res = await self.db.execute(stmt)
                if not res.scalar_one_or_none():
                    anio = int(datos_factura.get("ANIO") or datos_factura.get("anio") or date.today().year)
                    mes = int(datos_factura.get("NMES") or datos_factura.get("mes") or date.today().month)
                    monto_bs = float(datos_factura.get("MONTOTOTAL") or datos_factura.get("monto_bs") or 0.0)
                    cod_aut = str(datos_factura.get("CODAUTORIZACION") or datos_factura.get("cod_autorizacion") or "")
                    await self.guardar_documento(
                        cod_socio=cod_socio,
                        tipo_documento="FACTURA",
                        periodo=periodo,
                        anio=anio,
                        mes=mes,
                        monto_bs=monto_bs,
                        pdf_bytes=pdf_bytes,
                        nro_factura=nro_factura,
                        cod_autorizacion=cod_aut
                    )
                return pdf_bytes
            except Exception as exc:
                logger.warning(f"[STORAGE] Error al recuperar '{s3_key}' de MinIO: {exc}. Regenerando...")

        # 2. Generar on-demand
        pdf_bytes = self.pdf.generar_pdf_factura(datos_factura=datos_factura, datos_socio=datos_socio)

        # 3. Persistir en MinIO y PostgreSQL
        try:
            anio = int(datos_factura.get("ANIO") or datos_factura.get("anio") or date.today().year)
            mes = int(datos_factura.get("NMES") or datos_factura.get("mes") or date.today().month)
            monto_bs = float(datos_factura.get("MONTOTOTAL") or datos_factura.get("monto_bs") or 0.0)
            cod_aut = str(datos_factura.get("CODAUTORIZACION") or datos_factura.get("cod_autorizacion") or "")

            await self.guardar_documento(
                cod_socio=cod_socio,
                tipo_documento="FACTURA",
                periodo=periodo,
                anio=anio,
                mes=mes,
                monto_bs=monto_bs,
                pdf_bytes=pdf_bytes,
                nro_factura=nro_factura,
                cod_autorizacion=cod_aut
            )
        except Exception as exc:
            logger.error(f"[STORAGE] Fallo al indexar factura generada en BD: {exc}")

        return pdf_bytes

    async def obtener_o_generar_pdf_aviso_cobranza(
        self,
        cod_socio: str,
        datos_deuda: Dict[str, Any],
        datos_socio: Dict[str, Any]
    ) -> bytes:
        """
        Recupera o genera el Aviso de Cobranza preventivo en PDF.
        """
        nro_facip = str(datos_deuda.get("NROFACIP") or datos_deuda.get("nro_facip") or "aviso").strip()
        nmes = int(datos_deuda.get("NMES") or datos_deuda.get("mes") or 0)
        anio = int(datos_deuda.get("ANIO") or datos_deuda.get("anio") or 0)
        periodo = str(datos_deuda.get("periodo") or f"{nmes:02d}/{anio}").strip()
        s3_key = self.construir_s3_key(cod_socio, "AVISO_COBRANZA", periodo, nro_facip)

        if self.s3.existe_archivo(s3_key):
            try:
                pdf_bytes = self.s3.obtener_archivo_bytes(s3_key)
                stmt = select(Documento).where(
                    Documento.cod_socio == cod_socio,
                    Documento.tipo_documento == "AVISO_COBRANZA",
                    Documento.periodo == periodo
                )
                res = await self.db.execute(stmt)
                if not res.scalar_one_or_none():
                    anio_val = int(datos_deuda.get("ANIO") or datos_deuda.get("anio") or date.today().year)
                    mes_val = int(datos_deuda.get("NMES") or datos_deuda.get("mes") or date.today().month)
                    monto_val = float(datos_deuda.get("MONTOTOTAL") or datos_deuda.get("monto_bs") or 0.0)
                    await self.guardar_documento(
                        cod_socio=cod_socio,
                        tipo_documento="AVISO_COBRANZA",
                        periodo=periodo,
                        anio=anio_val,
                        mes=mes_val,
                        monto_bs=monto_val,
                        pdf_bytes=pdf_bytes,
                        nro_facip=nro_facip
                    )
                return pdf_bytes
            except Exception as exc:
                logger.warning(f"[STORAGE] Error al recuperar '{s3_key}': {exc}. Regenerando...")

        pdf_bytes = self.pdf.generar_pdf_aviso_cobranza(datos_deuda=datos_deuda, datos_socio=datos_socio)

        try:
            anio = int(datos_deuda.get("ANIO") or datos_deuda.get("anio") or date.today().year)
            mes = int(datos_deuda.get("NMES") or datos_deuda.get("mes") or date.today().month)
            monto_bs = float(datos_deuda.get("MONTOTOTAL") or datos_deuda.get("monto_bs") or 0.0)

            await self.guardar_documento(
                cod_socio=cod_socio,
                tipo_documento="AVISO_COBRANZA",
                periodo=periodo,
                anio=anio,
                mes=mes,
                monto_bs=monto_bs,
                pdf_bytes=pdf_bytes,
                nro_facip=nro_facip
            )
        except Exception as exc:
            logger.error(f"[STORAGE] Fallo al indexar aviso de cobranza en BD: {exc}")

        return pdf_bytes

    async def obtener_o_generar_pdf_aviso_corte(
        self,
        cod_socio: str,
        datos_socio: Dict[str, Any],
        facturas_pendientes: List[Dict[str, Any]]
    ) -> bytes:
        """
        Recupera o genera la Notificación de Corte formal en PDF.
        """
        periodo_reciente = date.today().strftime("%m/%Y")
        s3_key = self.construir_s3_key(cod_socio, "AVISO_CORTE", periodo_reciente, "corte_inminente")

        if self.s3.existe_archivo(s3_key):
            try:
                return self.s3.obtener_archivo_bytes(s3_key)
            except Exception as exc:
                logger.warning(f"[STORAGE] Error al recuperar '{s3_key}': {exc}. Regenerando...")

        pdf_bytes = self.pdf.generar_pdf_aviso_corte(datos_socio=datos_socio, facturas_pendientes=facturas_pendientes)

        try:
            total_monto = sum(float(f.get("MONTOTOTAL") or f.get("monto_bs") or 0.0) for f in facturas_pendientes)
            await self.guardar_documento(
                cod_socio=cod_socio,
                tipo_documento="AVISO_CORTE",
                periodo=periodo_reciente,
                anio=date.today().year,
                mes=date.today().month,
                monto_bs=round(total_monto, 2),
                pdf_bytes=pdf_bytes
            )
        except Exception as exc:
            logger.error(f"[STORAGE] Fallo al indexar aviso de corte en BD: {exc}")

        return pdf_bytes
