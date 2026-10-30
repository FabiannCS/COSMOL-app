import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_app_bar.dart';
import '../../../../core/widgets/cosmol_button.dart';
import '../../../../core/widgets/cosmol_card.dart';
import '../../../multicuenta/presentation/providers/multicuenta_provider.dart';
import '../providers/reconexion_provider.dart';
import '../widgets/gps_capture_card.dart';
import '../widgets/photo_evidence_picker.dart';
import '../widgets/tipo_reconexion_selector.dart';

class SolicitarReconexionScreen extends ConsumerStatefulWidget {
  const SolicitarReconexionScreen({super.key});

  @override
  ConsumerState<SolicitarReconexionScreen> createState() =>
      _SolicitarReconexionScreenState();
}

class _SolicitarReconexionScreenState
    extends ConsumerState<SolicitarReconexionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _glosaController = TextEditingController();
  final _motivoOtroController = TextEditingController();

  int _selectedTipoId = 1;
  String? _coordenadasGps;
  Uint8List? _fotoBytes;
  String? _fotoFilename;

  @override
  void dispose() {
    _glosaController.dispose();
    _motivoOtroController.dispose();
    super.dispose();
  }

  Future<void> _enviarSolicitud() async {
    final activeSuministro = ref.read(multicuentaProvider).activeSuministro;
    final codSocio = activeSuministro?.codSocio ?? '';

    if (codSocio.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay un Socio activo seleccionado.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    if (_coordenadasGps == null || _coordenadasGps!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe capturar la ubicación GPS para orientar a los técnicos.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final motivoOtro = _selectedTipoId == 4 && _motivoOtroController.text.trim().isNotEmpty
        ? '[Motivo: ${_motivoOtroController.text.trim()}] '
        : '';
    final glosaFinal = '$motivoOtro${_glosaController.text.trim()}';

    final success = await ref.read(reconexionProvider.notifier).registrarSolicitud(
          codSocio: codSocio,
          idTipoReconexion: _selectedTipoId,
          coordenadasGps: _coordenadasGps!,
          glosa: glosaFinal,
          fotoBytes: _fotoBytes,
          fotoFilename: _fotoFilename,
        );

    if (success && mounted) {
      final ticket = ref.read(reconexionProvider).ticketEmitido;
      if (ticket != null) {
        context.pushReplacement(
          '/reconexion/ticket/${ticket.idReconexion}',
          extra: {
            'id_reconexion': ticket.idReconexion,
            'estado': ticket.estado,
            'cod_socio': codSocio,
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reconexionProvider);
    final activeSuministro = ref.watch(multicuentaProvider).activeSuministro;
    final codSocio = activeSuministro?.codSocio ?? '';
    final alias = activeSuministro?.alias ?? 'Socio $codSocio';

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: const CosmolAppBar(
        title: 'Formulario de Reconexión',
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Resumen de Suministro
            CosmolCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Socio:', style: AppTextStyles.subtitle2),
                  Text(
                    '$alias (#$codSocio)',
                    style: AppTextStyles.subtitle2.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 1. Selector de Tipo
            TipoReconexionSelector(
              selectedId: _selectedTipoId,
              motivoOtroController: _motivoOtroController,
              onSelected: (id) => setState(() => _selectedTipoId = id),
            ),
            const SizedBox(height: 14),

            // 2. Coordenadas GPS
            GpsCaptureCard(
              initialValue: _coordenadasGps,
              onGpsCaptured: (coords) => setState(() => _coordenadasGps = coords),
            ),
            const SizedBox(height: 14),

            // 3. Foto de Evidencia
            PhotoEvidencePicker(
              onImageSelected: (bytes, filename) {
                setState(() {
                  _fotoBytes = bytes;
                  _fotoFilename = filename;
                });
              },
            ),
            const SizedBox(height: 14),

            // 4. Referencias Domiciliarias
            CosmolCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Referencias del Domicilio', style: AppTextStyles.subtitle1),
                  const SizedBox(height: 6),
                  Text(
                    'Describa detalles visibles del inmueble (color de rejas, portón, árbol o comercio cercano).',
                    style: AppTextStyles.body2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _glosaController,
                    maxLines: 3,
                    maxLength: 250,
                    style: AppTextStyles.body1,
                    decoration: InputDecoration(
                      hintStyle: AppTextStyles.body2.copyWith(color: AppColors.textMuted),
                      fillColor: AppColors.lightBackground,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.borderSubtle),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().length < 4) {
                        return 'Ingrese una descripción de al menos 4 caracteres.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Mensaje de Error si ocurrió
            if (state.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.errorRed),
                ),
                child: Text(
                  state.errorMessage!,
                  style: AppTextStyles.caption.copyWith(color: AppColors.errorRed),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Botón de Envío
            CosmolButton(
              text: 'Enviar Solicitud',
              isLoading: state.isSubmitting,
              onPressed: state.isSubmitting ? null : _enviarSolicitud,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
