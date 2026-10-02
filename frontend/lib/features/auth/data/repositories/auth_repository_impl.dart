import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/recuperar_password_models.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/login_response_model.dart';
import '../models/otp_models.dart';
import '../models/register_credentials_model.dart';
import '../models/verify_socio_response_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remoteDataSource = ref.watch(authRemoteDataSourceProvider);
  return AuthRepositoryImpl(remoteDataSource);
});

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl(this._remoteDataSource);

  @override
  Future<VerifySocioResponseModel> verificarSocio({
    required String codSocio,
    required String ci,
  }) {
    return _remoteDataSource.verificarSocio(codSocio: codSocio, ci: ci);
  }

  @override
  Future<OtpResponseModel> solicitarOtp({
    required String codSocio,
    required String telefono,
    String canal = 'WHATSAPP',
  }) {
    return _remoteDataSource.solicitarOtp(
      codSocio: codSocio,
      telefono: telefono,
      canal: canal,
    );
  }

  @override
  Future<VerifyOtpResponseModel> verificarOtp({
    required String telefono,
    required String codigo,
  }) {
    return _remoteDataSource.verificarOtp(telefono: telefono, codigo: codigo);
  }

  @override
  Future<RegisterCredentialsResponseModel> establecerPin({
    required RegisterCredentialsRequestModel request,
  }) {
    return _remoteDataSource.establecerPin(request: request);
  }

  @override
  Future<LoginResponseModel> login({
    required String codSocio,
    required String password,
    required String deviceId,
    String modeloDispositivo = 'Mobile Device',
  }) {
    return _remoteDataSource.login(
      codSocio: codSocio,
      password: password,
      deviceId: deviceId,
      modeloDispositivo: modeloDispositivo,
    );
  }

  @override
  Future<ValidarTitularResponseModel> validarTitularRecuperacion({
    required String codSocio,
    required String ci,
  }) {
    return _remoteDataSource.validarTitularRecuperacion(
      codSocio: codSocio,
      ci: ci,
    );
  }

  @override
  Future<SolicitarOtpRecuperacionResponseModel> solicitarOtpRecuperacion({
    required String sessionId,
    String canal = 'WHATSAPP',
  }) {
    return _remoteDataSource.solicitarOtpRecuperacion(
      sessionId: sessionId,
      canal: canal,
    );
  }

  @override
  Future<VerificarOtpRecuperacionResponseModel> verificarOtpRecuperacion({
    required String sessionId,
    required String codigo,
  }) {
    return _remoteDataSource.verificarOtpRecuperacion(
      sessionId: sessionId,
      codigo: codigo,
    );
  }

  @override
  Future<CambiarPinRecuperacionResponseModel> cambiarPinRecuperacion({
    required String tokenRecuperacion,
    required String nuevoPin,
  }) {
    return _remoteDataSource.cambiarPinRecuperacion(
      tokenRecuperacion: tokenRecuperacion,
      nuevoPin: nuevoPin,
    );
  }
}
