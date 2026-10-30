import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../multicuenta/presentation/providers/multicuenta_provider.dart';
import '../../data/models/resumen_deuda_model.dart';
import '../../data/repositories/deuda_repository_impl.dart';
import '../../domain/repositories/deuda_repository.dart';

class DeudaState {
  final bool isLoading;
  final ResumenDeudaModel? resumenDeuda;
  final String? errorMessage;
  final String? currentCodSocio;
  final bool isOffline;
  final DateTime? lastSyncTime;

  const DeudaState({
    this.isLoading = false,
    this.resumenDeuda,
    this.errorMessage,
    this.currentCodSocio,
    this.isOffline = false,
    this.lastSyncTime,
  });

  DeudaState copyWith({
    bool? isLoading,
    ResumenDeudaModel? resumenDeuda,
    String? errorMessage,
    String? currentCodSocio,
    bool? isOffline,
    DateTime? lastSyncTime,
  }) {
    return DeudaState(
      isLoading: isLoading ?? this.isLoading,
      resumenDeuda: resumenDeuda ?? this.resumenDeuda,
      errorMessage: errorMessage,
      currentCodSocio: currentCodSocio ?? this.currentCodSocio,
      isOffline: isOffline ?? this.isOffline,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  bool get hasDebt => resumenDeuda?.hasDebt ?? false;
  double get saldoTotal => resumenDeuda?.saldoPendienteBs ?? 0.0;
  int get cantidadFacturas => resumenDeuda?.cantidadFacturasPendientes ?? 0;
  
  /// Regla Oficial de Negocio COSMOL R.L.: Un aviso/alerta de corte solo aplica cuando se deben 3 o más facturas.
  bool get alertaCorte => (cantidadFacturas >= 3) && (resumenDeuda?.alertaCorte ?? false);
  bool get estaVencido => resumenDeuda?.estaVencido ?? false;
  List<FacturaPendienteModel> get facturas =>
      resumenDeuda?.facturasPendientes ?? const [];
}

final deudaProvider = StateNotifierProvider<DeudaNotifier, DeudaState>((ref) {
  final repository = ref.watch(deudaRepositoryProvider);
  final storageService = ref.watch(storageServiceProvider);
  final activeCodSocio = ref.watch(
    multicuentaProvider.select((s) => s.activeSuministro?.codSocio),
  );

  final notifier = DeudaNotifier(repository, storageService);

  // Cargar automáticamente la deuda cuando haya un suministro activo
  if (activeCodSocio != null && activeCodSocio.isNotEmpty) {
    notifier.cargarDeuda(activeCodSocio);
  }

  return notifier;
});

class DeudaNotifier extends StateNotifier<DeudaState> {
  final DeudaRepository _repository;
  final StorageService? _storageService;

  DeudaNotifier(this._repository, [this._storageService])
      : super(const DeudaState());

  Future<void> cargarDeuda(
    String codSocio, {
    bool forzarRefresco = false,
  }) async {
    final cleanCod = codSocio.trim();
    if (cleanCod.isEmpty) return;

    // Si ya estamos cargando el mismo socio sin refresco forzado, evitar peticiones duplicadas
    if (state.isLoading && state.currentCodSocio == cleanCod && !forzarRefresco) {
      return;
    }

    if (!mounted) return;
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      currentCodSocio: cleanCod,
    );

    try {
      final resumen = await _repository.obtenerDeudaSuministro(
        codSocio: cleanCod,
        forzarRefresco: forzarRefresco,
      );

      final isOfflineData = resumen.origenDatos == 'OFFLINE_CACHE';
      final syncTime = isOfflineData
          ? (_storageService?.getDeudaSyncTime(cleanCod) ?? DateTime.now())
          : DateTime.now();

      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        resumenDeuda: resumen,
        errorMessage: null,
        currentCodSocio: cleanCod,
        isOffline: isOfflineData,
        lastSyncTime: syncTime,
      );
    } on AppException catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isOffline: true,
        errorMessage: e.message,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isOffline: true,
        errorMessage:
            'No se pudo consultar el saldo de deuda. Verifique su conexión.',
      );
    }
  }

  Future<void> refrescar() async {
    final codSocio = state.currentCodSocio;
    if (codSocio != null && codSocio.isNotEmpty) {
      await cargarDeuda(codSocio, forzarRefresco: true);
    }
  }
}
