import 'package:flutter/material.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_card.dart';

class TipoReconexionSelector extends StatelessWidget {
  final int selectedId;
  final ValueChanged<int> onSelected;
  final TextEditingController? motivoOtroController;
  final ValueChanged<String>? onMotivoOtroChanged;

  const TipoReconexionSelector({
    super.key,
    required this.selectedId,
    required this.onSelected,
    this.motivoOtroController,
    this.onMotivoOtroChanged,
  });

  static const List<Map<String, dynamic>> _tipos = [
    {
      'id': 1,
      'titulo': 'Reconexión normal',
      'subtitulo': 'Sin retiro de medidor',
      'descripcion':
          'Si su medidor no fue retirado y si no requiere material extra para la reconexión.',
    },
    {
      'id': 2,
      'titulo': 'Reconexión con medidor',
      'subtitulo': 'Medidor retirado físicamente',
      'descripcion':
          'Si su medidor fue retirado físicamente de su domicilio y se requiere reinstalación del equipo de medición.',
    },
    {
      'id': 3,
      'titulo': 'Reconexión con material',
      'subtitulo': 'Requiere accesorios de plomería',
      'descripcion':
          'Si su reconexion requiere material físico de plomería, como ser tubería u otros accesorios.',
    },
    {
      'id': 4,
      'titulo': 'Otros motivos',
      'subtitulo': 'Casos especiales o extras',
      'descripcion':
          'Si tiene algún caso especial, como ser reconexiones no vistas en las opciones anteriores.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return CosmolCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Por favor, seleccione el tipo de reconexión requerida.',
            style: AppTextStyles.subtitle1,
          ),
          const SizedBox(height: 12),
          Column(
            children: _tipos.map((tipo) {
              final int id = tipo['id'] as int;
              final bool isSelected = id == selectedId;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.lightBackground : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.borderSubtle,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: InkWell(
                  onTap: () => onSelected(id),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: isSelected ? AppColors.primary : AppColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tipo['titulo'] as String,
                                    style: AppTextStyles.body1.copyWith(
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    tipo['subtitulo'] as String,
                                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isSelected ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: isSelected ? AppColors.primary : AppColors.textSecondary,
                              size: 20,
                            ),
                          ],
                        ),
                        // Pestaña desplegable con la descripción detallada
                        if (isSelected) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        tipo['descripcion'] as String,
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textPrimary,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (id == 4) ...[
                                  const SizedBox(height: 12),
                                  const Divider(height: 1, color: AppColors.borderSubtle),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Especifique el motivo externo:',
                                    style: AppTextStyles.caption.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: motivoOtroController,
                                    onChanged: onMotivoOtroChanged,
                                    maxLines: 2,
                                    maxLength: 150,
                                    style: AppTextStyles.body2,
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.all(10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: const BorderSide(color: AppColors.borderSubtle),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: const BorderSide(color: AppColors.borderSubtle),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                      ),
                                    ),
                                    validator: (val) {
                                      if (isSelected && (val == null || val.trim().isEmpty)) {
                                        return 'Por favor especifique el motivo.';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

