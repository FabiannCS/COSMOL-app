import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/storage_service.dart';
import '../../../deuda/presentation/providers/deuda_provider.dart';
import '../../../multicuenta/presentation/providers/multicuenta_provider.dart';
import '../../../reconexion/presentation/providers/reconexion_provider.dart';
import '../../data/models/notificacion_item_model.dart';

class NotificacionesState {
  final List<NotificacionItemModel> notificaciones;
  final Set<String> readIds;
  final int unreadCount;

  const NotificacionesState({
    this.notificaciones = const [],
    this.readIds = const {},
    this.unreadCount = 0,
  });

  NotificacionesState copyWith({
    List<NotificacionItemModel>? notificaciones,
    Set<String>? readIds,
    int? unreadCount,
  }) {
    return NotificacionesState(
      notificaciones: notificaciones ?? this.notificaciones,
      readIds: readIds ?? this.readIds,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

final notificacionesProvider =
    StateNotifierProvider<NotificacionesNotifier, NotificacionesState>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  final multicuentaState = ref.watch(multicuentaProvider);
  final deudaState = ref.watch(deudaProvider);
  final reconexionState = ref.watch(reconexionProvider);

  return NotificacionesNotifier(
    storageService: storageService,
    multicuentaState: multicuentaState,
    deudaState: deudaState,
    reconexionState: reconexionState,
  );
});

class NotificacionesNotifier extends StateNotifier<NotificacionesState> {
  final StorageService _storageService;
  final MulticuentaState _multicuentaState;
  final DeudaState _deudaState;
  final ReconexionState _reconexionState;

  NotificacionesNotifier({
    required StorageService storageService,
    required MulticuentaState multicuentaState,
    required DeudaState deudaState,
    required ReconexionState reconexionState,
  })  : _storageService = storageService,
        _multicuentaState = multicuentaState,
        _deudaState = deudaState,
        _reconexionState = reconexionState,
        super(const NotificacionesState()) {
    _generarNotificaciones();
  }

  void _generarNotificaciones() {
    final readIds = _storageService.getReadNotificationIds();
    final items = <NotificacionItemModel>[];

    final activeSuministro = _multicuentaState.activeSuministro;
    final codSocio = activeSuministro?.codSocio ?? _deudaState.resumenDeuda?.codSocio ?? '';
    final isTitular = activeSuministro?.rol.toUpperCase() == 'TITULAR';
    final alias = activeSuministro?.alias.isNotEmpty == true
        ? activeSuministro!.alias
        : (codSocio.isNotEmpty ? 'Socio $codSocio' : 'Cuenta');

    final resumen = _deudaState.resumenDeuda;

    // 1. Notificaciones basadas en el estado de deuda / facturación
    if (resumen != null) {
      final cantFacturas = resumen.cantidadFacturasPendientes;
      final saldo = resumen.saldoPendienteBs;
      final vencimiento = resumen.fechaProximoVencimiento;

      if (cantFacturas >= 2) {
        // Alerta Crítica: Aviso de corte
        final notifId = 'corte_${codSocio}_cant${cantFacturas}_saldo${saldo.toStringAsFixed(0)}';
        items.add(
          NotificacionItemModel(
            id: notifId,
            tipo: TipoNotificacion.avisoCorte,
            titulo: isTitular
                ? '⚠️ Aviso de Corte del Servicio'
                : '⚠️ Facturas Acumuladas en Mora',
            mensaje: isTitular
                ? 'Tu cuenta ($alias) acumula $cantFacturas facturas impagas por Bs. ${saldo.toStringAsFixed(2)}. Regulariza tu saldo para evitar la suspensión del servicio.'
                : 'Esta cuenta ($alias) acumula $cantFacturas facturas impagas por Bs. ${saldo.toStringAsFixed(2)}. Puedes realizar el pago mediante QR.',
            fechaHora: DateTime.now(),
            esUrgente: true,
            accionTipo: NotificacionAccionTipo.pagar,
            codSocio: codSocio,
            esLeida: readIds.contains(notifId),
          ),
        );
      } else if (cantFacturas == 1) {
        if (resumen.estaVencido) {
          final notifId = 'vencida_${codSocio}_saldo${saldo.toStringAsFixed(0)}';
          items.add(
            NotificacionItemModel(
              id: notifId,
              tipo: TipoNotificacion.facturaVencida,
              titulo: 'Factura Vencida',
              mensaje: 'Tienes 1 factura vencida por Bs. ${saldo.toStringAsFixed(2)} en tu cuenta $alias. Paga a tiempo para evitar recargos.',
              fechaHora: DateTime.now(),
              esUrgente: true,
              accionTipo: NotificacionAccionTipo.pagar,
              codSocio: codSocio,
              esLeida: readIds.contains(notifId),
            ),
          );
        } else {
          final notifId = 'impaga_${codSocio}_saldo${saldo.toStringAsFixed(0)}';
          items.add(
            NotificacionItemModel(
              id: notifId,
              tipo: TipoNotificacion.facturaImpaga,
              titulo: 'Factura Pendiente de Pago',
              mensaje: vencimiento != null && vencimiento.isNotEmpty
                  ? 'Tienes 1 factura emitida por Bs. ${saldo.toStringAsFixed(2)} en tu cuenta $alias con vencimiento el $vencimiento.'
                  : 'Tienes 1 factura emitida por Bs. ${saldo.toStringAsFixed(2)} en tu cuenta $alias.',
              fechaHora: DateTime.now(),
              esUrgente: false,
              accionTipo: NotificacionAccionTipo.pagar,
              codSocio: codSocio,
              esLeida: readIds.contains(notifId),
            ),
          );
        }
      } else if (cantFacturas == 0 && saldo <= 0.0) {
        final notifId = 'aldia_$codSocio';
        items.add(
          NotificacionItemModel(
            id: notifId,
            tipo: TipoNotificacion.alDia,
            titulo: '¡Cuenta al Día!',
            mensaje: 'No tienes facturas pendientes en tu cuenta $alias. ¡Gracias por tu puntualidad!',
            fechaHora: DateTime.now(),
            esUrgente: false,
            accionTipo: NotificacionAccionTipo.ninguno,
            codSocio: codSocio,
            esLeida: readIds.contains(notifId),
          ),
        );
      }
    }

    // 2. Notificaciones de Reconexión (Solo Titular)
    if (isTitular) {
      final ticket = _reconexionState.ticketEmitido;
      if (ticket != null) {
        final notifId = 'reconexion_${ticket.idReconexion}_${ticket.estado}';
        items.add(
          NotificacionItemModel(
            id: notifId,
            tipo: TipoNotificacion.reconexion,
            titulo: 'Solicitud de Reconexión #${ticket.idReconexion}',
            mensaje: 'Tu solicitud de reconexión se encuentra en estado: ${ticket.estado}. En breve se despachará la cuadrilla técnica.',
            fechaHora: DateTime.now(),
            esUrgente: ticket.estado != 'COMPLETADA',
            accionTipo: NotificacionAccionTipo.verReconexion,
            accionPayload: ticket.idReconexion.toString(),
            codSocio: codSocio,
            esLeida: readIds.contains(notifId),
          ),
        );
      } else if (_reconexionState.historial.isNotEmpty) {
        final ultimoTramite = _reconexionState.historial.first;
        final notifId = 'reconexion_${ultimoTramite.idReconexion}_${ultimoTramite.estado}';
        items.add(
          NotificacionItemModel(
            id: notifId,
            tipo: TipoNotificacion.reconexion,
            titulo: 'Trámite de Reconexión #${ultimoTramite.idReconexion}',
            mensaje: 'Último estado registrado: ${ultimoTramite.estado}. Inspección técnica de la cuenta $codSocio.',
            fechaHora: DateTime.now(),
            esUrgente: ultimoTramite.estado != 'COMPLETADA',
            accionTipo: NotificacionAccionTipo.verReconexion,
            accionPayload: ultimoTramite.idReconexion.toString(),
            codSocio: codSocio,
            esLeida: readIds.contains(notifId),
          ),
        );
      }
    }

    // 3. Notificación de Gestión Multicuenta si tiene más de 1 suministro
    if (_multicuentaState.suministros.length > 1) {
      final notifId = 'multicuenta_info_${_multicuentaState.suministros.length}';
      items.add(
        NotificacionItemModel(
          id: notifId,
          tipo: TipoNotificacion.multicuenta,
          titulo: 'Gestión Multicuenta Activa',
          mensaje: 'Tienes ${_multicuentaState.suministros.length} cuentas asociadas. Puedes cambiar de cuenta activa desde la pestaña Socios o el menú superior.',
          fechaHora: DateTime.now(),
          esUrgente: false,
          accionTipo: NotificacionAccionTipo.cambiarSuministro,
          esLeida: readIds.contains(notifId),
        ),
      );
    }

    // Ordenar: primero las urgentes no leídas, luego las no leídas normales, luego las leídas
    items.sort((a, b) {
      if (!a.esLeida && b.esLeida) return -1;
      if (a.esLeida && !b.esLeida) return 1;
      if (a.esUrgente && !b.esUrgente) return -1;
      if (!a.esUrgente && b.esUrgente) return 1;
      return 0;
    });

    final unreadCount = items.where((it) => !it.esLeida).length;

    state = NotificacionesState(
      notificaciones: items,
      readIds: readIds,
      unreadCount: unreadCount,
    );
  }

  Future<void> marcarComoLeida(String id) async {
    final updatedReadIds = Set<String>.from(state.readIds)..add(id);
    await _storageService.saveReadNotificationIds(updatedReadIds);

    final updatedNotificaciones = state.notificaciones.map((n) {
      if (n.id == id) {
        return n.copyWith(esLeida: true);
      }
      return n;
    }).toList();

    final unread = updatedNotificaciones.where((it) => !it.esLeida).length;

    state = state.copyWith(
      notificaciones: updatedNotificaciones,
      readIds: updatedReadIds,
      unreadCount: unread,
    );
  }

  Future<void> marcarTodasComoLeidas() async {
    final allIds = state.notificaciones.map((n) => n.id).toSet();
    final updatedReadIds = Set<String>.from(state.readIds)..addAll(allIds);
    await _storageService.saveReadNotificationIds(updatedReadIds);

    final updatedNotificaciones = state.notificaciones.map((n) {
      return n.copyWith(esLeida: true);
    }).toList();

    state = state.copyWith(
      notificaciones: updatedNotificaciones,
      readIds: updatedReadIds,
      unreadCount: 0,
    );
  }

  void refrescar() {
    _generarNotificaciones();
  }
}
