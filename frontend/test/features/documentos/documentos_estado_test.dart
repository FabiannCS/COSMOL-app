import 'dart:typed_data';
import 'package:cosmol_app/core/services/storage_service.dart';
import 'package:cosmol_app/features/auth/data/models/login_response_model.dart';
import 'package:cosmol_app/features/documentos/data/models/documento_model.dart';
import 'package:cosmol_app/features/documentos/domain/repositories/documentos_repository.dart';
import 'package:cosmol_app/features/documentos/presentation/providers/documentos_provider.dart';
import 'package:cosmol_app/features/documentos/presentation/screens/documentos_screen.dart';
import 'package:cosmol_app/features/documentos/presentation/widgets/document_card_widget.dart';
import 'package:cosmol_app/features/multicuenta/domain/repositories/multicuenta_repository.dart';
import 'package:cosmol_app/features/multicuenta/presentation/providers/multicuenta_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStorageService implements StorageService {
  @override
  Future<void> clearAuthData() async {}
  @override
  Future<String?> getAccessToken() async => 'fake-token';
  @override
  Future<String?> getActiveCodSocio() async => '23807';
  @override
  bool getBool(String key, {bool defaultValue = false}) => defaultValue;
  @override
  Map<String, dynamic>? getCachedDeuda(String codSocio) => null;
  @override
  List<Map<String, dynamic>>? getCachedSuministros() => null;
  @override
  DateTime? getDeudaSyncTime(String codSocio) => null;
  @override
  Future<String?> getDeviceId() async => 'dev-1';
  @override
  Future<String?> getRefreshToken() async => 'refresh-1';
  @override
  Future<void> init() async {}
  @override
  Future<void> saveActiveCodSocio(String codSocio) async {}
  @override
  Future<void> saveCachedDeuda(String codSocio, Map<String, dynamic> data) async {}
  @override
  Future<void> saveCachedSuministros(List<Map<String, dynamic>> data) async {}
  @override
  Future<void> saveDeviceId(String deviceId) async {}
  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {}
  @override
  Future<void> setBool(String key, bool value) async {}
  @override
  Future<void> saveReadNotificationIds(Set<String> ids) async {}
  @override
  Set<String> getReadNotificationIds() => <String>{};
}

class _FakeMulticuentaRepository implements MulticuentaRepository {
  @override
  Future<void> desvincularSuministro(String codSocio) async {}

  @override
  Future<List<SuministroModel>> listarSuministros() async => const [
        SuministroModel(
          id: 'sum-1',
          codSocio: '23807',
          alias: 'Casa Principal',
          rol: 'TITULAR',
          esSuministroPrincipal: true,
        ),
      ];

  @override
  Future<SuministroModel> vincularSuministro({
    required String codSocio,
    String? ciOMedidor,
    required String alias,
  }) async {
    return SuministroModel(
      id: 'sum-2',
      codSocio: codSocio,
      alias: alias,
      rol: 'TITULAR',
      esSuministroPrincipal: false,
    );
  }
}

class _FakeDocumentosRepository implements DocumentosRepository {
  final ListaDocumentosModel response;

  _FakeDocumentosRepository(this.response);

  @override
  Future<Uint8List> descargarPdfBytes({required String docId}) async {
    return Uint8List.fromList([37, 80, 68, 70]);
  }

  @override
  Future<ListaDocumentosModel> obtenerDocumentos({
    required String codSocio,
    String? tipo,
  }) async {
    return response;
  }
}

DocumentoModel _crearDoc({
  required String id,
  required String tipoDocumento,
  required int anio,
  required int mes,
  String estadoPago = 'PENDIENTE',
  double montoBs = 60.0,
}) {
  final mm = mes.toString().padLeft(2, '0');
  return DocumentoModel(
    id: id,
    codSocio: '23807',
    tipoDocumento: tipoDocumento,
    nroFactura: tipoDocumento == 'FACTURA' ? 'F-$mes$anio' : null,
    nroFacip: tipoDocumento == 'AVISO_COBRANZA' ? 'AV-$mes$anio' : null,
    periodo: '$mm/$anio',
    anio: anio,
    mes: mes,
    montoBs: montoBs,
    fechaEmision: DateTime(anio, mes, 1),
    fechaVencimiento: DateTime(anio, mes, 28),
    estadoPago: estadoPago,
    fechaPago: estadoPago == 'PAGADO' ? '$anio-$mm-20' : null,
  );
}

void main() {
  group('Reglas de Negocio - Estados en Documentos (Factura y Cobranza)', () {
    test('Facturas con <= 2 impagas marcan las no pagadas como impaga y las pagadas como pagada', () {
      final facturas = [
        _crearDoc(id: 'f1', tipoDocumento: 'FACTURA', anio: 2026, mes: 1, estadoPago: 'PAGADO'),
        _crearDoc(id: 'f2', tipoDocumento: 'FACTURA', anio: 2026, mes: 2, estadoPago: 'PENDIENTE'),
        _crearDoc(id: 'f3', tipoDocumento: 'FACTURA', anio: 2026, mes: 3, estadoPago: 'PENDIENTE'),
      ];

      expect(facturas.obtenerEstadoDocumento(facturas[0]), EstadoDocumento.pagada);
      expect(facturas.obtenerEstadoDocumento(facturas[1]), EstadoDocumento.impaga);
      expect(facturas.obtenerEstadoDocumento(facturas[2]), EstadoDocumento.impaga);
    });

    test('Facturas con 5 impagas (orden descendente como BFF): 2 recientes impagas, 3 antiguas vencidas', () {
      final facturasDesc = [
        _crearDoc(id: 'f6', tipoDocumento: 'FACTURA', anio: 2026, mes: 6, estadoPago: 'PENDIENTE'),
        _crearDoc(id: 'f5', tipoDocumento: 'FACTURA', anio: 2026, mes: 5, estadoPago: 'PENDIENTE'),
        _crearDoc(id: 'f4', tipoDocumento: 'FACTURA', anio: 2026, mes: 4, estadoPago: 'PENDIENTE'),
        _crearDoc(id: 'f3', tipoDocumento: 'FACTURA', anio: 2026, mes: 3, estadoPago: 'PENDIENTE'),
        _crearDoc(id: 'f2', tipoDocumento: 'FACTURA', anio: 2026, mes: 2, estadoPago: 'PENDIENTE'),
        _crearDoc(id: 'f1', tipoDocumento: 'FACTURA', anio: 2026, mes: 1, estadoPago: 'PAGADO'),
      ];

      final estados = facturasDesc.map((d) => facturasDesc.obtenerEstadoDocumento(d)).toList();

      expect(estados, [
        EstadoDocumento.impaga,  // Junio
        EstadoDocumento.impaga,  // Mayo
        EstadoDocumento.vencida, // Abril
        EstadoDocumento.vencida, // Marzo
        EstadoDocumento.vencida, // Febrero
        EstadoDocumento.pagada,  // Enero
      ]);
    });

    test('Avisos de Cobranza con 3 impagos: [pagada, pagada, vencida, impaga, impaga]', () {
      final cobranzas = [
        _crearDoc(id: 'c1', tipoDocumento: 'AVISO_COBRANZA', anio: 2026, mes: 1, estadoPago: 'PAGADO'),
        _crearDoc(id: 'c2', tipoDocumento: 'AVISO_COBRANZA', anio: 2026, mes: 2, estadoPago: 'PAGADO'),
        _crearDoc(id: 'c3', tipoDocumento: 'AVISO_COBRANZA', anio: 2026, mes: 3, estadoPago: 'PENDIENTE'),
        _crearDoc(id: 'c4', tipoDocumento: 'AVISO_COBRANZA', anio: 2026, mes: 4, estadoPago: 'PENDIENTE'),
        _crearDoc(id: 'c5', tipoDocumento: 'AVISO_COBRANZA', anio: 2026, mes: 5, estadoPago: 'PENDIENTE'),
      ];

      final estados = cobranzas.map((c) => cobranzas.obtenerEstadoDocumento(c)).toList();

      expect(estados, [
        EstadoDocumento.pagada,
        EstadoDocumento.pagada,
        EstadoDocumento.vencida,
        EstadoDocumento.impaga,
        EstadoDocumento.impaga,
      ]);
    });
  });

  group('Widgets Documentos - DocumentCardWidget y DocumentosScreen', () {
    testWidgets('DocumentCardWidget muestra Pagada, Impaga, Vencida, Corte y nunca Pendiente', (tester) async {
      final docPagada = _crearDoc(id: '1', tipoDocumento: 'FACTURA', anio: 2026, mes: 1, estadoPago: 'PAGADO');
      final docImpaga = _crearDoc(id: '2', tipoDocumento: 'FACTURA', anio: 2026, mes: 5, estadoPago: 'PENDIENTE');
      final docVencida = _crearDoc(id: '3', tipoDocumento: 'AVISO_COBRANZA', anio: 2026, mes: 2, estadoPago: 'PENDIENTE');
      final docCorte = _crearDoc(id: '4', tipoDocumento: 'AVISO_CORTE', anio: 2026, mes: 6, estadoPago: 'PENDIENTE');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  DocumentCardWidget(
                    documento: docPagada,
                    estadoDocumento: EstadoDocumento.pagada,
                    onVer: () {},
                    onDescargar: () {},
                    onCompartir: () {},
                  ),
                  DocumentCardWidget(
                    documento: docImpaga,
                    estadoDocumento: EstadoDocumento.impaga,
                    onVer: () {},
                    onDescargar: () {},
                    onCompartir: () {},
                  ),
                  DocumentCardWidget(
                    documento: docVencida,
                    estadoDocumento: EstadoDocumento.vencida,
                    onVer: () {},
                    onDescargar: () {},
                    onCompartir: () {},
                  ),
                  DocumentCardWidget(
                    documento: docCorte,
                    onVer: () {},
                    onDescargar: () {},
                    onCompartir: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Pagada'), findsOneWidget);
      expect(find.text('Impaga'), findsOneWidget);
      expect(find.text('Vencida'), findsOneWidget);
      expect(find.text('Corte'), findsOneWidget);
      expect(find.text('Pendiente'), findsNothing);
    });

    testWidgets('DocumentCardWidget en estado Vencida mantiene PDF por defecto y muestra solo aviso en filtro Vencidas', (tester) async {
      final docFacturaVencida = _crearDoc(
        id: 'fv-1',
        tipoDocumento: 'FACTURA',
        anio: 2026,
        mes: 8,
        estadoPago: 'PENDIENTE',
      );
      final docCobranzaVencida = _crearDoc(
        id: 'cv-1',
        tipoDocumento: 'AVISO_COBRANZA',
        anio: 2026,
        mes: 7,
        estadoPago: 'PENDIENTE',
      );
      var accionesInvocadas = 0;

      // 1) En vista "Todas" (mostrarSoloAvisoVencida = false): se muestra como tarjeta normal con Ver PDF/Descargar/Compartir
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  DocumentCardWidget(
                    documento: docFacturaVencida,
                    estadoDocumento: EstadoDocumento.vencida,
                    initiallyExpanded: true,
                    onVer: () => accionesInvocadas++,
                    onDescargar: () => accionesInvocadas++,
                    onCompartir: () => accionesInvocadas++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Agosto 2026'), findsOneWidget);
      expect(find.text('Factura #F-82026'), findsOneWidget);
      expect(find.text('Vencida'), findsOneWidget);
      expect(find.text('Aviso de Factura Vencida'), findsNothing);
      expect(find.text('Ver PDF').hitTestable(), findsOneWidget);
      expect(find.text('Descargar').hitTestable(), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined).hitTestable(), findsOneWidget);

      // 2) En filtro "Vencidas" (mostrarSoloAvisoVencida = true): se muestra solo como aviso sin PDF
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  DocumentCardWidget(
                    documento: docFacturaVencida,
                    estadoDocumento: EstadoDocumento.vencida,
                    mostrarSoloAvisoVencida: true,
                    initiallyExpanded: true,
                    onVer: () => accionesInvocadas++,
                    onDescargar: () => accionesInvocadas++,
                    onCompartir: () => accionesInvocadas++,
                  ),
                  DocumentCardWidget(
                    documento: docCobranzaVencida,
                    estadoDocumento: EstadoDocumento.vencida,
                    mostrarSoloAvisoVencida: true,
                    initiallyExpanded: true,
                    onVer: () => accionesInvocadas++,
                    onDescargar: () => accionesInvocadas++,
                    onCompartir: () => accionesInvocadas++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Aviso de Factura Vencida'), findsOneWidget);
      expect(find.text('Aviso de Cobranza Vencido'), findsOneWidget);
      expect(find.text('Vencida'), findsNWidgets(2));
      expect(find.byIcon(Icons.warning_amber_rounded), findsNWidgets(2));
      expect(find.text('Ver PDF'), findsNothing);
      expect(find.text('Descargar'), findsNothing);
      expect(find.byIcon(Icons.share_outlined), findsNothing);
      expect(accionesInvocadas, 0);
    });

    testWidgets('DocumentosScreen oculta Corte; en Todas muestra Vencida como documento con PDF y en Vencidas solo como aviso', (tester) async {
      final response = ListaDocumentosModel(
        codSocio: '23807',
        rolAcceso: 'TITULAR',
        totalDocumentos: 11,
        facturas: [
          _crearDoc(id: 'f5', tipoDocumento: 'FACTURA', anio: 2026, mes: 5, estadoPago: 'PENDIENTE'),
          _crearDoc(id: 'f4', tipoDocumento: 'FACTURA', anio: 2026, mes: 4, estadoPago: 'PENDIENTE'),
          _crearDoc(id: 'f3', tipoDocumento: 'FACTURA', anio: 2026, mes: 3, estadoPago: 'PENDIENTE'),
          _crearDoc(id: 'f2', tipoDocumento: 'FACTURA', anio: 2026, mes: 2, estadoPago: 'PAGADO'),
          _crearDoc(id: 'f1', tipoDocumento: 'FACTURA', anio: 2026, mes: 1, estadoPago: 'PAGADO'),
        ],
        avisosCobranza: [
          _crearDoc(id: 'c5', tipoDocumento: 'AVISO_COBRANZA', anio: 2026, mes: 5, estadoPago: 'PENDIENTE'),
          _crearDoc(id: 'c4', tipoDocumento: 'AVISO_COBRANZA', anio: 2026, mes: 4, estadoPago: 'PENDIENTE'),
          _crearDoc(id: 'c3', tipoDocumento: 'AVISO_COBRANZA', anio: 2026, mes: 3, estadoPago: 'PENDIENTE'),
          _crearDoc(id: 'c2', tipoDocumento: 'AVISO_COBRANZA', anio: 2026, mes: 2, estadoPago: 'PAGADO'),
          _crearDoc(id: 'c1', tipoDocumento: 'AVISO_COBRANZA', anio: 2026, mes: 1, estadoPago: 'PAGADO'),
        ],
        avisosCorte: [
          _crearDoc(id: 'corte-1', tipoDocumento: 'AVISO_CORTE', anio: 2026, mes: 5, estadoPago: 'PENDIENTE'),
        ],
        documentos: const [],
      );

      final fakeRepo = _FakeDocumentosRepository(response);
      const suministro = SuministroModel(
        id: 'sum-1',
        codSocio: '23807',
        alias: 'Casa Principal',
        rol: 'TITULAR',
        esSuministroPrincipal: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            multicuentaProvider.overrideWith(
              (ref) => MulticuentaNotifier(
                repository: _FakeMulticuentaRepository(),
                storageService: _FakeStorageService(),
                initialSuministros: const [suministro],
                initialCodSocio: '23807',
              ),
            ),
            documentosProvider.overrideWith(
              (ref) => DocumentosNotifier(
                repository: fakeRepo,
                initialCodSocio: '23807',
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DocumentosScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // La pestaña Corte no debe existir aunque el backend envie avisosCorte
      expect(find.text('Factura'), findsOneWidget);
      expect(find.text('Cobranza'), findsOneWidget);
      expect(find.text('Corte'), findsNothing);

      // Pestaña Factura (filtro Todas): la vencida (Marzo 2026) aparece como factura normal, NO como aviso
      expect(find.text('Todas (5)'), findsOneWidget);
      expect(find.text('Pagadas (2)'), findsOneWidget);
      expect(find.text('Impagas (2)'), findsOneWidget);
      expect(find.text('Vencidas (1)'), findsOneWidget);
      expect(find.text('Pagada'), findsNWidgets(2));
      expect(find.text('Impaga'), findsNWidgets(2));
      expect(find.text('Vencida'), findsOneWidget);
      expect(find.text('Aviso de Factura Vencida'), findsNothing);
      expect(find.text('Factura #F-32026'), findsOneWidget);
      expect(find.text('Pendiente'), findsNothing);
      expect(find.text('Pendientes (3)'), findsNothing);

      // Al expandir Marzo 2026 (Vencida) dentro de "Todas", muestra sus botones de PDF
      await tester.ensureVisible(find.text('Marzo 2026'));
      await tester.tap(find.text('Marzo 2026'));
      await tester.pumpAndSettle();
      expect(find.text('Ver PDF').hitTestable(), findsOneWidget);
      expect(find.text('Descargar').hitTestable(), findsOneWidget);

      // Al filtrar por "Vencidas (1)", se muestra únicamente como tarjeta de aviso sin Ver PDF / Descargar / Compartir
      await tester.ensureVisible(find.text('Vencidas (1)'));
      await tester.tap(find.text('Vencidas (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Vencida'), findsOneWidget);
      expect(find.text('Aviso de Factura Vencida'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('Ver PDF'), findsNothing);
      expect(find.text('Descargar'), findsNothing);
      expect(find.byIcon(Icons.share_outlined), findsNothing);
      expect(find.text('Impaga'), findsNothing);
      expect(find.text('Pagada'), findsNothing);

      // Cambiar a pestaña Cobranza (por defecto en Todas)
      await tester.ensureVisible(find.text('Cobranza'));
      await tester.tap(find.text('Cobranza'));
      await tester.pumpAndSettle();

      expect(find.text('Todas (5)'), findsOneWidget);
      expect(find.text('Pagadas (2)'), findsOneWidget);
      expect(find.text('Impagas (2)'), findsOneWidget);
      expect(find.text('Vencidas (1)'), findsOneWidget);
      expect(find.text('Pagada'), findsNWidgets(2));
      expect(find.text('Impaga'), findsNWidgets(2));
      expect(find.text('Vencida'), findsOneWidget);
      expect(find.text('Aviso de Cobranza Vencido'), findsNothing);
      expect(find.text('Aviso Cobranza N° AV-32026'), findsOneWidget);
      expect(find.text('Pendiente'), findsNothing);

      // En Cobranza -> filtro "Vencidas (1)", también aparece únicamente como aviso sin PDF
      await tester.ensureVisible(find.text('Vencidas (1)'));
      await tester.tap(find.text('Vencidas (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Aviso de Cobranza Vencido'), findsOneWidget);
      expect(find.text('Vencida'), findsOneWidget);
      expect(find.text('Ver PDF'), findsNothing);
      expect(find.text('Descargar'), findsNothing);
      expect(find.byIcon(Icons.share_outlined), findsNothing);
    });
  });
}
