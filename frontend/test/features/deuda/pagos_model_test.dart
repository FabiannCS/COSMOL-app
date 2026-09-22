import 'package:flutter_test/flutter_test.dart';
import 'package:cosmol_app/features/deuda/data/models/pago_model.dart';

void main() {
  group('PagosModel Tests', () {
    test('CanalPagoModel serializa y deserializa correctamente', () {
      final json = {
        'id': 'multipago',
        'nombre': 'Multipago Bolivia',
        'descripcion': 'Pago con Simple QR y tarjetas',
        'url_redireccion': 'https://multipago.com/service/cosmol_payment/first',
        'icono': 'qr_code',
        'soporta_qr': true,
        'activo': true,
      };

      final canal = CanalPagoModel.fromJson(json);

      expect(canal.id, 'multipago');
      expect(canal.nombre, 'Multipago Bolivia');
      expect(canal.soportaQr, true);
      expect(canal.icono, 'qr_code');

      final map = canal.toJson();
      expect(map['id'], 'multipago');
      expect(map['soporta_qr'], true);
    });

    test('CanalesPagoResponseModel serializa y deserializa lista de canales', () {
      final json = {
        'cod_socio': '540',
        'nombre_titular': 'DURAN ELOISA RIVERA DE',
        'total_deuda_bs': 132.34,
        'cant_facturas_pendientes': 2,
        'canales': [
          {
            'id': 'multipago',
            'nombre': 'Multipago Bolivia',
            'descripcion': 'Pago con Simple QR',
            'url_redireccion': 'https://multipago.com/service/cosmol_payment/first',
            'icono': 'qr_code',
            'soporta_qr': true,
            'activo': true,
          },
          {
            'id': 'pago_al_paso',
            'nombre': 'Pago al Paso 24/7',
            'descripcion': 'Paga mediante QR Bancario',
            'url_redireccion': 'https://red.pagoalpaso247.net/servicio/cosmol',
            'icono': 'storefront',
            'soporta_qr': true,
            'activo': true,
          }
        ],
        'mensaje_ayuda': 'Selecciona un canal para pagar.',
        'fecha_consulta': '2026-09-22T16:00:00Z',
      };

      final response = CanalesPagoResponseModel.fromJson(json);

      expect(response.codSocio, '540');
      expect(response.totalDeudaBs, 132.34);
      expect(response.cantFacturasPendientes, 2);
      expect(response.canales.length, 2);
      expect(response.canales[0].id, 'multipago');
      expect(response.canales[1].id, 'pago_al_paso');
    });

    test('RegistrarIntentoPagoResponseModel serializa correctamente', () {
      final json = {
        'exito': true,
        'cod_socio': '540',
        'canal_id': 'multipago',
        'mensaje': 'Intención registrada exitosamente',
        'url_redireccion': 'https://multipago.com/service/cosmol_payment/first',
        'ventana_verificacion_activa': true,
        'tiempo_expiracion_segundos': 900,
      };

      final response = RegistrarIntentoPagoResponseModel.fromJson(json);

      expect(response.exito, true);
      expect(response.codSocio, '540');
      expect(response.canalId, 'multipago');
      expect(response.ventanaVerificacionActiva, true);
      expect(response.tiempoExpiracionSegundos, 900);
      expect(response.urlRedireccion, contains('multipago.com'));
    });

    test('EstadoVerificacionPagoModel serializa correctamente', () {
      final json = {
        'cod_socio': '540',
        'deuda_saldada': true,
        'saldo_actual_bs': 0.0,
        'cant_facturas_pendientes': 0,
        'mensaje': 'Servicio al día sin deudas pendientes',
        'ventana_activa': false,
      };

      final response = EstadoVerificacionPagoModel.fromJson(json);

      expect(response.codSocio, '540');
      expect(response.deudaSaldada, true);
      expect(response.saldoActualBs, 0.0);
      expect(response.cantFacturasPendientes, 0);
      expect(response.ventanaActiva, false);
    });
  });
}
