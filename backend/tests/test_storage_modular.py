"""
Pruebas unitarias para la modularización de almacenamiento de documentos y extracción de NROFACTURA.
"""
from app.services.servicio_storage_documentos import ServicioStorageDocumentos
from app.integrations.cosmol_client import CosmolLegacyClient


def test_construir_s3_key_modular():
    """Valida que la clave canónica modular en MinIO se genere según la nueva jerarquía."""
    # Instanciamos el servicio con dependencias dummy para probar la función pura
    servicio = ServicioStorageDocumentos(db=None, s3_client=None)

    # 1. Factura Impaga
    key_impaga = servicio.construir_s3_key(
        cod_socio="11543",
        tipo_documento="FACTURA",
        periodo="09/2026",
        identificador="7492196",
        estado_pago="PENDIENTE",
        anio=2026
    )
    assert key_impaga == "facturas/impagas/11543/2026/FAC_7492196_09_2026.pdf"

    # 2. Factura Pagada
    key_pagada = servicio.construir_s3_key(
        cod_socio="11543",
        tipo_documento="FACTURA",
        periodo="09/2026",
        identificador="7492196",
        estado_pago="PAGADO",
        anio=2026
    )
    assert key_pagada == "facturas/pagadas/11543/2026/FAC_7492196_09_2026.pdf"

    # 3. Aviso de Cobranza
    key_aviso = servicio.construir_s3_key(
        cod_socio="11543",
        tipo_documento="AVISO_COBRANZA",
        periodo="09/2026",
        identificador="1208149",
        anio=2026
    )
    assert key_aviso == "avisos_cobranza/11543/2026/AVISO_1208149_09_2026.pdf"

    # 4. Aviso de Corte
    key_corte = servicio.construir_s3_key(
        cod_socio="11543",
        tipo_documento="AVISO_CORTE",
        periodo="MORA",
        identificador="corte_inminente",
        anio=2026
    )
    assert key_corte == "avisos_corte/11543/2026/CORTE_11543_MORA.pdf"


def test_normalizacion_historial_factura_con_nrofactura():
    """Valida la extracción directa de NROFACTURA del endpoint modificado de COSMOL."""
    client = CosmolLegacyClient()
    item_api = {
        "NROFACTURA": "7492196",
        "CODIGO": "11543",
        "NOMBRE": "GUASASE ANDRADE IGNACIO FREDDY                              ",
        "MES": "9",
        "ANIO": "2026",
        "MONTO": "82.22",
        "ESTADO": "0",
        "CONSUMO": "22",
        "FECHA": None
    }

    norm = client._normalizar_consumo_legado(item_api)

    assert norm["nro_factura"] == "7492196"
    assert norm["NROFACTURA"] == "7492196"
    assert norm["cod_socio"] == "11543"
    assert norm["nombre"] == "GUASASE ANDRADE IGNACIO FREDDY"
    assert norm["periodo"] == "09/2026"
    assert norm["mes"] == 9
    assert norm["anio"] == 2026
    assert norm["monto_bs"] == 82.22
    assert norm["consumo_m3"] == 22.0


def test_normalizacion_historial_factura_con_nroaviso():
    """Valida la extracción directa de NROAVISO del endpoint modificado de COSMOL."""
    client = CosmolLegacyClient()
    item_api = {
        "NROFACTURA": "7516140",
        "CODIGO": "11543",
        "NOMBRE": "GUASASE ANDRADE IGNACIO FREDDY                              ",
        "MES": "10",
        "ANIO": "2026",
        "MONTO": "61.86",
        "ESTADO": "0",
        "CONSUMO": "16",
        "FECHA": None,
        "NROAVISO": "4742124"
    }

    norm = client._normalizar_consumo_legado(item_api)

    assert norm["nro_factura"] == "7516140"
    assert norm["nro_aviso"] == "4742124"
    assert norm["NROAVISO"] == "4742124"
    assert norm["cod_socio"] == "11543"
    assert norm["mes"] == 10
    assert norm["anio"] == 2026


def test_normalizacion_url_defensiva():
    """Valida que _normalizar_url elimine barras duplicadas y deduplique prefijos de ruta."""
    from app.integrations.base_client import BaseApiClient

    # 1. URL con dobles barras como en el reporte del usuario
    url1 = BaseApiClient._normalizar_url("http://api.cosmol.com.bo//api-consultas/", "//avisos/4742124")
    assert url1 == "http://api.cosmol.com.bo/api-consultas/avisos/4742124"

    # 2. Base y endpoint que repiten el prefijo /api-consultas
    url2 = BaseApiClient._normalizar_url("http://api.cosmol.com.bo/api-consultas", "/api-consultas/avisos/4742124")
    assert url2 == "http://api.cosmol.com.bo/api-consultas/avisos/4742124"

    # 3. URL completa en endpoint
    url3 = BaseApiClient._normalizar_url("http://api.cosmol.com.bo/api-consultas", "http://api.cosmol.com.bo//api-consultas/avisos/4742124")
    assert url3 == "http://api.cosmol.com.bo/api-consultas/avisos/4742124"


def test_generador_aviso_desde_payload_oficial():
    """Valida que generador_aviso_cobranza genere un PDF válido directamente desde el payload de /avisos/{id}."""
    from app.services.generador_aviso_cobranza import generador_aviso_cobranza

    payload_oficial = {
        "MES": "10",
        "ANIO": "2026",
        "FECHA_EMISION": "2026-10-07 12:16:51.000",
        "FECHA_VENCIMIENTO": "2026-11-12 00:00:00.000",
        "CODIGO": "11543",
        "UBICACION": "7.25.18.0           ",
        "NRO_AVISO": "4742124",
        "NOMBRE": "GUASASE ANDRADE IGNACIO FREDDY                                                                                          ",
        "DIRECCION": "V.VIRGINIATAMARINDO                                         ",
        "NUMEROCI": "4661010                       ",
        "CATEGORIA": "DOMICILIARIA                                                ",
        "DISTRITO": "3",
        "ENVIO": "1",
        "FECHA_ANTERIOR": "2026-09-07 00:00:00.000",
        "FECHA_ACTUAL": "2026-10-07 12:16:51.000",
        "LECTURA_ANTEROR": "741",
        "LECTURA_ACTUAL": "757",
        "CONSUMO": "16",
        "OBSERVACION": "0",
        "FECHA_CORTE": "2026-11-11 12:16:51.000",
        "IMPORTE": "61.86",
        "DETALLE": [
            {"COD_DET": "1", "CONCEPTO_DET": "SERVICIO DE AGUA POTABLE", "IMPORTE_DET": "53.40"},
            {"COD_DET": "2", "CONCEPTO_DET": "SERV.ALCANT.SANITARIO", "IMPORTE_DET": "0.00"},
            {"COD_DET": "3", "CONCEPTO_DET": "CARGOS POR INSTALACION AGUA", "IMPORTE_DET": "3.96"},
            {"COD_DET": "27", "CONCEPTO_DET": "TASA DE REGULACION (AFCOOP)", "IMPORTE_DET": "0.50"},
            {"COD_DET": "18", "CONCEPTO_DET": "APORTE CLUB GUABIRA", "IMPORTE_DET": "2.00"},
            {"COD_DET": "191", "CONCEPTO_DET": "APORTE AUXILIO FUNERARIO", "IMPORTE_DET": "2.00"}
        ],
        "HISTORIAL": [
            {
                "NROFACTURA": "7516140",
                "CODIGO": "11543",
                "NOMBRE": "GUASASE ANDRADE IGNACIO FREDDY",
                "MES": "10",
                "ANIO": "2026",
                "MONTO": "61.86",
                "ESTADO": "0",
                "CONSUMO": "16",
                "FECHA": None,
                "NROAVISO": "4742124"
            }
        ]
    }

    pdf_bytes = generador_aviso_cobranza.generar(datos_aviso=payload_oficial)
    assert isinstance(pdf_bytes, bytes)
    assert len(pdf_bytes) > 20000
    assert pdf_bytes.startswith(b"%PDF")

