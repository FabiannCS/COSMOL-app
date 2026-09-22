"""
Batería de Pruebas de Integración DEV 2: Enganche de Auditoría Asíncrona a COSMOL-Reportes.
COSMOL R.L. - App de Socios (Fase 6).
Verifica que los endpoints de Autenticación, Deuda, Consumo, Documentos y Pagos
despachen en BackgroundTasks los eventos con id_tipo y tipo_consulta pactados
según el Contrato Oficial, manteniendo 0 ms de overhead y resiliencia total.
"""
import uuid
from unittest.mock import AsyncMock, patch
import pytest
from httpx import AsyncClient
from redis.asyncio import Redis
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, get_password_hash
from app.db.models import Documento, Suministro, Usuario


def generar_telefono_unico() -> str:
    """Genera un número telefónico único para evitar conflictos de integridad."""
    return f"+5917{uuid.uuid4().int % 9000000 + 1000000}"


async def crear_socio_de_prueba(
    db: AsyncSession,
    cod_socio: str = "540",
    pin: str = "1234",
    rol: str = "TITULAR"
) -> tuple[Usuario, str]:
    """Crea usuario y suministro en BD y retorna (usuario, token_jwt)."""
    await db.execute(delete(Suministro).where(Suministro.cod_socio == cod_socio))
    await db.commit()

    user_id = uuid.uuid4()
    usuario = Usuario(
        id=user_id,
        telefono=generar_telefono_unico(),
        password_hash=get_password_hash(pin),
        esta_activo=True
    )
    db.add(usuario)
    await db.flush()

    suministro = Suministro(
        id=uuid.uuid4(),
        usuario_id=user_id,
        cod_socio=cod_socio,
        alias="Casa Central",
        rol=rol,
        es_suministro_principal=True
    )
    db.add(suministro)
    await db.commit()

    token = create_access_token(subject=str(user_id))
    return usuario, token


# ------------------------------------------------------------------------------
# 1. AUTENTICACIÓN: LOGIN Y ESTABLECER PIN (id_tipo = 1)
# ------------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_login_despacha_evento_reportes(client: AsyncClient, db_session: AsyncSession):
    """Valida que POST /autenticacion/login despache evento id_tipo=1 a Reportes."""
    cod_socio = "23807"
    pin = "4321"
    await crear_socio_de_prueba(db_session, cod_socio=cod_socio, pin=pin)

    with patch("app.api.v1.autenticacion.despachar_auditoria_reportes", new_callable=AsyncMock) as mock_despachar:
        response = await client.post(
            "/api/v1/autenticacion/login",
            json={
                "cod_socio": cod_socio,
                "pin_password": pin,
                "device_id": "test-device-uuid-12345",
                "modelo_dispositivo": "Samsung Galaxy S23"
            }
        )
        assert response.status_code == 200
        mock_despachar.assert_called_once()
        args, kwargs = mock_despachar.call_args
        assert kwargs["codigo_socio"] == 23807
        assert kwargs["id_tipo"] == 1
        assert kwargs["tipo_consulta"] == "Autenticación / Acceso"


@pytest.mark.asyncio
async def test_establecer_pin_despacha_evento_reportes(
    client: AsyncClient, db_session: AsyncSession, redis_override: Redis
):
    """Valida que POST /autenticacion/establecer-pin despache evento id_tipo=1 con teléfono."""
    telefono = generar_telefono_unico()
    token_valido = "test_otp_valid_token_xyz"
    token_key = f"token_otp_valido:{token_valido}"
    await redis_override.set(token_key, f"{telefono}:9988", ex=300)

    # Inyectar mock para socio verificado en onboarding
    with patch("app.services.servicio_autenticacion.cosmol_client.obtener_datos_socio", new_callable=AsyncMock) as mock_datos, \
         patch("app.api.v1.autenticacion.despachar_auditoria_reportes", new_callable=AsyncMock) as mock_despachar:
        mock_datos.return_value = {"NOMBRE": "NUEVO SOCIO REGISTRADO"}

        response = await client.post(
            "/api/v1/autenticacion/establecer-pin",
            json={
                "telefono": telefono,
                "token_otp_valido": token_valido,
                "nuevo_pin": "5678"
            }
        )
        assert response.status_code == 201
        mock_despachar.assert_called_once()
        args, kwargs = mock_despachar.call_args
        assert kwargs["id_tipo"] == 1
        assert kwargs["tipo_consulta"] == "Autenticación / Acceso"
        assert kwargs["telefono"] == telefono


# ------------------------------------------------------------------------------
# 2. CONSULTA DE DEUDA (id_tipo = 2)
# ------------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_deuda_despacha_evento_reportes(client: AsyncClient, db_session: AsyncSession):
    """Valida que GET /deuda/{cod_socio} despache evento id_tipo=2 a Reportes."""
    cod_socio = "540"
    usuario, token = await crear_socio_de_prueba(db_session, cod_socio=cod_socio)

    with patch("app.api.v1.deuda.despachar_auditoria_reportes", new_callable=AsyncMock) as mock_despachar:
        response = await client.get(
            f"/api/v1/deuda/{cod_socio}",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 200
        mock_despachar.assert_called_once()
        args, kwargs = mock_despachar.call_args
        assert kwargs["codigo_socio"] == 540
        assert kwargs["id_tipo"] == 2
        assert kwargs["tipo_consulta"] == "Consulta de Deuda"
        assert "nombres" in kwargs


# ------------------------------------------------------------------------------
# 3. HISTORIAL DE CONSUMO (id_tipo = 3)
# ------------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_consumo_despacha_evento_reportes(client: AsyncClient, db_session: AsyncSession):
    """Valida que GET /consumo/{cod_socio} despache evento id_tipo=3 a Reportes."""
    cod_socio = "540"
    usuario, token = await crear_socio_de_prueba(db_session, cod_socio=cod_socio)

    with patch("app.api.v1.consumo.despachar_auditoria_reportes", new_callable=AsyncMock) as mock_despachar:
        response = await client.get(
            f"/api/v1/consumo/{cod_socio}",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 200
        mock_despachar.assert_called_once()
        args, kwargs = mock_despachar.call_args
        assert kwargs["codigo_socio"] == 540
        assert kwargs["id_tipo"] == 3
        assert kwargs["tipo_consulta"] == "Historial de Facturas"


# ------------------------------------------------------------------------------
# 4. DESCARGA DE FACTURA PDF (id_tipo = 9)
# ------------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_documentos_descarga_despacha_evento_reportes(
    client: AsyncClient, db_session: AsyncSession
):
    """Valida que GET /documentos/{doc_id}/descargar despache evento id_tipo=9 a Reportes."""
    from app.services.servicio_storage_documentos import ServicioStorageDocumentos
    cod_socio = "540"
    usuario, token = await crear_socio_de_prueba(db_session, cod_socio=cod_socio)

    # Crear documento mediante el servicio de storage
    with patch("app.integrations.minio_client.CosmolMinioClient.subir_archivo_bytes", return_value="documentos/540/FACTURA_08_2026.pdf"):
        storage = ServicioStorageDocumentos(db=db_session)
        doc = await storage.guardar_documento(
            cod_socio=cod_socio,
            tipo_documento="FACTURA",
            periodo="08/2026",
            anio=2026,
            mes=8,
            monto_bs=150.0,
            pdf_bytes=b"%PDF-1.4 Mock Document Content",
            nro_factura="FAC-9999",
            cod_autorizacion="AUTH-9999"
        )

    with patch("app.integrations.minio_client.CosmolMinioClient.obtener_archivo_stream") as mock_stream, \
         patch("app.integrations.minio_client.CosmolMinioClient.existe_archivo", return_value=True), \
         patch("app.api.v1.documentos.despachar_auditoria_reportes", new_callable=AsyncMock) as mock_despachar:
        
        def fake_stream():
            yield b"%PDF-1.4 mock content"
        mock_stream.return_value = fake_stream()

        response = await client.get(
            f"/api/v1/documentos/{doc.id}/descargar",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 200
        mock_despachar.assert_called_once()
        args, kwargs = mock_despachar.call_args
        assert kwargs["codigo_socio"] == 540
        assert kwargs["id_tipo"] == 9
        assert kwargs["tipo_consulta"] == "Descarga de Factura PDF"


# ------------------------------------------------------------------------------
# 5. REGISTRAR INTENTO DE PAGO (id_tipo = 10)
# ------------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_pagos_registrar_intento_despacha_evento_reportes(
    client: AsyncClient, db_session: AsyncSession
):
    """Valida que POST /pagos/registrar-intento/{cod_socio} despache evento id_tipo=10."""
    cod_socio = "540"
    usuario, token = await crear_socio_de_prueba(db_session, cod_socio=cod_socio)

    with patch("app.api.v1.pagos.despachar_auditoria_reportes", new_callable=AsyncMock) as mock_despachar:
        response = await client.post(
            f"/api/v1/pagos/registrar-intento/{cod_socio}",
            json={"canal_id": "multipago"},
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 200
        mock_despachar.assert_called_once()
        args, kwargs = mock_despachar.call_args
        assert kwargs["codigo_socio"] == 540
        assert kwargs["id_tipo"] == 10
        assert kwargs["tipo_consulta"] == "Intento de Pago"


# ------------------------------------------------------------------------------
# 6. RESILIENCIA TOTAL (ZERO-CRASH): REPORTES CAÍDO NUNCA AFECTA AL SOCIO
# ------------------------------------------------------------------------------
@pytest.mark.asyncio
async def test_resiliencia_endpoints_reportes_caido(
    client: AsyncClient, db_session: AsyncSession
):
    """
    Simula falla total o caída de red hacia COSMOL-Reportes.
    Verifica que la función despachar_auditoria_reportes capture la excepción
    y los endpoints continúen retornando HTTP 200 OK inmediatamente al socio.
    """
    cod_socio = "540"
    usuario, token = await crear_socio_de_prueba(db_session, cod_socio=cod_socio)

    with patch("app.integrations.reportes_client.httpx.AsyncClient.post", side_effect=Exception("Reportes Server Offline")):
        response = await client.get(
            f"/api/v1/deuda/{cod_socio}",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["cod_socio"] == "540"
