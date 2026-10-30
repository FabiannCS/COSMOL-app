import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi import BackgroundTasks

from app.core.exceptions import BadRequestException
from app.schemas.reconexion import (
    SolicitudReconexionCreate,
    TipoReconexionEnum,
)
from app.services.servicio_reconexion import ServicioReconexion


@pytest.fixture
def mock_socio_datos():
    return {
        "CODIGO": "267657",
        "NOMBRE": "JUAN PEREZ GUTIERREZ",
        "DIRECCION": "BARRIO CENTRAL C/ BOLIVAR #120",
        "ZONA": "1",
        "RUTA": "4",
        "NROC": "120",
        "NROI": "0"
    }


@pytest.mark.asyncio
async def test_elegibilidad_bloqueada_por_tramite_pendiente(mock_socio_datos):
    """Regla 1: Trámite previo con estado PENDIENTE bloquea la solicitud."""
    servicio = ServicioReconexion()

    with patch("app.services.servicio_reconexion.cosmol_client.obtener_datos_socio", new_callable=AsyncMock) as mock_datos, \
         patch("app.services.servicio_reconexion.cosmol_client.obtener_reconexiones_socio", new_callable=AsyncMock) as mock_rec:
        
        mock_datos.return_value = mock_socio_datos
        mock_rec.return_value = [
            {
                "id_reconexion": 1284,
                "fecha": "2026-10-15 09:30:00",
                "tipo": "Corte normal",
                "estado": "PENDIENTE",
                "glosa": "Portón blanco"
            }
        ]

        resp = await servicio.verificar_elegibilidad("267657")
        assert resp.es_elegible is False
        assert resp.motivo_bloqueo == "TRAMITE_DUPLICADO"
        assert resp.tramite_pendiente_id == 1284
        assert "ya cuenta con una solicitud de reconexión en estado PENDIENTE" in resp.mensaje_usuario


@pytest.mark.asyncio
async def test_elegibilidad_bloqueada_por_alta_morosidad(mock_socio_datos):
    """Regla 2: Más de 2 facturas pendientes bloquea la solicitud."""
    servicio = ServicioReconexion()

    with patch("app.services.servicio_reconexion.cosmol_client.obtener_datos_socio", new_callable=AsyncMock) as mock_datos, \
         patch("app.services.servicio_reconexion.cosmol_client.obtener_reconexiones_socio", new_callable=AsyncMock) as mock_rec, \
         patch("app.services.servicio_reconexion.cosmol_client.obtener_deudas_socio", new_callable=AsyncMock) as mock_deudas:
        
        mock_datos.return_value = mock_socio_datos
        mock_rec.return_value = []
        mock_deudas.return_value = [
            {"NROFACTURA": "101", "MONTOTOTAL": 50.0},
            {"NROFACTURA": "102", "MONTOTOTAL": 50.0},
            {"NROFACTURA": "103", "MONTOTOTAL": 60.0},  # 3 facturas > 2
        ]

        resp = await servicio.verificar_elegibilidad("267657")
        assert resp.es_elegible is False
        assert resp.motivo_bloqueo == "ALTA_MOROSIDAD"
        assert resp.facturas_pendientes == 3
        assert resp.total_deuda_bs == 160.0
        assert "registra 3 facturas pendientes" in resp.mensaje_usuario


@pytest.mark.asyncio
async def test_elegibilidad_exitosa_y_ubicacion_catastral(mock_socio_datos):
    """Regla 3: Si mora <= 2 y no hay PENDIENTE, es elegible y compone ZONA.RUTA.NROC.NROI."""
    servicio = ServicioReconexion()

    with patch("app.services.servicio_reconexion.cosmol_client.obtener_datos_socio", new_callable=AsyncMock) as mock_datos, \
         patch("app.services.servicio_reconexion.cosmol_client.obtener_reconexiones_socio", new_callable=AsyncMock) as mock_rec, \
         patch("app.services.servicio_reconexion.cosmol_client.obtener_deudas_socio", new_callable=AsyncMock) as mock_deudas:
        
        mock_datos.return_value = mock_socio_datos
        mock_rec.return_value = [
            {"id_reconexion": 900, "estado": "FINALIZADO"}
        ]
        mock_deudas.return_value = [
            {"NROFACTURA": "101", "MONTOTOTAL": 45.50},
            {"NROFACTURA": "102", "MONTOTOTAL": 55.00},  # 2 facturas <= 2
        ]

        resp = await servicio.verificar_elegibilidad("267657")
        assert resp.es_elegible is True
        assert resp.motivo_bloqueo is None
        assert resp.facturas_pendientes == 2
        assert resp.total_deuda_bs == 100.50
        assert resp.ubicacion_catastral == "1.4.120.0"
        assert resp.zona == 1
        assert resp.ruta == 4


@pytest.mark.asyncio
async def test_solicitar_reconexion_exitosa(mock_socio_datos):
    """Regla 4 y 5: Registro exitoso con usuario_registro=2 y auditoría a Reportes (id_tipo=5)."""
    servicio = ServicioReconexion()
    background_tasks = MagicMock(spec=BackgroundTasks)

    solicitud = SolicitudReconexionCreate(
        codigo_socio="267657",
        id_tipo_reconexion=TipoReconexionEnum.CORTE_NORMAL,
        coordenadas_gps="-17.345678, -63.254123",
        glosa="Casa frente a la plaza, rejas blancas",
        foto_url="https://servidor.cosmol.com/uploads/reconexiones/foto.jpg"
    )

    with patch("app.services.servicio_reconexion.cosmol_client.obtener_datos_socio", new_callable=AsyncMock) as mock_datos, \
         patch("app.services.servicio_reconexion.cosmol_client.obtener_reconexiones_socio", new_callable=AsyncMock) as mock_rec, \
         patch("app.services.servicio_reconexion.cosmol_client.obtener_deudas_socio", new_callable=AsyncMock) as mock_deudas, \
         patch("app.services.servicio_reconexion.cosmol_client.registrar_solicitud_reconexion", new_callable=AsyncMock) as mock_sai:
        
        mock_datos.return_value = mock_socio_datos
        mock_rec.return_value = []
        mock_deudas.return_value = [{"NROFACTURA": "101", "MONTOTOTAL": 40.0}]
        mock_sai.return_value = {
            "id_reconexion": 4921,
            "estado": "PENDIENTE",
            "facturas_pendientes": 1
        }

        resp = await servicio.solicitar_reconexion(
            datos=solicitud,
            background_tasks=background_tasks,
            telefono="71234567"
        )

        assert resp.id_reconexion == 4921
        assert resp.estado == "PENDIENTE"
        assert "#4921" in resp.mensaje

        mock_sai.assert_called_once_with(
            "267657",
            {
                "usuario_registro": 2,
                "coordenadas_gps": "-17.345678, -63.254123",
                "id_tipo_reconexion": 1,
                "ubicacion": "1.4.120.0",
                "zona": 1,
                "ruta": 4,
                "glosa": "Casa frente a la plaza, rejas blancas",
                "foto": "https://servidor.cosmol.com/uploads/reconexiones/foto.jpg",
            }
        )

        assert background_tasks.add_task.called
        args, kwargs = background_tasks.add_task.call_args
        assert kwargs["codigo_socio"] == 267657
        assert kwargs["id_tipo"] == 5
        assert kwargs["tipo_consulta"] == "Solicitud de Reconexión"

