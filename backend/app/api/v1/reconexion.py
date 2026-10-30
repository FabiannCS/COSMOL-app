"""
Endpoints de la API REST para el Módulo de Reconexión de Servicios (COSMOL R.L.).
Permite consultar elegibilidad de reconexión, historial de trámites,
subida de fotografías de evidencia y registro formal de órdenes en el sistema central.
"""
import io
import logging
from typing import List, Optional
from uuid import UUID

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Depends,
    File,
    Form,
    HTTPException,
    UploadFile,
    status,
)
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user_id, get_db
from app.core.exceptions import BadRequestException, NotFoundException
from app.db.models import Usuario
from app.integrations.minio_client import minio_client
from app.schemas.reconexion import (
    ElegibilidadReconexionResponse,
    ReconexionHistorialItem,
    SolicitudReconexionCreate,
    SolicitudReconexionResponse,
)
from app.services.servicio_reconexion import servicio_reconexion

logger = logging.getLogger(__name__)

router = APIRouter()

MAX_IMAGE_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB
ALLOWED_MIME_TYPES = {
    "image/jpeg": "jpg",
    "image/jpg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
}


@router.get(
    "/elegibilidad/{cod_socio}",
    response_model=ElegibilidadReconexionResponse,
    status_code=status.HTTP_200_OK,
    summary="Verificar elegibilidad para trámite de reconexión",
    description=(
        "Evalúa las políticas comerciales de COSMOL: no duplicidad de trámites "
        "con estado PENDIENTE y morosidad máxima de 2 facturas."
    ),
)
async def verificar_elegibilidad(
    cod_socio: str,
    current_user_id: str = Depends(get_current_user_id),
) -> ElegibilidadReconexionResponse:
    return await servicio_reconexion.verificar_elegibilidad(cod_socio=cod_socio)


@router.get(
    "/historial/{cod_socio}",
    response_model=List[ReconexionHistorialItem],
    status_code=status.HTTP_200_OK,
    summary="Consultar historial de reconexiones",
    description="Retorna el listado de órdenes previas de reconexión registradas en el sistema central.",
)
async def obtener_historial_reconexiones(
    cod_socio: str,
    current_user_id: str = Depends(get_current_user_id),
) -> List[ReconexionHistorialItem]:
    return await servicio_reconexion.obtener_historial(cod_socio=cod_socio)


@router.post(
    "/subir-foto",
    status_code=status.HTTP_201_CREATED,
    summary="Subir fotografía de evidencia a MinIO",
    description="Recibe una imagen (JPEG/PNG/WebP), la almacena en MinIO y retorna la URL accesible.",
)
async def subir_fotografia_evidencia(
    archivo: UploadFile = File(...),
    cod_socio: str = Form(...),
    current_user_id: str = Depends(get_current_user_id),
):
    mime = (archivo.content_type or "").lower().split(";")[0].strip()
    if mime not in ALLOWED_MIME_TYPES:
        raise BadRequestException(
            message="Formato de imagen no soportado. Se admiten archivos JPEG, PNG o WebP.",
            error_code="FORMATO_IMAGEN_INVALIDO",
        )

    contenido = await archivo.read()
    if len(contenido) == 0:
        raise BadRequestException(
            message="El archivo de imagen cargado está vacío.",
            error_code="IMAGEN_VACIA",
        )

    if len(contenido) > MAX_IMAGE_SIZE_BYTES:
        raise BadRequestException(
            message="La imagen excede el límite máximo permitido de 10 MB.",
            error_code="IMAGEN_DEMASIADO_PESADA",
        )

    extension = ALLOWED_MIME_TYPES[mime]
    object_name = minio_client.subir_foto_evidencia_reconexion(
        cod_socio=cod_socio,
        data_bytes=contenido,
        extension=extension,
        content_type=mime,
    )

    url_proxy = f"/api/v1/reconexion/foto/{object_name}"

    try:
        url_presigned = minio_client.generar_url_prefirmada(object_name, expires_seconds=86400 * 7)
    except Exception:
        url_presigned = url_proxy

    return {
        "estado": "exito",
        "object_name": object_name,
        "foto_url": url_presigned,
        "url_proxy": url_proxy,
    }


@router.get(
    "/foto/{object_name:path}",
    summary="Descargar o visualizar fotografía de evidencia almacenada en MinIO",
)
async def obtener_foto_evidencia(object_name: str):
    """
    Streaming de la fotografía desde MinIO hacia el cliente a través del BFF.
    """
    try:
        contenido = minio_client.obtener_archivo_bytes(object_name)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fotografía de evidencia no encontrada.",
        )

    ext = object_name.split(".")[-1].lower()
    media_type = "image/png" if ext == "png" else "image/jpeg"
    return StreamingResponse(io.BytesIO(contenido), media_type=media_type)


@router.post(
    "/solicitar",
    response_model=SolicitudReconexionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar solicitud formal de reconexión",
    description=(
        "Registra la orden técnica en el sistema central de COSMOL y despacha "
        "la auditoría asíncrona hacia COSMOL-Reportes."
    ),
)
async def registrar_solicitud_reconexion(
    datos: SolicitudReconexionCreate,
    background_tasks: BackgroundTasks,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> SolicitudReconexionResponse:
    telefono_usuario = None
    try:
        uid = UUID(current_user_id)
        res = await db.execute(select(Usuario.telefono).where(Usuario.id == uid))
        telefono_usuario = res.scalar_one_or_none()
    except Exception as exc:
        logger.debug(f"No se pudo consultar teléfono de usuario {current_user_id}: {exc}")

    return await servicio_reconexion.solicitar_reconexion(
        datos=datos,
        background_tasks=background_tasks,
        telefono=telefono_usuario,
    )

