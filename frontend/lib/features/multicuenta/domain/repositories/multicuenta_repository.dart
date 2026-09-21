import '../../../auth/data/models/login_response_model.dart';

abstract class MulticuentaRepository {
  Future<List<SuministroModel>> listarSuministros();

  Future<SuministroModel> vincularSuministro({
    required String codSocio,
    String? ciOMedidor,
    required String alias,
  });
}
