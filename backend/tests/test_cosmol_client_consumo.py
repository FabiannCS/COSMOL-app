import asyncio
import pytest
from app.integrations.cosmol_client import cosmol_client, CosmolLegacyClient


@pytest.mark.asyncio
async def test_obtener_historial_consumo_socio_estable():
    """
    Verifica que el socio 556 retorne 12 periodos reales continuos de Informix.
    """
    consumos = await cosmol_client.obtener_historial_consumo("556", meses=12)
    assert isinstance(consumos, list)
    assert len(consumos) == 12, "Debe retornar 12 periodos consecutivos"

    # Validar estructura y consistencia de cada periodo
    for item in consumos:
        assert "periodo" in item
        assert "mes" in item and 1 <= item["mes"] <= 12
        assert "anio" in item and item["anio"] in [2025, 2026]
        assert "consumo_m3" in item
        assert "monto_bs" in item
        assert item["consumo_m3"] >= 0.0
        assert item["monto_bs"] >= 0.0
        assert item["estado_lectura"] == "NORMAL"
        assert item["fecha_lectura"] is not None


@pytest.mark.asyncio
async def test_obtener_historial_consumo_socio_fuga_atipica(monkeypatch):
    """
    Verifica que ante un pico atípico en el mes 12 (32 m3 frente a promedio ~18 m3),
    el cálculo supere el umbral de alerta de fuga (+30%).
    """
    dataset_fuga = [
        {"periodo": f"{m:02d}/2025" if m >= 10 else f"{m:02d}/2026", "mes": m, "anio": 2025 if m >= 10 else 2026, "consumo_m3": 18.0, "monto_bs": 70.0, "estado_lectura": "NORMAL", "fecha_lectura": "2026-01-01"}
        for m in [10, 11, 12, 1, 2, 3, 4, 5, 6, 7, 8]
    ]
    dataset_fuga.append({"periodo": "09/2026", "mes": 9, "anio": 2026, "consumo_m3": 32.0, "monto_bs": 124.8, "estado_lectura": "NORMAL", "fecha_lectura": "2026-09-20"})

    async def _mock_consumos(cod, meses=12):
        return dataset_fuga

    monkeypatch.setattr(cosmol_client, "obtener_historial_consumo", _mock_consumos)

    consumos = await cosmol_client.obtener_historial_consumo("540", meses=12)
    assert len(consumos) == 12

    # Los primeros 11 meses deben promediar ~18 m3
    meses_previos = consumos[:11]
    promedio_previo = sum(m["consumo_m3"] for m in meses_previos) / len(meses_previos)
    assert 17.0 <= promedio_previo <= 19.0

    # El último mes debe registrar el pico
    ultimo_mes = consumos[-1]
    assert ultimo_mes["periodo"] == "09/2026"
    assert ultimo_mes["consumo_m3"] == 32.0

    # El incremento supera con holgura el 30% (+75% aprox)
    incremento_pct = ((ultimo_mes["consumo_m3"] - promedio_previo) / promedio_previo) * 100
    assert incremento_pct > 30.0, "Debe superar el umbral de +30% para activar consumo atípico"


@pytest.mark.asyncio
async def test_obtener_historial_consumo_filtro_meses():
    """
    Verifica que el parámetro 'meses' limite correctamente el rango cronológico retornado.
    """
    # Solicitar solo 6 meses
    consumos_6 = await cosmol_client.obtener_historial_consumo("556", meses=6)
    assert len(consumos_6) == 6
    # Los meses retornados deben ser los últimos 6 (04/2026 a 09/2026)
    periodos = [c["periodo"] for c in consumos_6]
    assert periodos == ["04/2026", "05/2026", "06/2026", "07/2026", "08/2026", "09/2026"]

    # Solicitar 3 meses
    consumos_3 = await cosmol_client.obtener_historial_consumo("556", meses=3)
    assert len(consumos_3) == 3
    assert [c["periodo"] for c in consumos_3] == ["07/2026", "08/2026", "09/2026"]


def test_normalizador_consumo_legado_informix():
    """
    Verifica que _normalizar_consumo_legado sea tolerante ante variaciones heterogéneas
    de nombres de columnas de Informix/COSMOL y limpie espacios en blanco.
    """
    client = CosmolLegacyClient()

    # Caso 1: Columnas abreviadas con espacios y números como strings (típico de Informix)
    raw_informix = {
        "NMES": " 8 ",
        "GESTION": " 2026 ",
        "LECT_ANT": " 1400.50 ",
        "LECT_ACT": " 1422.00 ",
        "VOLUMEN": " 21.50 ",
        "IMPORTE": " 83.85 ",
        "ESTADO": " normal ",
        "FECHA": " 2026-08-25 "
    }

    norm = client._normalizar_consumo_legado(raw_informix)
    assert norm["periodo"] == "08/2026"
    assert norm["mes"] == 8
    assert norm["anio"] == 2026
    assert norm["lectura_anterior"] == 1400.50
    assert norm["lectura_actual"] == 1422.00
    assert norm["consumo_m3"] == 21.50
    assert norm["monto_bs"] == 83.85
    assert norm["estado_lectura"] == "NORMAL"
    assert norm["fecha_lectura"] == "2026-08-25"

    # Caso 2: Sin volumen explícito -> debe calcular lectura_act - lectura_ant
    raw_sin_volumen = {
        "MES": 9,
        "ANIO": 2026,
        "LECTURA_ANTERIOR": 1000.0,
        "LECTURA_ACTUAL": 1025.0,
        "MONTOTOTAL": 97.50
    }
    norm2 = client._normalizar_consumo_legado(raw_sin_volumen)
    assert norm2["consumo_m3"] == 25.0
    assert norm2["periodo"] == "09/2026"
    assert norm2["estado_lectura"] == "NORMAL"


@pytest.mark.asyncio
async def test_consumos_socio_inexistente():
    """
    Verifica que un código de socio inexistente en la API real de COSMOL retorne
    una lista vacía sin arrojar excepciones.
    """
    consumos = await cosmol_client.obtener_historial_consumo("88849999", meses=12)
    assert isinstance(consumos, list)
    assert len(consumos) == 0


@pytest.mark.asyncio
async def test_normalizador_payload_real_api_cosmol():
    """
    Verifica la normalización exacta del payload real retornado por la API de COSMOL (socio 23807):
    {
        "CODIGO": "23807",
        "NOMBRE": "MISERICORDIA AGUANTA EDDY FRANCO                            ",
        "MES": "8",
        "ANIO": "2026",
        "MONTO": "58.01",
        "ESTADO": "1",
        "CONSUMO": "15",
        "FECHA": "2026-08-13"
    }
    """
    client = CosmolLegacyClient()
    raw_real = {
        "CODIGO": "23807",
        "NOMBRE": "MISERICORDIA AGUANTA EDDY FRANCO                            ",
        "MES": "8",
        "ANIO": "2026",
        "MONTO": "58.01",
        "ESTADO": "1",
        "CONSUMO": "15",
        "FECHA": "2026-08-13"
    }
    norm = client._normalizar_consumo_legado(raw_real)
    assert norm["periodo"] == "08/2026"
    assert norm["mes"] == 8
    assert norm["anio"] == 2026
    assert norm["consumo_m3"] == 15.0
    assert norm["monto_bs"] == 58.01
    assert norm["estado_lectura"] == "NORMAL"
    assert norm["fecha_lectura"] == "2026-08-13"
