import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

import '../../../deuda/presentation/providers/deuda_provider.dart';
import '../../../multicuenta/presentation/providers/multicuenta_provider.dart';
import '../../../consumo/presentation/providers/consumo_provider.dart';
import '../../../documentos/presentation/providers/documentos_provider.dart';

class PerfilScreen extends ConsumerStatefulWidget {
  final dynamic activeSuministro;

  const PerfilScreen({
    super.key,
    required this.activeSuministro,
  });

  @override
  ConsumerState<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends ConsumerState<PerfilScreen> {
  bool _biometricEnabled = false;

  void _mostrarInfoModal(BuildContext context, {required String titulo, required String contenido}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: AppTextStyles.h3),
              const SizedBox(height: 16),
              Text(
                contenido,
                style: AppTextStyles.body1.copyWith(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              CosmolButton(
                text: 'Entendido',
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final deudaState = ref.watch(deudaProvider);
    final detalle = deudaState.resumenDeuda?.suministro;

    final nombreTitular = detalle?.nombreTitular ?? '';
    final isTitular = detalle?.rolUsuario == 'TITULAR';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarjeta Principal (Plano sin gradiente)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombreTitular,
                  style: AppTextStyles.h3.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Código de Socio: ${widget.activeSuministro?.codSocio ?? 'N/A'}',
                  style: AppTextStyles.body2.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Información del Socio
          if (detalle != null) ...[
            Text('Información del Socio', style: AppTextStyles.subtitle1),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                children: [
                  _InfoRow(label: 'Rol de Usuario', value: isTitular ? 'Titular' : 'Consulta y Pago'),
                  const Divider(height: 24, color: AppColors.borderSubtle),
                  _InfoRow(label: 'Teléfono', value: detalle.telefonoCelular.isNotEmpty ? detalle.telefonoCelular : 'No registrado'),
                  const Divider(height: 24, color: AppColors.borderSubtle),
                  _InfoRow(label: 'CI', value: detalle.ciNit.isNotEmpty ? detalle.ciNit : 'No registrado'),
                  const Divider(height: 24, color: AppColors.borderSubtle),
                  _InfoRow(label: 'Dirección', value: detalle.direccion.isNotEmpty ? detalle.direccion : 'No registrada'),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],

          Text('Seguridad y Cuenta', style: AppTextStyles.subtitle1),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: Text('Autenticación Biométrica', style: AppTextStyles.body1),
                  subtitle: Text(
                    'Huella o reconocimiento facial',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                  value: _biometricEnabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() {
                      _biometricEnabled = val;
                    });
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(val
                            ? 'Autenticación biométrica habilitada.'
                            : 'Autenticación biométrica deshabilitada.'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, color: AppColors.borderSubtle),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  title: Text('Cambiar PIN / Contraseña', style: AppTextStyles.body1),
                  subtitle: Text(
                    'Actualiza tu clave de acceso',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  onTap: () {
                    _mostrarInfoModal(
                      context,
                      titulo: 'Cambiar PIN / Contraseña',
                      contenido:
                          'Para actualizar su clave de acceso personal de forma segura, el sistema enviará un código de verificación único (OTP) de 6 dígitos al número de celular registrado en su perfil.\n\nPodrá elegir recibir el código por WhatsApp o SMS.',
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Text('Acerca de', style: AppTextStyles.subtitle1),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  title: Text('Términos y Privacidad', style: AppTextStyles.body1),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  onTap: () {
                    _mostrarInfoModal(
                      context,
                      titulo: 'Términos del Servicio y Privacidad',
                      contenido:
                          'COSMOL R.L. garantiza la seguridad y confidencialidad de la información personal y de consumo de todos los asociados.\n\nLos datos recolectados en la plataforma son utilizados exclusivamente para la gestión de servicios de agua potable y saneamiento, la consulta de avisos y la facilitación del pago electrónico de facturas.',
                    );
                  },
                ),
                const Divider(height: 1, color: AppColors.borderSubtle),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  title: Text('Versión de la App', style: AppTextStyles.body1),
                  trailing: Text('1.0.0', style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
          CosmolButton(
            text: 'Cerrar Sesión',
            type: CosmolButtonType.outline,
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              ref.invalidate(deudaProvider);
              ref.invalidate(multicuentaProvider);
              ref.invalidate(consumoProvider);
              ref.invalidate(documentosProvider);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w500),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
