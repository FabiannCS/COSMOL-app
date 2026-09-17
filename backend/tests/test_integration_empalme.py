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


@pytest.mark.asyncio
async def test_empalme_e2e_fase1_y_fase2(
    client: AsyncClient, redis_override, db_session: AsyncSession
):
    """
    Certificación de Empalme Completo Fase 1 + Fase 2:
    Valida el flujo de punta a punta:
    1. Registro y login del socio emitiendo JWT Bearer real (Fase 1).
    2. Vinculación multicuenta de 2 suministros:
       - Suministro principal '556' (rol TITULAR, al día, saldo 0).
       - Suministro secundario '540' (rol CONSULTA_PAGO, en mora, saldo 132.34).
    3. Consulta HTTP a GET /api/v1/deuda/dashboard/resumen:
       - Valida consolidación de balance multicuenta en Bs.
    4. Consulta HTTP a GET /api/v1/deuda/540:
       - Valida semaforización, alerta de corte y enmascaramiento para CONSULTA_PAGO.
    5. Invalidación de caché vía POST /api/v1/deuda/540/invalidar-cache.
    """
    cod_principal = "556"
    cod_secundario = "540"
    telefono = "+59179988112"
    pin = "9876"

    # Limpieza previa
    await db_session.execute(delete(Suministro).where(Suministro.cod_socio.in_([cod_principal, cod_secundario])))
    await db_session.execute(delete(Usuario).where(Usuario.telefono == telefono))
    await db_session.commit()
    await redis_override.delete(f"deuda:{cod_principal}", f"deuda:{cod_secundario}")

    auth_service = ServicioAutenticacion(redis_override, db=db_session)
    suministro_service = ServicioSuministros(redis_override, db=db_session)

    # 1. Onboarding del socio titular
    verif = await auth_service.verificar_primer_acceso(cod_principal, "4638847")
    assert verif["cod_socio"] == cod_principal

    sol = await auth_service.solicitar_otp(cod_principal, telefono, "WHATSAPP")
    otp_code = sol["debug_codigo_otp"]

    verif_otp = await auth_service.verificar_otp(telefono, otp_code)
    token_otp = verif_otp["token_otp_valido"]

    await auth_service.establecer_pin(telefono, token_otp, pin)

    # 2. Login para obtener JWT
    login_resp = await auth_service.autenticar_socio(
        cod_socio=cod_principal,
        pin_password=pin,
        device_id="empalme-device-full-02",
        modelo_dispositivo="Google Pixel 8"
    )
    access_token = login_resp.access_token
    headers = {"Authorization": f"Bearer {access_token}"}

    # 3. Vincular segundo suministro en modo CONSULTA_PAGO (Inquilino)
    from app.schemas.suministro import VincularSuministroRequest
    await suministro_service.vincular_suministro(
        cod_principal,
        VincularSuministroRequest(
            cod_socio=cod_secundario,
            alias="Alquiler Tienda"
        )
    )

    # 4. HTTP GET /api/v1/deuda/dashboard/resumen (Fase 2)
    resp_dash = await client.get("/api/v1/deuda/dashboard/resumen", headers=headers)
    assert resp_dash.status_code == 200
    dash_data = resp_dash.json()
    assert dash_data["cantidad_suministros"] == 2
    assert dash_data["deuda_total_consolidada_bs"] == 132.34
    assert len(dash_data["suministros"]) == 2

    # 5. HTTP GET /api/v1/deuda/540 con rol CONSULTA_PAGO
    resp_deuda = await client.get(f"/api/v1/deuda/{cod_secundario}", headers=headers)
    assert resp_deuda.status_code == 200
    deuda_data = resp_deuda.json()
    assert deuda_data["cod_socio"] == cod_secundario
    assert deuda_data["saldo_pendiente_bs"] == 132.34
    assert deuda_data["alerta_corte"] is True
    assert deuda_data["esta_vencido"] is True
    # Enmascaramiento activo para CONSULTA_PAGO
    assert deuda_data["suministro"]["rol_usuario"] == "CONSULTA_PAGO"
    assert "D****" in deuda_data["suministro"]["nombre_titular"]
    assert deuda_data["suministro"]["ci_nit"] == "***231"

    # 6. HTTP POST /api/v1/deuda/540/invalidar-cache
    resp_inv = await client.post(f"/api/v1/deuda/{cod_secundario}/invalidar-cache", headers=headers)
    assert resp_inv.status_code == 200
    assert resp_inv.json()["cache_invalidada"] is True

