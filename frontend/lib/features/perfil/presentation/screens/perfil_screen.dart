import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Pantalla y Tab de Perfil de Socio, Seguridad y Logout.
class PerfilScreen extends ConsumerWidget {
  final dynamic activeSuministro;

  const PerfilScreen({
    super.key,
    required this.activeSuministro,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.person, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Socio Digital COSMOL',
                        style: AppTextStyles.subtitle1
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Código Activo: ${activeSuministro?.codSocio ?? 'N/A'}',
                        style: AppTextStyles.body2
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Seguridad y Cuenta', style: AppTextStyles.subtitle1),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.fingerprint, color: AppColors.primary),
                  title: const Text('Autenticación Biométrica'),
                  subtitle: const Text('Huella Dactilar o Reconocimiento Facial'),
                  trailing: Switch(
                    value: true,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(val
                              ? 'Biometría habilitada para inicio rápido.'
                              : 'Biometría deshabilitada.'),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1, color: AppColors.borderSubtle),
                ListTile(
                  leading: const Icon(Icons.lock_reset, color: AppColors.primary),
                  title: const Text('Cambiar PIN / Contraseña'),
                  subtitle: const Text('Actualiza tu clave de acceso personal'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Para cambiar su PIN se enviará un OTP a su celular.'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Información Legal', style: AppTextStyles.subtitle1),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.policy_outlined, color: AppColors.primary),
                  title: const Text('Términos del Servicio y Privacidad'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {},
                ),
                const Divider(height: 1, color: AppColors.borderSubtle),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: AppColors.primary),
                  title: const Text('Versión de la App'),
                  trailing: Text('1.0.0', style: AppTextStyles.caption),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          CosmolButton(
            text: 'Cerrar Sesión',
            type: CosmolButtonType.outline,
            icon: Icons.logout,
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }
}
