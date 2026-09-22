import pytest
from unittest.mock import AsyncMock, patch, MagicMock
import httpx

from app.core.config import settings
from app.integrations.reportes_client import ReportesApiClient
from app.tasks.auditoria_reportes import despachar_auditoria_reportes


@pytest.mark.asyncio
async def test_configuracion_reportes_valores_por_defecto():
    """Valida los parámetros de configuración institucional de COSMOL-Reportes."""
    assert settings.REPORTES_ID_USUARIO_APP == 3
    assert settings.REPORTES_TIMEOUT_SECONDS == 3.0
    assert settings.REPORTES_ENABLED is True


@pytest.mark.asyncio
async def test_omision_limpia_cuando_url_vacia():
    """Si REPORTES_API_URL está vacía (desarrollo local), omite el envío sin error."""
    client = ReportesApiClient()
    with patch.object(settings, "REPORTES_API_URL", ""):
        resultado = await client.enviar_evento_auditoria(
            codigo_socio=1470,
            nombres="JUAN PEREZ",
            telefono="+59177012345",
            id_tipo=2,
            tipo_consulta="Consulta de Deuda",
        )
        assert resultado is False


@pytest.mark.asyncio
async def test_omision_limpia_cuando_deshabilitado():
    """Si REPORTES_ENABLED es False, omite el envío limpiamente."""
    client = ReportesApiClient()
    with patch.object(settings, "REPORTES_API_URL", "http://reportes.cosmol.local"), \
         patch.object(settings, "REPORTES_ENABLED", False):
        resultado = await client.enviar_evento_auditoria(
            codigo_socio=1470,
            nombres="JUAN PEREZ",
        )
        assert resultado is False


@pytest.mark.asyncio
async def test_envio_exitoso_auditoria_payload_y_headers():
    """Valida que el payload JSON contenga id_usuario=3, tipo_ubicacion=APP_MOVIL y cabeceras."""
    client = ReportesApiClient()
    mock_response = MagicMock(spec=httpx.Response)
    mock_response.status_code = 201
    mock_response.text = '{"success": true}'

    mock_http_client = AsyncMock()
    mock_http_client.post.return_value = mock_response

    with patch.object(settings, "REPORTES_API_URL", "http://reportes.cosmol.local"), \
         patch.object(settings, "REPORTES_API_TOKEN", "token_secreto_reportes_xyz"), \
         patch.object(settings, "REPORTES_ENABLED", True), \
         patch.object(client, "get_client", return_value=mock_http_client):

        resultado = await client.enviar_evento_auditoria(
            codigo_socio=23807,
            nombres="MISERICORDIA AGUANTA EDDY FRANCO",
            telefono="+59171029384",
            id_tipo=2,
            tipo_consulta="Consulta de Deuda",
            tipo_ubicacion="APP_MOVIL",
        )

        assert resultado is True
        mock_http_client.post.assert_called_once()
        args, kwargs = mock_http_client.post.call_args
        assert args[0] == "/api/consultas"
        
        payload = kwargs["json"]
        assert payload["codigo_socio"] == 23807
        assert payload["nombres"] == "MISERICORDIA AGUANTA EDDY FRANCO"
        assert payload["telefono"] == "+59171029384"
        assert payload["id_usuario"] == 3
        assert payload["id_tipo"] == 2
        assert payload["tipo_consulta"] == "Consulta de Deuda"
        assert payload["tipo_ubicacion"] == "APP_MOVIL"
        assert "fecha_consulta" in payload
        assert "hora_consulta" in payload

        headers = kwargs["headers"]
        assert headers["X-Reportes-Token"] == "token_secreto_reportes_xyz"


@pytest.mark.asyncio
async def test_resiliencia_servidor_offline():
    """Si el servidor de Reportes está fuera de línea (ConnectError), atrapa la excepción y retorna False."""
    client = ReportesApiClient()
    mock_http_client = AsyncMock()
    mock_http_client.post.side_effect = httpx.ConnectError("Connection refused")

    with patch.object(settings, "REPORTES_API_URL", "http://reportes.cosmol.local"), \
         patch.object(settings, "REPORTES_ENABLED", True), \
         patch.object(client, "get_client", return_value=mock_http_client):

        resultado = await client.enviar_evento_auditoria(
            codigo_socio=1470,
            nombres="TEST SOCIO",
        )
        assert resultado is False


@pytest.mark.asyncio
async def test_resiliencia_servidor_timeout():
    """Si el servidor de Reportes agota el tiempo de espera (Timeout), no propaga el error."""
    client = ReportesApiClient()
    mock_http_client = AsyncMock()
    mock_http_client.post.side_effect = httpx.TimeoutException("Read timeout")

    with patch.object(settings, "REPORTES_API_URL", "http://reportes.cosmol.local"), \
         patch.object(settings, "REPORTES_ENABLED", True), \
         patch.object(client, "get_client", return_value=mock_http_client):

        resultado = await client.enviar_evento_auditoria(
            codigo_socio=1470,
            nombres="TEST SOCIO",
        )
        assert resultado is False


@pytest.mark.asyncio
async def test_tarea_despacho_background():
    """Valida que la función asíncrona despachar_auditoria_reportes se ejecute sin excepciones."""
    with patch("app.tasks.auditoria_reportes.ReportesApiClient") as MockClient:
        instance = MockClient.return_value
        instance.enviar_evento_auditoria = AsyncMock(return_value=True)

        await despachar_auditoria_reportes(
            codigo_socio=1470,
            nombres="SOCIO BACKGROUND",
            telefono="+59177000000",
            id_tipo=1,
            tipo_consulta="Autenticación / Acceso",
        )

        instance.enviar_evento_auditoria.assert_awaited_once_with(
            codigo_socio=1470,
            nombres="SOCIO BACKGROUND",
            telefono="+59177000000",
            id_tipo=1,
            tipo_consulta="Autenticación / Acceso",
            tipo_ubicacion="APP_MOVIL",
        )
