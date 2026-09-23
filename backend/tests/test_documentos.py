"""
Batería de pruebas automatizadas para Repositorio Digital de Documentos y Descargas (DEV 2).
Valida:
- Privacidad Multicuenta: 'TITULAR' accede a Facturas, Avisos de Cobranza y Corte.
- Restricción estricta para 'CONSULTA_PAGO' (inquilinos): 403 DOCUMENT_ACCESS_DENIED ante facturas o cortes.
- Descarga binaria por streaming (StreamingResponse con application/pdf).
- Manejo de excepciones y códigos de error (404 SUMINISTRO_NOT_FOUND, 404 DOCUMENT_NOT_FOUND, 403 SUMINISTRO_ACCESS_DENIED).
- Auditoría asíncrona de descarga.
"""
from datetime import date
import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token
from app.db.models import Documento, Suministro, Usuario
from app.integrations.minio_client import minio_client
from app.services.servicio_documentos import ServicioDocumentos, registrar_auditoria_descarga
from app.services.servicio_storage_documentos import ServicioStorageDocumentos


def generar_telefono_unico() -> str:
    return f"+5917{uuid.uuid4().int % 9000000 + 1000000}"


@pytest.mark.asyncio
async def test_listar_documentos_titular_completo(
    client: AsyncClient,
    db_session: AsyncSession
):
    """
    Verifica que el usuario con rol TITULAR pueda visualizar todas las categorías de documentos
    (Facturas fiscales, Avisos de Cobranza y Avisos de Corte).
    """
    user_id = uuid.uuid4()
    cod_socio = f"tit_{uuid.uuid4().hex[:6]}"

    # 1. Crear usuario y suministro TITULAR
    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True
    )
    suministro = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio,
        alias="Mi Casa",
        rol="TITULAR",
        es_suministro_principal=True
    )
    db_session.add(usuario)
    db_session.add(suministro)
    await db_session.commit()

    # 2. Insertar los 3 tipos de documentos
    storage = ServicioStorageDocumentos(db=db_session)
    pdf_bytes = b"%PDF-1.4 Mock Document Content"

    doc_fac = await storage.guardar_documento(
        cod_socio=cod_socio,
        tipo_documento="FACTURA",
        periodo="08/2026",
        anio=2026,
        mes=8,
        monto_bs=120.50,
        pdf_bytes=pdf_bytes,
        nro_factura="FAC-1001",
        cod_autorizacion="AUTH-SIAT-1001"
    )
    doc_aviso = await storage.guardar_documento(
        cod_socio=cod_socio,
        tipo_documento="AVISO_COBRANZA",
        periodo="08/2026",
        anio=2026,
        mes=8,
        monto_bs=120.50,
        pdf_bytes=pdf_bytes,
        nro_facip="FACIP-1001"
    )
    doc_corte = await storage.guardar_documento(
        cod_socio=cod_socio,
        tipo_documento="AVISO_CORTE",
        periodo="08/2026",
        anio=2026,
        mes=8,
        monto_bs=240.00,
        pdf_bytes=pdf_bytes
    )

    # 3. Petición GET autenticada
    token = create_access_token(subject=str(user_id))
    resp = await client.get(
        f"/api/v1/documentos/{cod_socio}",
        headers={"Authorization": f"Bearer {token}"}
    )

    assert resp.status_code == 200
    data = resp.json()

    assert data["cod_socio"] == cod_socio
    assert data["rol_acceso"] == "TITULAR"
    assert data["total_documentos"] == 3
    assert len(data["facturas"]) == 1
    assert len(data["avisos_cobranza"]) == 1
    assert len(data["avisos_corte"]) == 1
    assert data["facturas"][0]["nro_factura"] == "FAC-1001"

    # Limpieza MinIO
    minio_client.eliminar_archivo(doc_fac.s3_key)
    minio_client.eliminar_archivo(doc_aviso.s3_key)
    minio_client.eliminar_archivo(doc_corte.s3_key)


@pytest.mark.asyncio
async def test_listar_documentos_inquilino_filtra_privacidad(
    client: AsyncClient,
    db_session: AsyncSession
):
    """
    Verifica que el usuario con rol CONSULTA_PAGO (inquilino) solo reciba avisos de cobranza,
    ocultando por completo facturas oficiales y avisos de corte.
    """
    user_id = uuid.uuid4()
    cod_socio = f"inq_{uuid.uuid4().hex[:6]}"

    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True
    )
    suministro = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio,
        alias="Alquiler",
        rol="CONSULTA_PAGO",
        es_suministro_principal=False
    )
    db_session.add(usuario)
    db_session.add(suministro)
    await db_session.commit()

    storage = ServicioStorageDocumentos(db=db_session)
    pdf_bytes = b"%PDF-1.4 Mock Privacy Test"

    doc_fac = await storage.guardar_documento(
        cod_socio=cod_socio,
        tipo_documento="FACTURA",
        periodo="08/2026",
        anio=2026,
        mes=8,
        monto_bs=75.0,
        pdf_bytes=pdf_bytes,
        nro_factura="FAC-PRIVADA"
    )
    doc_aviso = await storage.guardar_documento(
        cod_socio=cod_socio,
        tipo_documento="AVISO_COBRANZA",
        periodo="08/2026",
        anio=2026,
        mes=8,
        monto_bs=75.0,
        pdf_bytes=pdf_bytes,
        nro_facip="AVISO-PUBLICO"
    )
    doc_corte = await storage.guardar_documento(
        cod_socio=cod_socio,
        tipo_documento="AVISO_CORTE",
        periodo="08/2026",
        anio=2026,
        mes=8,
        monto_bs=150.0,
        pdf_bytes=pdf_bytes
    )

    token = create_access_token(subject=str(user_id))
    resp = await client.get(
        f"/api/v1/documentos/{cod_socio}",
        headers={"Authorization": f"Bearer {token}"}
    )

    assert resp.status_code == 200
    data = resp.json()

    assert data["rol_acceso"] == "CONSULTA_PAGO"
    # Privacidad: facturas y avisos_corte deben estar vacíos
    assert data["facturas"] == []
    assert data["avisos_corte"] == []
    # Solo el aviso de cobranza debe ser devuelto
    assert len(data["avisos_cobranza"]) == 1
    assert data["avisos_cobranza"][0]["nro_facip"] == "AVISO-PUBLICO"
    assert data["total_documentos"] == 1

    # Limpieza
    minio_client.eliminar_archivo(doc_fac.s3_key)
    minio_client.eliminar_archivo(doc_aviso.s3_key)
    minio_client.eliminar_archivo(doc_corte.s3_key)


@pytest.mark.asyncio
async def test_listar_documentos_inquilino_tipo_prohibido_retorna_403(
    client: AsyncClient,
    db_session: AsyncSession
):
    """
    Verifica que si un inquilino intenta forzar un filtro explícito ?tipo=FACTURA o ?tipo=AVISO_CORTE,
    el backend rechace con 403 Forbidden y código DOCUMENT_ACCESS_DENIED.
    """
    user_id = uuid.uuid4()
    cod_socio = f"inq_{uuid.uuid4().hex[:6]}"

    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True
    )
    suministro = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio,
        alias="Alquiler",
        rol="CONSULTA_PAGO"
    )
    db_session.add(usuario)
    db_session.add(suministro)
    await db_session.commit()

    token = create_access_token(subject=str(user_id))

    # Intento 1: ?tipo=FACTURA
    resp1 = await client.get(
        f"/api/v1/documentos/{cod_socio}?tipo=FACTURA",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert resp1.status_code == 403
    assert resp1.json()["error"]["code"] == "DOCUMENT_ACCESS_DENIED"

    # Intento 2: ?tipo=AVISO_CORTE
    resp2 = await client.get(
        f"/api/v1/documentos/{cod_socio}?tipo=AVISO_CORTE",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert resp2.status_code == 403
    assert resp2.json()["error"]["code"] == "DOCUMENT_ACCESS_DENIED"

    # Intento 3: ?tipo=AVISO_COBRANZA (Permitido)
    resp3 = await client.get(
        f"/api/v1/documentos/{cod_socio}?tipo=AVISO_COBRANZA",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert resp3.status_code == 200


@pytest.mark.asyncio
async def test_descargar_factura_titular_streaming_pdf(
    client: AsyncClient,
    db_session: AsyncSession
):
    """
    Verifica que el titular pueda descargar su factura fiscal con cabeceras correctas de PDF.
    """
    user_id = uuid.uuid4()
    cod_socio = f"tit_{uuid.uuid4().hex[:6]}"

    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True
    )
    suministro = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio,
        alias="Casa Central",
        rol="TITULAR"
    )
    db_session.add(usuario)
    db_session.add(suministro)
    await db_session.commit()

    storage = ServicioStorageDocumentos(db=db_session)
    pdf_content = b"%PDF-1.4 Factura Fiscal Oficial Streaming Test."

    doc = await storage.guardar_documento(
        cod_socio=cod_socio,
        tipo_documento="FACTURA",
        periodo="07/2026",
        anio=2026,
        mes=7,
        monto_bs=95.40,
        pdf_bytes=pdf_content,
        nro_factura="FAC-8899"
    )

    token = create_access_token(subject=str(user_id))
    resp = await client.get(
        f"/api/v1/documentos/{doc.id}/descargar",
        headers={"Authorization": f"Bearer {token}"}
    )

    assert resp.status_code == 200
    assert "application/pdf" in resp.headers["content-type"]
    assert "attachment" in resp.headers["content-disposition"]
    assert f"Factura_Oficial_COSMOL_{cod_socio}_07-2026.pdf" in resp.headers["content-disposition"]
    assert resp.content == pdf_content

    # Limpieza
    minio_client.eliminar_archivo(doc.s3_key)


@pytest.mark.asyncio
async def test_descargar_documentos_inquilino_permisos(
    client: AsyncClient,
    db_session: AsyncSession
):
    """
    Verifica que un inquilino:
    - SÍ pueda descargar Aviso de Cobranza (200 OK).
    - NO pueda descargar Factura Fiscal (403 DOCUMENT_ACCESS_DENIED).
    - NO pueda descargar Aviso de Corte (403 DOCUMENT_ACCESS_DENIED).
    """
    user_id = uuid.uuid4()
    cod_socio = f"inq_{uuid.uuid4().hex[:6]}"

    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True
    )
    suministro = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio,
        alias="Depto 3B",
        rol="CONSULTA_PAGO"
    )
    db_session.add(usuario)
    db_session.add(suministro)
    await db_session.commit()

    storage = ServicioStorageDocumentos(db=db_session)
    pdf_bytes = b"%PDF-1.4 Binario de prueba."

    doc_fac = await storage.guardar_documento(
        cod_socio=cod_socio,
        tipo_documento="FACTURA",
        periodo="08/2026",
        anio=2026,
        mes=8,
        monto_bs=50.0,
        pdf_bytes=pdf_bytes,
        nro_factura="FAC-SECRET"
    )
    doc_aviso = await storage.guardar_documento(
        cod_socio=cod_socio,
        tipo_documento="AVISO_COBRANZA",
        periodo="08/2026",
        anio=2026,
        mes=8,
        monto_bs=50.0,
        pdf_bytes=pdf_bytes,
        nro_facip="AVISO-OK"
    )
    doc_corte = await storage.guardar_documento(
        cod_socio=cod_socio,
        tipo_documento="AVISO_CORTE",
        periodo="08/2026",
        anio=2026,
        mes=8,
        monto_bs=100.0,
        pdf_bytes=pdf_bytes
    )

    token = create_access_token(subject=str(user_id))

    # 1. Factura por inquilino -> 403
    resp_fac = await client.get(
        f"/api/v1/documentos/{doc_fac.id}/descargar",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert resp_fac.status_code == 403
    assert resp_fac.json()["error"]["code"] == "DOCUMENT_ACCESS_DENIED"

    # 2. Aviso de corte por inquilino -> 403
    resp_corte = await client.get(
        f"/api/v1/documentos/{doc_corte.id}/descargar",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert resp_corte.status_code == 403
    assert resp_corte.json()["error"]["code"] == "DOCUMENT_ACCESS_DENIED"

    # 3. Aviso de cobranza por inquilino -> 200 OK
    resp_aviso = await client.get(
        f"/api/v1/documentos/{doc_aviso.id}/descargar",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert resp_aviso.status_code == 200
    assert resp_aviso.content == pdf_bytes

    # Limpieza
    minio_client.eliminar_archivo(doc_fac.s3_key)
    minio_client.eliminar_archivo(doc_aviso.s3_key)
    minio_client.eliminar_archivo(doc_corte.s3_key)


@pytest.mark.asyncio
async def test_acceso_documentos_suministro_ajeno_retorna_403(
    client: AsyncClient,
    db_session: AsyncSession
):
    """
    Verifica que un usuario no pueda descargar documentos de un suministro que no tiene vinculado.
    """
    user_propietario = uuid.uuid4()
    user_intruso = uuid.uuid4()
    cod_socio = f"priv_{uuid.uuid4().hex[:6]}"

    # Usuario A con el suministro
    u1 = Usuario(id=user_propietario, telefono=generar_telefono_unico(), password_hash="hash1", esta_activo=True)
    suministro = Suministro(id=uuid.uuid4(), usuario_id=user_propietario, cod_socio=cod_socio, rol="TITULAR")
    # Usuario B sin el suministro
    u2 = Usuario(id=user_intruso, telefono=generar_telefono_unico(), password_hash="hash2", esta_activo=True)

    db_session.add_all([u1, suministro, u2])
    await db_session.commit()

    storage = ServicioStorageDocumentos(db=db_session)
    doc = await storage.guardar_documento(
        cod_socio=cod_socio,
        tipo_documento="AVISO_COBRANZA",
        periodo="08/2026",
        anio=2026,
        mes=8,
        monto_bs=30.0,
        pdf_bytes=b"%PDF-1.4 Privado"
    )

    # Intruso intenta descargar
    token_intruso = create_access_token(subject=str(user_intruso))
    resp = await client.get(
        f"/api/v1/documentos/{doc.id}/descargar",
        headers={"Authorization": f"Bearer {token_intruso}"}
    )
    assert resp.status_code == 403
    assert resp.json()["error"]["code"] == "SUMINISTRO_ACCESS_DENIED"

    # Intruso intenta listar el suministro ajeno
    resp_list = await client.get(
        f"/api/v1/documentos/{cod_socio}",
        headers={"Authorization": f"Bearer {token_intruso}"}
    )
    assert resp_list.status_code == 404
    assert resp_list.json()["error"]["code"] == "SUMINISTRO_NOT_FOUND"

    minio_client.eliminar_archivo(doc.s3_key)


@pytest.mark.asyncio
async def test_documento_inexistente_retorna_404(
    client: AsyncClient,
    db_session: AsyncSession
):
    """
    Verifica que descargar un doc_id inexistente retorne 404 DOCUMENT_NOT_FOUND.
    """
    user_id = uuid.uuid4()
    usuario = Usuario(id=user_id, telefono=generar_telefono_unico(), password_hash="hash", esta_activo=True)
    db_session.add(usuario)
    await db_session.commit()

    token = create_access_token(subject=str(user_id))
    random_doc_id = uuid.uuid4()
    resp = await client.get(
        f"/api/v1/documentos/{random_doc_id}/descargar",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "DOCUMENT_NOT_FOUND"


@pytest.mark.asyncio
async def test_auditoria_descarga_despacha_evento():
    """
    Verifica que la función auxiliar de auditoría registre el evento sin errores.
    """
    user_id = uuid.uuid4()
    doc_id = uuid.uuid4()
    # Debe ejecutarse sin lanzar excepciones
    await registrar_auditoria_descarga(
        usuario_id=user_id,
        cod_socio="102030",
        doc_id=doc_id,
        tipo_documento="FACTURA"
    )


@pytest.mark.asyncio
async def test_documentos_sin_token_retorna_401(client: AsyncClient):
    """
    Verifica que los endpoints requieran autenticación JWT obligatoria.
    """
    resp_list = await client.get("/api/v1/documentos/102030")
    assert resp_list.status_code == 401

    resp_down = await client.get(f"/api/v1/documentos/{uuid.uuid4()}/descargar")
    assert resp_down.status_code == 401


@pytest.mark.asyncio
async def test_listar_documentos_auto_sincroniza_con_sistema_legado(
    client: AsyncClient,
    db_session: AsyncSession
):
    """
    Verifica que si un titular consulta un suministro recién vinculado que aún no
    tiene documentos en la tabla PostgreSQL local, el backend se auto-sincronice
    en vivo con el sistema comercial legado y genere los documentos on-demand.
    """
    user_id = uuid.uuid4()
    # Usamos el socio mock 540 (con facturas pendientes en MOCK_DEUDAS_LEGADO)
    cod_socio = "540"

    # Limpiar suministros y documentos previos de este socio para prueba limpia
    await db_session.execute(delete(Suministro).where(Suministro.cod_socio == cod_socio))
    await db_session.execute(delete(Documento).where(Documento.cod_socio == cod_socio))
    await db_session.commit()

    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash="mock_hash",
        esta_activo=True
    )
    suministro = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio,
        alias="Casa Principal",
        rol="TITULAR",
        es_suministro_principal=True
    )
    db_session.add(usuario)
    db_session.add(suministro)
    await db_session.commit()

    token = create_access_token(subject=str(user_id))
    resp = await client.get(
        f"/api/v1/documentos/{cod_socio}",
        headers={"Authorization": f"Bearer {token}"}
    )

    assert resp.status_code == 200
    data = resp.json()

    assert data["cod_socio"] == cod_socio
    assert data["rol_acceso"] == "TITULAR"
    # Debe haberse auto-poblado con los avisos y facturas generados
    assert data["total_documentos"] > 0
    assert len(data["avisos_cobranza"]) > 0
    assert len(data["facturas"]) > 0

