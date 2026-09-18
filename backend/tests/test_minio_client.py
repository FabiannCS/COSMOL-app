"""
Pruebas automatizadas para el cliente MinIO S3 Object Storage (DEV 1).
Valida conexión, inicialización de bucket, subida, verificación de existencia, descarga y streaming.
"""
import uuid
import pytest

from app.core.exceptions import NotFoundException
from app.integrations.minio_client import CosmolMinioClient, minio_client


def test_minio_client_instantiation():
    """
    Verifica que el cliente MinIO se instancie con los parámetros del entorno.
    """
    assert minio_client is not None
    assert minio_client.default_bucket == "cosmol-docs"
    assert "storage-minio" in minio_client.endpoint or "localhost" in minio_client.endpoint


def test_asegurar_bucket_existe():
    """
    Verifica la creación idempotente del bucket por defecto.
    """
    creado = minio_client.asegurar_bucket_existe()
    assert creado is True
    assert minio_client.client.bucket_exists(minio_client.default_bucket) is True


def test_subir_comprobar_y_descargar_archivo():
    """
    Valida el ciclo completo de almacenamiento en MinIO:
    1. Subida de bytes con put_object.
    2. Comprobación de existencia con stat_object.
    3. Descarga de bytes íntegros.
    4. Eliminación limpia del objeto de prueba.
    """
    test_id = uuid.uuid4().hex[:8]
    object_name = f"tests/test_doc_{test_id}.pdf"
    content = b"%PDF-1.4 Mock Binary Content for Testing MinIO Storage."

    # 1. Subir
    uploaded_key = minio_client.subir_archivo_bytes(
        object_name=object_name,
        data_bytes=content,
        content_type="application/pdf"
    )
    assert uploaded_key == object_name

    # 2. Comprobar existencia
    assert minio_client.existe_archivo(object_name) is True
    assert minio_client.existe_archivo(f"no_existe_{test_id}.pdf") is False

    # 3. Descargar bytes completos
    downloaded = minio_client.obtener_archivo_bytes(object_name)
    assert downloaded == content

    # 4. Stream por fragmentos
    stream_chunks = list(minio_client.obtener_archivo_stream(object_name, chunk_size=16))
    assert len(stream_chunks) > 0
    assert b"".join(stream_chunks) == content

    # 5. Generar URL prefirmada
    url = minio_client.generar_url_prefirmada(object_name, expires_seconds=300)
    assert url.startswith("http")
    assert object_name in url or test_id in url

    # 6. Eliminar
    eliminado = minio_client.eliminar_archivo(object_name)
    assert eliminado is True
    assert minio_client.existe_archivo(object_name) is False


def test_obtener_archivo_inexistente_lanza_404():
    """
    Verifica que intentar descargar un objeto que no existe lance NotFoundException.
    """
    with pytest.raises(NotFoundException):
        minio_client.obtener_archivo_bytes(f"inexistente_{uuid.uuid4().hex}.pdf")
