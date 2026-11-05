import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../providers/auth_provider.dart';

enum _PasoTransferencia {
  advertencia,
  verificarOtp,
}

/// Modal interactivo de advertencia y confirmación de traspaso de sesión única
/// (Modelo WhatsApp / Single Device Policy con autorización OTP).
class TransferenciaDispositivoModal extends ConsumerStatefulWidget {
  final String codSocio;

  const TransferenciaDispositivoModal({
    super.key,
    required this.codSocio,
  });

  static Future<void> show(
    BuildContext context, {
    required String codSocio,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransferenciaDispositivoModal(codSocio: codSocio),
    );
  }

  @override
  ConsumerState<TransferenciaDispositivoModal> createState() =>
      _TransferenciaDispositivoModalState();
}

class _TransferenciaDispositivoModalState
    extends ConsumerState<TransferenciaDispositivoModal> {
  _PasoTransferencia _paso = _PasoTransferencia.advertencia;
  String _canalSeleccionado = 'WHATSAPP';
  final TextEditingController _otpController = TextEditingController();

  // Temporizador para reenvío de OTP (60s)
  int _segundosReenvio = 60;
  Timer? _timerReenvio;

  @override
  void dispose() {
    _timerReenvio?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _iniciarContadorReenvio() {
    setState(() {
      _segundosReenvio = 60;
    });
    _timerReenvio?.cancel();
    _timerReenvio = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_segundosReenvio > 1) {
        if (mounted) {
          setState(() {
            _segundosReenvio--;
          });
        }
      } else {
        timer.cancel();
        if (mounted) {
          setState(() {
            _segundosReenvio = 0;
          });
        }
      }
    });
  }

  Future<void> _enviarCodigoOtp() async {
    final success = await ref
        .read(authProvider.notifier)
        .solicitarOtpTransferencia(canal: _canalSeleccionado);

    if (success && mounted) {
      setState(() {
        _paso = _PasoTransferencia.verificarOtp;
      });
      _iniciarContadorReenvio();
    }
  }

  Future<void> _confirmarTraspaso() async {
    final codigo = _otpController.text.trim();
    if (codigo.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingrese el código completo de 6 dígitos.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final success = await ref
        .read(authProvider.notifier)
        .confirmarTransferenciaDispositivo(
          codSocio: widget.codSocio,
          codigoOtp: codigo,
        );

    if (success && mounted) {
      Navigator.of(context).pop(); // Cerrar modal
      context.go('/dashboard');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Sesión transferida exitosamente a este equipo!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    }
  }

  void _cancelarYSalir() {
    ref.read(authProvider.notifier).cancelarTransferencia();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Transferencia cancelada. Su sesión en el equipo anterior sigue activa.',
        ),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.90,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: _paso == _PasoTransferencia.advertencia
                  ? _buildPasoAdvertencia(authState)
                  : _buildPasoVerificarOtp(authState),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // PASO 1: Advertencia de sesión activa en otro dispositivo
  // =========================================================================
  Widget _buildPasoAdvertencia(AuthState state) {
    final modeloAnterior =
        state.dispositivoAnteriorModelo ?? 'Otro teléfono móvil';
    final telefono = state.telefonoEnmascarado ?? 'su celular';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barra de arrastre
        _buildPillArrastre(),

        // Encabezado
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.devices_other_rounded,
                    color: Color(0xFFD97706),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sesión activa detectada',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkNavy,
                      ),
                    ),
                    Text(
                      'Seguridad de sesión única (COSMOL R.L.)',
                      style: TextStyle(
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
              onPressed: _cancelarYSalir,
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Tarjeta con el equipo que tiene la sesión activa
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.smartphone_rounded,
                      color: Color(0xFFB45309), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sesión abierta en: $modeloAnterior',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'ACTIVO',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Por políticas de seguridad de la cooperativa, solo se permite un dispositivo a la vez. Si inicias sesión en este equipo, la sesión anterior se cerrará permanentemente.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF78350F),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Información de autorización OTP
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined,
                  color: Color(0xFF16A34A), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Autorización requerida por código OTP',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF166534),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Te enviaremos un código de seguridad de 6 dígitos a tu celular registrado $telefono para validar que eres el titular.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF15803D),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Selector de canal
        const Text(
          'Canal de entrega del código:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.darkNavy,
          ),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _buildOpcionCanal(
                id: 'WHATSAPP',
                titulo: 'WhatsApp',
                subtitulo: 'Recomendado',
                icono: Icons.chat_rounded,
                colorIcono: const Color(0xFF25D366),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildOpcionCanal(
                id: 'SMS',
                titulo: 'Mensaje SMS',
                subtitulo: 'Tradicional',
                icono: Icons.sms_rounded,
                colorIcono: AppColors.primary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        if (state.errorMessage != null) ...[
          Text(
            state.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.errorRed, fontSize: 12),
          ),
          const SizedBox(height: 10),
        ],

        // Botón Principal: Continuar y Enviar Código
        ElevatedButton(
          onPressed: state.isLoading ? null : _enviarCodigoOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.pureWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 2,
          ),
          child: state.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Continuar y Recibir Código OTP',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 10),

        // Botón Secundario: Cancelar y Mantener Equipo Anterior
        OutlinedButton(
          onPressed: _cancelarYSalir,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.borderSubtle),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text('Cancelar y Mantener Equipo Anterior'),
        ),
      ],
    );
  }

  // =========================================================================
  // PASO 2: Ingreso y Verificación de Código OTP (con demostración en pantalla)
  // =========================================================================
  Widget _buildPasoVerificarOtp(AuthState state) {
    final telefono = state.telefonoEnmascarado ?? 'su celular';
    final debugOtp = state.debugCodigoOtp ?? '123456';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPillArrastre(),

        // Encabezado con flecha atrás
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.darkNavy),
              onPressed: () {
                setState(() {
                  _paso = _PasoTransferencia.advertencia;
                });
              },
            ),
            const Text(
              'Confirmar Traspaso de Sesión',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.darkNavy,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textSecondary),
              onPressed: _cancelarYSalir,
            ),
          ],
        ),

        const SizedBox(height: 12),

        Center(
          child: Text(
            'Ingresa el código de 6 dígitos enviado a $telefono vía $_canalSeleccionado.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),

        const SizedBox(height: 14),

        // BANNER DE DEMOSTRACIÓN (Requerimiento especial del usuario)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF93C5FD)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.science_rounded,
                      color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'MODO DEMOSTRACIÓN (OTP del Servidor)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      _otpController.text = debugOtp;
                    },
                    icon: const Icon(Icons.touch_app_rounded, size: 14),
                    label: const Text(
                      'Pegar',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Código generado: ',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                  ),
                  Text(
                    debugOtp,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Campo de entrada OTP de 6 dígitos
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: 14,
            color: AppColors.darkNavy,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••••',
            hintStyle: const TextStyle(
              letterSpacing: 14,
              color: AppColors.borderStrong,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Temporizador de reenvío
        Center(
          child: _segundosReenvio > 0
              ? Text(
                  'Reenviar código en $_segundosReenvio s',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                )
              : TextButton(
                  onPressed: state.isLoading ? null : _enviarCodigoOtp,
                  child: const Text(
                    '¿No recibiste el código? Reenviar OTP',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
        ),

        const SizedBox(height: 14),

        if (state.errorMessage != null) ...[
          Text(
            state.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.errorRed, fontSize: 12),
          ),
          const SizedBox(height: 10),
        ],

        // Botón de Confirmación Definitiva
        ElevatedButton(
          onPressed: state.isTransferring ? null : _confirmarTraspaso,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: AppColors.pureWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 2,
          ),
          child: state.isTransferring
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
                      'Confirmar e Iniciar en Este Equipo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 10),

        OutlinedButton(
          onPressed: _cancelarYSalir,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.borderSubtle),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text('Cancelar Transferencia'),
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

  Widget _buildOpcionCanal({
    required String id,
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required Color colorIcono,
  }) {
    final bool seleccionado = _canalSeleccionado == id;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _canalSeleccionado = id;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: seleccionado ? const Color(0xFFF0FDF4) : AppColors.pureWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado
                ? const Color(0xFF22C55E)
                : AppColors.borderSubtle,
            width: seleccionado ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icono, color: colorIcono, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: seleccionado
                          ? AppColors.darkNavy
                          : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

