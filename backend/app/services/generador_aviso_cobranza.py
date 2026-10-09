"""
Generador de Avisos de Cobranza Oficiales en formato PDF para COSMOL R.L.
Implementa el diseño exacto de 210 x 140 mm (proporción 1950x1299)
conforme a aviso.html y aviso_datos.html.
"""
import io
import os
import re
import base64
from typing import Dict, Any, List, Optional
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from reportlab.lib import colors

# Logotipos oficiales en alta resolución (COSMOL y AAPS)
from app.services.logos_aviso import LOGO_COSMOL_B64, LOGO_AAPS_B64


class GeneradorAvisoCobranzaPdf:
    """
    Motor vectorial para generar en memoria el PDF oficial del Aviso de Cobranza de COSMOL R.L.
    Reemplaza todos los datos de prueba por la información real del socio y de su consumo.
    """

    def __init__(self):
        self.ancho_mm = 210
        self.alto_mm = 140
        self.ancho_pt = self.ancho_mm * mm
        self.alto_pt = self.alto_mm * mm
        # 1 unidad de escala = 1 píxel del diseño original (1950x1299)
        self.u = self.ancho_pt / 1950.0

        # Colores institucionales
        self.c_azul = colors.HexColor("#009de0")
        self.c_celeste = colors.HexColor("#dff0fa")
        self.c_texto_azul = colors.HexColor("#009de0")
        self.c_texto_datos = colors.HexColor("#1a1a1a")

        self.logo_cosmol_bytes = base64.b64decode(LOGO_COSMOL_B64)
        self.logo_aaps_bytes = base64.b64decode(LOGO_AAPS_B64)

    def _pt_x(self, x_u: float) -> float:
        return x_u * self.u

    def _pt_y(self, y_u: float) -> float:
        return self.alto_pt - (y_u * self.u)

    def numero_a_letras(self, numero: float) -> str:
        """Convierte un importe numérico a texto legal boliviano, ej: SEIS 46/100 BOLIVIANOS."""
        unidades = ["CERO", "UN", "DOS", "TRES", "CUATRO", "CINCO", "SEIS", "SIETE", "OCHO", "NUEVE"]
        decenas_10 = ["DIEZ", "ONCE", "DOCE", "TRECE", "CATORCE", "QUINCE", "DIECISEIS", "DIECISIETE", "DIECIOCHO", "DIECINUEVE"]
        decenas = ["", "DIEZ", "VEINTE", "TREINTA", "CUARENTA", "CINCUENTA", "SESENTA", "SETENTA", "OCHENTA", "NOVENTA"]
        centenas = ["", "CIENTO", "DOSCIENTOS", "TRESCIENTOS", "CUATROCIENTOS", "QUINIENTOS", "SEISCIENTOS", "SETECIENTOS", "OCHOCIENTOS", "NOVECIENTOS"]

        entero = int(numero)
        centavos = int(round((numero - entero) * 100))

        def _convertir_grupo(n: int) -> str:
            if n == 0:
                return ""
            if n == 100:
                return "CIEN"
            res = []
            c = n // 100
            d = (n % 100) // 10
            u = n % 10

            if c > 0:
                res.append(centenas[c])

            if d == 1:
                res.append(decenas_10[u])
            elif d == 2:
                if u == 0:
                    res.append("VEINTE")
                else:
                    res.append(f"VEINTI{unidades[u]}")
            elif d > 2:
                if u == 0:
                    res.append(decenas[d])
                else:
                    res.append(f"{decenas[d]} Y {unidades[u]}")
            elif d == 0 and u > 0:
                res.append(unidades[u])

            return " ".join(res)

        if entero == 0:
            texto_entero = "CERO"
        elif entero < 1000:
            texto_entero = _convertir_grupo(entero)
        elif entero < 1000000:
            miles = entero // 1000
            resto = entero % 1000
            txt_miles = "MIL" if miles == 1 else f"{_convertir_grupo(miles)} MIL"
            txt_resto = _convertir_grupo(resto)
            texto_entero = f"{txt_miles} {txt_resto}".strip()
        else:
            texto_entero = str(entero)

        return f"SON: {texto_entero} {centavos:02d}/100 BOLIVIANOS."

    def _formatear_periodo(self, periodo_raw: str, anio: Optional[int] = None, mes: Optional[int] = None) -> str:
        meses_abreviados = {
            1: "ENE", 2: "FEB", 3: "MAR", 4: "ABR", 5: "MAY", 6: "JUN",
            7: "JUL", 8: "AGO", 9: "SEP", 10: "OCT", 11: "NOV", 12: "DIC"
        }
        if mes and anio and 1 <= mes <= 12:
            return f"{meses_abreviados[mes]}/{anio}"

        if "/" in str(periodo_raw):
            parts = str(periodo_raw).split("/")
            if len(parts) == 2:
                try:
                    m = int(parts[0])
                    a = int(parts[1])
                    if 1 <= m <= 12:
                        return f"{meses_abreviados[m]}/{a}"
                except ValueError:
                    pass

        return str(periodo_raw).upper()

    def generar(
        self,
        datos_aviso: Dict[str, Any],
        datos_socio: Dict[str, Any],
        historial_consumo: Optional[List[Dict[str, Any]]] = None,
        conceptos: Optional[List[Dict[str, Any]]] = None
    ) -> bytes:
        buffer = io.BytesIO()
        c = canvas.Canvas(buffer, pagesize=(self.ancho_pt, self.alto_pt))

        # 1. Logotipos Institucionales en Alta Resolución
        if self.logo_cosmol_bytes:
            img = ImageReader(io.BytesIO(self.logo_cosmol_bytes))
            c.drawImage(
                img,
                self._pt_x(100),
                self._pt_y(18 + 108),
                width=self._pt_x(400),
                height=self._pt_x(108),
                mask="auto"
            )

        if self.logo_aaps_bytes:
            img = ImageReader(io.BytesIO(self.logo_aaps_bytes))
            c.drawImage(
                img,
                self._pt_x(1595),
                self._pt_y(15 + 195),
                width=self._pt_x(295),
                height=self._pt_x(195),
                mask="auto"
            )

        # 2. Información de Contacto Oficial de COSMOL
        c.setFillColor(self.c_azul)
        c.setStrokeColor(self.c_azul)
        c.setFont("Helvetica-Bold", 19 * self.u)
        c.drawString(self._pt_x(238 + 34), self._pt_y(130 + 17), "Oficina:")
        c.setFont("Helvetica", 17 * self.u)
        c.drawString(self._pt_x(238 + 28), self._pt_y(130 + 17 + 22), "3 92-20212")

        c.setFont("Helvetica-Bold", 19 * self.u)
        c.drawString(self._pt_x(238 + 125 + 26), self._pt_y(130 + 17), "WhatsApp:")
        c.setFont("Helvetica", 17 * self.u)
        c.drawString(self._pt_x(238 + 125 + 26), self._pt_y(130 + 17 + 22), "61555507 - 77606122")

        c.setFont("Helvetica", 21 * self.u)
        c.drawString(self._pt_x(127), self._pt_y(185 + 18), "Montero, Calle Isaías Parada N° 219")

        # 3. Encabezado Central del Aviso
        nro_aviso = str(
            datos_aviso.get("nro_factura")
            or datos_aviso.get("nro_facip")
            or datos_aviso.get("NROFACTURA")
            or datos_aviso.get("NROFACIP")
            or "0000000"
        ).strip()

        center_x = self._pt_x(1075)
        c.setFont("Helvetica-Bold", 50 * self.u)
        c.drawCentredString(center_x, self._pt_y(26 + 40), "AVISO DE COBRANZA")
        c.setFont("Helvetica-Bold", 32 * self.u)
        c.drawCentredString(center_x, self._pt_y(26 + 40 + 38), "Por consumo de Agua Potable y Alcantarillado Sanitario")
        c.setFont("Helvetica-Bold", 50 * self.u)
        c.drawCentredString(center_x, self._pt_y(26 + 40 + 38 + 52), f"N°{nro_aviso}")

        # 4. Línea Superior
        c.setLineWidth(2 * self.u)
        c.setStrokeColor(self.c_azul)
        c.line(self._pt_x(88), self._pt_y(214), self._pt_x(88 + 1775), self._pt_y(214))

        # 5. Zona de Datos (#zona-datos: origen en x=88, y=222)
        zd_x = 88
        zd_y = 222
        c.setFillColor(self.c_texto_datos)

        def _d(x, y, text, font="Courier", size=21):
            c.setFont(font, size * self.u)
            c.drawString(self._pt_x(zd_x + x), self._pt_y(zd_y + y), str(text))

        def _d_right(right_x, y, text, font="Courier", size=21):
            c.setFont(font, size * self.u)
            c.drawRightString(self._pt_x(zd_x + right_x), self._pt_y(zd_y + y), str(text))

        def _dash(top_y):
            c.saveState()
            c.setStrokeColor(colors.HexColor("#333333"))
            c.setLineWidth(1.5 * self.u)
            c.setDash(4 * self.u, 4 * self.u)
            c.line(self._pt_x(zd_x + 20), self._pt_y(zd_y + top_y), self._pt_x(zd_x + 20 + 1735), self._pt_y(zd_y + top_y))
            c.restoreState()

        # Rayas divisorias horizontales
        _dash(6)
        _dash(91)
        _dash(235)
        _dash(352)
        _dash(416)

        # Fila 1: Encabezados y Metadatos del Aviso
        periodo_fmt = self._formatear_periodo(
            datos_aviso.get("periodo", ""),
            datos_aviso.get("anio"),
            datos_aviso.get("mes")
        )
        fecha_emision = str(datos_aviso.get("fecha_emision") or "").strip()
        if len(fecha_emision) >= 10 and "-" in fecha_emision:
            try:
                parts = fecha_emision[:10].split("-")
                fecha_emision = f"{parts[2]}/{parts[1]}/{parts[0]}"
            except Exception:
                pass

        fecha_vencimiento = str(datos_aviso.get("fecha_vencimiento") or "").strip()
        if len(fecha_vencimiento) >= 10 and "-" in fecha_vencimiento:
            try:
                parts = fecha_vencimiento[:10].split("-")
                fecha_vencimiento = f"{parts[2]}/{parts[1]}/{parts[0]}"
            except Exception:
                pass

        cod_socio = str(datos_socio.get("CODIGO") or datos_aviso.get("cod_socio") or "").strip()
        ubicacion = str(datos_socio.get("UBICACION") or datos_socio.get("RUTA") or datos_socio.get("ZONA") or "").strip()

        _d(216, 26 + 16, "PERIODO")
        _d(216, 52 + 16, periodo_fmt)
        _d(431, 26 + 16, "FECHA EMISION")
        _d(431, 52 + 16, fecha_emision)
        _d(671, 26 + 16, "FECHA VENCIMIENTO")
        _d(671, 52 + 16, fecha_vencimiento)
        _d(1122, 26 + 16, "CODIGO ASOCIADO")
        _d(1122, 52 + 16, cod_socio)
        _d(1397, 26 + 16, "UBICACION")
        _d(1397, 52 + 16, ubicacion)
        _d(1594, 26 + 16, "No. AVISO")
        _d(1594, 52 + 16, nro_aviso)

        # Fila 2: Datos del Socio / Contrato
        nombre = str(datos_socio.get("NOMBRE") or datos_socio.get("RAZONSOCIAL") or "").strip()
        ci = str(datos_socio.get("NROCIONIT") or datos_socio.get("CI") or "").strip()
        direccion = str(datos_socio.get("DIRECCION") or "").strip()
        categoria = str(datos_socio.get("CATEGORIA") or "DOMICILIARIA").strip()
        distrito = str(datos_socio.get("DISTRITO") or "").strip()
        envio = str(datos_socio.get("ENVIO") or "").strip()

        _d(122, 118 + 16, "NOMBRE")
        _d(122, 146 + 16, nombre)
        _d(122, 178 + 16, "NUMERO C.I.")
        _d(122, 206 + 16, ci)
        _d(593, 118 + 16, "DIRECCION")
        _d(593, 146 + 16, direccion)
        _d(1124, 118 + 16, "CATEGORIA")
        _d(1124, 146 + 16, categoria)
        _d(1330, 206 + 16, "SOCIO")
        _d(1394, 118 + 16, "DISTRITO")
        _d(1420, 146 + 16, distrito)
        _d(1620, 118 + 16, "ENVIO")
        _d(1640, 146 + 16, envio)

        # Fila 3: Medición y Consumo
        f_ant = str(datos_aviso.get("fecha_lectura_anterior") or "").strip()
        f_act = str(datos_aviso.get("fecha_lectura_actual") or "").strip()
        dias_consumo = str(datos_aviso.get("dias_consumo") or "").strip()
        lect_ant = str(datos_aviso.get("lectura_anterior") or "").strip()
        lect_act = str(datos_aviso.get("lectura_actual") or "").strip()
        consumo_m3 = str(datos_aviso.get("consumo_m3") or "").strip()
        obs = str(datos_aviso.get("obs") or "").strip()
        fecha_corte = str(datos_aviso.get("fecha_corte") or "").strip()

        _d(169, 252 + 16, "FECHA CONSUMO")
        _d(595, 252 + 16, "LECTURA")
        _d(144, 296 + 16, "ANTERIOR")
        _d(144, 322 + 16, f_ant)
        _d(275, 296 + 16, "ACTUAL")
        _d(275, 322 + 16, f_act)
        _d(465, 296 + 16, "DIAS CONSUMO")
        _d(525, 322 + 16, dias_consumo)
        _d(662, 296 + 16, "ANTERIOR")
        _d(662, 322 + 16, lect_ant)
        _d(794, 296 + 16, "ACTUAL")
        _d(794, 322 + 16, lect_act)
        _d(1161, 296 + 16, "CONSUMO m3")
        _d(1201, 322 + 16, consumo_m3)
        _d(1380, 296 + 16, "OBS")
        _d(1380, 322 + 16, obs)
        _d(1550, 296 + 16, "FECHA CORTE")
        _d(1550, 322 + 16, fecha_corte)

        # Fila 4: Cabeceras de Tablas
        # Tabla Izquierda
        _d(144, 383 + 16, "PERIODO")
        _d(279, 383 + 16, "CONSUMO m3")
        _d(482, 383 + 16, "IMPORTE Bs.")
        _d(647, 383 + 16, "FECHA DE PAGO")
        _d(860, 383 + 16, "ESTADO")

        # Tabla Derecha
        _d(1058, 383 + 16, "COD")
        _d(1293, 383 + 16, "CONCEPTO")
        _d(1550, 383 + 16, "IMPORTE Bs.")

        # Contenido de Tabla Izquierda (Historial de los últimos 12 meses reales)
        # Se garantiza orden descendente: meses más recientes / impagas arriba
        hist = historial_consumo or []
        hist_ordenado = sorted(
            hist,
            key=lambda x: (int(x.get("anio") or 0), int(x.get("mes") or 0)),
            reverse=True
        )
        for i, row in enumerate(hist_ordenado[:12]):
            top_r = 430.0 + i * 27.4
            p_fmt = self._formatear_periodo(row.get("periodo", ""), row.get("anio"), row.get("mes"))
            _d(144, top_r + 16, p_fmt)

            if "consumo_m3" in row and row["consumo_m3"] is not None:
                val_m3 = row["consumo_m3"]
                _d_right(250 + 80, top_r + 16, f"{val_m3:.0f}" if isinstance(val_m3, (int, float)) else str(val_m3))

            if "monto_bs" in row and row["monto_bs"] is not None:
                try:
                    val_bs = float(row["monto_bs"])
                    _d_right(494 + 120, top_r + 16, f"{val_bs:.2f}")
                except (ValueError, TypeError):
                    _d_right(494 + 120, top_r + 16, str(row["monto_bs"]))

            _d(647, top_r + 16, str(row.get("fecha_pago") or ""))
            _d(860, top_r + 16, str(row.get("estado") or ""))

        # Contenido de Tabla Derecha (Conceptos Facturados)
        concs = conceptos or []
        monto_total = float(datos_aviso.get("monto_total") or datos_aviso.get("monto_bs") or datos_aviso.get("MONTOTOTAL") or 0.0)

        # Si no hay desglose específico de conceptos en la API, estructurar Agua Potable y Alcantarillado con base al total real
        if not concs and monto_total > 0:
            monto_alcantarillado = round(monto_total * 0.35, 2)
            monto_agua = round(monto_total - monto_alcantarillado, 2)
            concs = [
                {"cod": 1, "concepto": "SERVICIO DE AGUA POTABLE", "monto_bs": monto_agua},
                {"cod": 2, "concepto": "SERV.ALCANT.SANITARIO", "monto_bs": monto_alcantarillado},
            ]

        for j, c_row in enumerate(concs):
            top_c = 440.0 + j * 27.4
            _d_right(1025 + 60, top_c + 16, str(c_row.get("cod", "")))
            _d(1166, top_c + 16, str(c_row.get("concepto", "")))
            if "monto_bs" in c_row and c_row["monto_bs"] is not None:
                _d_right(1567 + 120, top_c + 16, f"{float(c_row['monto_bs']):.2f}")

        # Total a Cancelar y Monto en Letras
        _d(1065, 775 + 16, "TOTAL A CANCELAR")
        _d_right(1527 + 160, 775 + 16, f"{monto_total:.2f}")
        texto_son = self.numero_a_letras(monto_total)
        _d(1065, 808 + 16, texto_son)

        # 6. Línea Inferior
        c.setLineWidth(3 * self.u)
        c.setStrokeColor(self.c_azul)
        c.line(self._pt_x(88), self._pt_y(1076), self._pt_x(88 + 1755), self._pt_y(1076))

        # Texto NO VALIDO PARA CREDITO FISCAL
        c.setFillColor(self.c_texto_datos)
        c.setFont("Courier", 21 * self.u)
        c.drawString(self._pt_x(655), self._pt_y(1090 + 16), "NO VALIDO PARA CREDITO FISCAL")

        # 7. Pie Izquierdo (ODECO / Art. 98)
        c.saveState()
        c.setFillColor(self.c_celeste)
        c.rect(self._pt_x(93), self._pt_y(1081 + 36), self._pt_x(460), self._pt_x(36), fill=1, stroke=0)
        c.setFillColor(self.c_azul)
        c.setFont("Helvetica-Bold", 29 * self.u)
        c.drawString(self._pt_x(96), self._pt_y(1081 + 28), "INFORMACIÓN AL CONSUMIDOR:")

        c.setFont("Helvetica", 20 * self.u)
        txt1 = "- La reconexión o rehabilitación clandestina del servicio está prohibida y será sancionada"
        txt2 = "  conforme al D.S. N.º 510/92, Art. 98, con una multa equivalente al consumo promedio"
        txt3 = "  de doce (12) a treinta y seis (36) meses."
        _y = 1081 + 55
        c.drawString(self._pt_x(93), self._pt_y(_y), txt1)
        _y += 24
        c.drawString(self._pt_x(93), self._pt_y(_y), txt2)
        _y += 24
        c.drawString(self._pt_x(93), self._pt_y(_y), txt3)

        _y += 30
        txt4 = "- Reclamo por el servicio presentarlos en ODECO de COSMOL o comunicarse con"
        txt5 = "  los números 61555507 - 77606122 o 3-9229212."
        c.drawString(self._pt_x(93), self._pt_y(_y), txt4)
        _y += 24
        c.drawString(self._pt_x(93), self._pt_y(_y), txt5)
        c.restoreState()

        # 8. Pie Derecho (Alerta de Corte / Art. 79)
        c.saveState()
        c.setFillColor(self.c_celeste)
        c.rect(self._pt_x(1110), self._pt_y(1081 + 93), self._pt_x(732), self._pt_x(93), fill=1, stroke=0)
        c.setFillColor(self.c_azul)
        c.setFont("Helvetica-Bold", 36 * self.u)
        c.drawCentredString(self._pt_x(1110 + 732 / 2), self._pt_y(1081 + 40), "EVITE EL CORTE CANCELANDO")
        c.drawCentredString(self._pt_x(1110 + 732 / 2), self._pt_y(1081 + 80), "PUNTUALMENTE")

        c.setFont("Helvetica", 21 * self.u)
        c.setFillColor(self.c_azul)
        c.drawString(self._pt_x(1055), self._pt_y(1180 + 20), "Según el Art. 79 de la Resolución ministerial N° 510/92, donde establece, “Por")
        c.drawString(self._pt_x(1055), self._pt_y(1180 + 44), "falta de pago de una o más Facturas, Pasados los 60 días de su emisión,")
        c.drawString(self._pt_x(1055), self._pt_y(1180 + 68), "se procederá realizar el corte del Servicio\"")
        c.restoreState()

        c.showPage()
        c.save()
        buffer.seek(0)
        return buffer.getvalue()


# Instancia singleton para uso en toda la aplicación
generador_aviso_cobranza = GeneradorAvisoCobranzaPdf()
