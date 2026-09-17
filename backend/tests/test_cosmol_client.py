import pytest
from app.integrations.cosmol_client import cosmol_client


@pytest.mark.asyncio
async def test_cosmol_client_socio_al_dia():
    """
    Verifica consulta de datos y deudas de un socio al día (ej. socio 556).
    """
    socio = await cosmol_client.obtener_datos_socio("556")
    assert socio is not None
    assert socio["CODIGO"] == "556"
    assert "SUAREZ BALTAZAR" in socio["NOMBRE"]
    assert socio["NROCIONIT"] == "4638847"
    assert socio["NOMBRE"] == socio["NOMBRE"].strip(), "Los campos deben estar normalizados con .strip()"

    deudas = await cosmol_client.obtener_deudas_socio("556")
    assert isinstance(deudas, list)
    assert len(deudas) == 0, "El socio 556 no debe tener facturas pendientes"


@pytest.mark.asyncio
async def test_cosmol_client_socio_con_deuda():
    """
    Verifica consulta de facturas pendientes de un socio con deuda (ej. socio 540).
    """
    socio = await cosmol_client.obtener_datos_socio("540")
    assert socio is not None
    assert socio["CODIGO"] == "540"
    assert "DURAN ELOISA" in socio["NOMBRE"]
    assert socio["NROCIONIT"] == "2823231"

    deudas = await cosmol_client.obtener_deudas_socio("540")
    assert isinstance(deudas, list)
    assert len(deudas) >= 1, "El socio 540 debe tener al menos una factura pendiente"

    factura = deudas[0]
    assert "NROFACTURA" in factura
    assert "CODAUTORIZACION" in factura
    assert "ANIO" in factura
    assert "NMES" in factura
    assert "MONTOTOTAL" in factura
    # Validar que el monto sea numéricamente convertible a float
    monto = float(factura["MONTOTOTAL"])
    assert monto > 0


@pytest.mark.asyncio
async def test_cosmol_client_socio_inexistente():
    """
    Verifica que consultar un código inexistente retorne None de forma segura sin excepciones.
    """
    socio = await cosmol_client.obtener_datos_socio("999999999")
    assert socio is None

    deudas = await cosmol_client.obtener_deudas_socio("999999999")
    assert deudas == []
