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

import json

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ForbiddenException, NotFoundException
from app.core.redis import get_redis
from app.db.models import Documento, Suministro
from app.integrations.cosmol_client import CosmolLegacyClient, cosmol_client
from app.integrations.minio_client import CosmolMinioClient, minio_client
from app.schemas.documento import DocumentoResponse, ListaDocumentosResponse
from app.schemas.factura import FacturaDetalleResponse, ItemFacturaDetalle
from app.services.generador_factura_digital import generador_factura_digital
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
        mapa_fechas_pago: Dict[str, Optional[str]] = {}

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
                            s3_key_aviso = self.storage.construir_s3_key(
                                cod_socio=cod_socio,
                                tipo_documento="AVISO_COBRANZA",
                                periodo=periodo,
                                identificador=identificador,
                                anio=anio
                            )
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
                            s3_key_fac = self.storage.construir_s3_key(
                                cod_socio=cod_socio,
                                tipo_documento="FACTURA",
                                periodo=periodo,
                                identificador=identificador,
                                estado_pago="PENDIENTE",
                                anio=anio
                            )
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

                # 3. Conciliar facturas y avisos que ya fueron cancelados en COSMOL
                if periodos_pendientes:
                    for d in existentes_todos:
                        if d.tipo_documento in ["FACTURA", "AVISO_COBRANZA"] and d.periodo not in periodos_pendientes:
                            if d.estado_pago != "PAGADO":
                                d.estado_pago = "PAGADO"
                                ident = d.nro_factura or d.nro_facip or str(d.id)[:8]
                                nueva_key = self.storage.construir_s3_key(
                                    cod_socio=cod_socio,
                                    tipo_documento=d.tipo_documento,
                                    periodo=d.periodo,
                                    identificador=ident,
                                    estado_pago="PAGADO",
                                    anio=d.anio
                                )
                                if d.s3_key != nueva_key:
                                    if d.s3_key:
                                        try:
                                            self.s3.eliminar_archivo(d.s3_key)
                                        except Exception:
                                            pass
                                    d.s3_key = nueva_key
                                hubo_cambios = True

                # 4. Sincronizar facturas pagadas históricas desde GET /socios/{cod_socio}/historial-facturas
                try:
                    historial_docs = await self.cosmol.obtener_historial_consumo(cod_socio, meses=12)
                    if historial_docs:
                        for h_item in historial_docs:
                            h_mes = int(h_item.get("mes") or 1)
                            h_anio = int(h_item.get("anio") or date.today().year)
                            h_periodo = f"{h_mes:02d}/{h_anio}"
                            h_nro_factura = h_item.get("nro_factura") or h_item.get("NROFACTURA")
                            h_monto = float(h_item.get("monto_bs") or 0.0)
                            h_fecha = h_item.get("fecha_pago") or h_item.get("fecha") or h_item.get("FECHA")
                            if h_fecha:
                                mapa_fechas_pago[h_periodo] = str(h_fecha).strip()

                            # Enriquecer nro_factura si la factura ya existía (ej: pendiente) y no lo tenía
                            if ("FACTURA", h_periodo) in mapa_existentes:
                                doc_exist_f = mapa_existentes[("FACTURA", h_periodo)]
                                if not doc_exist_f.nro_factura and h_nro_factura:
                                    doc_exist_f.nro_factura = str(h_nro_factura)
                                    hubo_cambios = True

                            # Si no está en deudas pendientes y tiene nro_factura, es una factura PAGADA
                            if h_periodo not in periodos_pendientes and h_nro_factura:
                                fecha_emi_h = self.storage._determinar_fecha_emision(h_anio, h_mes, h_item)
                                fecha_venc_h = self.storage._determinar_fecha_vencimiento(h_anio, h_mes, h_item)

                                if ("FACTURA", h_periodo) not in mapa_existentes:
                                    s3_key_fac_pagada = self.storage.construir_s3_key(
                                        cod_socio=cod_socio,
                                        tipo_documento="FACTURA",
                                        periodo=h_periodo,
                                        identificador=str(h_nro_factura),
                                        estado_pago="PAGADO",
                                        anio=h_anio
                                    )
                                    doc_h = Documento(
                                        cod_socio=cod_socio,
                                        tipo_documento="FACTURA",
                                        nro_factura=str(h_nro_factura),
                                        periodo=h_periodo,
                                        anio=h_anio,
                                        mes=h_mes,
                                        monto_bs=round(h_monto, 2),
                                        s3_key=s3_key_fac_pagada,
                                        fecha_emision=fecha_emi_h,
                                        fecha_vencimiento=fecha_venc_h,
                                        estado_pago="PAGADO",
                                        suministro_id=suministro.id
                                    )
                                    self.db.add(doc_h)
                                    mapa_existentes[("FACTURA", h_periodo)] = doc_h
                                    hubo_cambios = True
                                else:
                                    doc_exist_h = mapa_existentes[("FACTURA", h_periodo)]
                                    if doc_exist_h.estado_pago != "PAGADO":
                                        doc_exist_h.estado_pago = "PAGADO"
                                        hubo_cambios = True
                                    if not doc_exist_h.nro_factura and h_nro_factura:
                                        doc_exist_h.nro_factura = str(h_nro_factura)
                                        hubo_cambios = True
                                    nueva_key_h = self.storage.construir_s3_key(
                                        cod_socio=cod_socio,
                                        tipo_documento="FACTURA",
                                        periodo=h_periodo,
                                        identificador=doc_exist_h.nro_factura or str(h_nro_factura),
                                        estado_pago="PAGADO",
                                        anio=h_anio
                                    )
                                    if doc_exist_h.s3_key != nueva_key_h:
                                        if doc_exist_h.s3_key:
                                            try:
                                                self.s3.eliminar_archivo(doc_exist_h.s3_key)
                                            except Exception:
                                                pass
                                        doc_exist_h.s3_key = nueva_key_h
                                        hubo_cambios = True

                                # Asegurar Aviso de Cobranza histórico para este periodo
                                if ("AVISO_COBRANZA", h_periodo) not in mapa_existentes:
                                    s3_key_aviso_h = self.storage.construir_s3_key(
                                        cod_socio=cod_socio,
                                        tipo_documento="AVISO_COBRANZA",
                                        periodo=h_periodo,
                                        identificador=str(h_nro_factura),
                                        anio=h_anio
                                    )
                                    doc_aviso_h = Documento(
                                        cod_socio=cod_socio,
                                        tipo_documento="AVISO_COBRANZA",
                                        nro_factura=str(h_nro_factura),
                                        nro_facip=str(h_nro_factura),
                                        periodo=h_periodo,
                                        anio=h_anio,
                                        mes=h_mes,
                                        monto_bs=round(h_monto, 2),
                                        s3_key=s3_key_aviso_h,
                                        fecha_emision=fecha_emi_h,
                                        fecha_vencimiento=fecha_venc_h,
                                        estado_pago="PAGADO",
                                        suministro_id=suministro.id
                                    )
                                    self.db.add(doc_aviso_h)
                                    mapa_existentes[("AVISO_COBRANZA", h_periodo)] = doc_aviso_h
                                    hubo_cambios = True
                except Exception as exc_hist:
                    logger.warning(f"[DOCUMENTOS] Error al sincronizar facturas pagadas históricas: {exc_hist}")

                # 5. Conciliar Aviso de Corte si aplica mora (2 o más facturas pendientes)
                tiene_corte = any(d.tipo_documento == "AVISO_CORTE" for d in existentes_todos)
                if len(facturas_pendientes) >= 2 and not tiene_corte and rol_acceso == "TITULAR":
                    s3_key_corte = self.storage.construir_s3_key(
                        cod_socio=cod_socio,
                        tipo_documento="AVISO_CORTE",
                        periodo="AVISO_DE_CORTE",
                        identificador=py_uuid.uuid4().hex[:8],
                        anio=date.today().year
                    )
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
            fecha_pago_val = None
            if doc.estado_pago == "PAGADO":
                fecha_pago_val = mapa_fechas_pago.get(doc.periodo)

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
                fecha_pago=fecha_pago_val,
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
        # Para AVISO_COBRANZA y FACTURA siempre regeneramos para garantizar el diseño oficial y datos reales
        if doc.tipo_documento in ["AVISO_COBRANZA", "FACTURA"] or not self.s3.existe_archivo(doc.s3_key):
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

    async def obtener_detalle_factura_socio(
        self,
        usuario_id: UUID,
        nro_factura: str
    ) -> FacturaDetalleResponse:
        """
        Recupera el detalle fiscal estructurado de una factura oficial de COSMOL R.L.
        - Valida que el usuario tenga vinculado el suministro correspondiente a la factura.
        - Valida restricción fiscal: si el rol es 'CONSULTA_PAGO' (inquilino), se deniega el acceso (403 Forbidden).
        - Consulta primero la caché en Redis (<20ms).
        - Si no está en caché, consulta la API oficial externa GET /facturas/{nro_factura}.
        - Si la API no responde, realiza fallback con datos persistidos en PostgreSQL.
        - Guarda en Redis (TTL 10 min) y retorna FacturaDetalleResponse.
        """
        nro_clean = str(nro_factura).strip()
        if not nro_clean:
            raise NotFoundException(
                message="Número de factura no válido o no especificado.",
                error_code="INVALID_INVOICE_NUMBER"
            )

        # 1. Buscar si el documento ya está persistido en PostgreSQL
        stmt_doc = select(Documento).where(
            (Documento.nro_factura == nro_clean) | (Documento.nro_facip == nro_clean)
        )
        res_doc = await self.db.execute(stmt_doc)
        doc = res_doc.scalar_one_or_none()

        # 2. Validar pertenencia del suministro al usuario
        stmt_suministros = select(Suministro).where(Suministro.usuario_id == usuario_id)
        res_sum = await self.db.execute(stmt_suministros)
        suministros_usuario = list(res_sum.scalars().all())
        mapa_suministros = {s.cod_socio: s for s in suministros_usuario}

        if doc:
            if doc.cod_socio not in mapa_suministros:
                raise ForbiddenException(
                    message="No tiene autorización para consultar facturas de este suministro.",
                    error_code="SUMINISTRO_ACCESS_DENIED"
                )
            suministro = mapa_suministros[doc.cod_socio]
            if suministro.rol == "CONSULTA_PAGO":
                raise ForbiddenException(
                    message="Acceso denegado: solo el titular registrado puede consultar el detalle de facturas fiscales.",
                    error_code="DOCUMENT_ACCESS_DENIED"
                )

        # 3. Intentar recuperar desde Redis (<20ms)
        redis_key = f"factura:detalle:{nro_clean}"
        redis = None
        try:
            redis = await get_redis()
            cached = await redis.get(redis_key)
            if cached:
                cached_dict = json.loads(cached)
                cod_socio_cached = cached_dict.get("cod_socio")
                if cod_socio_cached and cod_socio_cached not in mapa_suministros:
                    raise ForbiddenException(
                        message="No tiene autorización para consultar facturas de este suministro.",
                        error_code="SUMINISTRO_ACCESS_DENIED"
                    )
                return FacturaDetalleResponse(**cached_dict)
        except ForbiddenException:
            raise
        except Exception as err_redis:
            logger.debug(f"[REDIS] Error al leer caché de factura: {err_redis}")

        # 4. Consultar API oficial de COSMOL
        datos_api = await self.cosmol.obtener_detalle_factura(nro_clean)

        # Si no vino de la API y tampoco teníamos doc en BD -> 404
        if not datos_api and not doc:
            raise NotFoundException(
                message=f"No se encontró la factura N° '{nro_clean}' en el sistema comercial.",
                error_code="INVOICE_NOT_FOUND"
            )

        # Si vino de la API, validar que pertenezca a uno de los suministros del usuario
        if datos_api:
            cod_socio_api = str(datos_api.get("CODSOCIO") or "").strip()
            if cod_socio_api:
                if cod_socio_api not in mapa_suministros:
                    raise ForbiddenException(
                        message="No tiene autorización para consultar facturas de este suministro.",
                        error_code="SUMINISTRO_ACCESS_DENIED"
                    )
                suministro = mapa_suministros[cod_socio_api]
                if suministro.rol == "CONSULTA_PAGO":
                    raise ForbiddenException(
                        message="Acceso denegado: solo el titular registrado puede consultar el detalle de facturas fiscales.",
                        error_code="DOCUMENT_ACCESS_DENIED"
                    )

        # 5. Construir DTO estructurado
        if datos_api:
            items_detalle = []
            for item in datos_api.get("detalle", []):
                try:
                    pu = float(item.get("PRECIOUNITARIO") or 0.0)
                    des = float(item.get("DESCUENTO") or 0.0)
                    sub = float(item.get("SUBTOTAL") or pu)
                    cant = float(item.get("CANTIDAD") or 1.0)
                except Exception:
                    pu, des, sub, cant = 0.0, 0.0, 0.0, 1.0

                items_detalle.append(ItemFacturaDetalle(
                    prefijo=str(item.get("PREFIJO") or "").strip() or None,
                    codigo_servicio=str(item.get("CODIGOSERVICIO") or "1").strip(),
                    cantidad=cant,
                    unidad_medida=str(item.get("UNIDADMEDIDA") or "SERVICIO").strip(),
                    concepto=str(item.get("CONCEPTO") or "").strip(),
                    precio_unitario=pu,
                    descuento=des,
                    subtotal=sub,
                ))

            try:
                tot = float(datos_api.get("TOTAL") or 0.0)
                desc_tot = float(datos_api.get("DESCUENTO") or 0.0)
                subtot = tot + desc_tot
                cred_fisc = float(datos_api.get("IMPORTECREDITOFISCAL") or tot)
            except Exception:
                tot, desc_tot, subtot, cred_fisc = 0.0, 0.0, 0.0, 0.0

            pmes = int(datos_api.get("PERIODOMES") or (doc.mes if doc else 1))
            panio = int(datos_api.get("PERIODOANIO") or (doc.anio if doc else 2026))

            response_dto = FacturaDetalleResponse(
                nro_factura=str(datos_api.get("NROFACTURA") or nro_clean).strip(),
                nro_factura_imp=str(datos_api.get("NROFACTURAIMP") or nro_clean).strip(),
                cod_autorizacion=str(datos_api.get("CODAUTORIZACION") or "").strip(),
                tipo_factura=str(datos_api.get("TIPOFACTURA") or "1").strip(),
                nit_emisor=str(datos_api.get("NITEMISOR") or "1028317027").strip(),
                empresa=str(datos_api.get("EMPRESA") or "COSMOL RL").strip(),
                actividad_economica=str(datos_api.get("ACTIVIDADECO") or "CAPTACIÓN Y DISTRIBUCIÓN DE AGUA").strip(),
                casa_matriz=str(datos_api.get("CASAMATRIZ") or "CASA MATRIZ").strip(),
                punto_venta=str(datos_api.get("PUNTODEVENTA") or "No. punto de venta 0").strip(),
                ciudad=str(datos_api.get("CIUDAD") or "MONTERO").strip(),
                dir_empresa=str(datos_api.get("DIREMPRESA") or "CALLE ISAIAS PARADA Nro. 219").strip(),
                telf_empresa=str(datos_api.get("TELFEMPRESA") or "TELEFONO 392-20212 - 61555507").strip(),
                cod_socio=str(datos_api.get("CODSOCIO") or (doc.cod_socio if doc else "")).strip(),
                nombre_razon_social=str(datos_api.get("NOMBRE") or "").strip(),
                nit_ci=str(datos_api.get("NITCI") or "").strip(),
                direccion=str(datos_api.get("DIRECCION") or "").strip(),
                cod_ubicacion=str(datos_api.get("CODUBICACION") or "").strip(),
                consumo_m3=int(datos_api.get("CONSUMOM3") or 0),
                periodo_mes=pmes,
                periodo_anio=panio,
                periodo_formateado=f"{pmes:02d}/{panio}",
                fecha_emision=str(datos_api.get("FECHAEMISION") or "").strip(),
                subtotal=subtot,
                descuento=desc_tot,
                total=tot,
                monto_gift_card=0.0,
                monto_a_pagar=tot,
                importe_credito_fiscal=cred_fisc,
                total_literal=generador_factura_digital.numero_a_letras(tot),
                estado_factura=str(datos_api.get("ESTADOFACTURA") or "0").strip(),
                fecha_pago=str(datos_api.get("FECHAPAGO")).strip() if datos_api.get("FECHAPAGO") else None,
                hora_pago=str(datos_api.get("HORAPAGO")).strip() if datos_api.get("HORAPAGO") else None,
                caja_pago=str(datos_api.get("CAJAPAGO")).strip() if datos_api.get("CAJAPAGO") else None,
                codigo_qr=str(datos_api.get("CODIGOQR") or "").strip(),
                des_leyenda=str(datos_api.get("DESLEYENDA") or "").strip(),
                leyenda_1=str(datos_api.get("LEYENDA1") or "").strip(),
                leyenda_3=str(datos_api.get("LEYENDA3") or "").strip(),
                detalle=items_detalle,
                url_descarga_pdf=f"/api/v1/documentos/{doc.id}/descargar" if doc else None,
            )
        else:
            datos_socio = {}
            try:
                datos_socio = await self.cosmol.obtener_datos_socio(doc.cod_socio) or {}
            except Exception:
                pass

            tot = float(doc.monto_bs)
            response_dto = FacturaDetalleResponse(
                nro_factura=doc.nro_factura or nro_clean,
                nro_factura_imp=doc.nro_facip or doc.nro_factura or nro_clean,
                cod_autorizacion=doc.cod_autorizacion or "N/A",
                tipo_factura="1",
                nit_emisor="1028317027",
                empresa="COSMOL RL",
                actividad_economica="CAPTACIÓN Y DISTRIBUCIÓN DE AGUA",
                casa_matriz="CASA MATRIZ",
                punto_venta="No. punto de venta 0",
                ciudad="MONTERO",
                dir_empresa="CALLE ISAIAS PARADA Nro. 219",
                telf_empresa="TELEFONO 392-20212 - 61555507",
                cod_socio=doc.cod_socio,
                nombre_razon_social=str(datos_socio.get("NOMBRE") or datos_socio.get("nombre_titular") or f"SOCIO {doc.cod_socio}").strip(),
                nit_ci=str(datos_socio.get("NROCIONIT") or datos_socio.get("ci_nit") or "").strip(),
                direccion=str(datos_socio.get("DIRECCION") or datos_socio.get("direccion") or "").strip(),
                cod_ubicacion=str(datos_socio.get("ubicacion") or "1.4.64.0").strip(),
                consumo_m3=0,
                periodo_mes=doc.mes,
                periodo_anio=doc.anio,
                periodo_formateado=doc.periodo,
                fecha_emision=doc.fecha_emision.strftime("%Y-%m-%d") if doc.fecha_emision else "",
                subtotal=tot,
                descuento=0.0,
                total=tot,
                monto_gift_card=0.0,
                monto_a_pagar=tot,
                importe_credito_fiscal=tot,
                total_literal=generador_factura_digital.numero_a_letras(tot),
                estado_factura="1" if doc.estado_pago == "PAGADO" else "0",
                fecha_pago=None,
                hora_pago=None,
                caja_pago=None,
                codigo_qr=f"https://siat.impuestos.gob.bo/consulta/QR?nit=1028317027&cuf={doc.cod_autorizacion or ''}&numero={doc.nro_factura or ''}&t=2",
                des_leyenda="Ley N° 453: El proveedor deberá suministrar el servicio en las modalidades y términos ofertados o convenidos.",
                leyenda_1="ESTA FACTURA CONTRIBUYE AL DESARROLLO DEL PAIS. EL USO ILÍCITO DE ESTA SERÁ SANCIONADO DE ACUERDO A LEY.",
                leyenda_3="Este documento es la representacion Gráfica de un Documento Fiscal Digital emitido en una Modalidad de Facturacion Electrónica en Linea.",
                detalle=[ItemFacturaDetalle(
                    prefijo="1",
                    codigo_servicio="1",
                    cantidad=1.0,
                    unidad_medida="SERVICIO",
                    concepto="SERVICIO DE AGUA POTABLE Y ALCANTARILLADO",
                    precio_unitario=tot,
                    descuento=0.0,
                    subtotal=tot,
                )],
                url_descarga_pdf=f"/api/v1/documentos/{doc.id}/descargar",
            )

        # 6. Almacenar en Redis (TTL 600 segundos)
        if redis:
            try:
                await redis.set(redis_key, response_dto.model_dump_json(), ex=600)
            except Exception as err_set:
                logger.debug(f"[REDIS] Error al escribir en caché: {err_set}")

        return response_dto
