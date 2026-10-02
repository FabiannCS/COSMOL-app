import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../data/models/consumo_factura_model.dart';

/// Gráfico interactivo de evolución de consumo mensual (m³).
class ConsumoChartWidget extends StatefulWidget {
  final List<ConsumoPeriodoModel> facturas;
  final int selectedIndex;
  final ValueChanged<int> onMonthSelected;

  const ConsumoChartWidget({
    super.key,
    required this.facturas,
    required this.selectedIndex,
    required this.onMonthSelected,
  });

  @override
  State<ConsumoChartWidget> createState() => _ConsumoChartWidgetState();
}

class _ConsumoChartWidgetState extends State<ConsumoChartWidget> {
  @override
  Widget build(BuildContext context) {
    if (widget.facturas.isEmpty) {
      return const SizedBox.shrink();
    }

    // Cronológicamente de izquierda a derecha (el más antiguo primero en la gráfica)
    final chronologicItems = widget.facturas.reversed.toList();
    final firstYear = chronologicItems.first.anio;
    final lastYear = chronologicItems.last.anio;
    final yearSubtitle = firstYear == lastYear
        ? 'Gestión $firstYear'
        : 'Gestión $firstYear - $lastYear';

    // Calcular el promedio del conjunto filtrado (6 o 12 meses)
    final totalVolumen = chronologicItems.fold<double>(0.0, (sum, f) => sum + f.consumoM3);
    final promedio = chronologicItems.isNotEmpty ? (totalVolumen / chronologicItems.length) : 0.0;

    // Calcular el índice correspondiente en la lista cronológica
    final activeChronologicalIndex =
        (chronologicItems.length - 1 - widget.selectedIndex).clamp(0, chronologicItems.length - 1);

    // Identificar meses con incremento mayor al 40% respecto al mes inmediatamente anterior
    final alertIndices = <int>{};
    for (int i = 1; i < chronologicItems.length; i++) {
      final prev = chronologicItems[i - 1].consumoM3;
      final curr = chronologicItems[i].consumoM3;
      if (prev > 0 && ((curr - prev) / prev) > 0.40) {
        alertIndices.add(i);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08003E6B),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título y Subtítulo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Registro de consumo (m³)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    yearSubtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${chronologicItems.length} meses',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Leyenda
          Wrap(
            spacing: 14,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildLegendItem(
                color: AppColors.primaryContainer,
                isDashed: false,
                label: 'Consumo medido',
                isPrimary: true,
              ),
              _buildLegendItem(
                color: Colors.blueGrey,
                isDashed: true,
                label: 'Promedio (${promedio.toStringAsFixed(1)} m³)',
                isPrimary: false,
              ),
              if (alertIndices.isNotEmpty)
                _buildLegendItem(
                  color: const Color(0xFFDC2626),
                  isDashed: false,
                  label: 'Alerta fuga (>+40%)',
                  isPrimary: false,
                  isAlert: true,
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Área de Dibujo de la Gráfica con Gestos Táctiles
          SizedBox(
            height: 195,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final itemWidth = (constraints.maxWidth - 46) /
                        math.max(1, chronologicItems.length - 1);
                    final dx = details.localPosition.dx - 36;
                    final clickedIndex = (dx / itemWidth).round().clamp(0, chronologicItems.length - 1);

                    // Convertir el índice cronológico de vuelta al índice descendente original
                    final originalIndex = (chronologicItems.length - 1) - clickedIndex;
                    widget.onMonthSelected(originalIndex);
                  },
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 195),
                    painter: _ConsumoChartPainter(
                      items: chronologicItems,
                      selectedIndex: activeChronologicalIndex,
                      promedio: promedio,
                      alertIndices: alertIndices,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required bool isDashed,
    required String label,
    required bool isPrimary,
    bool isAlert = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isAlert)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 5),
            decoration: const BoxDecoration(
              color: Color(0xFFDC2626),
              shape: BoxShape.circle,
            ),
          )
        else
          Container(
            width: 16,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        if (!isAlert) const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: isPrimary || isAlert ? FontWeight.w700 : FontWeight.w500,
            color: isAlert
                ? const Color(0xFFDC2626)
                : (isPrimary ? AppColors.primary : AppColors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _ConsumoChartPainter extends CustomPainter {
  final List<ConsumoPeriodoModel> items;
  final int selectedIndex;
  final double promedio;
  final Set<int> alertIndices;

  _ConsumoChartPainter({
    required this.items,
    required this.selectedIndex,
    required this.promedio,
    required this.alertIndices,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;

    const leftMargin = 38.0;
    const rightMargin = 16.0;
    const topMargin = 22.0;
    const bottomMargin = 28.0;

    final chartWidth = size.width - leftMargin - rightMargin;
    final chartHeight = size.height - topMargin - bottomMargin;

    // Determinar valor máximo de escala
    double maxConsumo = 20.0;
    for (final item in items) {
      if (item.consumoM3 > maxConsumo) maxConsumo = item.consumoM3;
    }
    // Redondear maxConsumo a múltiplo superior de 5
    final maxY = ((maxConsumo / 5).ceil() * 5).toDouble() + 5.0;
    const minY = 0.0;

    // Pintar líneas de fondo horizontales y etiquetas Y
    final gridLinePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;

    final textStyleY = GoogleFonts.plusJakartaSans(
      fontSize: 9,
      color: const Color(0xFF727781),
      fontWeight: FontWeight.w500,
    );

    final ySteps = [maxY, (maxY * 0.66), (maxY * 0.33), 0.0];
    for (final yVal in ySteps) {
      final normY = (yVal - minY) / (maxY - minY);
      final yPos = topMargin + (chartHeight * (1.0 - normY));

      // Línea punteada horizontal
      _drawDashedLine(
        canvas: canvas,
        p1: Offset(leftMargin, yPos),
        p2: Offset(size.width - rightMargin, yPos),
        paint: gridLinePaint,
      );

      // Texto de escala m³
      final span = TextSpan(
        text: '${yVal.toInt()} m³',
        style: textStyleY,
      );
      final textPainter = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(leftMargin - textPainter.width - 6, yPos - (textPainter.height / 2)),
      );
    }

    // Línea horizontal punteada del Promedio (sobre el período filtrado)
    if (promedio > 0) {
      final normPromY = (promedio - minY) / (maxY - minY);
      final yPromPos = topMargin + (chartHeight * (1.0 - normPromY.clamp(0.0, 1.0)));
      final promPaint = Paint()
        ..color = const Color(0xFF94A3B8)
        ..strokeWidth = 1.5;

      _drawDashedLine(
        canvas: canvas,
        p1: Offset(leftMargin, yPromPos),
        p2: Offset(size.width - rightMargin, yPromPos),
        paint: promPaint,
        dashWidth: 4.0,
        dashSpace: 4.0,
      );
    }

    final numPoints = items.length;
    final stepX = numPoints > 1 ? (chartWidth / (numPoints - 1)) : 0.0;

    // Calcular puntos de la serie de consumo
    final currentPoints = <Offset>[];
    for (int i = 0; i < numPoints; i++) {
      final item = items[i];
      final x = leftMargin + (i * stepX);
      final normY = (item.consumoM3 - minY) / (maxY - minY);
      final y = topMargin + (chartHeight * (1.0 - normY.clamp(0.0, 1.0)));
      currentPoints.add(Offset(x, y));
    }

    // 1. Dibujar área sombreada con gradiente
    if (currentPoints.isNotEmpty) {
      final fillPath = Path();
      fillPath.moveTo(currentPoints.first.dx, size.height - bottomMargin);
      fillPath.lineTo(currentPoints.first.dx, currentPoints.first.dy);

      for (int i = 0; i < currentPoints.length - 1; i++) {
        final p0 = currentPoints[i];
        final p1 = currentPoints[i + 1];
        final midX = (p0.dx + p1.dx) / 2;
        fillPath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      }

      fillPath.lineTo(currentPoints.last.dx, size.height - bottomMargin);
      fillPath.close();

      final gradientPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x33005691),
            Color(0x02005691),
          ],
        ).createShader(Rect.fromLTWH(0, topMargin, size.width, chartHeight))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, gradientPaint);
    }

    // 2. Dibujar línea principal (curva sólida)
    final mainLinePaint = Paint()
      ..color = AppColors.primaryContainer
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final mainPath = Path();
    if (currentPoints.isNotEmpty) {
      mainPath.moveTo(currentPoints.first.dx, currentPoints.first.dy);
      for (int i = 0; i < currentPoints.length - 1; i++) {
        final p0 = currentPoints[i];
        final p1 = currentPoints[i + 1];
        final midX = (p0.dx + p1.dx) / 2;
        mainPath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      }
      canvas.drawPath(mainPath, mainLinePaint);
    }

    // 3. Dibujar puntos de datos principales, alertas de fuga y etiquetas de meses
    final textStyleX = GoogleFonts.plusJakartaSans(
      fontSize: 10,
      color: AppColors.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    final textStyleSelectedX = GoogleFonts.plusJakartaSans(
      fontSize: 10,
      color: AppColors.primary,
      fontWeight: FontWeight.w800,
    );

    final textStyleValue = GoogleFonts.plusJakartaSans(
      fontSize: 9,
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
    );

    for (int i = 0; i < numPoints; i++) {
      final pt = currentPoints[i];
      final item = items[i];
      final isSelected = (i == selectedIndex);
      final isAlert = alertIndices.contains(i);

      // Halo de alerta o de selección interactiva
      if (isSelected) {
        canvas.drawCircle(
          pt,
          11.0,
          Paint()
            ..color = isAlert
                ? const Color(0xFFDC2626).withValues(alpha: 0.25)
                : AppColors.primary.withValues(alpha: 0.18),
        );
      } else if (isAlert) {
        canvas.drawCircle(
          pt,
          8.0,
          Paint()..color = const Color(0xFFDC2626).withValues(alpha: 0.18),
        );
      }

      // Punto central
      final pointColor = isAlert
          ? (isSelected ? const Color(0xFFDC2626) : const Color(0xFFEF4444))
          : (isSelected ? AppColors.primary : Colors.white);

      final pointBorderColor = isAlert
          ? const Color(0xFF991B1B)
          : (isSelected ? Colors.white : AppColors.primary);

      canvas.drawCircle(
        pt,
        isSelected ? 5.5 : 4.0,
        Paint()..color = pointColor,
      );
      canvas.drawCircle(
        pt,
        isSelected ? 5.5 : 4.0,
        Paint()
          ..color = pointBorderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 2.2 : 2.0,
      );

      // Etiqueta de valor sobre el punto (con distintivo de alerta si > 40%)
      final showLabel = numPoints <= 7 || isSelected || isAlert || (i % 2 == 0);
      if (showLabel) {
        final valText = item.consumoM3 == item.consumoM3.roundToDouble()
            ? item.consumoM3.toInt().toString()
            : item.consumoM3.toStringAsFixed(1);

        final labelText = isAlert ? '⚠️ $valText' : valText;

        final valSpan = TextSpan(
          text: labelText,
          style: textStyleValue.copyWith(
            color: isAlert
                ? const Color(0xFFDC2626)
                : (isSelected ? AppColors.primary : const Color(0xFF003E6B)),
            fontWeight: isSelected || isAlert ? FontWeight.w900 : FontWeight.w700,
            fontSize: isAlert ? 8.5 : 9,
          ),
        );
        final valPainter = TextPainter(
          text: valSpan,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout();
        valPainter.paint(
          canvas,
          Offset(pt.dx - (valPainter.width / 2), pt.dy - (valPainter.height) - 6),
        );
      }

      // Etiqueta del Mes en el eje X
      final xSpan = TextSpan(
        text: item.mesNombreCorto,
        style: isSelected
            ? textStyleSelectedX
            : (isAlert ? textStyleX.copyWith(color: const Color(0xFFB91C1C), fontWeight: FontWeight.w700) : textStyleX),
      );
      final xPainter = TextPainter(
        text: xSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      xPainter.paint(
        canvas,
        Offset(pt.dx - (xPainter.width / 2), size.height - bottomMargin + 8),
      );
    }
  }

  void _drawDashedLine({
    required Canvas canvas,
    required Offset p1,
    required Offset p2,
    required Paint paint,
    double dashWidth = 3.0,
    double dashSpace = 3.0,
  }) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final totalDistance = math.sqrt((dx * dx) + (dy * dy));
    final unitVectorX = dx / totalDistance;
    final unitVectorY = dy / totalDistance;

    double currentDistance = 0.0;
    while (currentDistance < totalDistance) {
      final start = Offset(
        p1.dx + (unitVectorX * currentDistance),
        p1.dy + (unitVectorY * currentDistance),
      );
      final endDistance = math.min(currentDistance + dashWidth, totalDistance);
      final end = Offset(
        p1.dx + (unitVectorX * endDistance),
        p1.dy + (unitVectorY * endDistance),
      );
      canvas.drawLine(start, end, paint);
      currentDistance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _ConsumoChartPainter oldDelegate) {
    return oldDelegate.items != items ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.promedio != promedio ||
        oldDelegate.alertIndices != alertIndices;
  }
}
