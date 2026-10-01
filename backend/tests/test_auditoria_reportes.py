import json
import pytest
from unittest.mock import AsyncMock, patch, MagicMock
import httpx

from app.core.config import settings
from app.integrations.reportes_client import ReportesApiClient
from app.tasks.auditoria_reportes import (
    despachar_auditoria_reportes,
    encolar_evento_en_redis,
    vaciar_cola_pendientes,
    REDIS_KEY_COLA_PENDIENTES,
)


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
        assert client.esta_servidor_offline() is False
        mock_http_client.post.assert_called_once()
        args, kwargs = mock_http_client.post.call_args
        assert args[0] == "http://reportes.cosmol.local/api/consultas"
        assert kwargs.get("follow_redirects") is True
        
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
        assert headers["ngrok-skip-browser-warning"] == "true"


@pytest.mark.asyncio
async def test_resiliencia_servidor_offline():
    """Si el servidor de Reportes está fuera de línea (ConnectError), atrapa la excepción y marca offline."""
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
        assert client.esta_servidor_offline() is True


@pytest.mark.asyncio
async def test_resiliencia_servidor_timeout():
    """Si el servidor de Reportes agota el tiempo de espera (Timeout), marca offline y no propaga error."""
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
        assert client.esta_servidor_offline() is True


@pytest.mark.asyncio
async def test_encolado_en_redis_ante_fallo_reportes():
    """Valida que si Reportes está caído, el evento se guarde en la cola de Redis."""
    mock_redis = AsyncMock()
    mock_redis.rpush = AsyncMock(return_value=1)

    payload = {
        "codigo_socio": 23807,
        "nombres": "TEST SOCIO",
        "id_usuario": 3,
        "id_tipo": 2,
        "tipo_consulta": "Consulta de Deuda",
        "tipo_ubicacion": "APP_MOVIL",
        "fecha_consulta": "2026-09-23",
        "hora_consulta": "10:00:00",
    }

    with patch("app.tasks.auditoria_reportes.get_redis", return_value=mock_redis), \
         patch.object(settings, "REPORTES_ENABLED", True), \
         patch.object(settings, "REPORTES_API_URL", "http://reportes.cosmol.local"):

        resultado = await encolar_evento_en_redis(payload)
        assert resultado is True
        mock_redis.rpush.assert_called_once()
        args, kwargs = mock_redis.rpush.call_args
        assert args[0] == REDIS_KEY_COLA_PENDIENTES
        guardado = json.loads(args[1])
        assert guardado["codigo_socio"] == 23807


@pytest.mark.asyncio
async def test_vaciar_cola_pendientes_exitosa():
    """Valida que los eventos en la cola de Redis se expulsen hacia Reportes cuando esté activo."""
    evento1 = json.dumps({"codigo_socio": 101, "tipo_consulta": "Login"})
    evento2 = json.dumps({"codigo_socio": 102, "tipo_consulta": "Deuda"})

    mock_redis = AsyncMock()
    mock_redis.llen = AsyncMock(side_effect=[2, 0])
    mock_redis.lpop = AsyncMock(side_effect=[evento1, evento2, None])

    with patch("app.tasks.auditoria_reportes.get_redis", return_value=mock_redis), \
         patch("app.tasks.auditoria_reportes.ReportesApiClient") as MockClient, \
         patch.object(settings, "REPORTES_ENABLED", True), \
         patch.object(settings, "REPORTES_API_URL", "http://reportes.cosmol.local"):

        instance = MockClient.return_value
        instance.enviar_payload_directo = AsyncMock(return_value=True)

        sincronizados = await vaciar_cola_pendientes(limite=10)
        assert sincronizados == 2
        assert instance.enviar_payload_directo.await_count == 2


@pytest.mark.asyncio
async def test_vaciar_cola_se_detiene_si_servidor_offline():
    """Si durante el vaciado el servidor vuelve a caer, reinserta el evento y suspende la iteración."""
    evento1 = json.dumps({"codigo_socio": 101, "tipo_consulta": "Login"})

    mock_redis = AsyncMock()
    mock_redis.llen = AsyncMock(return_value=1)
    mock_redis.lpop = AsyncMock(return_value=evento1)
    mock_redis.lpush = AsyncMock(return_value=1)

    with patch("app.tasks.auditoria_reportes.get_redis", return_value=mock_redis), \
         patch("app.tasks.auditoria_reportes.ReportesApiClient") as MockClient, \
         patch.object(settings, "REPORTES_ENABLED", True), \
         patch.object(settings, "REPORTES_API_URL", "http://reportes.cosmol.local"):

        instance = MockClient.return_value
        instance.enviar_payload_directo = AsyncMock(return_value=False)
        instance.esta_servidor_offline = MagicMock(return_value=True)

        sincronizados = await vaciar_cola_pendientes(limite=5)
        assert sincronizados == 0
        mock_redis.lpush.assert_called_once_with(REDIS_KEY_COLA_PENDIENTES, evento1)


@pytest.mark.asyncio
async def test_tarea_despacho_background_exitosa_y_fallida():
    """Valida el flujo de despacho en segundo plano: directo si está activo, encolado si falla."""
    mock_redis = AsyncMock()
    mock_redis.llen = AsyncMock(return_value=0)
    mock_redis.rpush = AsyncMock(return_value=1)

    # 1. Caso Exitoso
    with patch("app.tasks.auditoria_reportes.ReportesApiClient") as MockClient, \
         patch("app.tasks.auditoria_reportes.get_redis", return_value=mock_redis), \
         patch.object(settings, "REPORTES_ENABLED", True), \
         patch.object(settings, "REPORTES_API_URL", "http://reportes.cosmol.local"):

        instance = MockClient.return_value
        instance.enviar_payload_directo = AsyncMock(return_value=True)

        await despachar_auditoria_reportes(
            codigo_socio=1470,
            nombres="SOCIO BACKGROUND",
            telefono="+59177000000",
            id_tipo=1,
            tipo_consulta="Autenticación / Acceso",
        )

        instance.enviar_payload_directo.assert_awaited_once()

    # 2. Caso Caído (debe encolar en Redis)
    with patch("app.tasks.auditoria_reportes.ReportesApiClient") as MockClient, \
         patch("app.tasks.auditoria_reportes.get_redis", return_value=mock_redis), \
         patch.object(settings, "REPORTES_ENABLED", True), \
         patch.object(settings, "REPORTES_API_URL", "http://reportes.cosmol.local"):

        instance = MockClient.return_value
        instance.enviar_payload_directo = AsyncMock(return_value=False)

        await despachar_auditoria_reportes(
            codigo_socio=1470,
            nombres="SOCIO CAIDO",
            id_tipo=2,
        )

        mock_redis.rpush.assert_called_once()
