import 'package:flutter_test/flutter_test.dart';
import 'package:cosmol_app/features/documentos/data/models/historial_factura_item_model.dart';

void main() {
  group('HistorialFacturaItemModel Test con datos reales', () {
    final realPagadaJson = {
      "CODIGO": "11543",
      "NOMBRE": "GUASASE ANDRADE IGNACIO FREDDY                              ",
      "MES": "7",
      "ANIO": "2026",
      "MONTO": "60.90",
      "ESTADO": "1",
      "CONSUMO": "16",
      "FECHA": "2026-09-05"
    };

    final realPendienteJson = {
      "CODIGO": "11543",
      "NOMBRE": "GUASASE ANDRADE IGNACIO FREDDY                              ",
      "MES": "9",
      "ANIO": "2026",
      "MONTO": "82.22",
      "ESTADO": "0",
      "CONSUMO": "22",
      "FECHA": null
    };

    test('debe deserializar factura pagada con fecha y estado correcto', () {
      final item = HistorialFacturaItemModel.fromJson(realPagadaJson);

      expect(item.codigo, '11543');
      expect(item.nombre, 'GUASASE ANDRADE IGNACIO FREDDY');
      expect(item.mes, 7);
      expect(item.anio, 2026);
      expect(item.monto, 60.90);
      expect(item.consumoM3, 16.0);
      expect(item.isPagado, isTrue);
      expect(item.fechaPago, '2026-09-05');
      expect(item.fechaPagoFormateada, '05/09/2026');
      expect(item.periodo, '07/2026');
      expect(item.periodoFormateado, 'Julio 2026');
    });

    test('debe deserializar factura pendiente con estado no pagado', () {
      final item = HistorialFacturaItemModel.fromJson(realPendienteJson);

      expect(item.isPagado, isFalse);
      expect(item.fechaPago, isNull);
      expect(item.fechaPagoFormateada, 'Pendiente');
    });
  });
}
