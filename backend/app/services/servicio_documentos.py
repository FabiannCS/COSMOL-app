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

        # 3. Sincronización continua e incremental de facturas y avisos desde COSMOL
        try:
            import uuid as py_uuid
            facturas_pendientes = await self.cosmol.obtener_deudas_socio(cod_socio)

            if facturas_pendientes is not None:
                # Consultar todos los documentos ya persistidos de este suministro para comparar periodos
                stmt_existentes = select(Documento).where(Documento.cod_socio == cod_socio)
                res_existentes = await self.db.execute(stmt_existentes)
                existentes_todos = list(res_existentes.scalars().all())

                mapa_existentes = {
                    (d.tipo_documento, d.periodo): d for d in existentes_todos
                }

                periodos_pendientes = set()
                hubo_cambios = False

                for fac in facturas_pendientes:
                    try:
                        anio = int(fac.get("ANIO") or fac.get("anio") or date.today().year)
                        mes = int(fac.get("NMES") or fac.get("mes") or 1)
                        periodo = f"{mes:02d}/{anio}"
                        periodos_pendientes.add(periodo)

                        monto_bs = round(float(fac.get("MONTOTOTAL") or fac.get("monto_bs") or 0.0), 2)
                        nro_factura = str(fac.get("NROFACTURA") or "").strip() or None
                        nro_facip = str(fac.get("NROFACIP") or "").strip() or None
                        cod_autorizacion = str(fac.get("CODAUTORIZACION") or "").strip() or None
                        fecha_emi = self.storage._determinar_fecha_emision(anio, mes, fac)
                        fecha_venc = self.storage._determinar_fecha_vencimiento(anio, mes, fac)
                        identificador = nro_factura or nro_facip or py_uuid.uuid4().hex[:8]

                        # 1. Asegurar Aviso de Cobranza para este periodo
                        if ("AVISO_COBRANZA", periodo) not in mapa_existentes:
                            s3_key_aviso = self.storage.construir_s3_key(cod_socio, "AVISO_COBRANZA", periodo, identificador)
                            doc_aviso = Documento(
                                cod_socio=cod_socio,
                                tipo_documento="AVISO_COBRANZA",
                                nro_factura=nro_factura,
                                nro_facip=nro_facip,
                                cod_autorizacion=cod_autorizacion,
                                periodo=periodo,
                                anio=anio,
                                mes=mes,
                                monto_bs=monto_bs,
                                s3_key=s3_key_aviso,
                                fecha_emision=fecha_emi,
                                fecha_vencimiento=fecha_venc,
                                estado_pago="PENDIENTE",
                                suministro_id=suministro.id
                            )
                            self.db.add(doc_aviso)
                            mapa_existentes[("AVISO_COBRANZA", periodo)] = doc_aviso
                            hubo_cambios = True
                        else:
                            doc_exist = mapa_existentes[("AVISO_COBRANZA", periodo)]
                            if doc_exist.estado_pago != "PENDIENTE":
                                doc_exist.estado_pago = "PENDIENTE"
                                hubo_cambios = True
                            if nro_facip and not doc_exist.nro_facip:
                                doc_exist.nro_facip = nro_facip
                                hubo_cambios = True

                        # 2. Asegurar Factura Fiscal para este periodo (disponible en BD para el titular)
                        if ("FACTURA", periodo) not in mapa_existentes:
                            s3_key_fac = self.storage.construir_s3_key(cod_socio, "FACTURA", periodo, identificador)
                            doc_fac = Documento(
                                cod_socio=cod_socio,
                                tipo_documento="FACTURA",
                                nro_factura=nro_factura,
                                nro_facip=nro_facip,
                                cod_autorizacion=cod_autorizacion,
                                periodo=periodo,
                                anio=anio,
                                mes=mes,
                                monto_bs=monto_bs,
                                s3_key=s3_key_fac,
                                fecha_emision=fecha_emi,
                                fecha_vencimiento=fecha_venc,
                                estado_pago="PENDIENTE",
                                suministro_id=suministro.id
                            )
                            self.db.add(doc_fac)
                            mapa_existentes[("FACTURA", periodo)] = doc_fac
                            hubo_cambios = True
                        else:
                            doc_exist = mapa_existentes[("FACTURA", periodo)]
                            if doc_exist.estado_pago != "PENDIENTE":
                                doc_exist.estado_pago = "PENDIENTE"
                                hubo_cambios = True
                            if nro_factura and not doc_exist.nro_factura:
                                doc_exist.nro_factura = nro_factura
                                hubo_cambios = True
                            if cod_autorizacion and not doc_exist.cod_autorizacion:
                                doc_exist.cod_autorizacion = cod_autorizacion
                                hubo_cambios = True

                    except Exception as err_item:
                        logger.warning(f"[DOCUMENTOS] Error al normalizar metadato de factura: {err_item}")

                # 3. Conciliar facturas y avisos históricos que ya fueron cancelados en COSMOL
                if periodos_pendientes:
                    for d in existentes_todos:
                        if d.tipo_documento in ["FACTURA", "AVISO_COBRANZA"] and d.periodo not in periodos_pendientes:
                            if d.estado_pago != "PAGADO":
                                d.estado_pago = "PAGADO"
                                hubo_cambios = True

                # 4. Conciliar Aviso de Corte si aplica mora (2 o más facturas pendientes)
                tiene_corte = any(d.tipo_documento == "AVISO_CORTE" for d in existentes_todos)
                if len(facturas_pendientes) >= 2 and not tiene_corte and rol_acceso == "TITULAR":
                    s3_key_corte = self.storage.construir_s3_key(cod_socio, "AVISO_CORTE", "MORA", py_uuid.uuid4().hex[:8])
                    doc_corte = Documento(
                        cod_socio=cod_socio,
                        tipo_documento="AVISO_CORTE",
                        periodo="AVISO DE CORTE",
                        anio=date.today().year,
                        mes=date.today().month,
                        monto_bs=round(sum(float(f.get("MONTOTOTAL", 0.0)) for f in facturas_pendientes), 2),
                        s3_key=s3_key_corte,
                        fecha_emision=date.today(),
                        fecha_vencimiento=None,
                        estado_pago="PENDIENTE",
                        suministro_id=suministro.id
                    )
                    self.db.add(doc_corte)
                    hubo_cambios = True

                if hubo_cambios:
                    await self.db.commit()
                    # Re-consultar documentos tras sincronización
                    res_sync = await self.db.execute(stmt_docs)
                    documentos_db = list(res_sync.scalars().all())

        except Exception as exc:
            logger.warning(f"[DOCUMENTOS] Sincronización continua de facturas no ejecutada: {exc}")

        # 4. Auto-remediación rápida de fechas en BD (sin regeneración síncrona de archivos)
        modificado = False
        for doc in documentos_db:
            if doc.anio and doc.mes:
                emision_esperada = self.storage._determinar_fecha_emision(doc.anio, doc.mes, {})
                vencimiento_esperado = self.storage._determinar_fecha_vencimiento(doc.anio, doc.mes, {})
                if doc.fecha_emision != emision_esperada:
                    doc.fecha_emision = emision_esperada
                    modificado = True
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

        # 4. Asegurar que el archivo en MinIO S3 exista y esté actualizado con el formato oficial
        # Para AVISO_COBRANZA siempre regeneramos para garantizar el diseño oficial y datos reales de consumo
        if doc.tipo_documento == "AVISO_COBRANZA" or not self.s3.existe_archivo(doc.s3_key):
            try:
                datos_socio = await self.cosmol.obtener_datos_socio(doc.cod_socio) or {}
            except Exception:
                datos_socio = {}

            try:
                await self.storage.regenerar_pdf_desde_documento(doc, datos_socio)
            except Exception as exc:
                logger.error(f"[STORAGE] Error al regenerar documento para descarga: {exc}")
                if not self.s3.existe_archivo(doc.s3_key):
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
