"""
Cliente de integración con MinIO Object Storage (S3-Compatible) para COSMOL R.L.
Gestiona almacenamiento seguro de documentos binarios PDF (facturas, avisos de cobranza y corte)
en el bucket privado 'cosmol-docs'.
"""
from datetime import timedelta
import io
import logging
from typing import BinaryIO, Generator, Optional

from minio import Minio
from minio.error import S3Error

from app.core.config import settings
from app.core.exceptions import NotFoundException, ServiceUnavailableException

logger = logging.getLogger(__name__)


class CosmolMinioClient:
    """
    Cliente para interactuar con MinIO S3 Object Storage.
    Implementa creación idempotente de buckets, carga, descarga y streaming de PDFs.
    """

    def __init__(
        self,
        endpoint: Optional[str] = None,
        access_key: Optional[str] = None,
        secret_key: Optional[str] = None,
        default_bucket: Optional[str] = None,
        secure: bool = False
    ):
        self.endpoint = endpoint or settings.MINIO_ENDPOINT
        self.access_key = access_key or settings.MINIO_ROOT_USER
        self.secret_key = secret_key or settings.MINIO_ROOT_PASSWORD
        self.default_bucket = default_bucket or settings.MINIO_BUCKET_NAME
        self.secure = secure

        self.client = Minio(
            endpoint=self.endpoint,
            access_key=self.access_key,
            secret_key=self.secret_key,
            secure=self.secure
        )

    def asegurar_bucket_existe(self, bucket_name: Optional[str] = None) -> bool:
        """
        Verifica si el bucket existe en MinIO; si no existe, lo crea automáticamente.
        """
        bucket = bucket_name or self.default_bucket
        try:
            if not self.client.bucket_exists(bucket):
                logger.info(f"[MINIO] El bucket '{bucket}' no existe. Creando bucket...")
                self.client.make_bucket(bucket)
                logger.info(f"[MINIO] Bucket '{bucket}' creado exitosamente.")
            return True
        except Exception as exc:
            logger.error(f"[MINIO] Error al asegurar existencia del bucket '{bucket}': {exc}")
            raise ServiceUnavailableException(
                message="No se pudo inicializar el repositorio de almacenamiento de documentos.",
                error_code="STORAGE_BUCKET_ERROR"
            )

    def subir_archivo_bytes(
        self,
        object_name: str,
        data_bytes: bytes,
        content_type: str = "application/pdf",
        bucket_name: Optional[str] = None
    ) -> str:
        """
        Sube un arreglo de bytes a MinIO S3 y retorna la clave del objeto.
        """
        bucket = bucket_name or self.default_bucket
        self.asegurar_bucket_existe(bucket)

        stream = io.BytesIO(data_bytes)
        length = len(data_bytes)

        try:
            self.client.put_object(
                bucket_name=bucket,
                object_name=object_name,
                data=stream,
                length=length,
                content_type=content_type
            )
            logger.info(f"[MINIO] Archivo '{object_name}' ({length} bytes) subido al bucket '{bucket}'.")
            return object_name
        except Exception as exc:
            logger.error(f"[MINIO] Error al subir archivo '{object_name}' a '{bucket}': {exc}")
            raise ServiceUnavailableException(
                message="Error al persistir el documento en el almacenamiento digital.",
                error_code="STORAGE_UPLOAD_ERROR"
            )

    def existe_archivo(
        self,
        object_name: str,
        bucket_name: Optional[str] = None
    ) -> bool:
        """
        Comprueba de forma rápida si un objeto existe en el bucket sin descargarlo.
        """
        bucket = bucket_name or self.default_bucket
        try:
            self.client.stat_object(bucket_name=bucket, object_name=object_name)
            return True
        except S3Error as err:
            if err.code in ["NoSuchKey", "NoSuchBucket", "ResourceNotFound"]:
                return False
            logger.error(f"[MINIO] Error S3 al verificar existencia de '{object_name}': {err}")
            return False
        except Exception as exc:
            logger.error(f"[MINIO] Excepción al verificar existencia de '{object_name}': {exc}")
            return False

    def obtener_archivo_bytes(
        self,
        object_name: str,
        bucket_name: Optional[str] = None
    ) -> bytes:
        """
        Descarga y retorna el contenido completo de un archivo en memoria.
        """
        bucket = bucket_name or self.default_bucket
        try:
            response = self.client.get_object(bucket_name=bucket, object_name=object_name)
            try:
                return response.read()
            finally:
                response.close()
                response.release_conn()
        except S3Error as err:
            if err.code in ["NoSuchKey", "NoSuchBucket"]:
                raise NotFoundException(
                    message=f"El archivo solicitado '{object_name}' no existe en el almacenamiento.",
                    error_code="DOCUMENT_NOT_FOUND"
                )
            logger.error(f"[MINIO] Error S3 al leer archivo '{object_name}': {err}")
            raise ServiceUnavailableException(
                message="No se pudo recuperar el documento del almacenamiento digital.",
                error_code="STORAGE_DOWNLOAD_ERROR"
            )
        except Exception as exc:
            logger.error(f"[MINIO] Error al obtener archivo '{object_name}': {exc}")
            raise ServiceUnavailableException(
                message="Fallo en el servicio de almacenamiento de documentos.",
                error_code="STORAGE_DOWNLOAD_ERROR"
            )

    def obtener_archivo_stream(
        self,
        object_name: str,
        bucket_name: Optional[str] = None,
        chunk_size: int = 32 * 1024
    ) -> Generator[bytes, None, None]:
        """
        Generador para streaming por fragmentos HTTP (StreamingResponse)
        evitando cargar archivos pesados simultáneamente en memoria.
        """
        bucket = bucket_name or self.default_bucket
        try:
            response = self.client.get_object(bucket_name=bucket, object_name=object_name)
        except S3Error as err:
            if err.code in ["NoSuchKey", "NoSuchBucket"]:
                raise NotFoundException(
                    message=f"El archivo solicitado '{object_name}' no existe en el almacenamiento.",
                    error_code="DOCUMENT_NOT_FOUND"
                )
            raise ServiceUnavailableException(
                message="No se pudo abrir el documento solicitado.",
                error_code="STORAGE_STREAM_ERROR"
            )

        try:
            for chunk in response.stream(chunk_size):
                yield chunk
        finally:
            response.close()
            response.release_conn()

    def eliminar_archivo(
        self,
        object_name: str,
        bucket_name: Optional[str] = None
    ) -> bool:
        """
        Elimina un objeto del bucket.
        """
        bucket = bucket_name or self.default_bucket
        try:
            self.client.remove_object(bucket_name=bucket, object_name=object_name)
            logger.info(f"[MINIO] Archivo '{object_name}' eliminado del bucket '{bucket}'.")
            return True
        except Exception as exc:
            logger.error(f"[MINIO] Error al eliminar '{object_name}': {exc}")
            return False

    def generar_url_prefirmada(
        self,
        object_name: str,
        expires_seconds: int = 600,
        bucket_name: Optional[str] = None
    ) -> str:
        """
        Genera una URL temporal prefirmada con firma criptográfica HMAC para descarga directa.
        """
        bucket = bucket_name or self.default_bucket
        try:
            return self.client.get_presigned_url(
                method="GET",
                bucket_name=bucket,
                object_name=object_name,
                expires=timedelta(seconds=expires_seconds)
            )
        except Exception as exc:
            logger.error(f"[MINIO] Error al generar URL prefirmada para '{object_name}': {exc}")
            raise ServiceUnavailableException(
                message="No se pudo generar el enlace seguro de descarga.",
                error_code="STORAGE_PRESIGNED_URL_ERROR"
            )


# Instancia singleton para uso en toda la aplicación
minio_client = CosmolMinioClient()
