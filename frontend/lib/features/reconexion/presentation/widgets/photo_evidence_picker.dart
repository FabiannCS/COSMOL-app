import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_card.dart';

class PhotoEvidencePicker extends StatefulWidget {
  final void Function(Uint8List? bytes, String? filename) onImageSelected;

  const PhotoEvidencePicker({
    super.key,
    required this.onImageSelected,
  });

  @override
  State<PhotoEvidencePicker> createState() => _PhotoEvidencePickerState();
}

class _PhotoEvidencePickerState extends State<PhotoEvidencePicker> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  String? _filename;
  bool _isLoading = false;

  Future<void> _seleccionarImagen(ImageSource source) async {
    setState(() => _isLoading = true);
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _filename = file.name;
          _isLoading = false;
        });
        widget.onImageSelected(bytes, file.name);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _eliminarImagen() {
    setState(() {
      _imageBytes = null;
      _filename = null;
    });
    widget.onImageSelected(null, null);
  }

  @override
  Widget build(BuildContext context) {
    return CosmolCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Fotografía del medidor / fachada',
                  style: AppTextStyles.subtitle1,
                ),
              ),
              const SizedBox(width: 8),
              if (_imageBytes != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.successBackground,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.successGreen),
                  ),
                  child: Text(
                    'Adjuntada',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.successGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Envíe una fotografía para verificar el estado de la conexión física del medidor.',
            style: AppTextStyles.body2,
          ),
          const SizedBox(height: 12),
          if (_imageBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Image.memory(
                  _imageBytes!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (_filename != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.attach_file, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _filename!,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _seleccionarImagen(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 16, color: AppColors.primary),
                    label: Text(
                      'Cambiar',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _seleccionarImagen(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 16, color: AppColors.primary),
                    label: Text(
                      'Cámara',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _eliminarImagen,
                  icon: const Icon(Icons.delete_outline, color: AppColors.errorRed, size: 22),
                  tooltip: 'Quitar foto',
                ),
              ],
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                children: [
                  const Icon(Icons.camera_alt_outlined, size: 36, color: AppColors.textSecondary),
                  const SizedBox(height: 8),
                  Text(
                    'Suba una foto clara del medidor o fachada',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : () => _seleccionarImagen(ImageSource.gallery),
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: const Text('Archivo', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : () => _seleccionarImagen(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.primary),
                          label: const Text('Cámara', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
