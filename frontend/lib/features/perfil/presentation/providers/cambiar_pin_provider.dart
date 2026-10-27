import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';

class CambiarPinState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;
  final String? successMessage;

  const CambiarPinState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
    this.successMessage,
  });

  CambiarPinState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
    String? successMessage,
  }) {
    return CambiarPinState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
      successMessage: successMessage ?? this.successMessage,
    );
  }
}

class CambiarPinNotifier extends StateNotifier<CambiarPinState> {
  final AuthRemoteDataSource _dataSource;

  CambiarPinNotifier(this._dataSource) : super(const CambiarPinState());

  void reset() {
    state = const CambiarPinState();
  }

  Future<bool> cambiarPin({
    required String pinActual,
    required String nuevoPin,
    required String confirmarPin,
  }) async {
    final actual = pinActual.trim();
    final nuevo = nuevoPin.trim();
    final confirmar = confirmarPin.trim();

    if (actual.isEmpty) {
      state = state.copyWith(errorMessage: 'Debe ingresar su PIN actual.');
      return false;
    }

    if (nuevo.length < 4) {
      state = state.copyWith(
          errorMessage: 'El nuevo PIN debe tener al menos 4 dígitos.');
      return false;
    }

    if (nuevo != confirmar) {
      state = state.copyWith(
          errorMessage: 'El nuevo PIN y su confirmación no coinciden.');
      return false;
    }

    if (actual == nuevo) {
      state = state.copyWith(
          errorMessage: 'El nuevo PIN no puede ser idéntico al PIN actual.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final res = await _dataSource.cambiarPinAutenticado(
        pinActual: actual,
        nuevoPin: nuevo,
        confirmarPin: confirmar,
      );

      final msg = res['mensaje']?.toString() ??
          '¡Su PIN de seguridad ha sido actualizado exitosamente!';

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        successMessage: msg,
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Ocurrió un error inesperado al actualizar el PIN.',
      );
      return false;
    }
  }
}

final cambiarPinProvider =
    StateNotifierProvider.autoDispose<CambiarPinNotifier, CambiarPinState>((ref) {
  final dataSource = ref.watch(authRemoteDataSourceProvider);
  return CambiarPinNotifier(dataSource);
});
