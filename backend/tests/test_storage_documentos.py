"""
Pruebas automatizadas para ServicioStorageDocumentos (DEV 1).
Valida la integración completa entre ReportLab (generador PDF), MinIO S3 (almacenamiento binario)
y PostgreSQL (metadatos e índices de documentos).
"""
import uuid
import pytest
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Documento, Suministro, Usuario
from app.services.servicio_storage_documentos import ServicioStorageDocumentos


@pytest.mark.asyncio
async def test_guardar_documento_en_storage_y_db(db_session: AsyncSession):
    """
    Verifica que guardar_documento suba el archivo a MinIO y persista el registro en PostgreSQL.
    """
    cod_socio = f"test_{uuid.uuid4().hex[:6]}"
    tipo_doc = "FACTURA"
    periodo = "08/2026"
    pdf_content = b"%PDF-1.4 Mock Invoice Content for Testing."

    service = ServicioStorageDocumentos(db=db_session)

    doc = await service.guardar_documento(
        cod_socio=cod_socio,
        tipo_documento=tipo_doc,
        periodo=periodo,
        anio=2026,
        mes=8,
        monto_bs=70.92,
        pdf_bytes=pdf_content,
        nro_factura="998877",
        cod_autorizacion="AUTH-CODE-SIAT-123"
    )

    assert doc.id is not None
    assert doc.cod_socio == cod_socio
    assert doc.tipo_documento == tipo_doc
    assert float(doc.monto_bs) == 70.92
    assert "facturas" in doc.s3_key


    # Verificar que exista en PostgreSQL
    stmt = select(Documento).where(Documento.id == doc.id)
    res = await db_session.execute(stmt)
    doc_en_db = res.scalar_one_or_none()
    assert doc_en_db is not None
    assert doc_en_db.nro_factura == "998877"

    # Verificar que exista físicamente en MinIO
    assert service.s3.existe_archivo(doc.s3_key) is True
    archivo_bytes = service.s3.obtener_archivo_bytes(doc.s3_key)
    assert archivo_bytes == pdf_content

    # Limpieza
    service.s3.eliminar_archivo(doc.s3_key)


@pytest.mark.asyncio
async def test_obtener_o_generar_pdf_factura(db_session: AsyncSession):
    """
    Verifica que en la primera llamada genere el PDF oficial y lo guarde en MinIO y PostgreSQL,
    y que en la segunda llamada lo sirva directamente desde MinIO S3 sin regenerar.
    """
    cod_socio = "540"
    datos_socio = {
        "CODIGO": cod_socio,
        "NOMBRE": "DURAN ELOISA RIVERA DE",
        "NROCIONIT": "2823231",
        "DIRECCION": "SANTA CRUZ 117"
    }
    datos_factura = {
        "NROFACTURA": "7444051",
        "CODAUTORIZACION": "465C3D0702C232069B9F771B83440D4217AF35B442086180BD081BF74",
        "periodo": "08/2026",
        "ANIO": 2026,
        "NMES": 8,
        "MONTOTOTAL": 70.92
    }

    service = ServicioStorageDocumentos(db=db_session)
    s3_key = service.construir_s3_key(cod_socio, "FACTURA", "08/2026", "7444051")

    # Limpieza preventiva en MinIO y PostgreSQL
    service.s3.eliminar_archivo(s3_key)
    await db_session.execute(delete(Documento).where(Documento.cod_socio == cod_socio, Documento.periodo == "08/2026"))
    await db_session.commit()

    # 1. Primera llamada: Generación on-demand + almacenamiento
    pdf_bytes_1 = await service.obtener_o_generar_pdf_factura(cod_socio, datos_factura, datos_socio)
    assert isinstance(pdf_bytes_1, bytes)
    assert pdf_bytes_1.startswith(b"%PDF")
    assert service.s3.existe_archivo(s3_key) is True

    # Comprobar que se creó registro en PostgreSQL
    stmt = select(Documento).where(Documento.cod_socio == cod_socio, Documento.periodo == "08/2026")
    res = await db_session.execute(stmt)
    doc_db = res.scalar_one_or_none()
    assert doc_db is not None
    assert doc_db.tipo_documento == "FACTURA"

    # 2. Segunda llamada: Recuperación directa desde MinIO S3
    pdf_bytes_2 = await service.obtener_o_generar_pdf_factura(cod_socio, datos_factura, datos_socio)
    assert pdf_bytes_2 == pdf_bytes_1


@pytest.mark.asyncio
async def test_obtener_o_generar_aviso_corte(db_session: AsyncSession):
    """
    Verifica la generación y persistencia de un Aviso de Corte para un socio en mora.
    """
    cod_socio = "540"
    datos_socio = {
        "CODIGO": cod_socio,
        "NOMBRE": "DURAN ELOISA RIVERA DE",
        "DIRECCION": "SANTA CRUZ 117"
    }
    facturas_en_mora = [
        {"periodo": "08/2026", "nro_factura": "7444051", "monto_bs": 70.92},
        {"periodo": "09/2026", "nro_factura": "7473308", "monto_bs": 61.42}
    ]

    service = ServicioStorageDocumentos(db=db_session)
    pdf_corte = await service.obtener_o_generar_pdf_aviso_corte(cod_socio, datos_socio, facturas_en_mora)

    assert isinstance(pdf_corte, bytes)
    assert pdf_corte.startswith(b"%PDF")
