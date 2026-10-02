import 'package:flutter_test/flutter_test.dart';
import 'package:cosmol_app/features/consumo/data/models/consumo_factura_model.dart';
import 'package:cosmol_app/features/consumo/presentation/providers/consumo_provider.dart';

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

    test('ConsumoState calcula promedio según período y activa alerta únicamente si > 40% vs mes anterior', () {
      final periodos = [
        const ConsumoPeriodoModel(periodo: '08/2026', mes: 8, mesNombre: 'Agosto', anio: 2026, consumoM3: 28.0, montoBs: 100, lecturaAnterior: 100, lecturaActual: 128),
        const ConsumoPeriodoModel(periodo: '07/2026', mes: 7, mesNombre: 'Julio', anio: 2026, consumoM3: 18.0, montoBs: 70, lecturaAnterior: 82, lecturaActual: 100),
        const ConsumoPeriodoModel(periodo: '06/2026', mes: 6, mesNombre: 'Junio', anio: 2026, consumoM3: 16.0, montoBs: 60, lecturaAnterior: 66, lecturaActual: 82),
        const ConsumoPeriodoModel(periodo: '05/2026', mes: 5, mesNombre: 'Mayo', anio: 2026, consumoM3: 14.0, montoBs: 50, lecturaAnterior: 52, lecturaActual: 66),
        const ConsumoPeriodoModel(periodo: '04/2026', mes: 4, mesNombre: 'Abril', anio: 2026, consumoM3: 15.0, montoBs: 55, lecturaAnterior: 37, lecturaActual: 52),
        const ConsumoPeriodoModel(periodo: '03/2026', mes: 3, mesNombre: 'Marzo', anio: 2026, consumoM3: 17.0, montoBs: 65, lecturaAnterior: 20, lecturaActual: 37),
        const ConsumoPeriodoModel(periodo: '02/2026', mes: 2, mesNombre: 'Febrero', anio: 2026, consumoM3: 20.0, montoBs: 75, lecturaAnterior: 0, lecturaActual: 20),
      ];

      final historial = HistorialConsumoModel(
        codSocio: '23807',
        alias: 'Casa',
        rolAcceso: 'TITULAR',
        totalPeriodos: periodos.length,
        periodos: periodos,
        estadisticas: const EstadisticasConsumoModel(
          promedioM3: 18.0,
          consumoMaximoM3: 28.0,
          mesConsumoMaximo: '08/2026',
          consumoMinimoM3: 14.0,
          mesConsumoMinimo: '05/2026',
          consumoUltimoMesM3: 28.0,
        ),
      );

      // 1. Estado en 6 meses
      final state6 = ConsumoState(
        historial: historial,
        periodo: PeriodoConsumo.seisMeses,
      );

      expect(state6.filteredFacturas.length, 6);
      // Promedio de los 6 meses más recientes: (28 + 18 + 16 + 14 + 15 + 17) / 6 = 108 / 6 = 18.0
      expect(state6.promedioConsumo, 18.0);
      expect(state6.consumoActual, 28.0);
      expect(state6.mesAnteriorAlActual?.consumoM3, 18.0);
      // Variación vs mes anterior: (28 - 18) / 18 = +55.6% (> 40%)
      expect(state6.variacionVsMesAnterior, 55.6);
      expect(state6.consumoAtipico, isTrue);
      expect(state6.mensajeAlerta, contains('fugas de agua'));

      // 2. Estado cuando el incremento es <= 40% (ejemplo: 22 m³ vs 18 m³ -> +22.2%)
      final periodosSinFuga = List<ConsumoPeriodoModel>.from(periodos);
      periodosSinFuga[0] = const ConsumoPeriodoModel(
        periodo: '08/2026',
        mes: 8,
        mesNombre: 'Agosto',
        anio: 2026,
        consumoM3: 22.0,
        montoBs: 80,
        lecturaAnterior: 100,
        lecturaActual: 122,
      );
      final historialSinFuga = HistorialConsumoModel(
        codSocio: '23807',
        alias: 'Casa',
        rolAcceso: 'TITULAR',
        totalPeriodos: periodosSinFuga.length,
        periodos: periodosSinFuga,
        estadisticas: const EstadisticasConsumoModel(
          promedioM3: 17.0,
          consumoMaximoM3: 22.0,
          mesConsumoMaximo: '08/2026',
          consumoMinimoM3: 14.0,
          mesConsumoMinimo: '05/2026',
          consumoUltimoMesM3: 22.0,
        ),
      );
      final stateSinFuga = ConsumoState(
        historial: historialSinFuga,
        periodo: PeriodoConsumo.seisMeses,
      );
      // Variación vs mes anterior: (22 - 18) / 18 = 22.2% (NO supera el 40%)
      expect(stateSinFuga.variacionVsMesAnterior, 22.2);
      expect(stateSinFuga.consumoAtipico, isFalse);
      expect(stateSinFuga.mensajeAlerta, isNull);
    });
  });
}
