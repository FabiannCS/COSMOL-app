"""
Motor de generación de documentos PDF institucionales para COSMOL R.L. (DEV 1).
Utiliza ReportLab para construir Facturas Oficiales con valor legal, Avisos de Cobranza
y Avisos de Corte formales, listos para descarga y visualización en Flutter.
"""
from datetime import date, datetime
import io
import logging
from typing import Any, Dict, List, Optional

from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import HRFlowable, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

logger = logging.getLogger(__name__)

# Paleta corporativa de COSMOL R.L.
COLOR_PRIMARIO = colors.HexColor("#0D47A1")   # Azul marino institucional
COLOR_SECUNDARIO = colors.HexColor("#0288D1") # Cyan / Agua
COLOR_ALERTA = colors.HexColor("#D32F2F")     # Rojo alerta para avisos de corte
COLOR_TEXTO = colors.HexColor("#212121")      # Gris oscuro para lectura
COLOR_GRIS_CLARO = colors.HexColor("#F5F5F5") # Fondo de tablas


class GeneradorPdfDocumento:
    """
    Genera documentos PDF en memoria (BytesIO) cumpliendo estándares institucionales y fiscales.
    """

    def __init__(self):
        self.styles = getSampleStyleSheet()
        self._configurar_estilos()

    def _configurar_estilos(self):
        """Crea estilos tipográficos personalizados para ReportLab."""
        self.estilo_titulo = ParagraphStyle(
            name="CosmolTitulo",
            parent=self.styles["Heading1"],
            fontSize=16,
            leading=20,
            textColor=COLOR_PRIMARIO,
            alignment=1, # Centrado
            spaceAfter=4,
        )
        self.estilo_subtitulo = ParagraphStyle(
            name="CosmolSubtitulo",
            parent=self.styles["Heading2"],
            fontSize=11,
            leading=14,
            textColor=COLOR_SECUNDARIO,
            alignment=1,
            spaceAfter=10,
        )
        self.estilo_alerta = ParagraphStyle(
            name="CosmolAlerta",
            parent=self.styles["Heading2"],
            fontSize=13,
            leading=16,
            textColor=COLOR_ALERTA,
            alignment=1,
            spaceAfter=10,
        )
        self.estilo_celda = ParagraphStyle(
            name="CosmolCelda",
            parent=self.styles["Normal"],
            fontSize=9,
            leading=12,
            textColor=COLOR_TEXTO,
        )
        self.estilo_celda_negrita = ParagraphStyle(
            name="CosmolCeldaNegrita",
            parent=self.estilo_celda,
            fontName="Helvetica-Bold",
        )
        self.estilo_pie = ParagraphStyle(
            name="CosmolPie",
            parent=self.styles["Italic"],
            fontSize=8,
            leading=10,
            textColor=colors.HexColor("#757575"),
            alignment=1,
        )

    def generar_pdf_factura(
        self,
        datos_factura: Dict[str, Any],
        datos_socio: Dict[str, Any]
    ) -> bytes:
        """
        Genera una Factura Oficial con valor legal y derecho a crédito fiscal.
        """
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            buffer,
            pagesize=letter,
            rightMargin=36,
            leftMargin=36,
            topMargin=36,
            bottomMargin=36
        )
        story = []

        # 1. Membrete Institucional
        story.append(Paragraph("COOPERATIVA DE SERVICIOS PÚBLICOS 'MONTERO' R.L.", self.estilo_titulo))
        story.append(Paragraph("COSMOL R.L. — NIT: 1028374029 — Montero, Santa Cruz, Bolivia", self.estilo_subtitulo))
        story.append(HRFlowable(width="100%", thickness=1.5, color=COLOR_PRIMARIO, spaceAfter=10))

        # 2. Caja de Información Fiscal
        nro_factura = str(datos_factura.get("NROFACTURA") or datos_factura.get("nro_factura") or "0000000").strip()
        cod_autorizacion = str(datos_factura.get("CODAUTORIZACION") or datos_factura.get("cod_autorizacion") or "N/A").strip()
        nmes = int(datos_factura.get('NMES') or datos_factura.get('mes') or 8)
        anio = int(datos_factura.get('ANIO') or datos_factura.get('anio') or 2026)
        periodo = str(datos_factura.get("periodo") or f"{nmes:02d}/{anio}").strip()
        monto_bs = float(datos_factura.get("MONTOTOTAL") or datos_factura.get("monto_bs") or 0.0)

        tabla_fiscal_data = [
            [
                Paragraph("<b>FACTURA CON DERECHO A CRÉDITO FISCAL</b>", self.estilo_celda_negrita),
                Paragraph(f"<b>N° FACTURA:</b> {nro_factura}", self.estilo_celda_negrita)
            ],
            [
                Paragraph(f"<b>CÓD. AUTORIZACIÓN:</b><br/>{cod_autorizacion}", self.estilo_celda),
                Paragraph(f"<b>FECHA EMISIÓN:</b> {date.today().strftime('%d/%m/%Y')}<br/><b>PERIODO:</b> {periodo}", self.estilo_celda)
            ]
        ]
        tabla_fiscal = Table(tabla_fiscal_data, colWidths=[4.0 * inch, 3.5 * inch])
        tabla_fiscal.setStyle(TableStyle([
            ("BOX", (0, 0), (-1, -1), 1, COLOR_PRIMARIO),
            ("BACKGROUND", (0, 0), (-1, 0), COLOR_GRIS_CLARO),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("TOPPADDING", (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ]))
        story.append(tabla_fiscal)
        story.append(Spacer(1, 12))

        # 3. Datos del Socio / Contrato
        cod_socio = str(datos_socio.get("CODIGO") or datos_socio.get("cod_socio") or "").strip()
        nombre = str(datos_socio.get("NOMBRE") or datos_socio.get("nombre_titular") or "").strip()
        ci_nit = str(datos_socio.get("NROCIONIT") or datos_socio.get("ci_nit") or "").strip()
        direccion = str(datos_socio.get("DIRECCION") or datos_socio.get("direccion") or "").strip()
        ubicacion = str(datos_socio.get("ubicacion") or "1.4.64.0").strip()

        tabla_socio_data = [
            [
                Paragraph(f"<b>CÓDIGO DE SOCIO:</b> {cod_socio}", self.estilo_celda),
                Paragraph(f"<b>CATEGORÍA:</b> DOMÉSTICA", self.estilo_celda)
            ],
            [
                Paragraph(f"<b>SEÑOR(ES):</b> {nombre}", self.estilo_celda),
                Paragraph(f"<b>NIT / CI:</b> {ci_nit}", self.estilo_celda)
            ],
            [
                Paragraph(f"<b>DIRECCIÓN:</b> {direccion}", self.estilo_celda),
                Paragraph(f"<b>UBICACIÓN TÉCNICA:</b> {ubicacion}", self.estilo_celda)
            ]
        ]
        tabla_socio = Table(tabla_socio_data, colWidths=[4.5 * inch, 3.0 * inch])
        tabla_socio.setStyle(TableStyle([
            ("BOX", (0, 0), (-1, -1), 0.5, colors.grey),
            ("BACKGROUND", (0, 0), (-1, -1), colors.white),
            ("TOPPADDING", (0, 0), (-1, -1), 3),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ]))
        story.append(tabla_socio)
        story.append(Spacer(1, 14))

        # 4. Detalle de Liquidación / Conceptos
        monto_agua = round(monto_bs * 0.70, 2)
        monto_alcantarillado = round(monto_bs - monto_agua, 2)

        tabla_conceptos_data = [
            [
                Paragraph("<b>CONCEPTO / SERVICIO</b>", self.estilo_celda_negrita),
                Paragraph("<b>UNIDAD</b>", self.estilo_celda_negrita),
                Paragraph("<b>CANTIDAD</b>", self.estilo_celda_negrita),
                Paragraph("<b>SUBTOTAL (Bs)</b>", self.estilo_celda_negrita)
            ],
            [
                Paragraph("Servicio de Agua Potable Montero", self.estilo_celda),
                Paragraph("m³", self.estilo_celda),
                Paragraph("18", self.estilo_celda),
                Paragraph(f"{monto_agua:.2f}", self.estilo_celda)
            ],
            [
                Paragraph("Servicio de Alcantarillado Sanitario", self.estilo_celda),
                Paragraph("Servicio", self.estilo_celda),
                Paragraph("1", self.estilo_celda),
                Paragraph(f"{monto_alcantarillado:.2f}", self.estilo_celda)
            ],
            [
                Paragraph("<b>TOTAL A PAGAR (BOLIVIANOS)</b>", self.estilo_celda_negrita),
                Paragraph("", self.estilo_celda),
                Paragraph("", self.estilo_celda),
                Paragraph(f"<b>Bs {monto_bs:.2f}</b>", self.estilo_celda_negrita)
            ]
        ]
        tabla_conceptos = Table(tabla_conceptos_data, colWidths=[4.0 * inch, 1.0 * inch, 1.0 * inch, 1.5 * inch])
        tabla_conceptos.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), COLOR_PRIMARIO),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
            ("BACKGROUND", (0, -1), (-1, -1), COLOR_GRIS_CLARO),
            ("ALIGN", (1, 1), (-1, -1), "CENTER"),
            ("TOPPADDING", (0, 0), (-1, -1), 5),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ]))
        story.append(tabla_conceptos)
        story.append(Spacer(1, 20))

        # 5. Pie Legal SIAT
        story.append(HRFlowable(width="100%", thickness=0.5, color=colors.grey, spaceAfter=8))
        story.append(Paragraph(
            "ESTA FACTURA CONTRIBUYE AL DESARROLLO DEL PAÍS. EL USO ILÍCITO DE ÉSTA SERÁ SANCIONADO PENALMENTE DE ACUERDO A LEY.",
            self.estilo_pie
        ))
        story.append(Paragraph(
            "Ley N° 453: Los servicios deben prestarse en condiciones de calidad, regularidad y continuidad.",
            self.estilo_pie
        ))

        doc.build(story)
        buffer.seek(0)
        return buffer.getvalue()

    def generar_pdf_aviso_cobranza(
        self,
        datos_deuda: Dict[str, Any],
        datos_socio: Dict[str, Any]
    ) -> bytes:
        """
        Genera un Aviso Mensual de Cobranza preventivo.
        """
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            buffer,
            pagesize=letter,
            rightMargin=36,
            leftMargin=36,
            topMargin=36,
            bottomMargin=36
        )
        story = []

        # Membrete
        story.append(Paragraph("COSMOL R.L. — COOPERATIVA DE SERVICIOS PÚBLICOS", self.estilo_titulo))
        story.append(Paragraph("AVISO MENSUAL DE COBRANZA", self.estilo_subtitulo))
        story.append(HRFlowable(width="100%", thickness=1.5, color=COLOR_SECUNDARIO, spaceAfter=14))

        cod_socio = str(datos_socio.get("CODIGO") or datos_socio.get("cod_socio") or "").strip()
        nombre = str(datos_socio.get("NOMBRE") or datos_socio.get("nombre_titular") or "").strip()
        periodo = str(datos_deuda.get("periodo") or "Actual").strip()
        monto_bs = float(datos_deuda.get("MONTOTOTAL") or datos_deuda.get("monto_bs") or 0.0)
        fecha_vencimiento = str(datos_deuda.get("fecha_vencimiento") or "Fin de mes").strip()

        datos_aviso = [
            [Paragraph(f"<b>CÓDIGO DE SOCIO:</b> {cod_socio}", self.estilo_celda), Paragraph(f"<b>PERIODO:</b> {periodo}", self.estilo_celda)],
            [Paragraph(f"<b>TITULAR:</b> {nombre}", self.estilo_celda), Paragraph(f"<b>VENCIMIENTO:</b> {fecha_vencimiento}", self.estilo_celda)],
            [Paragraph("<b>TOTAL A PAGAR:</b>", self.estilo_celda_negrita), Paragraph(f"<b>Bs {monto_bs:.2f}</b>", self.estilo_celda_negrita)],
        ]
        tabla = Table(datos_aviso, colWidths=[4.0 * inch, 3.5 * inch])
        tabla.setStyle(TableStyle([
            ("BOX", (0, 0), (-1, -1), 1, COLOR_SECUNDARIO),
            ("BACKGROUND", (0, -1), (-1, -1), COLOR_GRIS_CLARO),
            ("TOPPADDING", (0, 0), (-1, -1), 6),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
        ]))
        story.append(tabla)
        story.append(Spacer(1, 20))

        story.append(Paragraph(
            "Recuerde que puede pagar su aviso cómodamente desde la aplicación mediante código QR interbancario o banca móvil.",
            self.estilo_celda
        ))
        story.append(Spacer(1, 10))
        story.append(Paragraph("Evite filas y mantenga su servicio al día.", self.estilo_pie))

        doc.build(story)
        buffer.seek(0)
        return buffer.getvalue()

    def generar_pdf_aviso_corte(
        self,
        datos_socio: Dict[str, Any],
        facturas_pendientes: List[Dict[str, Any]]
    ) -> bytes:
        """
        Genera una Notificación Formal de Aviso de Corte por acumulación de 2 o más facturas impagas.
        """
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            buffer,
            pagesize=letter,
            rightMargin=36,
            leftMargin=36,
            topMargin=36,
            bottomMargin=36
        )
        story = []

        # Membrete Alerta
        story.append(Paragraph("COSMOL R.L. — DEPARTAMENTO COMERCIAL Y COBRANZAS", self.estilo_titulo))
        story.append(Paragraph("NOTIFICACIÓN URGENTE: AVISO DE CORTE DEL SERVICIO", self.estilo_alerta))
        story.append(HRFlowable(width="100%", thickness=2, color=COLOR_ALERTA, spaceAfter=14))

        cod_socio = str(datos_socio.get("CODIGO") or datos_socio.get("cod_socio") or "").strip()
        nombre = str(datos_socio.get("NOMBRE") or datos_socio.get("nombre_titular") or "").strip()
        direccion = str(datos_socio.get("DIRECCION") or datos_socio.get("direccion") or "").strip()

        story.append(Paragraph(
            f"<b>Señor(a) Socio(a):</b> {nombre}<br/>"
            f"<b>Código de Suministro:</b> {cod_socio}<br/>"
            f"<b>Dirección del Predio:</b> {direccion}",
            self.estilo_celda
        ))
        story.append(Spacer(1, 12))

        story.append(Paragraph(
            "Se le notifica formalmente que, de acuerdo al Reglamento de Servicios de COSMOL R.L., "
            "su suministro presenta <b>2 o más facturas pendientes de pago</b>, encontrándose programado "
            "para la <b>SUSPENSIÓN TEMPORAL DEL SERVICIO DE AGUA POTABLE</b>.",
            self.estilo_celda
        ))
        story.append(Spacer(1, 12))

        # Tabla de facturas en mora
        filas_deuda = [
            [
                Paragraph("<b>PERIODO</b>", self.estilo_celda_negrita),
                Paragraph("<b>N° FACTURA</b>", self.estilo_celda_negrita),
                Paragraph("<b>MONTO (Bs)</b>", self.estilo_celda_negrita),
            ]
        ]
        total_acumulado = 0.0
        for f in facturas_pendientes:
            nmes = int(f.get('NMES') or f.get('mes') or 0)
            anio = int(f.get('ANIO') or f.get('anio') or 0)
            periodo = str(f.get("periodo") or f"{nmes:02d}/{anio}")
            nro_fact = str(f.get("NROFACTURA") or f.get("nro_factura") or "")
            monto = float(f.get("MONTOTOTAL") or f.get("monto_bs") or 0.0)
            total_acumulado += monto
            filas_deuda.append([
                Paragraph(periodo, self.estilo_celda),
                Paragraph(nro_fact, self.estilo_celda),
                Paragraph(f"Bs {monto:.2f}", self.estilo_celda),
            ])

        filas_deuda.append([
            Paragraph("<b>TOTAL EN MORA:</b>", self.estilo_celda_negrita),
            Paragraph("", self.estilo_celda),
            Paragraph(f"<b>Bs {total_acumulado:.2f}</b>", self.estilo_celda_negrita),
        ])

        tabla_deuda = Table(filas_deuda, colWidths=[2.5 * inch, 2.5 * inch, 2.5 * inch])
        tabla_deuda.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), COLOR_ALERTA),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
            ("BACKGROUND", (0, -1), (-1, -1), COLOR_GRIS_CLARO),
            ("TOPPADDING", (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ]))
        story.append(tabla_deuda)
        story.append(Spacer(1, 16))

        story.append(Paragraph(
            "<b>PLAZO DE REGULARIZACIÓN:</b> Cancelar su saldo pendiente a la brevedad posible "
            "a través de los canales digitales de pago o en cajas centrales de la cooperativa "
            "para evitar cargos adicionales por corte y reconexión.",
            self.estilo_celda
        ))
        story.append(Spacer(1, 20))
        story.append(Paragraph("COSMOL R.L. — Al servicio de Montero", self.estilo_pie))

        doc.build(story)
        buffer.seek(0)
        return buffer.getvalue()


# Instancia singleton para uso en toda la aplicación
generador_pdf = GeneradorPdfDocumento()
