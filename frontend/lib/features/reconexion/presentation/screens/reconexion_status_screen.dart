import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/widgets/cosmol_app_bar.dart';
import '../../../../core/widgets/cosmol_button.dart';
import '../../../../core/widgets/cosmol_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../multicuenta/presentation/providers/multicuenta_provider.dart';
import '../../data/models/reconexion_tramite_model.dart';
import '../providers/reconexion_provider.dart';

class ReconexionStatusScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;

  const ReconexionStatusScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<ReconexionStatusScreen> createState() =>
      _ReconexionStatusScreenState();
}

class _ReconexionStatusScreenState
    extends ConsumerState<ReconexionStatusScreen> {
  int _paginaActual = 0;
  static const int _itemsPorPagina = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarDatos();
    });
  }

  void _cargarDatos() {
    setState(() {
      _paginaActual = 0;
    });
    final activeSuministro = ref.read(multicuentaProvider).activeSuministro;
    final codSocio = activeSuministro?.codSocio ?? '';
    if (codSocio.isNotEmpty) {
      ref.read(reconexionProvider.notifier).cargarEstado(codSocio);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(multicuentaProvider, (prev, next) {
      if (prev?.activeSuministro?.codSocio != next.activeSuministro?.codSocio) {
        _cargarDatos();
      }
    });

    final state = ref.watch(reconexionProvider);
    final activeSuministro = ref.watch(multicuentaProvider).activeSuministro;

    final codSocioRaw = activeSuministro?.codSocio.trim() ?? '';
    final codSocioElegibilidad = state.elegibilidad?.codigoSocio.trim() ?? '';
    final codSocioAuth = ref.watch(authProvider).activeCodSocio?.trim() ?? '';
    final String codSocio = codSocioRaw.isNotEmpty
        ? codSocioRaw
        : (codSocioElegibilidad.isNotEmpty ? codSocioElegibilidad : codSocioAuth);

    final alias = activeSuministro?.alias ?? 'Socio $codSocio';

    final totalTramites = state.historial.length;
    final totalPaginas = (totalTramites / _itemsPorPagina).ceil();
    final int paginaValida =
        totalPaginas > 0 ? _paginaActual.clamp(0, totalPaginas - 1) : 0;
    final int inicio = paginaValida * _itemsPorPagina;
    final int fin = (inicio + _itemsPorPagina > totalTramites)
        ? totalTramites
        : inicio + _itemsPorPagina;
    final tramitesPagina = totalTramites > 0
        ? state.historial.sublist(inicio, fin)
        : <ReconexionTramiteModel>[];

    final Widget bodyContent = state.isLoading
        ? const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          )
        : RefreshIndicator(
            onRefresh: () async => _cargarDatos(),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Suministro activo
                CosmolCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Socio Activo', style: AppTextStyles.caption),
                          const SizedBox(height: 2),
                          Text(alias, style: AppTextStyles.subtitle1),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.lightBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Text(
                          'Socio: $codSocio',
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Tarjeta de Estado / Elegibilidad
                if (state.errorMessage != null) ...[
                  CosmolCard(
                    backgroundColor: AppColors.errorBackground,
                    border: Border.all(color: AppColors.errorRed),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aviso de Verificación',
                          style: AppTextStyles.subtitle1
                              .copyWith(color: AppColors.errorRed),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          state.errorMessage!,
                          style: AppTextStyles.body2
                              .copyWith(color: AppColors.errorRed),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _cargarDatos,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.errorRed),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                          child: Text(
                            'Reintentar',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.errorRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else if (state.elegibilidad != null) ...[
                  _buildElegibilidadCard(context, state.elegibilidad!),
                  const SizedBox(height: 14),
                ],

                // Sección de Historial de Trámites
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Historial de Solicitudes',
                      style: AppTextStyles.subtitle1,
                    ),
                    if (totalTramites > 0)
                      Text(
                        '$totalTramites ${totalTramites == 1 ? 'solicitud' : 'solicitudes'}',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (state.historial.isEmpty)
                  CosmolCard(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No registra solicitudes de reconexión previas.',
                        style: AppTextStyles.body2,
                      ),
                    ),
                  )
                else ...[
                  ...tramitesPagina
                      .map((tramite) => _buildTramiteCard(tramite, codSocio)),
                  if (totalPaginas > 1) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton(
                          onPressed: paginaValida > 0
                              ? () => setState(
                                  () => _paginaActual = paginaValida - 1)
                              : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            side: BorderSide(
                              color: paginaValida > 0
                                  ? AppColors.primary
                                  : AppColors.borderSubtle,
                            ),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chevron_left,
                                size: 18,
                                color: paginaValida > 0
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Anterior',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: paginaValida > 0
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Pág. ${paginaValida + 1} de $totalPaginas (${inicio + 1}-$fin)',
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        OutlinedButton(
                          onPressed: paginaValida < totalPaginas - 1
                              ? () => setState(
                                  () => _paginaActual = paginaValida + 1)
                              : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            side: BorderSide(
                              color: paginaValida < totalPaginas - 1
                                  ? AppColors.primary
                                  : AppColors.borderSubtle,
                            ),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Siguiente',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: paginaValida < totalPaginas - 1
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: paginaValida < totalPaginas - 1
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          );

    if (widget.isEmbedded) {
      return Container(
        color: AppColors.lightBackground,
        child: bodyContent,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: const CosmolAppBar(
        title: 'Reconexión de Servicio',
      ),
      body: bodyContent,
    );
  }

  Widget _buildElegibilidadCard(BuildContext context, dynamic elegibilidad) {
    if (elegibilidad.motivoBloqueo == 'TRAMITE_DUPLICADO') {
      return CosmolCard(
        backgroundColor: AppColors.warningBackground,
        border: Border.all(color: AppColors.warningOrange),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.warningOrange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Solicitud en Proceso',
                  style: AppTextStyles.subtitle1
                      .copyWith(color: AppColors.warningOrange),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              elegibilidad.mensajeUsuario as String,
              style: AppTextStyles.body2,
            ),
          ],
        ),
      );
    }

    if (elegibilidad.motivoBloqueo == 'ALTA_MOROSIDAD') {
      return CosmolCard(
        backgroundColor: AppColors.errorBackground,
        border: Border.all(color: AppColors.errorRed),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.block, color: AppColors.errorRed, size: 20),
                const SizedBox(width: 8),
                Text(
                  'No Elegible por Deuda',
                  style: AppTextStyles.subtitle1
                      .copyWith(color: AppColors.errorRed),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              elegibilidad.mensajeUsuario as String,
              style: AppTextStyles.body2,
            ),
            const SizedBox(height: 14),
            CosmolButton(
              text: 'Pagar Facturas Pendientes',
              onPressed: () => context.push('/deuda'),
            ),
          ],
        ),
      );
    }

    if (elegibilidad.esElegible == true) {
      return CosmolCard(
        backgroundColor: AppColors.successBackground,
        border: Border.all(color: AppColors.successGreen),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: AppColors.successGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Habilitado',
                  style: AppTextStyles.subtitle1
                      .copyWith(color: AppColors.successGreen),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Usted cumple con los requisitos para solicitar la reactivación del servicio.',
              style: AppTextStyles.body2,
            ),
            const SizedBox(height: 14),
            CosmolButton(
              text: 'Solicitar Reconexión',
              onPressed: () => context.push('/reconexion/solicitar'),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildTramiteCard(ReconexionTramiteModel tramite, String codSocio) {
    Color estadoColor = AppColors.textSecondary;
    Color estadoBg = AppColors.lightBackground;

    if (tramite.isPendiente) {
      estadoColor = AppColors.warningOrange;
      estadoBg = AppColors.warningBackground;
    } else if (tramite.isEnProceso) {
      estadoColor = AppColors.primary;
      estadoBg = AppColors.lightBackground;
    } else if (tramite.isFinalizado) {
      estadoColor = AppColors.successGreen;
      estadoBg = AppColors.successBackground;
    } else if (tramite.isRechazado) {
      estadoColor = AppColors.errorRed;
      estadoBg = AppColors.errorBackground;
    }

    return CosmolCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: () => _mostrarDetalleTramite(context, tramite, codSocio),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  tramite.tipoFormateado,
                  style: AppTextStyles.subtitle1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: estadoBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: estadoColor),
                ),
                child: Text(
                  tramite.estado,
                  style: AppTextStyles.caption.copyWith(
                    color: estadoColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (tramite.fecha != null && tramite.fecha!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  tramite.fecha!,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
          if (tramite.glosa != null && tramite.glosa!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Referencia: ${tramite.glosa}',
              style: AppTextStyles.body2
                  .copyWith(color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Ver más detalles',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right,
                  size: 16, color: AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }

  void _mostrarDetalleTramite(
      BuildContext context, ReconexionTramiteModel tramite, String codSocio) {
    Color estadoColor = AppColors.textSecondary;
    Color estadoBg = AppColors.lightBackground;
    String estadoDescripcion =
        'El trámite se encuentra registrado en el sistema.';

    if (tramite.isPendiente) {
      estadoColor = AppColors.warningOrange;
      estadoBg = AppColors.warningBackground;
      estadoDescripcion =
          'Su solicitud está registrada en cola de espera para asignación técnica.';
    } else if (tramite.isEnProceso) {
      estadoColor = AppColors.primary;
      estadoBg = AppColors.lightBackground;
      estadoDescripcion =
          'Una cuadrilla técnica se encuentra atendiendo la orden de trabajo.';
    } else if (tramite.isFinalizado) {
      estadoColor = AppColors.successGreen;
      estadoBg = AppColors.successBackground;
      estadoDescripcion =
          'El servicio ha sido reconectado y verificado en su acometida.';
    } else if (tramite.isRechazado) {
      estadoColor = AppColors.errorRed;
      estadoBg = AppColors.errorBackground;
      estadoDescripcion =
          'La solicitud no pudo proceder o fue cancelada por normativa comercial.';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Detalle de Solicitud',
                      style: AppTextStyles.subtitle1
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 20, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(bottomSheetContext).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Estado Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: estadoBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: estadoColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            tramite.isFinalizado
                                ? Icons.check_circle_outline
                                : tramite.isPendiente
                                    ? Icons.pending_outlined
                                    : Icons.info_outline,
                            size: 18,
                            color: estadoColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Estado: ${tramite.estado}',
                            style: AppTextStyles.subtitle2.copyWith(
                              color: estadoColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        estadoDescripcion,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetalleFila('Tipo de Reconexión', tramite.tipoFormateado),
                _buildDetalleFila(
                    'Código de Socio', codSocio.isNotEmpty ? codSocio : 'No disponible'),
                if (tramite.fecha != null && tramite.fecha!.isNotEmpty)
                  _buildDetalleFila('Fecha de Solicitud', tramite.fecha!),
                if (tramite.glosa != null &&
                    tramite.glosa!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Referencias y Observaciones:',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.lightBackground,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      tramite.glosa!,
                      style: AppTextStyles.body2,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                CosmolButton(
                  text: 'Entendido',
                  onPressed: () => Navigator.of(bottomSheetContext).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetalleFila(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            etiqueta,
            style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            valor,
            style: AppTextStyles.subtitle2.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
