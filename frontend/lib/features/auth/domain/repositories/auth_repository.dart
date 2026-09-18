import '../../data/models/verify_socio_response_model.dart';
import '../../data/models/otp_models.dart';
import '../../data/models/register_credentials_model.dart';
import '../../data/models/login_response_model.dart';

abstract class AuthRepository {
  Future<VerifySocioResponseModel> verificarSocio({
    required String codSocio,
    required String ci,
  });

  Future<OtpResponseModel> solicitarOtp({
    required String codSocio,
    required String telefono,
    String canal = 'WHATSAPP',
  });

  Future<VerifyOtpResponseModel> verificarOtp({
    required String telefono,
    required String codigo,
  });

  Future<RegisterCredentialsResponseModel> establecerPin({
    required RegisterCredentialsRequestModel request,
  });

  Future<LoginResponseModel> login({
    required String codSocio,
    required String password,
    required String deviceId,
    String modeloDispositivo = 'Mobile Device',
  });
}
