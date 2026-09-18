"""
Endpoints de la API REST para el Repositorio Digital de Documentos y Descarga en PDF (COSMOL R.L. - DEV 2).
Provee:
- GET /api/v1/documentos/{cod_socio}: Listado categorizado por pestañas con privacidad multicuenta.
- GET /api/v1/documentos/{doc_id}/descargar: Transmisión eficiente por streaming del archivo binario PDF.
"""
from typing import Optional
from uuid import UUID
import logging
from fastapi import APIRouter, BackgroundTasks, Depends, Query, status
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user_id, get_db
from app.schemas.documento import ListaDocumentosResponse
from app.services.servicio_documentos import ServicioDocumentos, registrar_auditoria_descarga

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get(
    "/{cod_socio}",
    response_model=ListaDocumentosResponse,
    status_code=status.HTTP_200_OK,
    summary="Listar documentos digitales de un suministro",
    description=(
        "Obtiene las facturas, avisos de cobranza y avisos de corte disponibles para el socio. "
        "Si el usuario tiene rol CONSULTA_PAGO (inquilino), únicamente se retornan avisos de cobranza "
        "y se ocultan las facturas fiscales y avisos de corte del titular."
    ),
)
async def listar_documentos(
    cod_socio: str,
    tipo: Optional[str] = Query(
        None,
        description="Filtro opcional por tipo de documento: FACTURA, AVISO_COBRANZA o AVISO_CORTE"
    ),
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> ListaDocumentosResponse:
    """
    Retorna la colección de documentos organizados para pestañas en Flutter / Web.
    """
    servicio = ServicioDocumentos(db=db)
    return await servicio.listar_documentos_socio(
        usuario_id=UUID(current_user_id),
        cod_socio=cod_socio.strip(),
        tipo=tipo.strip() if tipo else None
    )


@router.get(
    "/{doc_id}/descargar",
    status_code=status.HTTP_200_OK,
    summary="Descargar documento en PDF por streaming",
    description=(
        "Transmite el archivo binario PDF directamente desde el almacenamiento de objetos MinIO S3. "
        "Aplica validación de permisos: los inquilinos no pueden descargar facturas fiscales ni avisos de corte. "
        "Despacha en segundo plano un evento de auditoría de descarga hacia ChatbotReportes."
    ),
    responses={
        200: {
            "content": {"application/pdf": {}},
            "description": "Flujo binario del archivo PDF con cabecera Content-Disposition para descarga."
        },
        403: {"description": "Acceso denegado (el rol de consulta no puede descargar documentos fiscales del titular)."},
        404: {"description": "Documento no encontrado."},
    }
)
async def descargar_documento_pdf(
    doc_id: UUID,
    background_tasks: BackgroundTasks,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> StreamingResponse:
    """
    Transmite el archivo PDF mediante StreamingResponse para un consumo óptimo en memoria.
    """
    servicio = ServicioDocumentos(db=db)
    user_uuid = UUID(current_user_id)

    stream, filename, doc = await servicio.obtener_documento_para_descarga(
        usuario_id=user_uuid,
        doc_id=doc_id
    )

    # Registrar evento de auditoría asíncrono
    background_tasks.add_task(
        registrar_auditoria_descarga,
        usuario_id=user_uuid,
        cod_socio=doc.cod_socio,
        doc_id=doc.id,
        tipo_documento=doc.tipo_documento
    )

    return StreamingResponse(
        content=stream,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "Access-Control-Expose-Headers": "Content-Disposition",
        }
    )
