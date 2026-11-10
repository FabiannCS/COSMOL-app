import 'package:flutter_test/flutter_test.dart';
import 'package:cosmol_app/features/consumo/data/models/consumo_factura_model.dart';

void main() {
  group('Reglas de Negocio - Estados de Facturas en Historial de Consumo', () {
    test('Todas pagadas retornan EstadoFacturaConsumo.pagada', () {
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
          estadoLectura: 'NORMAL',
        ),
        const ConsumoPeriodoModel(
          periodo: '02/2026',
          mes: 2,
          mesNombre: 'Febrero 2026',
          anio: 2026,
          consumoM3: 18.0,
          montoBs: 60.0,
          lecturaAnterior: 115,
          lecturaActual: 133,
          estadoLectura: 'PAGADA',
        ),
      ];

      expect(facturas.obtenerEstadoFactura(facturas[0]), EstadoFacturaConsumo.pagada);
      expect(facturas.obtenerEstadoFactura(facturas[1]), EstadoFacturaConsumo.pagada);
    });

    test('Una sola factura no pagada retorna EstadoFacturaConsumo.impaga (no vencida)', () {
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
          consumoM3: 18.0,
          montoBs: 60.0,
          lecturaAnterior: 115,
          lecturaActual: 133,
          estadoLectura: 'IMPAGA',
        ),
      ];

      expect(facturas.obtenerEstadoFactura(facturas[0]), EstadoFacturaConsumo.pagada);
      expect(facturas.obtenerEstadoFactura(facturas[1]), EstadoFacturaConsumo.impaga);
    });

    test('Dos facturas no pagadas retornan ambas EstadoFacturaConsumo.impaga (<= 2)', () {
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
          consumoM3: 18.0,
          montoBs: 60.0,
          lecturaAnterior: 115,
          lecturaActual: 133,
          estadoLectura: 'IMPAGA',
        ),
        const ConsumoPeriodoModel(
          periodo: '03/2026',
          mes: 3,
          mesNombre: 'Marzo 2026',
          anio: 2026,
          consumoM3: 20.0,
          montoBs: 70.0,
          lecturaAnterior: 133,
          lecturaActual: 153,
          estadoLectura: 'IMPAGA',
        ),
      ];

      expect(facturas.obtenerEstadoFactura(facturas[0]), EstadoFacturaConsumo.pagada);
      expect(facturas.obtenerEstadoFactura(facturas[1]), EstadoFacturaConsumo.impaga);
      expect(facturas.obtenerEstadoFactura(facturas[2]), EstadoFacturaConsumo.impaga);
    });

    test('Ejemplo confirmado por usuario: 6 facturas con 5 impagas -> las 2 más recientes son impagas y las 3 más antiguas vencidas: [pagada, vencida, vencida, vencida, impaga, impaga]', () {
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

      final estados = facturas.map((f) => facturas.obtenerEstadoFactura(f)).toList();

      expect(estados, [
        EstadoFacturaConsumo.pagada,   // Enero (pagada)
        EstadoFacturaConsumo.vencida,  // Febrero (vencida)
        EstadoFacturaConsumo.vencida,  // Marzo (vencida)
        EstadoFacturaConsumo.vencida,  // Abril (vencida)
        EstadoFacturaConsumo.impaga,   // Mayo (impaga - penúltima)
        EstadoFacturaConsumo.impaga,   // Junio (impaga - última emitida)
      ]);
    });

    test('Ejemplo del usuario con 3 impagas: [pagada, pagada, vencida, impaga, impaga]', () {
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

      final estados = facturas.map((f) => facturas.obtenerEstadoFactura(f)).toList();

      expect(estados, [
        EstadoFacturaConsumo.pagada,
        EstadoFacturaConsumo.pagada,
        EstadoFacturaConsumo.vencida,
        EstadoFacturaConsumo.impaga,
        EstadoFacturaConsumo.impaga,
      ]);
    });

    test('Lista en orden descendente (más reciente primero): la primera impaga cronológica sigue siendo vencida', () {
      final facturasDescendentes = [
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
      ];

      final estados = facturasDescendentes.map((f) => facturasDescendentes.obtenerEstadoFactura(f)).toList();

      expect(estados, [
        EstadoFacturaConsumo.impaga,   // Mayo (reciente)
        EstadoFacturaConsumo.impaga,   // Abril
        EstadoFacturaConsumo.vencida,  // Marzo (primera impaga en el tiempo)
        EstadoFacturaConsumo.pagada,   // Febrero
        EstadoFacturaConsumo.pagada,   // Enero
      ]);
    });

    test('Factura con estado explícito VENCIDA se marca como vencida', () {
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
          estadoLectura: 'VENCIDA',
        ),
      ];

      expect(facturas.obtenerEstadoFactura(facturas[0]), EstadoFacturaConsumo.vencida);
    });
  });
}

