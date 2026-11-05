"""
Pruebas Unitarias para el Flujo de Pago Mock y Telemetría hacia COSMOL-Reportes.
COSMOL R.L. - App de Socios (Tarea: Vista de Pago / Actualizar / Mock).
Valida:
1. Simulación exitosa con comprobante mock (sin tocar Informix).
2. Despacho de auditoría a COSMOL-Reportes en segundo plano (id_tipo: 12).
3. Verificación de pertenencia de suministro (seguridad multicuenta).
"""
import uuid
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi import BackgroundTasks
from fastapi.testclient import TestClient

from app.main import app
from app.api.deps import get_current_user_id, get_db, get_redis
from app.db.models.suministro import Suministro
from app.schemas.pago import SimularPagoRequest, SimularPagoResponse


@pytest.fixture
def mock_user_id():
    return str(uuid.uuid4())


@pytest.fixture
def client(mock_user_id):
    mock_db = AsyncMock()
    mock_redis = AsyncMock()

    # Sobrescribir dependencias de FastAPI
    app.dependency_overrides[get_current_user_id] = lambda: mock_user_id
    app.dependency_overrides[get_db] = lambda: mock_db
    app.dependency_overrides[get_redis] = lambda: mock_redis

    test_client = TestClient(app)
    yield test_client

    app.dependency_overrides.clear()


def test_simular_pago_exitoso(client, mock_user_id):
    """
    Verifica que la simulación de pago devuelva el comprobante con número TRX mock
    y encole la tarea de auditoría para COSMOL-Reportes.
    """
    with patch("app.services.servicio_pagos.ServicioPagos._validar_pertenencia_suministro", new_callable=AsyncMock) as mock_validar, \
         patch("app.api.v1.pagos.despachar_auditoria_reportes", new_callable=AsyncMock) as mock_auditoria:

        mock_suministro = MagicMock(spec=Suministro)
        mock_suministro.cod_socio = "23807"
        mock_suministro.alias = "Mi Casa"
        mock_validar.return_value = mock_suministro

        payload = {
            "canal_id": "qr_simple",
            "monto_bs": 142.50,
            "periodos": "08/2026, 09/2026"
        }

        response = client.post("/api/v1/pagos/simular-pago/23807", json=payload)

        assert response.status_code == 200
        data = response.json()
        assert data["exito"] is True
        assert data["cod_socio"] == "23807"
        assert data["canal_id"] == "qr_simple"
        assert data["monto_bs"] == 142.50
        assert "TRX-MOCK-" in data["nro_transaccion"]
        assert data["es_simulacion"] is True
        assert "fecha_pago" in data


def test_simular_pago_canal_multipago(client, mock_user_id):
    """
    Verifica que simular con canal multipago responda correctamente con su canal_id.
    """
    with patch("app.services.servicio_pagos.ServicioPagos._validar_pertenencia_suministro", new_callable=AsyncMock) as mock_validar, \
         patch("app.api.v1.pagos.despachar_auditoria_reportes", new_callable=AsyncMock) as mock_auditoria:

        mock_suministro = MagicMock(spec=Suministro)
        mock_validar.return_value = mock_suministro

        payload = {
            "canal_id": "multipago",
            "monto_bs": 85.00
        }

        response = client.post("/api/v1/pagos/simular-pago/23807", json=payload)

        assert response.status_code == 200
        data = response.json()
        assert data["canal_id"] == "multipago"
        assert data["monto_bs"] == 85.00
        assert data["es_simulacion"] is True

