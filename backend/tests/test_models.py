import uuid
from datetime import datetime, timezone
from app.db.models import Usuario, Suministro, Dispositivo, Otp, BaseModel


def test_models_metadata_and_tablenames():
    """Valida que los nombres de tablas y metadatos de SQLAlchemy sean correctos."""
    assert Usuario.__tablename__ == "usuarios"
    assert Suministro.__tablename__ == "suministros"
    assert Dispositivo.__tablename__ == "dispositivos"
    assert Otp.__tablename__ == "otps"

    # Verificar herencia de BaseModel
    assert issubclass(Usuario, BaseModel)
    assert issubclass(Suministro, BaseModel)
    assert issubclass(Dispositivo, BaseModel)
    assert issubclass(Otp, BaseModel)


def test_usuario_instantiation_and_defaults():
    """Valida la instanciación de Usuario con sus valores por defecto."""
    user = Usuario(
        telefono="+59170011223",
        password_hash="$2b$12$somehashedpasswordstring"
    )
    assert user.telefono == "+59170011223"
    assert user.esta_activo is True
    assert user.intentos_fallidos == 0
    assert user.bloqueado_hasta is None
    assert "<Usuario" in repr(user)


def test_suministro_and_multicuenta_relationships():
    """Valida la relación 1 a N entre Usuario y Suministro (Multicuenta)."""
    user_id = uuid.uuid4()
    user = Usuario(
        id=user_id,
        telefono="+59170011223",
        password_hash="hashed_pin"
    )

    suministro_casa = Suministro(
        usuario_id=user_id,
        cod_socio="10450",
        alias="Mi Casa Montero",
        rol="TITULAR",
        es_suministro_principal=True
    )

    suministro_mama = Suministro(
        usuario_id=user_id,
        cod_socio="20890",
        alias="Casa Mamá",
        rol="CONSULTA_PAGO",
        es_suministro_principal=False
    )

    user.suministros.append(suministro_casa)
    user.suministros.append(suministro_mama)

    assert len(user.suministros) == 2
    assert user.suministros[0].cod_socio == "10450"
    assert user.suministros[0].rol == "TITULAR"
    assert user.suministros[1].cod_socio == "20890"
    assert user.suministros[1].rol == "CONSULTA_PAGO"
    assert "<Suministro" in repr(suministro_casa)


def test_dispositivo_relationship():
    """Valida la relación entre Usuario y sus Dispositivos autorizados."""
    user_id = uuid.uuid4()
    user = Usuario(
        id=user_id,
        telefono="+59170011223",
        password_hash="hashed_pin"
    )

    disp = Dispositivo(
        usuario_id=user_id,
        device_id="android_hw_unique_id_99",
        modelo_dispositivo="Samsung Galaxy A54",
        fcm_token="sample_fcm_push_token_123"
    )

    user.dispositivos.append(disp)
    assert len(user.dispositivos) == 1
    assert user.dispositivos[0].device_id == "android_hw_unique_id_99"
    assert "<Dispositivo" in repr(disp)


def test_otp_instantiation():
    """Valida la entidad de auditoría de códigos OTP."""
    otp_record = Otp(
        telefono="+59170011223",
        canal="WHATSAPP",
        proposito="ONBOARDING",
        fue_verificado=False
    )
    assert otp_record.telefono == "+59170011223"
    assert otp_record.canal == "WHATSAPP"
    assert otp_record.proposito == "ONBOARDING"
    assert otp_record.fue_verificado is False
    assert "<Otp" in repr(otp_record)
