import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../providers/consumo_provider.dart';

/// Selector segmentado para alternar entre "Últimos 6 meses" y "Último año (12 meses)".
class ConsumoPeriodSelector extends StatelessWidget {
  final PeriodoConsumo selectedPeriodo;
  final ValueChanged<PeriodoConsumo> onPeriodoChanged;

  const ConsumoPeriodSelector({
    super.key,
    required this.selectedPeriodo,
    required this.onPeriodoChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          _buildSegment(
            title: 'Últimos 6 meses',
            isSelected: selectedPeriodo == PeriodoConsumo.seisMeses,
            onTap: () => onPeriodoChanged(PeriodoConsumo.seisMeses),
          ),
          const SizedBox(width: 4),
          _buildSegment(
            title: 'Último año (12 meses)',
            isSelected: selectedPeriodo == PeriodoConsumo.doceMeses,
            onTap: () => onPeriodoChanged(PeriodoConsumo.doceMeses),
          ),
        ],
      ),
    );
  }

  Widget _buildSegment({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cardSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x0A003E6B),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
