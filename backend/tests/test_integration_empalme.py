"""
Pruebas exhaustivas de integración y empalme 100% entre PostgreSQL, Redis, Gateways de Mensajería y Servicios de Negocio.
Verifica que los datos persistan físicamente en las tablas 'usuarios', 'suministros' y 'dispositivos'.
"""
import pytest
from httpx import AsyncClient
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Usuario, Suministro, Dispositivo
from app.services.servicio_autenticacion import ServicioAutenticacion
from app.services.servicio_suministros import ServicioSuministros


@pytest.mark.asyncio
async def test_empalme_persistencia_real_postgresql(redis_override, db_session: AsyncSession):
    """
    Valida el flujo completo de autenticación y confirma que Usuario y Suministro
    se persistan físicamente en PostgreSQL mediante SQLAlchemy AsyncSession.
    """
    cod_socio = "205566"
    ci = "4920192"
    telefono = "+59178899001"
    pin = "1234"
    device_id = "hardware-empalme-device-01"
    modelo = "Samsung Galaxy S24"

    # 1. Limpieza de registros previos
    await db_session.execute(delete(Suministro).where(Suministro.cod_socio.in_([cod_socio, "104523"])))
    await db_session.execute(delete(Usuario).where(Usuario.telefono == telefono))
    await db_session.commit()
    await redis_override.delete(
        f"rate_otp:{telefono}",
        f"otp:{telefono}",
        f"intentos_fallidos:{cod_socio}",
        f"bloqueado:{cod_socio}"
    )

    auth_service = ServicioAutenticacion(redis_override, db=db_session)
    suministro_service = ServicioSuministros(redis_override, db=db_session)

    # 2. Paso 1: Verificar socio en sistema legado
    verif = await auth_service.verificar_primer_acceso(cod_socio, ci)
    assert verif["cod_socio"] == cod_socio
    assert "MARIA ELENA" in verif["nombre_titular"]

    # 3. Paso 2: Solicitar OTP por WhatsApp
    solicitud = await auth_service.solicitar_otp(cod_socio, telefono, "WHATSAPP")
    assert solicitud["canal"] == "WHATSAPP"
    codigo_otp = solicitud["debug_codigo_otp"]

    # 4. Paso 3: Validar OTP
    verif_otp = await auth_service.verificar_otp(telefono, codigo_otp)
    token_otp = verif_otp["token_otp_valido"]

    # 5. Paso 4: Establecer PIN (debe persistir en PostgreSQL)
    res_pin = await auth_service.establecer_pin(telefono, token_otp, pin)
    assert res_pin["cod_socio"] == cod_socio

    # Verificar que el usuario exista en la tabla 'usuarios' de PostgreSQL
    stmt_u = select(Usuario).where(Usuario.telefono == telefono)
    res_u = await db_session.execute(stmt_u)
    usuario_db = res_u.scalars().first()
    assert usuario_db is not None
    assert usuario_db.esta_activo is True
    assert usuario_db.telefono == telefono

    # Verificar que el suministro exista en la tabla 'suministros' de PostgreSQL
    stmt_s = select(Suministro).where(Suministro.usuario_id == usuario_db.id)
    res_s = await db_session.execute(stmt_s)
    suministros_db = res_s.scalars().all()
    assert len(suministros_db) == 1
    assert suministros_db[0].cod_socio == cod_socio
    assert suministros_db[0].rol == "TITULAR"
    assert suministros_db[0].es_suministro_principal is True

    # 6. Login diario habitual: debe registrar el Dispositivo en PostgreSQL
    token_resp = await auth_service.autenticar_socio(
        cod_socio=cod_socio,
        pin_password=pin,
        device_id=device_id,
        modelo_dispositivo=modelo
    )
    assert token_resp.access_token is not None
    assert len(token_resp.suministros) == 1

    # Verificar que el dispositivo se haya registrado en la tabla 'dispositivos'
    stmt_d = select(Dispositivo).where(
        Dispositivo.usuario_id == usuario_db.id,
        Dispositivo.device_id == device_id
    )
    res_d = await db_session.execute(stmt_d)
    disp_db = res_d.scalars().first()
    assert disp_db is not None
    assert disp_db.modelo_dispositivo == modelo

    # 7. Multicuenta: Vincular suministro adicional en PostgreSQL
    from app.schemas.suministro import VincularSuministroRequest
    req_vincular = VincularSuministroRequest(
        cod_socio="104523",
        ci_o_medidor="8392019",
        alias="Casa de mis Padres"
    )
    sum_adicional = await suministro_service.vincular_suministro(cod_socio, req_vincular)
    assert sum_adicional.rol == "TITULAR"
    assert sum_adicional.alias == "Casa de mis Padres"

    # Listar suministros directamente de PostgreSQL
    lista = await suministro_service.listar_suministros(cod_socio)
    assert len(lista) == 2
    codigos = [s.cod_socio for s in lista]
    assert cod_socio in codigos
    assert "104523" in codigos
