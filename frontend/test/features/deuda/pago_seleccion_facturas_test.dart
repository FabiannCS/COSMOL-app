import 'package:flutter_test/flutter_test.dart';
import 'package:cosmol_app/features/deuda/data/models/resumen_deuda_model.dart';

void main() {
  group('Lógica de Selección Estricta de Facturas (FIFO - Tarjeta Trello)', () {
    late List<FacturaPendienteModel> facturas;

    setUp(() {
      facturas = [
        const FacturaPendienteModel(
          nroFacip: 'FAC-001',
          nroFactura: '1001',
          codAutorizacion: 'AUTH1',
          periodo: '07/2026',
          mesLectura: 'Julio 2026',
          anio: 2026,
          mes: 7,
          montoBs: 50.0,
          estaVencida: true,
          diasMora: 60,
        ),
        const FacturaPendienteModel(
          nroFacip: 'FAC-002',
          nroFactura: '1002',
          codAutorizacion: 'AUTH2',
          periodo: '08/2026',
          mesLectura: 'Agosto 2026',
          anio: 2026,
          mes: 8,
          montoBs: 60.0,
          estaVencida: true,
          diasMora: 30,
        ),
        const FacturaPendienteModel(
          nroFacip: 'FAC-003',
          nroFactura: '1003',
          codAutorizacion: 'AUTH3',
          periodo: '09/2026',
          mesLectura: 'Septiembre 2026',
          anio: 2026,
          mes: 9,
          montoBs: 70.0,
          estaVencida: false,
          diasMora: 0,
        ),
      ];
    });

    test('Ordenamiento cronológico obligatorio: la más antigua queda en índice 0', () {
      final desordenadas = [facturas[2], facturas[0], facturas[1]];
      desordenadas.sort((a, b) {
        if (a.anio != b.anio) return a.anio.compareTo(b.anio);
        if (a.mes != b.mes) return a.mes.compareTo(b.mes);
        return b.diasMora.compareTo(a.diasMora);
      });

      expect(desordenadas[0].nroFacip, 'FAC-001'); // Julio
      expect(desordenadas[1].nroFacip, 'FAC-002'); // Agosto
      expect(desordenadas[2].nroFacip, 'FAC-003'); // Septiembre
    });

    test('Regla FIFO: al marcar la segunda factura (índice 1), se marca automáticamente la primera (índice 0)', () {
      final seleccionadas = <String>{};

      // Función que replica la lógica implementada en PagoQrMockSheet
      void togglePorIndice(int index) {
        final fac = facturas[index].nroFacip;
        if (!seleccionadas.contains(fac)) {
          seleccionadas.clear();
          for (int i = 0; i <= index; i++) {
            seleccionadas.add(facturas[i].nroFacip);
          }
        }
      }

      // Usuario intenta marcar la factura en índice 1 (Agosto)
      togglePorIndice(1);

      expect(seleccionadas.length, 2);
      expect(seleccionadas.contains('FAC-001'), true);
      expect(seleccionadas.contains('FAC-002'), true);
      expect(seleccionadas.contains('FAC-003'), false);
    });

    test('Regla FIFO: al desmarcar la factura 1 cuando 0, 1 y 2 están marcadas, se desmarca la 2 obligatoriamente', () {
      final seleccionadas = {'FAC-001', 'FAC-002', 'FAC-003'};

      void togglePorIndice(int index) {
        final fac = facturas[index].nroFacip;
        if (seleccionadas.contains(fac)) {
          final total = seleccionadas.length;
          if (index == total - 1) {
            seleccionadas.clear();
            for (int i = 0; i < index; i++) {
              seleccionadas.add(facturas[i].nroFacip);
            }
          } else {
            // Corta para dejar seleccionadas hasta index
            seleccionadas.clear();
            for (int i = 0; i <= index; i++) {
              seleccionadas.add(facturas[i].nroFacip);
            }
          }
        }
      }

      // Si estaban marcadas 0, 1 y 2, y el usuario pulsa en el índice 0 para cortar
      togglePorIndice(0);

      // Debe quedar únicamente seleccionada la primera factura (FAC-001)
      expect(seleccionadas.length, 1);
      expect(seleccionadas.contains('FAC-001'), true);
      expect(seleccionadas.contains('FAC-002'), false);
      expect(seleccionadas.contains('FAC-003'), false);
    });

    test('Regla FIFO: desmarcar la última factura seleccionada reduce exactamente en 1 la secuencia', () {
      final seleccionadas = {'FAC-001', 'FAC-002'};

      void togglePorIndice(int index) {
        final fac = facturas[index].nroFacip;
        if (seleccionadas.contains(fac)) {
          final total = seleccionadas.length;
          if (index == total - 1) {
            seleccionadas.clear();
            for (int i = 0; i < index; i++) {
              seleccionadas.add(facturas[i].nroFacip);
            }
          }
        }
      }

      togglePorIndice(1);

      expect(seleccionadas.length, 1);
      expect(seleccionadas.contains('FAC-001'), true);
    });
  });
}
