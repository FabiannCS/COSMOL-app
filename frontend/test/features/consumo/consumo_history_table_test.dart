import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmol_app/features/consumo/data/models/consumo_factura_model.dart';
import 'package:cosmol_app/features/consumo/presentation/providers/consumo_provider.dart';
import 'package:cosmol_app/features/consumo/presentation/widgets/consumo_history_table.dart';

void main() {
  testWidgets('ConsumoHistoryTable muestra estados Pagada, Vencida e Impaga según las reglas', (tester) async {
    final facturas = [
      const ConsumoPeriodoModel(
        periodo: '01/2026',
        mes: 1,
        mesNombre: 'Enero 2026',
        anio: 2026,
        consumoM3: 15.0,
        montoBs: 50.0,
        lecturaAnterior: 100,
        lecturaActual: 115,
        estadoLectura: 'PAGADA',
      ),
      const ConsumoPeriodoModel(
        periodo: '02/2026',
        mes: 2,
        mesNombre: 'Febrero 2026',
        anio: 2026,
        consumoM3: 16.0,
        montoBs: 55.0,
        lecturaAnterior: 115,
        lecturaActual: 131,
        estadoLectura: 'PAGADA',
      ),
      const ConsumoPeriodoModel(
        periodo: '03/2026',
        mes: 3,
        mesNombre: 'Marzo 2026',
        anio: 2026,
        consumoM3: 18.0,
        montoBs: 60.0,
        lecturaAnterior: 131,
        lecturaActual: 149,
        estadoLectura: 'IMPAGA',
      ),
      const ConsumoPeriodoModel(
        periodo: '04/2026',
        mes: 4,
        mesNombre: 'Abril 2026',
        anio: 2026,
        consumoM3: 20.0,
        montoBs: 70.0,
        lecturaAnterior: 149,
        lecturaActual: 169,
        estadoLectura: 'IMPAGA',
      ),
      const ConsumoPeriodoModel(
        periodo: '05/2026',
        mes: 5,
        mesNombre: 'Mayo 2026',
        anio: 2026,
        consumoM3: 22.0,
        montoBs: 80.0,
        lecturaAnterior: 169,
        lecturaActual: 191,
        estadoLectura: 'IMPAGA',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConsumoHistoryTable(
              facturas: facturas,
              periodo: PeriodoConsumo.seisMeses,
              tarifaReferencial: 3.5,
              selectedIndex: 0,
              onSelectMes: (_) {},
              onExportarPdf: () {},
            ),
          ),
        ),
      ),
    );

    // Debe mostrar exactamente:
    // 2 chips "Pagada"
    // 1 chip "Vencida" (para Marzo, la primera impaga)
    // 2 chips "Impaga" (para Abril y Mayo)
    // 0 chips "Pendiente"
    expect(find.text('Pagada'), findsNWidgets(2));
    expect(find.text('Vencida'), findsOneWidget);
    expect(find.text('Impaga'), findsNWidgets(2));
    expect(find.text('Pendiente'), findsNothing);
  });

  testWidgets('ConsumoHistoryTable con 6 facturas (5 impagas) muestra 1 Pagada, 3 Vencidas y 2 Impagas', (tester) async {
    final facturas = [
      const ConsumoPeriodoModel(
        periodo: '01/2026',
        mes: 1,
        mesNombre: 'Enero 2026',
        anio: 2026,
        consumoM3: 15.0,
        montoBs: 50.0,
        lecturaAnterior: 100,
        lecturaActual: 115,
        estadoLectura: 'PAGADA',
      ),
      const ConsumoPeriodoModel(
        periodo: '02/2026',
        mes: 2,
        mesNombre: 'Febrero 2026',
        anio: 2026,
        consumoM3: 16.0,
        montoBs: 55.0,
        lecturaAnterior: 115,
        lecturaActual: 131,
        estadoLectura: 'IMPAGA',
      ),
      const ConsumoPeriodoModel(
        periodo: '03/2026',
        mes: 3,
        mesNombre: 'Marzo 2026',
        anio: 2026,
        consumoM3: 18.0,
        montoBs: 60.0,
        lecturaAnterior: 131,
        lecturaActual: 149,
        estadoLectura: 'IMPAGA',
      ),
      const ConsumoPeriodoModel(
        periodo: '04/2026',
        mes: 4,
        mesNombre: 'Abril 2026',
        anio: 2026,
        consumoM3: 20.0,
        montoBs: 70.0,
        lecturaAnterior: 149,
        lecturaActual: 169,
        estadoLectura: 'IMPAGA',
      ),
      const ConsumoPeriodoModel(
        periodo: '05/2026',
        mes: 5,
        mesNombre: 'Mayo 2026',
        anio: 2026,
        consumoM3: 22.0,
        montoBs: 80.0,
        lecturaAnterior: 169,
        lecturaActual: 191,
        estadoLectura: 'IMPAGA',
      ),
      const ConsumoPeriodoModel(
        periodo: '06/2026',
        mes: 6,
        mesNombre: 'Junio 2026',
        anio: 2026,
        consumoM3: 25.0,
        montoBs: 90.0,
        lecturaAnterior: 191,
        lecturaActual: 216,
        estadoLectura: 'IMPAGA',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConsumoHistoryTable(
              facturas: facturas,
              periodo: PeriodoConsumo.seisMeses,
              tarifaReferencial: 3.5,
              selectedIndex: 0,
              onSelectMes: (_) {},
              onExportarPdf: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Pagada'), findsOneWidget);
    expect(find.text('Vencida'), findsNWidgets(3));
    expect(find.text('Impaga'), findsNWidgets(2));
    expect(find.text('Pendiente'), findsNothing);
  });
}

