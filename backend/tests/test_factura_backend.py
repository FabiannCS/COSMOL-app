"""
Pruebas unitarias y de integración para la Factura Fiscal Digital (COSMOL R.L. - Backend).
Valida:
1. Generación del motor vectorial PDF con ReportLab y QR code.
2. Esquemas Pydantic v2 (FacturaDetalleResponse, ItemFacturaDetalle).
3. Conversión de montos numéricos a texto legal boliviano ("SON: ...").
4. Mapeo y serialización con el payload JSON oficial (factura 7492196).
"""
import io
from app.services.generador_factura_digital import generador_factura_digital
from app.schemas.factura import FacturaDetalleResponse, ItemFacturaDetalle

# Payload JSON de muestra oficial provisto por COSMOL
PAYLOAD_FACTURA_MUESTRA = {
    "EMPRESA": "COSMOL RL",
    "ACTIVIDADECO": "CAPTACIÓN Y DISTRIBUCIÓN DE AGUA",
    "CASAMATRIZ": "CASA MATRIZ",
    "PUNTODEVENTA": "No Punto de Venta 0",
    "DIREMPRESA": "CALLE ISAIAS PARADA Nro. 219",
    "TELFEMPRESA": "TELEFONO 392-20212 - 61555507",
    "CIUDAD": "MONTERO",
    "LEYENDA1": "ESTA FACTURA CONTRIBUYE AL DESARROLLO DEL PAIS. EL USO ILÍCITO DE ESTA SERÁ SANCIONADO DE ACUERDO A LEY.",
    "LEYENDA3": "Este documento es la representacion Gráfica de un Documento Fiscal Digital emitido en una Modalidad de Facturacion Electrónica en Linea.",
    "DESCUENTO": "0",
    "TIPOFACTURA": "1",
    "NROFACTURA": "7492196",
    "NITEMISOR": "1028317027",
    "NROFACTURAIMP": "1208149",
    "CODAUTORIZACION": "465C3D0702C24738F0ED537D886F1DD043F60B932070C61D2AA13BF74   ",
    "FECHAEMISION": "2026-09-14",
    "NITCI": "4661010             ",
    "NOMBRE": "GUASASE ANDRADE IGNACIO FREDDY                              ",
    "CODSOCIO": "11543",
    "DIRECCION": "V.VIRGINIATAMARINDO                                         ",
    "CODUBICACION": "07.25.018.0    ",
    "CONSUMOM3": "22",
    "PERIODOANIO": "2026",
    "PERIODOMES": "9",
    "TOTAL": "82.22",
    "IMPORTECREDITOFISCAL": "77.72",
    "FECHAPAGO": None,
    "HORAPAGO": None,
    "CANALPAGO": "0",
    "FORMAPAGO": "0",
    "ESTADOFACTURA": "0",
    "CAJAPAGO": None,
    "CODIGOCONTROL": "0                   ",
    "CODIGOQR": "https://siat.impuestos.gob.bo/consulta/QR?nit=1028317027&cuf=465C3D0702C24738F0ED537D886F1DD043F60B932070C61D2AA13BF74&numero=1208149&t=2",
    "DESLEYENDA": "Ley N° 453: El proveedor deberá suministrar el servicio en las modalidades y términos ofertados o convenidos.",
    "detalle": [
        {
            "PREFIJO": "1",
            "CODIGOSERVICIO": "1",
            "CANTIDAD": "1",
            "UNIDADMEDIDA": "SERVICIO                                                                                            ",
            "CONCEPTO": "SERVICIO DE AGUA POTABLE",
            "PRECIOUNITARIO": "73.76",
            "DESCUENTO": "0.00",
            "SUBTOTAL": "73.76"
        },
        {
            "PREFIJO": "1",
            "CODIGOSERVICIO": "3",
            "CANTIDAD": "1",
            "UNIDADMEDIDA": "SERVICIO                                                                                            ",
            "CONCEPTO": "FONDO REPOSICION DE MATERIALES",
            "PRECIOUNITARIO": "3.96",
            "DESCUENTO": "0.00",
            "SUBTOTAL": "3.96"
        },
        {
            "PREFIJO": "1",
            "CODIGOSERVICIO": "27",
            "CANTIDAD": "1",
            "UNIDADMEDIDA": "SERVICIO                                                                                            ",
            "CONCEPTO": "TASA DE REGULACION (AFCOOP)",
            "PRECIOUNITARIO": "0.50",
            "DESCUENTO": "0.00",
            "SUBTOTAL": "0.50"
        },
        {
            "PREFIJO": "1",
            "CODIGOSERVICIO": "18",
            "CANTIDAD": "1",
            "UNIDADMEDIDA": "SERVICIO                                                                                            ",
            "CONCEPTO": "APORTE CLUB GUABIRA",
            "PRECIOUNITARIO": "2.00",
            "DESCUENTO": "0.00",
            "SUBTOTAL": "2.00"
        },
        {
            "PREFIJO": "1",
            "CODIGOSERVICIO": "191",
            "CANTIDAD": "1",
            "UNIDADMEDIDA": "SERVICIO                                                                                            ",
            "CONCEPTO": "APORTE AUXILIO FUNERARIO",
            "PRECIOUNITARIO": "2.00",
            "DESCUENTO": "0.00",
            "SUBTOTAL": "2.00"
        }
    ]
}


def test_generador_pdf_factura_digital():
    """Valida que el motor ReportLab genere un binario PDF válido y no vacío."""
    pdf_bytes = generador_factura_digital.generar_pdf(PAYLOAD_FACTURA_MUESTRA)
    assert pdf_bytes is not None
    assert len(pdf_bytes) > 5000  # Más de 5 KB
    assert pdf_bytes.startswith(b"%PDF-")


def test_numero_a_letras():
    """Valida la conversión a literal legal boliviano."""
    assert generador_factura_digital.numero_a_letras(82.22) == "Ochenta y dos 22/100 Bolivianos"
    assert generador_factura_digital.numero_a_letras(36.30) == "Treinta y seis 30/100 Bolivianos"
    assert generador_factura_digital.numero_a_letras(100.00) == "Cien 00/100 Bolivianos"


def test_pydantic_factura_detalle_response():
    """Valida la instanciación y validación del esquema Pydantic v2."""
    items = []
    for d in PAYLOAD_FACTURA_MUESTRA["detalle"]:
        items.append(ItemFacturaDetalle(
            prefijo=d["PREFIJO"].strip(),
            codigo_servicio=d["CODIGOSERVICIO"].strip(),
            cantidad=float(d["CANTIDAD"]),
            unidad_medida=d["UNIDADMEDIDA"].strip(),
            concepto=d["CONCEPTO"].strip(),
            precio_unitario=float(d["PRECIOUNITARIO"]),
            descuento=float(d["DESCUENTO"]),
            subtotal=float(d["SUBTOTAL"]),
        ))

    total_val = float(PAYLOAD_FACTURA_MUESTRA["TOTAL"])
    response = FacturaDetalleResponse(
        nro_factura=PAYLOAD_FACTURA_MUESTRA["NROFACTURA"],
        nro_factura_imp=PAYLOAD_FACTURA_MUESTRA["NROFACTURAIMP"],
        cod_autorizacion=PAYLOAD_FACTURA_MUESTRA["CODAUTORIZACION"].strip(),
        tipo_factura=PAYLOAD_FACTURA_MUESTRA["TIPOFACTURA"],
        nit_emisor=PAYLOAD_FACTURA_MUESTRA["NITEMISOR"],
        empresa=PAYLOAD_FACTURA_MUESTRA["EMPRESA"],
        actividad_economica=PAYLOAD_FACTURA_MUESTRA["ACTIVIDADECO"],
        casa_matriz=PAYLOAD_FACTURA_MUESTRA["CASAMATRIZ"],
        punto_venta=PAYLOAD_FACTURA_MUESTRA["PUNTODEVENTA"],
        ciudad=PAYLOAD_FACTURA_MUESTRA["CIUDAD"],
        dir_empresa=PAYLOAD_FACTURA_MUESTRA["DIREMPRESA"],
        telf_empresa=PAYLOAD_FACTURA_MUESTRA["TELFEMPRESA"],
        cod_socio=PAYLOAD_FACTURA_MUESTRA["CODSOCIO"],
        nombre_razon_social=PAYLOAD_FACTURA_MUESTRA["NOMBRE"].strip(),
        nit_ci=PAYLOAD_FACTURA_MUESTRA["NITCI"].strip(),
        direccion=PAYLOAD_FACTURA_MUESTRA["DIRECCION"].strip(),
        cod_ubicacion=PAYLOAD_FACTURA_MUESTRA["CODUBICACION"].strip(),
        consumo_m3=int(PAYLOAD_FACTURA_MUESTRA["CONSUMOM3"]),
        periodo_mes=int(PAYLOAD_FACTURA_MUESTRA["PERIODOMES"]),
        periodo_anio=int(PAYLOAD_FACTURA_MUESTRA["PERIODOANIO"]),
        periodo_formateado="09/2026",
        fecha_emision=PAYLOAD_FACTURA_MUESTRA["FECHAEMISION"],
        subtotal=total_val,
        descuento=0.0,
        total=total_val,
        monto_gift_card=0.0,
        monto_a_pagar=total_val,
        importe_credito_fiscal=float(PAYLOAD_FACTURA_MUESTRA["IMPORTECREDITOFISCAL"]),
        total_literal=generador_factura_digital.numero_a_letras(total_val),
        estado_factura="0",
        fecha_pago=None,
        hora_pago=None,
        caja_pago=None,
        codigo_qr=PAYLOAD_FACTURA_MUESTRA["CODIGOQR"],
        des_leyenda=PAYLOAD_FACTURA_MUESTRA["DESLEYENDA"],
        leyenda_1=PAYLOAD_FACTURA_MUESTRA["LEYENDA1"],
        leyenda_3=PAYLOAD_FACTURA_MUESTRA["LEYENDA3"],
        detalle=items,
        url_descarga_pdf="/api/v1/documentos/dummy/descargar",
    )

    assert response.nro_factura == "7492196"
    assert response.total == 82.22
    assert len(response.detalle) == 5
    assert response.total_literal == "Ochenta y dos 22/100 Bolivianos"


if __name__ == "__main__":
    test_generador_pdf_factura_digital()
    print("[OK] test_generador_pdf_factura_digital: PASSED")
    test_numero_a_letras()
    print("[OK] test_numero_a_letras: PASSED")
    test_pydantic_factura_detalle_response()
    print("[OK] test_pydantic_factura_detalle_response: PASSED")
    print("\nTodos los tests pasaron exitosamente.")

