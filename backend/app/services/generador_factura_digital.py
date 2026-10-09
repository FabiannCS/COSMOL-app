"""
Generador de Facturas Fiscales Digitales Oficiales en formato PDF para COSMOL R.L.
Implementa el formato oficial boliviano del SIAT (Servicio de Impuestos Nacionales)
con Derecho a Crédito Fiscal, código QR 2D interoperable, desglose de servicios
y logotipos institucionales oficiales en alta resolución.
"""
import io
import re
import base64
from typing import Dict, Any, List, Optional
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from reportlab.lib import colors

import qrcode

# Logotipos oficiales en alta resolución (COSMOL Oficial y AAPS)
from app.services.logos_factura import LOGO_COSMOL_OFICIAL_B64, LOGO_AAPS_B64


class GeneradorFacturaDigitalPdf:
    """
    Motor vectorial ReportLab para generar la Factura Fiscal Digital Oficial de COSMOL R.L.
    Diseñada exactamente según la normativa SIAT y la representación gráfica oficial.
    """

    def __init__(self):
        # Página Carta (Letter): 612 x 792 pt (8.5 x 11 pulgadas)
        self.ancho_pt, self.alto_pt = letter
        self.margen_izq = 36.0
        self.margen_der = 576.0
        self.ancho_util = self.margen_der - self.margen_izq  # 540 pt

        # Decodificar logotipos institucionales
        try:
            self.logo_cosmol_bytes = base64.b64decode(LOGO_COSMOL_OFICIAL_B64)
        except Exception:
            self.logo_cosmol_bytes = None

        try:
            self.logo_aaps_bytes = base64.b64decode(LOGO_AAPS_B64)
        except Exception:
            self.logo_aaps_bytes = None

    def numero_a_letras(self, numero: float) -> str:
        """
        Convierte un importe numérico a texto legal boliviano,
        ej: 'Treinta y seis 30/100 Bolivianos' o 'Ochenta y dos 22/100 Bolivianos'.
        """
        unidades = ["", "un", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve"]
        especiales_10 = [
            "diez", "once", "doce", "trece", "catorce", "quince",
            "dieciséis", "diecisiete", "dieciocho", "diecinueve"
        ]
        veintis = [
            "", "veintiuno", "veintidós", "veintitrés", "veinticuatro",
            "veinticinco", "veintiséis", "veintisiete", "veintiocho", "veintinueve"
        ]
        decenas = [
            "", "diez", "veinte", "treinta", "cuarenta",
            "cincuenta", "sesenta", "setenta", "ochenta", "noventa"
        ]
        centenas = [
            "", "ciento", "doscientos", "trescientos", "cuatrocientos",
            "quinientos", "seiscientos", "setecientos", "ochocientos", "novecientos"
        ]

        entero = int(numero)
        centavos = int(round((numero - entero) * 100))
        if centavos < 0:
            centavos = 0

        def _convertir_grupo(n: int) -> str:
            if n == 0:
                return ""
            if n == 100:
                return "cien"
            res = []
            c = n // 100
            d = (n % 100) // 10
            u = n % 10

            if c > 0:
                res.append(centenas[c])

            if d == 1:
                res.append(especiales_10[u])
            elif d == 2:
                if u == 0:
                    res.append("veinte")
                else:
                    res.append(veintis[u])
            elif d > 2:
                if u == 0:
                    res.append(decenas[d])
                else:
                    res.append(f"{decenas[d]} y {unidades[u]}")
            elif d == 0 and u > 0:
                res.append(unidades[u])

            return " ".join(res)

        if entero == 0:
            texto = "cero"
        elif entero < 1000:
            texto = _convertir_grupo(entero)
        elif entero < 1000000:
            miles = entero // 1000
            resto = entero % 1000
            txt_miles = "mil" if miles == 1 else f"{_convertir_grupo(miles)} mil"
            txt_resto = _convertir_grupo(resto)
            texto = f"{txt_miles} {txt_resto}".strip()
        else:
            texto = str(entero)

        texto = texto.strip().capitalize()
        return f"{texto} {centavos:02d}/100 Bolivianos"

    def _generar_qr_bytes(self, url_siat: str) -> bytes:
        """Genera la imagen PNG del código QR 2D del SIAT."""
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_M,
            box_size=4,
            border=1,
        )
        qr.add_data(url_siat or "https://siat.impuestos.gob.bo")
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")

        buf = io.BytesIO()
        img.save(buf, format="PNG")
        buf.seek(0)
        return buf.getvalue()

    def generar_pdf(self, datos_factura: Dict[str, Any]) -> bytes:
        """
        Construye el PDF en memoria y retorna los bytes del archivo.
        datos_factura: Diccionario retornado por GET /api-consultas/facturas/{nro_factura}
        o estructura normalizada con metadatos de contingencia.
        """
        buffer = io.BytesIO()
        c = canvas.Canvas(buffer, pagesize=letter)
        c.setTitle(f"Factura_COSMOL_{datos_factura.get('NROFACTURAIMP', datos_factura.get('NROFACTURA', ''))}")

        # Normalización y extracción de campos
        empresa = str(datos_factura.get("EMPRESA") or "COSMOL RL").strip()
        casa_matriz = str(datos_factura.get("CASAMATRIZ") or "CASA MATRIZ").strip()
        punto_venta = str(datos_factura.get("PUNTODEVENTA") or "No. punto de venta 0").strip()
        ciudad = str(datos_factura.get("CIUDAD") or "MONTERO").strip()
        telf_empresa = str(datos_factura.get("TELFEMPRESA") or "TELEFONO 392-20212 - 61555507").strip()
        dir_empresa = str(datos_factura.get("DIREMPRESA") or "CALLE ISAIAS PARADA Nro. 219").strip()
        actividad_eco = str(datos_factura.get("ACTIVIDADECO") or "CAPTACIÓN Y DISTRIBUCIÓN DE AGUA").strip()

        nit_emisor = str(datos_factura.get("NITEMISOR") or "1028317027").strip()
        nro_factura_imp = str(
            datos_factura.get("NROFACTURAIMP")
            or datos_factura.get("nro_facip")
            or datos_factura.get("NROFACTURA")
            or datos_factura.get("nro_factura")
            or "0000000"
        ).strip()
        cod_autorizacion = str(
            datos_factura.get("CODAUTORIZACION") or datos_factura.get("cod_autorizacion") or ""
        ).strip()

        fecha_emision = str(datos_factura.get("FECHAEMISION") or datos_factura.get("fecha_emision") or "").strip()
        if len(fecha_emision) >= 10 and "-" in fecha_emision:
            try:
                parts = fecha_emision[:10].split("-")
                fecha_emision = f"{parts[2]}/{parts[1]}/{parts[0]} 00:00"
            except Exception:
                pass

        nit_ci = str(datos_factura.get("NITCI") or datos_factura.get("ci_nit") or "").strip()
        nombre_cliente = str(datos_factura.get("NOMBRE") or datos_factura.get("nombre_titular") or "").strip()
        cod_socio = str(datos_factura.get("CODSOCIO") or datos_factura.get("cod_socio") or "").strip()
        direccion_socio = str(datos_factura.get("DIRECCION") or datos_factura.get("direccion") or "").strip()
        cod_ubicacion = str(datos_factura.get("CODUBICACION") or datos_factura.get("ubicacion") or "").strip()
        consumo_m3 = str(datos_factura.get("CONSUMOM3") or "0").strip()

        periodo_mes = str(datos_factura.get("PERIODOMES") or datos_factura.get("mes") or "").strip()
        periodo_anio = str(datos_factura.get("PERIODOANIO") or datos_factura.get("anio") or "").strip()
        periodo_fmt = f"{periodo_mes}/{periodo_anio}" if periodo_mes and periodo_anio else str(datos_factura.get("periodo") or "")

        try:
            total_monto = float(datos_factura.get("TOTAL") or datos_factura.get("MONTOTOTAL") or datos_factura.get("monto_bs") or 0.0)
        except Exception:
            total_monto = 0.0

        try:
            descuento_monto = float(datos_factura.get("DESCUENTO") or 0.0)
        except Exception:
            descuento_monto = 0.0

        try:
            credito_fiscal = float(datos_factura.get("IMPORTECREDITOFISCAL") or total_monto)
        except Exception:
            credito_fiscal = total_monto

        # ----------------------------------------------------
        # 1. ENCABEZADO SUPERIOR
        # ----------------------------------------------------
        y_top = 752.0

        # Lado Izquierdo: Nuevo Logo Oficial Panorámico COSMOL
        if self.logo_cosmol_bytes:
            img_cosmol = ImageReader(io.BytesIO(self.logo_cosmol_bytes))
            c.drawImage(
                img_cosmol,
                self.margen_izq,
                y_top - 46,
                width=152,
                height=46,
                mask="auto"
            )

        # Textos debajo del logo
        c.setFillColor(colors.black)
        y_izq = y_top - 58
        c.setFont("Helvetica-Bold", 8.5)
        c.drawCentredString(self.margen_izq + 76, y_izq, empresa)
        y_izq -= 10
        c.setFont("Helvetica-Bold", 7.5)
        c.drawCentredString(self.margen_izq + 76, y_izq, casa_matriz)
        y_izq -= 10
        c.setFont("Helvetica", 7.5)
        c.drawCentredString(self.margen_izq + 76, y_izq, punto_venta)
        y_izq -= 10
        c.setFont("Helvetica-Bold", 7.5)
        c.drawCentredString(self.margen_izq + 76, y_izq, ciudad)
        y_izq -= 10
        c.setFont("Helvetica", 7.0)
        c.drawCentredString(self.margen_izq + 76, y_izq, telf_empresa)
        y_izq -= 10
        c.setFont("Helvetica", 7.0)
        c.drawCentredString(self.margen_izq + 76, y_izq, dir_empresa)

        # Lado Derecho: Bloque Tributario SIAT
        x_der_label = 320.0
        y_der = y_top - 8

        c.setFont("Helvetica-Bold", 8.5)
        c.drawString(x_der_label, y_der, f"NIT: {nit_emisor}")
        y_der -= 12
        c.drawString(x_der_label, y_der, f"Nro. FACTURA: {nro_factura_imp}")
        y_der -= 12
        c.drawString(x_der_label, y_der, "CÓD. AUTORIZACIÓN:")
        y_der -= 10

        # CUF en dos renglones con fuente monoespaciada
        c.setFont("Courier", 7.0)
        if len(cod_autorizacion) > 36:
            c.drawString(x_der_label, y_der, cod_autorizacion[:36])
            y_der -= 9
            c.drawString(x_der_label, y_der, cod_autorizacion[36:72])
        else:
            c.drawString(x_der_label, y_der, cod_autorizacion)

        y_der -= 16
        c.setFont("Helvetica-Bold", 7.5)
        c.drawRightString(self.margen_der, y_der, actividad_eco)

        # ----------------------------------------------------
        # 2. TÍTULO DEL DOCUMENTO
        # ----------------------------------------------------
        y_titulo = 645.0
        c.setFont("Helvetica-Bold", 12.0)
        c.drawCentredString(self.ancho_pt / 2.0, y_titulo, "FACTURA")
        c.setFont("Helvetica", 8.5)
        c.drawCentredString(self.ancho_pt / 2.0, y_titulo - 12, "(Con Derecho a Crédito Fiscal)")

        # ----------------------------------------------------
        # 3. METADATOS DEL SOCIO Y DEL PERIODO
        # ----------------------------------------------------
        y_cli = 612.0
        col1_x = self.margen_izq
        col2_x = 360.0

        def _linea_cliente(y, l1, v1, l2, v2):
            c.setFont("Helvetica-Bold", 7.5)
            c.drawString(col1_x, y, f"{l1}:")
            c.setFont("Helvetica", 7.5)
            c.drawString(col1_x + 65, y, str(v1))

            c.setFont("Helvetica-Bold", 7.5)
            c.drawString(col2_x, y, f"{l2}:")
            c.setFont("Helvetica", 7.5)
            c.drawString(col2_x + 95, y, str(v2))

        _linea_cliente(y_cli, "Fecha", fecha_emision, "NIT/CI/CEX", nit_ci)
        y_cli -= 11
        _linea_cliente(y_cli, "Nombre/Razón Social", nombre_cliente[:40], "Cod. Cliente", cod_socio)
        y_cli -= 11
        _linea_cliente(y_cli, "Dirección", direccion_socio[:40], "C. Ubicación", cod_ubicacion)
        y_cli -= 11
        _linea_cliente(y_cli, "Consumo", f"{consumo_m3} m3", "Periodo a Facturar", periodo_fmt)

        # ----------------------------------------------------
        # 4. TABLA DE DETALLE DE SERVICIOS
        # ----------------------------------------------------
        y_tbl = y_cli - 16

        # Línea superior de encabezado
        c.setLineWidth(0.8)
        c.setStrokeColor(colors.black)
        c.line(self.margen_izq, y_tbl, self.margen_der, y_tbl)
        y_tbl -= 10

        # Anchos y posiciones de columnas (Total = 540 pt)
        w_cod = 55.0
        w_cant = 45.0
        w_uni = 55.0
        w_desc = 205.0
        w_pu = 60.0
        w_des = 55.0
        w_sub = 65.0

        x_cod = self.margen_izq + w_cod / 2.0
        x_cant = self.margen_izq + w_cod + w_cant / 2.0
        x_uni = self.margen_izq + w_cod + w_cant + w_uni / 2.0
        x_desc = self.margen_izq + w_cod + w_cant + w_uni
        x_pu = self.margen_izq + w_cod + w_cant + w_uni + w_desc + w_pu
        x_des = x_pu + w_des
        x_sub = self.margen_der

        c.setFont("Helvetica-Bold", 6.5)
        c.drawCentredString(x_cod, y_tbl, "CODIGO")
        c.drawCentredString(x_cant, y_tbl, "CANTIDAD")
        c.drawCentredString(x_uni, y_tbl, "UNIDAD")
        c.drawString(x_desc, y_tbl, "DESCRIPCIÓN")
        c.drawRightString(x_pu, y_tbl, "PRECIO")
        c.drawRightString(x_des, y_tbl, "DESCUENTO")
        c.drawRightString(x_sub, y_tbl, "SUBTOTAL")

        y_tbl -= 8
        c.drawCentredString(x_cod, y_tbl, "PRODUCTO/SERVICIO")
        c.drawCentredString(x_uni, y_tbl, "MEDIDA")
        c.drawRightString(x_pu, y_tbl, "UNITARIO")

        y_tbl -= 5
        c.line(self.margen_izq, y_tbl, self.margen_der, y_tbl)
        y_tbl -= 11

        # Filas de ítems
        detalle = datos_factura.get("detalle") or []
        if not detalle:
            detalle = [{
                "CODIGOSERVICIO": "1",
                "CANTIDAD": "1",
                "UNIDADMEDIDA": "SERVICIO",
                "CONCEPTO": "SERVICIO DE AGUA POTABLE Y ALCANTARILLADO",
                "PRECIOUNITARIO": f"{total_monto:.2f}",
                "DESCUENTO": f"{descuento_monto:.2f}",
                "SUBTOTAL": f"{total_monto:.2f}"
            }]

        c.setFont("Helvetica", 7.0)
        for item in detalle:
            cod_srv = str(item.get("CODIGOSERVICIO") or item.get("CODIGO") or "1").strip()
            cant_srv = str(item.get("CANTIDAD") or "1").strip()
            uni_srv = str(item.get("UNIDADMEDIDA") or "SERVICIO").strip()
            con_srv = str(item.get("CONCEPTO") or item.get("DESCRIPCION") or "").strip()

            try:
                pu_val = float(item.get("PRECIOUNITARIO") or 0.0)
            except Exception:
                pu_val = 0.0

            try:
                des_val = float(item.get("DESCUENTO") or 0.0)
            except Exception:
                des_val = 0.0

            try:
                sub_val = float(item.get("SUBTOTAL") or pu_val)
            except Exception:
                sub_val = pu_val

            c.drawCentredString(x_cod, y_tbl, cod_srv)
            c.drawCentredString(x_cant, y_tbl, cant_srv)
            c.drawCentredString(x_uni, y_tbl, uni_srv)
            c.drawString(x_desc, y_tbl, con_srv[:42])
            c.drawRightString(x_pu, y_tbl, f"{pu_val:,.2f}")
            c.drawRightString(x_des, y_tbl, f"{des_val:,.2f}")
            c.drawRightString(x_sub, y_tbl, f"{sub_val:,.2f}")
            y_tbl -= 12

        # Línea de cierre de tabla
        y_tbl += 2
        c.line(self.margen_izq, y_tbl, self.margen_der, y_tbl)

        # ----------------------------------------------------
        # 5. CAJA DE TOTALES (Alineada a la derecha)
        # ----------------------------------------------------
        y_tot = y_tbl - 12
        x_tot_lbl = 450.0
        x_tot_val = self.margen_der

        def _linea_total(y, label, val):
            c.setFont("Helvetica-Bold", 7.5)
            c.drawRightString(x_tot_lbl, y, label)
            c.setFont("Helvetica", 7.5)
            c.drawRightString(x_tot_val, y, f"{val:,.2f}")

        _linea_total(y_tot, "SUBTOTAL Bs.:", total_monto + descuento_monto)
        y_tot -= 10
        _linea_total(y_tot, "DESCUENTO Bs.:", descuento_monto)
        y_tot -= 10
        _linea_total(y_tot, "TOTAL Bs.:", total_monto)
        y_tot -= 10
        _linea_total(y_tot, "MONTO GIFT CARD Bs.:", 0.0)
        y_tot -= 10
        _linea_total(y_tot, "MONTO A PAGAR Bs.:", total_monto)
        y_tot -= 4

        # Línea divisoria de crédito fiscal
        c.setLineWidth(0.6)
        c.line(320.0, y_tot, self.margen_der, y_tot)
        y_tot -= 10

        c.setFont("Helvetica-Bold", 7.5)
        c.drawRightString(x_tot_lbl, y_tot, "IMPORTE BASE CRÉDITO FISCAL Bs.:")
        c.setFont("Helvetica-Bold", 7.5)
        c.drawRightString(x_tot_val, y_tot, f"{credito_fiscal:,.2f}")

        # ----------------------------------------------------
        # 6. MONTO EN LETRAS (SON:)
        # ----------------------------------------------------
        y_son = y_tot - 14
        c.setFont("Helvetica-Bold", 8.0)
        literal = self.numero_a_letras(total_monto)
        c.drawString(self.margen_izq, y_son, f"SON: {literal}")

        # ----------------------------------------------------
        # 7. ESTADO DE PAGO O FECHA DE PAGO
        # ----------------------------------------------------
        y_pago = y_son - 26
        fecha_pago = datos_factura.get("FECHAPAGO")
        hora_pago = datos_factura.get("HORAPAGO") or ""
        caja_pago = datos_factura.get("CAJAPAGO") or ""

        if fecha_pago:
            texto_pago = f"FECHA DE PAGO: {fecha_pago} {hora_pago}  |  CAJA: {caja_pago}".strip()
            c.setFont("Courier-Bold", 7.5)
            c.drawString(self.margen_izq, y_pago, texto_pago)
        else:
            c.setFont("Courier-Bold", 7.5)
            c.drawString(self.margen_izq, y_pago, "ESTADO: PENDIENTE DE PAGO")

        # ----------------------------------------------------
        # 8. LEYENDAS FISCALES Y CÓDIGO QR OFICIAL SIAT
        # ----------------------------------------------------
        y_siat = y_pago - 18
        qr_url = str(datos_factura.get("CODIGOQR") or "").strip()
        if not qr_url:
            qr_url = f"https://siat.impuestos.gob.bo/consulta/QR?nit={nit_emisor}&cuf={cod_autorizacion}&numero={nro_factura_imp}&t=2"

        # Generar imagen QR
        try:
            qr_bytes = self._generar_qr_bytes(qr_url)
            img_qr = ImageReader(io.BytesIO(qr_bytes))
            c.drawImage(img_qr, self.margen_der - 82, y_siat - 70, width=80, height=80, mask="auto")
        except Exception:
            pass

        # Textos de Leyendas normativas a la izquierda
        des_leyenda = str(datos_factura.get("DESLEYENDA") or "Ley N° 453: El proveedor deberá suministrar el servicio en las modalidades y términos ofertados o convenidos.").strip()
        leyenda_1 = str(datos_factura.get("LEYENDA1") or "ESTA FACTURA CONTRIBUYE AL DESARROLLO DEL PAIS. EL USO ILÍCITO DE ESTA SERÁ SANCIONADO DE ACUERDO A LEY.").strip()
        leyenda_3 = str(datos_factura.get("LEYENDA3") or 'Este documento es la Representación Gráfica de un Documento Fiscal Digital emitido en una modalidad de facturación en línea').strip()

        c.setFont("Helvetica-Bold", 6.5)
        c.drawString(self.margen_izq, y_siat - 10, des_leyenda[:95])
        if len(des_leyenda) > 95:
            c.drawString(self.margen_izq, y_siat - 18, des_leyenda[95:])
            y_siat -= 8

        c.setFont("Helvetica-Bold", 6.5)
        c.drawString(self.margen_izq, y_siat - 24, leyenda_1)

        c.setFont("Helvetica", 6.5)
        c.drawString(self.margen_izq, y_siat - 36, f'"{leyenda_3}"')

        # ----------------------------------------------------
        # 9. PIE DE PÁGINA INSTITUCIONAL Y REGULATORIO
        # ----------------------------------------------------
        y_pie = 42.0

        # Logo AAPS
        if self.logo_aaps_bytes:
            img_aaps = ImageReader(io.BytesIO(self.logo_aaps_bytes))
            c.drawImage(img_aaps, self.margen_izq, y_pie - 4, width=48, height=30, mask="auto")

        c.setFont("Helvetica", 5.5)
        c.drawString(self.margen_izq + 54, y_pie + 14, "Esta entidad se encuentra regulada y fiscalizada")
        c.drawString(self.margen_izq + 54, y_pie + 7, "por la Autoridad de Fiscalización y Control Social")
        c.drawString(self.margen_izq + 54, y_pie, "de Agua Potable y Saneamiento Básico.")

        # Línea Habilitada 24 Horas
        c.setFont("Helvetica-Bold", 7.5)
        c.drawRightString(self.margen_der, y_pie + 12, "LINEA HABILITADA LAS 24 HORAS")
        c.setFont("Helvetica-Bold", 10.0)
        c.drawRightString(self.margen_der, y_pie - 1, "178 • 61555507")

        c.showPage()
        c.save()
        buffer.seek(0)
        return buffer.getvalue()


# Instancia singleton para uso en toda la aplicación
generador_factura_digital = GeneradorFacturaDigitalPdf()
