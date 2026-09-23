/// Jerarquía de excepciones tipadas para la aplicación cliente.
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final Map<String, dynamic>? details;

  const AppException({
    required this.message,
    this.code,
    this.details,
  });

  @override
  String toString() => '$runtimeType: [$code] $message';
}

/// Errores de Conexión de Red (sin conexión, timeout, DNS fail)
class NetworkException extends AppException {
  const NetworkException({
    super.message = 'No se pudo conectar al servidor. Verifique su conexión a Internet.',
    super.code = 'NETWORK_ERROR',
    super.details,
  });
}

/// No Autorizado (401 - token inválido o expirado)
class UnauthorizedException extends AppException {
  const UnauthorizedException({
    super.message = 'Sesión no válida o expirada. Por favor vuelva a ingresar.',
    super.code = 'UNAUTHORIZED',
    super.details,
  });
}

/// Cuenta Bloqueada por intentos fallidos (403 - ACCOUNT_LOCKED)
class AccountLockedException extends AppException {
  final int segundosRestantes;

  const AccountLockedException({
    required super.message,
    required this.segundosRestantes,
    super.code = 'ACCOUNT_LOCKED',
    super.details,
  });
}

/// Sesión Revocada por Inicio en Nuevo Dispositivo (401 - SESSION_REVOKED_NEW_DEVICE)
class SessionRevokedException extends AppException {
  const SessionRevokedException({
    super.message = 'Se ha iniciado sesión en otro dispositivo. Su sesión en este equipo fue revocada.',
    super.code = 'SESSION_REVOKED_NEW_DEVICE',
    super.details,
  });
}

/// Primer Acceso Requerido (401 - ONBOARDING_REQUIRED)
class OnboardingRequiredException extends AppException {
  const OnboardingRequiredException({
    super.message = 'Debe realizar el proceso de Primer Acceso antes de continuar.',
    super.code = 'ONBOARDING_REQUIRED',
    super.details,
  });
}

/// Error de Validación de Datos de Entrada (400 - OTP Inválido, etc.)
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    super.details,
  });
}

/// Error Interno del Servidor (500)
class ServerException extends AppException {
  const ServerException({
    super.message = 'Ha ocurrido un error inesperado en el servidor COSMOL. Intente más tarde.',
    super.code = 'SERVER_ERROR',
    super.details,
  });
}
