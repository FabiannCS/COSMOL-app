import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/elegibilidad_reconexion_model.dart';
import '../../data/models/reconexion_tramite_model.dart';
import '../../data/models/solicitud_reconexion_model.dart';
import '../../data/repositories/reconexion_repository_impl.dart';
import '../../domain/repositories/reconexion_repository.dart';

class ReconexionState {
  final bool isLoading;
  final bool isSubmitting;
  final ElegibilidadReconexionModel? elegibilidad;
  final List<ReconexionTramiteModel> historial;
  final String? errorMessage;
  final RespuestaSolicitudReconexionModel? ticketEmitido;

  const ReconexionState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.elegibilidad,
    this.historial = const [],
    this.errorMessage,
    this.ticketEmitido,
  });

  ReconexionState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    ElegibilidadReconexionModel? elegibilidad,
    List<ReconexionTramiteModel>? historial,
    String? errorMessage,
    bool clearError = false,
    RespuestaSolicitudReconexionModel? ticketEmitido,
  }) {
    return ReconexionState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      elegibilidad: elegibilidad ?? this.elegibilidad,
      historial: historial ?? this.historial,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      ticketEmitido: ticketEmitido ?? this.ticketEmitido,
    );
  }
}

final reconexionProvider =
    StateNotifierProvider.autoDispose<ReconexionNotifier, ReconexionState>((ref) {
  final repository = ref.watch(reconexionRepositoryProvider);
  return ReconexionNotifier(repository);
});

class ReconexionNotifier extends StateNotifier<ReconexionState> {
  final ReconexionRepository _repository;

  ReconexionNotifier(this._repository) : super(const ReconexionState());

  Future<void> cargarEstado(String codSocio) async {
    final clean = codSocio.trim();
    if (clean.isEmpty) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final elegibilidadFuture = _repository.checkElegibilidad(clean);
      final historialFuture = _repository.getHistorial(clean);

      final results = await Future.wait([elegibilidadFuture, historialFuture]);
      final elegibilidad = results[0] as ElegibilidadReconexionModel;
      final historial = results[1] as List<ReconexionTramiteModel>;

      state = state.copyWith(
        isLoading: false,
        elegibilidad: elegibilidad,
        historial: historial,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<bool> registrarSolicitud({
    required String codSocio,
    required int idTipoReconexion,
    required String coordenadasGps,
    required String glosa,
    Uint8List? fotoBytes,
    String? fotoFilename,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      String? fotoUrl;
      if (fotoBytes != null && fotoBytes.isNotEmpty) {
        fotoUrl = await _repository.subirFotoEvidencia(
          bytes: fotoBytes,
          filename: fotoFilename ?? 'evidencia.jpg',
          codSocio: codSocio,
        );
      }

      final payload = SolicitudReconexionPayload(
        codigoSocio: codSocio,
        idTipoReconexion: idTipoReconexion,
        coordenadasGps: coordenadasGps,
        glosa: glosa,
        fotoUrl: fotoUrl,
      );

      final respuesta = await _repository.solicitarReconexion(payload);

      state = state.copyWith(
        isSubmitting: false,
        ticketEmitido: respuesta,
      );

      await cargarEstado(codSocio);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }
}

