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
