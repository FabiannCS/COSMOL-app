import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/verify_socio_response_model.dart';
import '../models/otp_models.dart';
import '../models/register_credentials_model.dart';
import '../models/login_response_model.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final dio = ref.watch(apiClientProvider);
  return AuthRemoteDataSource(dio);
});

class AuthRemoteDataSource {
  final Dio _dio;

  AuthRemoteDataSource(this._dio);

  /// 1. Paso de Verificación de Socio (cod_socio + CI)
  Future<VerifySocioResponseModel> verificarSocio({
    required String codSocio,
    required String ci,
  }) async {
    try {
      final response = await _dio.post(
        '/autenticacion/verificar-socio',
        data: {
          'cod_socio': codSocio,
          'ci': ci,
        },
      );
      return VerifySocioResponseModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 2. Solicitud de código OTP Dual (WhatsApp o SMS)
  Future<OtpResponseModel> solicitarOtp({
    required String codSocio,
    required String telefono,
    String canal = 'WHATSAPP',
  }) async {
    try {
      final response = await _dio.post(
        '/autenticacion/solicitar-otp',
        data: {
          'cod_socio': codSocio.isNotEmpty ? codSocio : '104523',
          'telefono': telefono.startsWith('+591') ? telefono : '+591$telefono',
          'canal': canal,
        },
      );
      return OtpResponseModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 3. Verificación de Código OTP
  Future<VerifyOtpResponseModel> verificarOtp({
    required String telefono,
    required String codigo,
  }) async {
    try {
      final response = await _dio.post(
        '/autenticacion/verificar-otp',
        data: {
          'telefono': telefono.startsWith('+591') ? telefono : '+591$telefono',
          'codigo': codigo,
        },
      );
      return VerifyOtpResponseModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 4. Establecer PIN / Registro final de credenciales
  Future<RegisterCredentialsResponseModel> establecerPin({
    required RegisterCredentialsRequestModel request,
  }) async {
    try {
      final response = await _dio.post(
        '/autenticacion/establecer-pin',
        data: request.toJson(),
      );
      return RegisterCredentialsResponseModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// 5. Login diario habitual
  Future<LoginResponseModel> login({
    required String codSocio,
    required String password,
    required String deviceId,
    String modeloDispositivo = 'Mobile Device',
  }) async {
    try {
      final response = await _dio.post(
        '/autenticacion/login',
        data: {
          'cod_socio': codSocio,
          'pin_password': password,
          'device_id': deviceId,
          'modelo_dispositivo': modeloDispositivo,
        },
      );
      return LoginResponseModel.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  AppException _handleDioError(DioException e) {
    if (e.error is AppException) {
      return e.error as AppException;
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const NetworkException();
    }

    final response = e.response;
    if (response != null && response.data != null) {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['error'] is Map<String, dynamic>) {
          final errMap = data['error'] as Map<String, dynamic>;
          final message = errMap['message']?.toString() ?? 'Error en la solicitud';
          final code = errMap['code']?.toString();
          final details = errMap['details'] as Map<String, dynamic>?;

          if (code == 'ACCOUNT_LOCKED') {
            final int seg = (details?['bloqueado_segundos_restantes'] as num?)?.toInt() ?? 60;
            return AccountLockedException(
              message: message,
              segundosRestantes: seg,
              details: details,
            );
          }

          return ValidationException(
            message: message,
            code: code,
            details: details,
          );
        } else if (data['detail'] != null) {
          return ValidationException(
            message: data['detail'].toString(),
          );
        }
      }
    }

    return ServerException(
      message: 'Error de comunicación con el servidor (${response?.statusCode ?? 500})',
    );
  }
}
