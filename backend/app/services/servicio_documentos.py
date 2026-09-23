"""
Servicio de lógica de negocio para Repositorio Digital de Documentos y Descargas (COSMOL R.L. - DEV 2).
Implementa:
- Control de privacidad Multicuenta: 'TITULAR' accede a Facturas, Avisos de Cobranza y Avisos de Corte;
  'CONSULTA_PAGO' (inquilinos/pagadores externos) queda restringido exclusivamente a Avisos de Cobranza.
- Consultas optimizadas a PostgreSQL.
- Transmisión en streaming de PDFs binarios desde MinIO S3.
- Auditoría asíncrona de descargas hacia ChatbotReportes.
"""
from datetime import date, datetime, timezone
import io
import logging
from typing import Any, Dict, Generator, List, Optional, Tuple
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ForbiddenException, NotFoundException
from app.db.models import Documento, Suministro
from app.integrations.cosmol_client import CosmolLegacyClient, cosmol_client
from app.integrations.minio_client import CosmolMinioClient, minio_client
from app.schemas.documento import DocumentoResponse, ListaDocumentosResponse
from app.services.servicio_storage_documentos import ServicioStorageDocumentos

logger = logging.getLogger(__name__)


async def registrar_auditoria_descarga(
    usuario_id: UUID,
    cod_socio: str,
    doc_id: UUID,
    tipo_documento: str
) -> None:
    """
    Despacha en segundo plano (BackgroundTasks) el evento de auditoría de descarga
    hacia la base de datos de ChatbotReportes (AGENTS.md secciones 6 y 12.3).
    """
    timestamp = datetime.now(timezone.utc).isoformat()
    logger.info(
        f"[AUDITORIA] EVENT='DOCUMENT_DOWNLOADED' usuario_id={usuario_id} "
        f"cod_socio='{cod_socio}' doc_id={doc_id} tipo='{tipo_documento}' timestamp={timestamp}"
    )


class ServicioDocumentos:
    """
    Servicio de orquestación para consulta y descarga de documentos institucionales de COSMOL R.L.
    """

    def __init__(
        self,
        db: AsyncSession,
        s3_client: Optional[CosmolMinioClient] = None,
        cosmol: Optional[CosmolLegacyClient] = None,
        storage_service: Optional[ServicioStorageDocumentos] = None
    ):
        self.db = db
        self.s3 = s3_client or minio_client
        self.cosmol = cosmol or cosmol_client
        self.storage = storage_service or ServicioStorageDocumentos(db=db, s3_client=self.s3)

    async def _validar_suministro_usuario(
        self,
        usuario_id: UUID,
        cod_socio: str
    ) -> Suministro:
        """
        Verifica que el suministro pertenezca a la cartera del usuario autenticado.
        """
        stmt = select(Suministro).where(
            Suministro.usuario_id == usuario_id,
            Suministro.cod_socio == cod_socio
        )
        res = await self.db.execute(stmt)
        suministro = res.scalar_one_or_none()
        if not suministro:
            raise NotFoundException(
                message=f"El suministro '{cod_socio}' no está vinculado a su cuenta de usuario.",
                error_code="SUMINISTRO_NOT_FOUND"
            )
        return suministro

    async def listar_documentos_socio(
        self,
        usuario_id: UUID,
        cod_socio: str,
        tipo: Optional[str] = None
    ) -> ListaDocumentosResponse:
        """
        Retorna la colección de documentos disponibles para un suministro respetando la privacidad del rol:
        - Si el rol es 'CONSULTA_PAGO': solo puede ver Avisos de Cobranza.
          Intentar forzar ?tipo=FACTURA o ?tipo=AVISO_CORTE genera 403 Forbidden.
        - Si el rol es 'TITULAR': puede ver Facturas, Avisos de Cobranza y Avisos de Corte.
        """
        suministro = await self._validar_suministro_usuario(usuario_id=usuario_id, cod_socio=cod_socio)
        rol_acceso = suministro.rol

        # 1. Regla de seguridad multicuenta para inquilinos
        if rol_acceso == "CONSULTA_PAGO":
            if tipo and tipo.upper() in ["FACTURA", "AVISO_CORTE"]:
                raise ForbiddenException(
                    message="El perfil de consulta/inquilino no tiene autorización para acceder a facturas fiscales ni avisos de corte.",
                    error_code="DOCUMENT_ACCESS_DENIED"
                )

        # 2. Consultar registros en PostgreSQL
        stmt_docs = select(Documento).where(Documento.cod_socio == cod_socio)
        if rol_acceso == "CONSULTA_PAGO":
            stmt_docs = stmt_docs.where(Documento.tipo_documento == "AVISO_COBRANZA")
        elif tipo:
            stmt_docs = stmt_docs.where(Documento.tipo_documento == tipo.upper())

        stmt_docs = stmt_docs.order_by(
            Documento.anio.desc(),
            Documento.mes.desc(),
            Documento.fecha_emision.desc()
        )
        res_docs = await self.db.execute(stmt_docs)
        documentos_db = list(res_docs.scalars().all())

        # 3. Auto-sincronización on-demand si no hay documentos registrados aún
        if not documentos_db:
            try:
                datos_socio = await self.cosmol.obtener_datos_socio(cod_socio) or {}
                facturas_pendientes = await self.cosmol.obtener_deudas_socio(cod_socio) or []

                for fac in facturas_pendientes:
                    await self.storage.obtener_o_generar_pdf_aviso_cobranza(
                        cod_socio=cod_socio,
                        datos_deuda=fac,
                        datos_socio=datos_socio
                    )
                    if rol_acceso == "TITULAR":
                        await self.storage.obtener_o_generar_pdf_factura(
                            cod_socio=cod_socio,
                            datos_factura=fac,
                            datos_socio=datos_socio
                        )

                if len(facturas_pendientes) >= 2 and rol_acceso == "TITULAR":
                    await self.storage.obtener_o_generar_pdf_aviso_corte(
                        cod_socio=cod_socio,
                        datos_socio=datos_socio,
                        facturas_pendientes=facturas_pendientes
                    )

                # Re-consultar documentos tras sincronización
                res_sync = await self.db.execute(stmt_docs)
                documentos_db = list(res_sync.scalars().all())
            except Exception as exc:
                logger.warning(f"[DOCUMENTOS] Auto-sincronización con sistema comercial no ejecutada: {exc}")

        # 4. Auto-remediación de fechas históricas registradas previamente con fallback a today()
        modificado = False
        for doc in documentos_db:
            if doc.anio and doc.mes:
                emision_esperada = self.storage._determinar_fecha_emision(doc.anio, doc.mes, {})
                vencimiento_esperado = self.storage._determinar_fecha_vencimiento(doc.anio, doc.mes, {})
                if doc.fecha_emision != emision_esperada:
                    doc.fecha_emision = emision_esperada
                    modificado = True
                    try:
                        await self.storage.regenerar_pdf_desde_documento(doc)
                    except Exception as exc:
                        logger.warning(f"[DOCUMENTOS] No se pudo regenerar PDF en auto-remediación: {exc}")
                if doc.fecha_vencimiento is None or doc.fecha_vencimiento != vencimiento_esperado:
                    doc.fecha_vencimiento = vencimiento_esperado
                    modificado = True
        if modificado:
            await self.db.commit()
            for doc in documentos_db:
                await self.db.refresh(doc)

        # 5. Estructurar DTOs de respuesta por pestañas
        facturas_list: List[DocumentoResponse] = []
        avisos_cobranza_list: List[DocumentoResponse] = []
        avisos_corte_list: List[DocumentoResponse] = []
        todos_los_docs: List[DocumentoResponse] = []

        for doc in documentos_db:
            doc_item = DocumentoResponse(
                id=doc.id,
                cod_socio=doc.cod_socio,
                tipo_documento=doc.tipo_documento,
                nro_factura=doc.nro_factura,
                nro_facip=doc.nro_facip,
                cod_autorizacion=doc.cod_autorizacion,
                periodo=doc.periodo,
                anio=doc.anio,
                mes=doc.mes,
                monto_bs=float(doc.monto_bs),
                fecha_emision=doc.fecha_emision,
                fecha_vencimiento=doc.fecha_vencimiento,
                estado_pago=doc.estado_pago,
                s3_key=doc.s3_key,
                permite_descarga=True,
                url_descarga=f"/api/v1/documentos/{doc.id}/descargar"
            )
            todos_los_docs.append(doc_item)
            if doc.tipo_documento == "FACTURA":
                facturas_list.append(doc_item)
            elif doc.tipo_documento == "AVISO_COBRANZA":
                avisos_cobranza_list.append(doc_item)
            elif doc.tipo_documento == "AVISO_CORTE":
                avisos_corte_list.append(doc_item)

        return ListaDocumentosResponse(
            cod_socio=cod_socio,
            rol_acceso=rol_acceso,
            total_documentos=len(todos_los_docs),
            facturas=facturas_list if rol_acceso == "TITULAR" else [],
            avisos_cobranza=avisos_cobranza_list,
            avisos_corte=avisos_corte_list if rol_acceso == "TITULAR" else [],
            documentos=todos_los_docs
        )

    async def obtener_documento_para_descarga(
        self,
        usuario_id: UUID,
        doc_id: UUID
    ) -> Tuple[Generator[bytes, None, None], str, Documento]:
        """
        Valida permisos de descarga y recupera el flujo binario del archivo PDF:
        - Si el documento no existe -> 404 NOT_FOUND.
        - Si el suministro no pertenece al usuario -> 403 FORBIDDEN.
        - Si el rol es 'CONSULTA_PAGO' y se solicita 'FACTURA' o 'AVISO_CORTE' -> 403 FORBIDDEN (DOCUMENT_ACCESS_DENIED).
        - Si el archivo físico no está en S3, lo genera automáticamente con sus metadatos.
        - Retorna (stream_generador, nombre_archivo_descarga, objeto_documento).
        """
        # 1. Obtener documento de la base de datos
        stmt_doc = select(Documento).where(Documento.id == doc_id)
        res_doc = await self.db.execute(stmt_doc)
        doc = res_doc.scalar_one_or_none()
        if not doc:
            raise NotFoundException(
                message="El documento solicitado no existe o no se encuentra disponible.",
                error_code="DOCUMENT_NOT_FOUND"
            )

        # 2. Validar que el usuario tenga vinculado este suministro
        stmt_sum = select(Suministro).where(
            Suministro.usuario_id == usuario_id,
            Suministro.cod_socio == doc.cod_socio
        )
        res_sum = await self.db.execute(stmt_sum)
        suministro = res_sum.scalar_one_or_none()
        if not suministro:
            raise ForbiddenException(
                message="No tiene autorización para descargar documentos de este suministro.",
                error_code="SUMINISTRO_ACCESS_DENIED"
            )

        # 3. Validar restricción de privacidad fiscal
        if suministro.rol == "CONSULTA_PAGO" and doc.tipo_documento in ["FACTURA", "AVISO_CORTE"]:
            raise ForbiddenException(
                message="Acceso denegado: solo el titular registrado puede descargar facturas fiscales y avisos de corte.",
                error_code="DOCUMENT_ACCESS_DENIED"
            )

        # 4. Asegurar que el archivo en MinIO S3 exista, regenerándolo si fuera necesario
        if not self.s3.existe_archivo(doc.s3_key):
            try:
                datos_socio = await self.cosmol.obtener_datos_socio(doc.cod_socio) or {}
            except Exception:
                datos_socio = {}

            try:
                await self.storage.regenerar_pdf_desde_documento(doc, datos_socio)
            except Exception as exc:
                logger.error(f"[STORAGE] Error al regenerar documento faltante para descarga: {exc}")
                raise NotFoundException(
                    message="No se pudo generar ni recuperar el archivo PDF solicitado.",
                    error_code="PDF_GENERATION_FAILED"
                )

        # 5. Obtener stream desde MinIO
        stream = self.s3.obtener_archivo_stream(doc.s3_key)

        # 6. Construir nombre de archivo amigable para el navegador/móvil
        periodo_slug = doc.periodo.replace("/", "-")
        prefijos = {
            "FACTURA": "Factura_Oficial_COSMOL",
            "AVISO_COBRANZA": "Aviso_Cobranza_COSMOL",
            "AVISO_CORTE": "Aviso_Corte_COSMOL"
        }
        prefijo = prefijos.get(doc.tipo_documento, "Documento_COSMOL")
        filename = f"{prefijo}_{doc.cod_socio}_{periodo_slug}.pdf"

        return stream, filename, doc
