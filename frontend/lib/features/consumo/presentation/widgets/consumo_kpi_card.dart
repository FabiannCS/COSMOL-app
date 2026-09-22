import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../providers/consumo_provider.dart';

/// Tarjeta Hero destacada que muestra el consumo del mes actual y la comparativa con el promedio.
class ConsumoKpiCard extends StatelessWidget {
  final ConsumoState state;

  const ConsumoKpiCard({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final mesActual = state.mesActual;
    final consumo = mesActual?.consumo ?? 0.0;
    final promedio = state.promedioConsumo;
    final isBajo = state.isBajoPromedio;
    final mesesCount = state.periodo == PeriodoConsumo.seisMeses ? '6' : '12';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A003E6B),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Consumo del Mes Actual',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFD1E4FF),
                ),
              ),
              if (mesActual != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    mesActual.mesAnioCorto,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Número Grande de Consumo
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                consumo == consumo.roundToDouble()
                    ? '${consumo.toInt()}'
                    : consumo.toStringAsFixed(1),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'm³',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFC5E7FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Divisor sutil
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 12),

          // Fila de Promedio y Estado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFFD1E4FF),
                  ),
                  children: [
                    TextSpan(text: 'Promedio $mesesCount meses: '),
                    TextSpan(
                      text: '${promedio.toStringAsFixed(1)} m³',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isBajo
                      ? const Color(0xFF16A34A).withValues(alpha: 0.25)
                      : const Color(0xFFDC2626).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isBajo ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      size: 12,
                      color: isBajo ? const Color(0xFF4ADE80) : const Color(0xFFFCA5A5),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      isBajo ? 'Bajo el promedio' : 'Sobre el promedio',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isBajo ? const Color(0xFF4ADE80) : const Color(0xFFFCA5A5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
