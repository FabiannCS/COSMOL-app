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
