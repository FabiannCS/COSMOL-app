import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../data/models/pago_model.dart';
import '../providers/deuda_provider.dart';
import '../providers/pagos_provider.dart';

/// Modal interactivo de Pago con Código QR Mock y Simulación de Pago (Demo).
/// Cumple con:
/// 1. "Solo vista" mock sin registrar débitos reales ni alterar deudas de Informix.
/// 2. Envío de telemetría a COSMOL-Reportes (id_tipo: 12) en segundo plano.
class PagoQrMockSheet extends ConsumerStatefulWidget {
  final String codSocio;
  final String nombreTitular;
  final double montoBs;
  final int cantFacturas;

  const PagoQrMockSheet({
    super.key,
    required this.codSocio,
    required this.nombreTitular,
    required this.montoBs,
    this.cantFacturas = 1,
  });

  static Future<void> show(
    BuildContext context, {
    required String codSocio,
    required String nombreTitular,
    required double montoBs,
    int cantFacturas = 1,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PagoQrMockSheet(
        codSocio: codSocio,
        nombreTitular: nombreTitular,
        montoBs: montoBs,
        cantFacturas: cantFacturas,
      ),
    );
  }

  @override
  ConsumerState<PagoQrMockSheet> createState() => _PagoQrMockSheetState();
}

class _PagoQrMockSheetState extends ConsumerState<PagoQrMockSheet> {
  // Temporizador regresivo de 15 minutos (900 segundos)
  late int _segundosRestantes;
  Timer? _timer;
  SimularPagoResponseModel? _comprobante;

  @override
  void initState() {
    super.initState();
    _segundosRestantes = 900;
    _iniciarTemporizador();
  }

  void _iniciarTemporizador() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_segundosRestantes > 0) {
        if (mounted) {
          setState(() {
            _segundosRestantes--;
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatearTiempo(int segundos) {
    final minutos = segundos ~/ 60;
    final seg = segundos % 60;
    return '${minutos.toString().padLeft(2, '0')}:${seg.toString().padLeft(2, '0')}';
  }

  String _generarPayloadQr() {
    // Generación de payload estándar interoperable Simple QR (formato mock oficial)
    return 'COSMOL-QR|SOCIO:${widget.codSocio}|MONTO:${widget.montoBs.toStringAsFixed(2)}|BS|TIMESTAMP:${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _ejecutarSimulacionPago() async {
    final response = await ref.read(pagosProvider.notifier).simularPago(
          codSocio: widget.codSocio,
          canalId: 'qr_simple',
          montoBs: widget.montoBs,
          periodos: '${widget.cantFacturas} factura(s)',
        );

    if (response != null && mounted) {
      setState(() {
        _comprobante = response;
      });
      // Refrescar deuda visualmente en memoria a Bs 0.00 tras el pago demo
      ref.read(deudaProvider.notifier).marcarDeudaComoPagadaSimulada();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pagosState = ref.watch(pagosProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: _comprobante != null
                ? _buildVistaComprobanteExitoso(_comprobante!)
                : _buildVistaGeneracionQr(pagosState),
          ),
        ),
      ),
    );
  }

  /// Vista 1: Presentación del QR oficial con temporizador y botón de simulación
  Widget _buildVistaGeneracionQr(PagosState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barra superior de arrastre
        Center(
          child: Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.borderSubtle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Cabecera con Badge de Simulación
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Pago con Código QR',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkNavy,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'DEMO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Suministro #${widget.codSocio} • ${widget.nombreTitular}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textSecondary),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Tarjeta de Monto a Pagar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monto Total a Cancelar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF166534),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Simple QR Interoperable Bolivia',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
              Text(
                'Bs ${widget.montoBs.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF166534),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Contenedor del Código QR generado en vivo
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.pureWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderStrong, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadowColor,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: _generarPayloadQr(),
              version: QrVersions.auto,
              size: 210.0,
              gapless: true,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF003E6B),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF0B1C30),
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Temporizador de vigencia
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: AppColors.warningOrange),
              const SizedBox(width: 6),
              Text(
                'Código válido por: ${_formatearTiempo(_segundosRestantes)} min',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkNavy,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        const Center(
          child: Text(
            'Escanea este código desde la app de tu banco (BNB, BCP, Mercantil, Ganadero, etc.)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Botón: Copiar Código / Glosa
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _generarPayloadQr()));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Código de transferencia copiado al portapapeles.'),
                backgroundColor: AppColors.primary,
                duration: Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copiar Código QR'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),

        const SizedBox(height: 10),

        // Botón Principal: Simular Pago Realizado
        ElevatedButton(
          onPressed: state.isSimulating ? null : _ejecutarSimulacionPago,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: AppColors.pureWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 2,
          ),
          child: state.isSimulating
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Simular Pago Realizado (Demo)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),

        if (state.errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            state.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.errorRed,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  /// Vista 2: Comprobante Digital Mock tras completar la simulación
  Widget _buildVistaComprobanteExitoso(SimularPagoResponseModel comprobante) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.borderSubtle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Ícono de Éxito
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF16A34A),
              size: 44,
            ),
          ),
        ),

        const SizedBox(height: 16),

        const Center(
          child: Text(
            '¡Pago Simulado Exitoso!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.darkNavy,
            ),
          ),
        ),

        const SizedBox(height: 4),

        const Center(
          child: Text(
            'Evento de auditoría despachado a COSMOL-Reportes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Tarjeta del Comprobante
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: [
              _buildFilaTicket('N° Transacción', comprobante.nroTransaccion, isBold: true),
              const Divider(height: 18),
              _buildFilaTicket('Código de Socio', comprobante.codSocio),
              const Divider(height: 18),
              _buildFilaTicket('Canal', 'QR Simple Interbancario'),
              const Divider(height: 18),
              _buildFilaTicket('Fecha y Hora', comprobante.fechaPago),
              const Divider(height: 18),
              _buildFilaTicket('Monto Cancelado', 'Bs ${comprobante.montoBs.toStringAsFixed(2)}', isAmount: true),
              const Divider(height: 18),
              _buildFilaTicket('Estado', 'REGISTRADO EN AUDITORÍA', isStatus: true),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Aviso explicativo de demo
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Esta es una vista demostrativa de pago. No se debitó dinero ni se modificó su deuda real en la cooperativa.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF92400E),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Botón de Cierre
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.pureWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text(
            'Finalizar y Volver al Inicio',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilaTicket(String etiqueta, String valor, {bool isBold = false, bool isAmount = false, bool isStatus = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: isAmount ? 15 : 12,
            fontWeight: (isBold || isAmount || isStatus) ? FontWeight.bold : FontWeight.w500,
            color: isStatus
                ? const Color(0xFF16A34A)
                : isAmount
                    ? AppColors.primary
                    : AppColors.darkNavy,
          ),
        ),
      ],
    );
  }
}

