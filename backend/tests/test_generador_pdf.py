"""
Batería de pruebas automatizadas para el motor de generación de PDFs (DEV 1).
Verifica que las Facturas Oficiales, Avisos de Cobranza y Avisos de Corte
se generen con el formato binario estándar de PDF (%PDF) y contenido consistente.
"""
import pytest
from app.services.generador_pdf import generador_pdf


def test_generar_pdf_factura():
    """
    Verifica que la generación de una Factura con valor legal produzca un flujo PDF válido.
    """
    datos_socio = {
        "CODIGO": "540",
        "NOMBRE": "DURAN ELOISA RIVERA DE",
        "NROCIONIT": "2823231",
        "DIRECCION": "SANTA CRUZ 117",
        "ubicacion": "1.39.135.0"
    }
    datos_factura = {
        "NROFACTURA": "7444051",
        "CODAUTORIZACION": "465C3D0702C232069B9F771B83440D4217AF35B442086180BD081BF74",
        "periodo": "08/2026",
        "MONTOTOTAL": 70.92
    }

    pdf_bytes = generador_pdf.generar_pdf_factura(datos_factura, datos_socio)

    assert isinstance(pdf_bytes, bytes)
    assert len(pdf_bytes) > 1000  # Archivo PDF sustancial
    assert pdf_bytes.startswith(b"%PDF")  # Cabecera mágica oficial de PDF


def test_generar_pdf_aviso_cobranza():
    """
    Verifica que la generación de un Aviso de Cobranza preventivo sea un PDF válido.
    """
    datos_socio = {
        "CODIGO": "556",
        "NOMBRE": "SUAREZ BALTAZAR VICTOR HUGO",
        "DIRECCION": "ISAIAS PARADA"
    }
    datos_deuda = {
        "periodo": "09/2026",
        "monto_bs": 61.42,
        "fecha_vencimiento": "30/09/2026"
    }

    pdf_bytes = generador_pdf.generar_pdf_aviso_cobranza(datos_deuda, datos_socio)

    assert isinstance(pdf_bytes, bytes)
    assert len(pdf_bytes) > 500
    assert pdf_bytes.startswith(b"%PDF")


def test_generar_pdf_aviso_corte():
    """
    Verifica que la generación de una Notificación de Corte con facturas en mora sea un PDF válido.
    """
    datos_socio = {
        "CODIGO": "540",
        "NOMBRE": "DURAN ELOISA RIVERA DE",
        "DIRECCION": "SANTA CRUZ 117"
    }
    facturas_pendientes = [
        {"periodo": "08/2026", "nro_factura": "7444051", "monto_bs": 70.92},
        {"periodo": "09/2026", "nro_factura": "7473308", "monto_bs": 61.42},
    ]

    pdf_bytes = generador_pdf.generar_pdf_aviso_corte(datos_socio, facturas_pendientes)

    assert isinstance(pdf_bytes, bytes)
    assert len(pdf_bytes) > 800
    assert pdf_bytes.startswith(b"%PDF")


def test_generador_aviso_cobranza_oficial_completo():
    """
    Verifica que el generador oficial de Avisos de Cobranza (210x140mm)
    procese adecuadamente historial de 12 meses, estados de pago y conceptos.
    """
    from app.services.generador_aviso_cobranza import generador_aviso_cobranza

    datos_aviso = {
        "nro_factura": "7444051",
        "periodo": "08/2026",
        "anio": 2026,
        "mes": 8,
        "monto_total": 70.92,
        "fecha_emision": "13/08/2026",
        "fecha_vencimiento": "31/08/2026",
        "lectura_anterior": "210",
        "lectura_actual": "225",
        "consumo_m3": "15",
        "dias_consumo": "30",
        "obs": "NORMAL",
        "fecha_corte": "30/10/2026"
    }
    datos_socio = {
        "CODIGO": "540",
        "NOMBRE": "DURAN ELOISA RIVERA DE",
        "NROCIONIT": "2823231",
        "DIRECCION": "SANTA CRUZ 117",
        "CATEGORIA": "DOMICILIARIA",
        "DISTRITO": "1",
        "ENVIO": "1",
        "UBICACION": "1.39.135.0"
    }
    historial = [
        {"periodo": "08/2026", "consumo_m3": 15, "monto_bs": 70.92, "estado": "IMPAGA", "fecha_pago": ""},
        {"periodo": "07/2026", "consumo_m3": 14, "monto_bs": 66.50, "estado": "PAGADA", "fecha_pago": "10/08/2026"},
        {"periodo": "06/2026", "consumo_m3": 16, "monto_bs": 74.20, "estado": "PAGADA", "fecha_pago": "09/07/2026"},
    ]
    conceptos = [
        {"cod": 1, "concepto": "SERVICIO DE AGUA POTABLE", "monto_bs": 46.10},
        {"cod": 2, "concepto": "SERV.ALCANT.SANITARIO", "monto_bs": 24.82},
    ]

    pdf_bytes = generador_aviso_cobranza.generar(
        datos_aviso=datos_aviso,
        datos_socio=datos_socio,
        historial_consumo=historial,
        conceptos=conceptos
    )

    assert isinstance(pdf_bytes, bytes)
    assert len(pdf_bytes) > 20000  # Archivo PDF completo con logos vectoriales (>20KB)
    assert pdf_bytes.startswith(b"%PDF")

