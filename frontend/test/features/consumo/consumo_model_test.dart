import 'package:flutter_test/flutter_test.dart';
import 'package:cosmol_app/features/consumo/data/models/consumo_factura_model.dart';

void main() {
  group('HistorialConsumoModel Tests', () {
    test('Parsea JSON completo del backend FastAPI correctamente', () {
      final jsonBackend = {
        "cod_socio": "23807",
        "alias": "Mi Hogar",
        "rol_acceso": "TITULAR",
        "nro_medidor": "MED-23807",
        "total_periodos": 2,
        "periodos": [
          {
            "periodo": "07/2026",
            "mes": 7,
            "mes_nombre": "Julio 2026",
            "anio": 2026,
            "consumo_m3": 14.0,
            "monto_bs": 54.22,
            "lectura_anterior": 1180.0,
            "lectura_actual": 1194.0,
            "fecha_lectura": "2026-07-15",
            "estado_lectura": "NORMAL"
          },
          {
            "periodo": "08/2026",
            "mes": 8,
            "mes_nombre": "Agosto 2026",
            "anio": 2026,
            "consumo_m3": 22.0,
            "monto_bs": 85.00,
            "lectura_anterior": 1194.0,
            "lectura_actual": 1216.0,
            "fecha_lectura": "2026-08-13",
            "estado_lectura": "NORMAL"
          }
        ],
        "estadisticas": {
          "promedio_m3": 18.0,
          "consumo_maximo_m3": 22.0,
          "mes_consumo_maximo": "08/2026",
          "consumo_minimo_m3": 14.0,
          "mes_consumo_minimo": "07/2026",
          "consumo_ultimo_mes_m3": 22.0,
          "consumo_atipico": false,
          "porcentaje_variacion_ultimo_mes": 22.2,
          "mensaje_alerta": null,
          "tendencia": "SUBIENDO"
        }
      };

      final model = HistorialConsumoModel.fromJson(jsonBackend);

      expect(model.codSocio, '23807');
      expect(model.alias, 'Mi Hogar');
      expect(model.rolAcceso, 'TITULAR');
      expect(model.isTitular, isTrue);
      expect(model.nroMedidor, 'MED-23807');
      expect(model.totalPeriodos, 2);
      expect(model.periodos.length, 2);

      // Periodo 1
      final p1 = model.periodos[0];
      expect(p1.periodo, '07/2026');
      expect(p1.consumoM3, 14.0);
      expect(p1.montoBs, 54.22);
      expect(p1.litrosMedidos, 14000);
      expect(p1.mesNombreCorto, 'Jul');
      expect(p1.isPagado, isTrue);

      // Periodo 2
      final p2 = model.periodos[1];
      expect(p2.periodo, '08/2026');
      expect(p2.consumoM3, 22.0);
      expect(p2.litrosMedidos, 22000);
      expect(p2.tarifaPorM3, closeTo(3.86, 0.05));

      // Estadísticas
      final stats = model.estadisticas;
      expect(stats.promedioM3, 18.0);
      expect(stats.consumoMaximoM3, 22.0);
      expect(stats.consumoMinimoM3, 14.0);
      expect(stats.consumoAtipico, isFalse);
      expect(stats.tendencia, 'SUBIENDO');
    });

    test('Parsea alerta de fuga preventiva cuando consumo_atipico es true', () {
      final jsonFuga = {
        "cod_socio": "540",
        "alias": "Alquiler Durán",
        "rol_acceso": "CONSULTA_PAGO",
        "nro_medidor": "MED-***-40",
        "total_periodos": 1,
        "periodos": [
          {
            "periodo": "09/2026",
            "mes": 9,
            "mes_nombre": "Septiembre 2026",
            "anio": 2026,
            "consumo_m3": 35.0,
            "monto_bs": 140.0,
            "lectura_anterior": 1200.0,
            "lectura_actual": 1235.0,
            "estado_lectura": "NORMAL"
          }
        ],
        "estadisticas": {
          "promedio_m3": 18.0,
          "consumo_maximo_m3": 35.0,
          "mes_consumo_maximo": "09/2026",
          "consumo_minimo_m3": 18.0,
          "mes_consumo_minimo": "08/2026",
          "consumo_ultimo_mes_m3": 35.0,
          "consumo_atipico": true,
          "porcentaje_variacion_ultimo_mes": 94.4,
          "mensaje_alerta": "Detectamos un consumo anormalmente alto. Revise posibles fugas de agua.",
          "tendencia": "SUBIENDO"
        }
      };

      final model = HistorialConsumoModel.fromJson(jsonFuga);
      expect(model.rolAcceso, 'CONSULTA_PAGO');
      expect(model.isTitular, isFalse);
      expect(model.nroMedidor, 'MED-***-40');
      expect(model.estadisticas.consumoAtipico, isTrue);
      expect(model.estadisticas.mensajeAlerta, contains('fugas de agua'));
    });
  });
}
