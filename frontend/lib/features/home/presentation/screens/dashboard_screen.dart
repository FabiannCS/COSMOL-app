import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../multicuenta/presentation/widgets/suministro_selector_dropdown.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const SuministroSelectorDropdown(),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola, socio',
                style: AppTextStyles.h2,
              ),
              const SizedBox(height: 8),
              Text(
                'Consulta de Deuda y Estado de Servicio',
                style: AppTextStyles.body2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

