import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../data/models/pago_model.dart';
import '../../data/models/resumen_deuda_model.dart';
import '../providers/deuda_provider.dart';
import '../providers/pagos_provider.dart';

/// Pasos lógicos del flujo de pago interactivo
enum _PasoPagoSheet {
  seleccionFacturas,
  qrGenerado,
  comprobanteExitoso,
}

/// Variante bancaria de Simple QR para alternar entre cargas
class _VarianteQrBanco {
  final String bancoNombre;
  final String sigla;
  final Color colorPrimario;
  final Color colorSecundario;
  final QrEyeShape eyeShape;
  final QrDataModuleShape moduleShape;
  final String formatoGlosa;
  final String red = 'Simple QR Bolivia (ASOBAN / BCB)';

  const _VarianteQrBanco({
    required this.bancoNombre,
    required this.sigla,
    required this.colorPrimario,
    required this.colorSecundario,
    required this.eyeShape,
    required this.moduleShape,
    required this.formatoGlosa,
  });
}

/// Modal interactivo de Pago con Selección de Facturas, Código QR Mock y Simulación.
/// Cumple con:
/// 1. Listado previo de facturas para que el socio elija libremente cuáles pagar.
/// 2. Botón explícito "Generar Código QR" para crear el QR con el monto de las facturas elegidas.
/// 3. Código QR estático una vez mostrado (sin fluctuaciones), alternando de entidad bancaria cada vez que se genera.
/// 4. Flujo 100% in-app sin redirecciones externas y telemetría a COSMOL-Reportes.
class PagoQrMockSheet extends ConsumerStatefulWidget {
  final String codSocio;
  final String nombreTitular;
  final double montoBs;
  final int cantFacturas;
  final List<FacturaPendienteModel> facturas;

  const PagoQrMockSheet({
    super.key,
    required this.codSocio,
    required this.nombreTitular,
    required this.montoBs,
    this.cantFacturas = 1,
    this.facturas = const [],
  });

  static Future<void> show(
    BuildContext context, {
    required String codSocio,
    required String nombreTitular,
    required double montoBs,
    int cantFacturas = 1,
    List<FacturaPendienteModel> facturas = const [],
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
        facturas: facturas,
      ),
    );
  }

  @override
  ConsumerState<PagoQrMockSheet> createState() => _PagoQrMockSheetState();
}

class _PagoQrMockSheetState extends ConsumerState<PagoQrMockSheet> {
  // Catálogo de variantes bancarias oficiales para alternar en cada generación de QR
  static const List<_VarianteQrBanco> _variantesBancos = [
    _VarianteQrBanco(
      bancoNombre: 'Banco Unión S.A.',
      sigla: 'BUNION',
      colorPrimario: Color(0xFF003E6B), // Azul Petróleo Institucional
      colorSecundario: Color(0xFF0B1C30),
      eyeShape: QrEyeShape.square,
      moduleShape: QrDataModuleShape.square,
      formatoGlosa: 'COSMOL-UNION-SIMPLEQR',
    ),
    _VarianteQrBanco(
      bancoNombre: 'Banco de Crédito BCP',
      sigla: 'BCP',
      colorPrimario: Color(0xFF002A54), // Azul Marino BCP
      colorSecundario: Color(0xFF051B38),
      eyeShape: QrEyeShape.circle,
      moduleShape: QrDataModuleShape.circle,
      formatoGlosa: 'COSMOL-BCP-SIMPLEQR',
    ),
    _VarianteQrBanco(
      bancoNombre: 'Banco Nacional de Bolivia (BNB)',
      sigla: 'BNB',
      colorPrimario: Color(0xFF007A3D), // Verde BNB
      colorSecundario: Color(0xFF0A3319),
      eyeShape: QrEyeShape.square,
      moduleShape: QrDataModuleShape.circle,
      formatoGlosa: 'COSMOL-BNB-SIMPLEQR',
    ),
    _VarianteQrBanco(
      bancoNombre: 'Banco Mercantil Santa Cruz',
      sigla: 'BMSC',
      colorPrimario: Color(0xFF0C3860), // Azul BMSC
      colorSecundario: Color(0xFF1E293B),
      eyeShape: QrEyeShape.circle,
      moduleShape: QrDataModuleShape.square,
      formatoGlosa: 'COSMOL-BMSC-SIMPLEQR',
    ),
  ];

  // Contador global para alternar la entidad bancaria en cada nueva generación de QR
  static int _contadorGlobalGeneracion = 0;

  late _PasoPagoSheet _pasoActual;
  late List<FacturaPendienteModel> _facturasDisponibles;
  late Set<String> _facturasSeleccionadas;

  // Variables fijas del QR generado para asegurar que se mantenga 100% estático
  late _VarianteQrBanco _varianteActual;
  late String _payloadQrEstatico;
  late double _montoFijadoQr;
  late String _periodosFijadosQr;
  late int _cantFacturasFijadas;

  // Temporizador regresivo de 15 minutos (900 segundos) para el QR generado
  int _segundosRestantes = 900;
  Timer? _timer;
  SimularPagoResponseModel? _comprobante;

  @override
  void initState() {
    super.initState();
    _pasoActual = _PasoPagoSheet.seleccionFacturas;

    // Normalizar facturas disponibles
    if (widget.facturas.isNotEmpty) {
      _facturasDisponibles = List.from(widget.facturas);
    } else {
      // Fallback si no vinieron ítems desagregados pero existe saldo
      _facturasDisponibles = [
        FacturaPendienteModel(
          nroFacip: 'FAC-001',
          nroFactura: 'Actual',
          codAutorizacion: 'COSMOL',
          periodo: 'Periodo Vigente',
          mesLectura: 'Factura de Consumo Pendiente',
          anio: DateTime.now().year,
          mes: DateTime.now().month,
          montoBs: widget.montoBs > 0 ? widget.montoBs : 75.0,
          estaVencida: false,
          diasMora: 0,
        ),
      ];
    }

    // Por defecto, todas las facturas se seleccionan inicialmente
    _facturasSeleccionadas = _facturasDisponibles.map((f) => f.nroFacip).toSet();

    // Inicializar primera variante bancaria
    _varianteActual = _variantesBancos[0];
    _payloadQrEstatico = '';
    _montoFijadoQr = 0.0;
    _periodosFijadosQr = '';
    _cantFacturasFijadas = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- Métodos de Selección y Cálculo ---

  double get _montoSeleccionado {
    return _facturasDisponibles
        .where((f) => _facturasSeleccionadas.contains(f.nroFacip))
        .fold(0.0, (acc, f) => acc + f.montoBs);
  }

  int get _cantSeleccionadas => _facturasSeleccionadas.length;

  String get _periodosSeleccionadosTexto {
    final periodos = _facturasDisponibles
        .where((f) => _facturasSeleccionadas.contains(f.nroFacip))
        .map((f) => f.mesLectura.isNotEmpty ? f.mesLectura : f.periodo)
        .toList();
    if (periodos.isEmpty) return 'Ninguna factura';
    return periodos.join(', ');
  }

  void _toggleFactura(String nroFacip) {
    setState(() {
      if (_facturasSeleccionadas.contains(nroFacip)) {
        _facturasSeleccionadas.remove(nroFacip);
      } else {
        _facturasSeleccionadas.add(nroFacip);
      }
    });
  }

  void _toggleSeleccionarTodas() {
    setState(() {
      if (_facturasSeleccionadas.length == _facturasDisponibles.length) {
        _facturasSeleccionadas.clear();
      } else {
        _facturasSeleccionadas =
            _facturasDisponibles.map((f) => f.nroFacip).toSet();
      }
    });
  }

  // --- Generación y Alternancia del Código QR ---

  void _generarQrParaSeleccion() {
    if (_cantSeleccionadas == 0) return;

    // Alternar cíclicamente la entidad bancaria del QR en cada generación
    final indice = (_contadorGlobalGeneracion++) % _variantesBancos.length;
    _varianteActual = _variantesBancos[indice];

    _montoFijadoQr = _montoSeleccionado;
    _periodosFijadosQr = _periodosSeleccionadosTexto;
    _cantFacturasFijadas = _cantSeleccionadas;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final trxId =
        'TRX-${_varianteActual.sigla}-${widget.codSocio}-${timestamp.toString().substring(timestamp.toString().length - 6)}';

    // El payload generado queda congelado para esta visualización (QR 100% estático)
    _payloadQrEstatico =
        '${_varianteActual.formatoGlosa}|SOCIO:${widget.codSocio}|TITULAR:${widget.nombreTitular.replaceAll('|', '')}|MONTO:${_montoFijadoQr.toStringAsFixed(2)}|BS|TRX:$trxId|PERIODOS:$_periodosFijadosQr';

    // Iniciar temporizador regresivo de 15 minutos
    _segundosRestantes = 900;
    _iniciarTemporizador();

    setState(() {
      _pasoActual = _PasoPagoSheet.qrGenerado;
    });
  }

  void _iniciarTemporizador() {
    _timer?.cancel();
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

  String _formatearTiempo(int segundos) {
    final minutos = segundos ~/ 60;
    final seg = segundos % 60;
    return '${minutos.toString().padLeft(2, '0')}:${seg.toString().padLeft(2, '0')}';
  }

  Future<void> _ejecutarSimulacionPago() async {
    final response = await ref.read(pagosProvider.notifier).simularPago(
          codSocio: widget.codSocio,
          canalId: 'qr_simple',
          montoBs: _montoFijadoQr,
          periodos: '$_cantFacturasFijadas factura(s): $_periodosFijadosQr',
        );

    if (response != null && mounted) {
      setState(() {
        _comprobante = response;
        _pasoActual = _PasoPagoSheet.comprobanteExitoso;
      });

      // Actualizar deuda visualmente en memoria (descontando facturas pagadas o saldando a 0)
      ref.read(deudaProvider.notifier).marcarDeudaComoPagadaSimulada(
            facturasPagadasNroFacip: _facturasSeleccionadas.toList(),
            montoPagado: _montoFijadoQr,
          );
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
            child: _buildContenidoPorPaso(pagosState),
          ),
        ),
      ),
    );
  }

  Widget _buildContenidoPorPaso(PagosState state) {
    switch (_pasoActual) {
      case _PasoPagoSheet.seleccionFacturas:
        return _buildVistaSeleccionFacturas();
      case _PasoPagoSheet.qrGenerado:
        return _buildVistaQrGenerado(state);
      case _PasoPagoSheet.comprobanteExitoso:
        return _buildVistaComprobanteExitoso(_comprobante!);
    }
  }

  // =========================================================================
  // PASO 1: Listado de Facturas para Selección Libre
  // =========================================================================

  Widget _buildVistaSeleccionFacturas() {
    final todosSeleccionados =
        _facturasSeleccionadas.length == _facturasDisponibles.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barra superior de arrastre
        _buildPillArrastre(),

        // Encabezado
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
                        'Pagar Facturas de Agua',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkNavy,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildBadgeDemo(),
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

        // Barra informativa de selección
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Selecciona las facturas a cancelar (${_facturasDisponibles.length} disponibles):',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.darkNavy,
              ),
            ),
            TextButton(
              onPressed: _toggleSeleccionarTodas,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.zero,
              ),
              child: Text(
                todosSeleccionados ? 'Desmarcar todas' : 'Marcar todas',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Lista interactiva de facturas disponibles
        ...List.generate(_facturasDisponibles.length, (index) {
          final f = _facturasDisponibles[index];
          final estaSeleccionada = _facturasSeleccionadas.contains(f.nroFacip);
          final mesTexto =
              f.mesLectura.isNotEmpty ? f.mesLectura : 'Periodo ${f.periodo}';
          final numFacturaTexto = f.nroFactura.isNotEmpty
              ? 'Factura #${f.nroFactura}'
              : 'Facip #${f.nroFacip}';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: estaSeleccionada
                  ? const Color(0xFFF0FDF4)
                  : AppColors.pureWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: estaSeleccionada
                    ? const Color(0xFF22C55E)
                    : AppColors.borderSubtle,
                width: estaSeleccionada ? 1.5 : 1.0,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _toggleFactura(f.nroFacip),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      // Checkbox
                      Checkbox(
                        value: estaSeleccionada,
                        activeColor: const Color(0xFF16A34A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (_) => _toggleFactura(f.nroFacip),
                      ),
                      const SizedBox(width: 8),

                      // Detalle de la Factura
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    mesTexto,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: estaSeleccionada
                                          ? AppColors.darkNavy
                                          : AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _buildBadgeEstadoFactura(f.estaVencida),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              numFacturaTexto,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Monto
                      Text(
                        'Bs ${f.montoBs.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: estaSeleccionada
                              ? const Color(0xFF15803D)
                              : AppColors.darkNavy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 12),

        // Tarjeta resumen de la selección
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_cantSeleccionadas de ${_facturasDisponibles.length} seleccionada(s)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Total Seleccionado',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Text(
                'Bs ${_montoSeleccionado.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.darkNavy,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Botón Principal: Generar Código QR con el monto de las seleccionadas
        ElevatedButton.icon(
          onPressed: _cantSeleccionadas > 0 ? _generarQrParaSeleccion : null,
          icon: const Icon(Icons.qr_code_2_rounded, size: 22),
          label: Text(
            _cantSeleccionadas > 0
                ? 'Generar Código QR (Bs ${_montoSeleccionado.toStringAsFixed(2)})'
                : 'Selecciona al menos una factura',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.pureWhite,
            disabledBackgroundColor: AppColors.borderStrong,
            disabledForegroundColor: AppColors.textSecondary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // PASO 2: Visualización del Código QR Generado (Estático y Alternado)
  // =========================================================================

  Widget _buildVistaQrGenerado(PagosState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barra superior de arrastre
        _buildPillArrastre(),

        // Encabezado con Botón de Regreso a Selección
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: AppColors.darkNavy),
                  tooltip: 'Modificar selección de facturas',
                  onPressed: () {
                    setState(() {
                      _pasoActual = _PasoPagoSheet.seleccionFacturas;
                    });
                  },
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Código QR Generado',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkNavy,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildBadgeDemo(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Suministro #${widget.codSocio} • ${widget.nombreTitular}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textSecondary),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Banner de Entidad Bancaria Alternada (Red Simple QR Bolivia)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _varianteActual.colorPrimario.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _varianteActual.colorPrimario.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.account_balance_rounded,
                  size: 18, color: _varianteActual.colorPrimario),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_varianteActual.bancoNombre} • ${_varianteActual.red}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _varianteActual.colorPrimario,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.pureWhite,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$_cantFacturasFijadas fac.',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNavy,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Tarjeta del Monto Total Fijado
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monto a Cancelar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF166534),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _periodosFijadosQr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF15803D),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Bs ${_montoFijadoQr.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF166534),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Contenedor del Código QR Estático (Congelado mientras se muestra)
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
              data: _payloadQrEstatico,
              version: QrVersions.auto,
              size: 210.0,
              gapless: true,
              eyeStyle: QrEyeStyle(
                eyeShape: _varianteActual.eyeShape,
                color: _varianteActual.colorPrimario,
              ),
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: _varianteActual.moduleShape,
                color: _varianteActual.colorSecundario,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Temporizador de vigencia
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined,
                  size: 16, color: AppColors.warningOrange),
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

        const SizedBox(height: 6),

        const Center(
          child: Text(
            'Escanea este código desde la app de tu banco (BNB, BCP, Mercantil, Ganadero, Unión, etc.)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Botón: Copiar Código QR
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _payloadQrEstatico));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Código de transferencia copiado al portapapeles.'),
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

  // =========================================================================
  // PASO 3: Comprobante Digital Mock tras completar la simulación
  // =========================================================================

  Widget _buildVistaComprobanteExitoso(SimularPagoResponseModel comprobante) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPillArrastre(),

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
              _buildFilaTicket('N° Transacción', comprobante.nroTransaccion,
                  isBold: true),
              const Divider(height: 18),
              _buildFilaTicket('Código de Socio', comprobante.codSocio),
              const Divider(height: 18),
              _buildFilaTicket(
                  'Entidad Receptora', '${_varianteActual.bancoNombre} (Demo)'),
              const Divider(height: 18),
              _buildFilaTicket('Facturas Canceladas',
                  '$_cantFacturasFijadas factura(s) seleccionada(s)'),
              const Divider(height: 18),
              _buildFilaTicket('Periodos', _periodosFijadosQr),
              const Divider(height: 18),
              _buildFilaTicket('Fecha y Hora', comprobante.fechaPago),
              const Divider(height: 18),
              _buildFilaTicket('Monto Cancelado',
                  'Bs ${comprobante.montoBs.toStringAsFixed(2)}',
                  isAmount: true),
              const Divider(height: 18),
              _buildFilaTicket('Estado', 'REGISTRADO EN AUDITORÍA',
                  isStatus: true),
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
                  'Esta es una vista demostrativa de pago. No se debitó dinero ni se modificó su deuda contable real en COSMOL R.L.',
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

  // --- Widgets Auxiliares ---

  Widget _buildPillArrastre() {
    return Center(
      child: Container(
        width: 44,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.borderSubtle,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildBadgeDemo() {
    return Container(
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
    );
  }

  Widget _buildBadgeEstadoFactura(bool estaVencida) {
    if (estaVencida) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Vencida',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.errorRed,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDD5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Impaga',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Color(0xFFC2410C),
        ),
      ),
    );
  }

  Widget _buildFilaTicket(
    String etiqueta,
    String valor, {
    bool isBold = false,
    bool isAmount = false,
    bool isStatus = false,
  }) {
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
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            valor,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: isAmount ? 15 : 12,
              fontWeight: (isBold || isAmount || isStatus)
                  ? FontWeight.bold
                  : FontWeight.w500,
              color: isStatus
                  ? const Color(0xFF16A34A)
                  : isAmount
                      ? AppColors.primary
                      : AppColors.darkNavy,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
