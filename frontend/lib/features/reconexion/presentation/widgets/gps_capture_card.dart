import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_card.dart';

class GpsCaptureCard extends StatefulWidget {
  final ValueChanged<String?> onGpsCaptured;
  final String? initialValue;

  const GpsCaptureCard({
    super.key,
    required this.onGpsCaptured,
    this.initialValue,
  });

  @override
  State<GpsCaptureCard> createState() => _GpsCaptureCardState();
}

class _GpsCaptureCardState extends State<GpsCaptureCard> {
  String? _coordenadas;
  bool _isLoading = false;
  String? _error;
  bool _requiresSettings = false;

  @override
  void initState() {
    super.initState();
    _coordenadas = widget.initialValue;
  }

  Future<void> _capturarUbicacion() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _requiresSettings = false;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'El GPS está desactivado. Por favor actívelo en su dispositivo.';
          _isLoading = false;
          _requiresSettings = true;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _error = 'Permiso de ubicación denegado. Se requiere para ubicar la acometida.';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Permisos de ubicación denegados de forma permanente. Habilítelos en Ajustes.';
          _isLoading = false;
          _requiresSettings = true;
        });
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 12),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        setState(() {
          _error = 'No se pudo obtener la posición GPS. Intente nuevamente al aire libre.';
          _isLoading = false;
        });
        return;
      }

      final coords =
          '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      setState(() {
        _coordenadas = coords;
        _isLoading = false;
      });
      widget.onGpsCaptured(coords);
    } catch (e) {
      setState(() {
        _error = 'No se pudo obtener la posición GPS. Verifique la señal e intente nuevamente.';
        _isLoading = false;
      });
    }
  }

  Future<void> _abrirConfiguracion() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
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
                  'Ubicación del Domicilio (GPS)',
                  style: AppTextStyles.subtitle1,
                ),
              ),
              const SizedBox(width: 8),
              if (_coordenadas != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.successBackground,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.successGreen),
                  ),
                  child: Text(
                    'Registrado',
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
            'Coordenadas de referencia para los técnicos de reconexión.',
            style: AppTextStyles.body2,
          ),
          const SizedBox(height: 12),
          if (_coordenadas != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Text(
                _coordenadas!,
                style: AppTextStyles.body1.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (_error != null) ...[
            Text(
              _error!,
              style: AppTextStyles.caption.copyWith(color: AppColors.errorRed),
            ),
            if (_requiresSettings) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _abrirConfiguracion,
                  icon: const Icon(Icons.settings, size: 16, color: AppColors.primary),
                  label: const Text(
                    'Abrir Configuración de Ubicación',
                    style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isLoading ? null : _capturarUbicacion,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : Text(
                      _coordenadas == null ? 'Obtener ubicación actual' : 'Actualizar ubicación',
                      style: AppTextStyles.button.copyWith(color: AppColors.primary),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
