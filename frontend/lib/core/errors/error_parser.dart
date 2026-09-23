import 'package:dio/dio.dart';
import 'app_exception.dart';

/// Convierte respuestas del backend o excepciones de Dio en instancias de [AppException].
class ErrorParser {
  ErrorParser._();

  static AppException parse(dynamic error) {
    if (error is AppException) {
      return error;
    }

    if (error is DioException) {
      return _parseDioException(error);
    }

    return ServerException(
      message: error.toString(),
    );
  }

  static AppException _parseDioException(DioException dioException) {
    switch (dioException.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const NetworkException();

      case DioExceptionType.badResponse:
        return _parseResponseBody(dioException.response);

      case DioExceptionType.cancel:
        return const ValidationException(
          message: 'La petición fue cancelada.',
          code: 'CANCELLED',
        );

      default:
        return ServerException(
          message: dioException.message ?? 'Error inesperado de comunicación.',
        );
    }
  }

  static AppException _parseResponseBody(Response? response) {
    if (response == null || response.data == null) {
      return const ServerException();
    }

    final data = response.data;
    if (data is Map<String, dynamic>) {
      // Formato estándar backend COSMOL: { success: false, error: { code, message, details } }
      if (data.containsKey('error') && data['error'] is Map<String, dynamic>) {
        final errorMap = data['error'] as Map<String, dynamic>;
        final String code = errorMap['code'] ?? 'UNKNOWN';
        final String message = errorMap['message'] ?? 'Ha ocurrido un error.';
        final Map<String, dynamic>? details =
            errorMap['details'] is Map<String, dynamic>
                ? errorMap['details'] as Map<String, dynamic>
                : null;

        return _buildTypedException(code, message, details, response.statusCode);
      }

      // Fallback si viene en formato estándar FastAPI { detail: "..." }
      if (data.containsKey('detail')) {
        final detail = data['detail'];
        final String msg = detail is String
            ? detail
            : detail.toString();
        return ValidationException(message: msg);
      }
    }

    return ServerException(
      message: 'Respuesta inválida del servidor (HTTP ${response.statusCode}).',
    );
  }

  static AppException _buildTypedException(
    String code,
    String message,
    Map<String, dynamic>? details,
    int? statusCode,
  ) {
    switch (code) {
      case 'ACCOUNT_LOCKED':
        final int segundos = (details?['bloqueado_segundos_restantes'] as num?)?.toInt() ?? 60;
        return AccountLockedException(
          message: message,
          segundosRestantes: segundos,
          details: details,
        );

      case 'SESSION_REVOKED_NEW_DEVICE':
        return SessionRevokedException(
          message: message,
          details: details,
        );

      case 'ONBOARDING_REQUIRED':
        return OnboardingRequiredException(
          message: message,
          details: details,
        );

      case 'UNAUTHORIZED':
        return UnauthorizedException(
          message: message,
          details: details,
        );

      case 'OTP_INVALID':
      case 'OTP_MAX_ATTEMPTS':
      case 'OTP_RATE_LIMIT_EXCEEDED':
      case 'SUMINISTRO_ALREADY_LINKED':
        return ValidationException(
          message: message,
          code: code,
          details: details,
        );

      default:
        if (statusCode == 401) {
          return UnauthorizedException(message: message, code: code, details: details);
        }
        if (statusCode == 403) {
          return ValidationException(message: message, code: code, details: details);
        }
        if (statusCode == 400) {
          return ValidationException(message: message, code: code, details: details);
        }
        return ServerException(message: message, code: code, details: details);
    }
  }
}
