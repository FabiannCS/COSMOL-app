import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:cosmol_app/core/errors/app_exception.dart';
import 'package:cosmol_app/core/errors/error_parser.dart';

void main() {
  group('ErrorParser Tests', () {
    test('parse returns AppException unmodified if input is already AppException', () {
      const original = ValidationException(message: 'Error existente');
      final result = ErrorParser.parse(original);
      expect(result, same(original));
    });

    test('parse maps DioException connectionTimeout to NetworkException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/login'),
        type: DioExceptionType.connectionTimeout,
      );

      final result = ErrorParser.parse(dioException);
      expect(result, isA<NetworkException>());
    });

    test('parse maps ACCOUNT_LOCKED response to AccountLockedException with segundosRestantes', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/login'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/login'),
          statusCode: 403,
          data: {
            'success': false,
            'error': {
              'code': 'ACCOUNT_LOCKED',
              'message': 'Cuenta bloqueada por 3 intentos fallidos.',
              'details': {
                'bloqueado_segundos_restantes': 300,
              },
            },
          },
        ),
      );

      final result = ErrorParser.parse(dioException);
      expect(result, isA<AccountLockedException>());
      final lockedEx = result as AccountLockedException;
      expect(lockedEx.segundosRestantes, 300);
      expect(lockedEx.message, contains('3 intentos fallidos'));
    });

    test('parse maps ONBOARDING_REQUIRED code to OnboardingRequiredException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/login'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/login'),
          statusCode: 401,
          data: {
            'success': false,
            'error': {
              'code': 'ONBOARDING_REQUIRED',
              'message': 'Debe realizar el primer acceso.',
            },
          },
        ),
      );

      final result = ErrorParser.parse(dioException);
      expect(result, isA<OnboardingRequiredException>());
    });

    test('parse maps SESSION_REVOKED_NEW_DEVICE to SessionRevokedException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/me'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/me'),
          statusCode: 401,
          data: {
            'success': false,
            'error': {
              'code': 'SESSION_REVOKED_NEW_DEVICE',
              'message': 'Sesión iniciada en otro equipo.',
            },
          },
        ),
      );

      final result = ErrorParser.parse(dioException);
      expect(result, isA<SessionRevokedException>());
    });

    test('parse handles FastAPI detail string fallback', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/otp'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/otp'),
          statusCode: 400,
          data: {
            'detail': 'Código OTP inválido o expirado.',
          },
        ),
      );

      final result = ErrorParser.parse(dioException);
      expect(result, isA<ValidationException>());
      expect(result.message, 'Código OTP inválido o expirado.');
    });
  });
}
