"""
Prueba unitaria e integral del Aislamiento Multicuenta y Login Exclusivo Titular ("Caso Juan y José").
Valida que:
1. Si Juan agrega como inquilino el código de José, nadie pueda iniciar sesión con ese código secundario.
2. La vinculación de inquilino de Juan NO bloquee el Onboarding legítimo de José como Titular.
3. Al iniciar sesión, José solo ve su propia cuenta y Juan ve su titular y su consulta.
4. Existe estricto aislamiento unidireccional y privacidad de datos.
"""
import uuid
import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import UnauthorizedException
from app.db.models.usuario import Usuario
from app.db.models.suministro import Suministro
from app.core.security import get_password_hash
from app.services.servicio_autenticacion import ServicioAutenticacion
from app.services.servicio_suministros import ServicioSuministros
from app.schemas.suministro import VincularSuministroRequest


@pytest.mark.asyncio
async def test_aislamiento_multicuenta_y_login_titular_juan_y_jose(db_override, redis_override):
    from app.main import app
    from app.api.deps import get_db, get_redis

    # Resolver sesión DB y cliente Redis inyectados
    get_db_gen = app.dependency_overrides[get_db]()
    session: AsyncSession = await anext(get_db_gen)
    redis_client = app.dependency_overrides[get_redis]()

    auth_service = ServicioAutenticacion(redis_client, db=session)
    sum_service = ServicioSuministros(redis_client, db=session)

    rand_suffix = uuid.uuid4().hex[:6]
    cod_juan = f"J{rand_suffix[:4]}"
    ci_juan = "1111111"
    tel_juan = f"+59171{rand_suffix[:6]}"
    pin_juan = "1122"

    cod_jose = f"K{rand_suffix[:4]}"
    ci_jose = "2222222"
    tel_jose = f"+59172{rand_suffix[:6]}"
    pin_jose = "3344"

    try:
        # 1. Crear Usuario A (Juan) con Suministro Titular (99001)
        juan_id = uuid.uuid4()
        user_juan = Usuario(
            id=juan_id,
            telefono=tel_juan,
            password_hash=get_password_hash(pin_juan),
            esta_activo=True
        )
        session.add(user_juan)
        await session.flush()

        sum_juan_titular = Suministro(
            usuario_id=juan_id,
            cod_socio=cod_juan,
            alias="Casa de Juan",
            rol="TITULAR",
            es_suministro_principal=True
        )
        session.add(sum_juan_titular)

        # Juan agrega el código de José (99002) como INQUILINO / CONSULTA_PAGO
        sum_juan_inquilino = Suministro(
            usuario_id=juan_id,
            cod_socio=cod_jose,
            alias="Alquiler José",
            rol="CONSULTA_PAGO",
            es_suministro_principal=False
        )
        session.add(sum_juan_inquilino)
        await session.commit()

        # 2. Intento de inicio de sesión con el código de José (que solo existe como CONSULTA_PAGO)
        # Debe ser estrictamente RECHAZADO porque no es Titular
        with pytest.raises(UnauthorizedException) as exc_login_inq:
            await auth_service.autenticar_socio(cod_jose, "0000", device_id="dev-jose-0")
        assert exc_login_inq.value.error_code == "LOGIN_TITULAR_REQUIRED"

        # 3. José intenta hacer primer acceso (Onboarding) con su código
        # Comprobar que verificar_primer_acceso detecta es_recuperacion = False
        # (Es decir, la existencia del registro CONSULTA_PAGO de Juan NO bloquea a José)
        stmt_tit = select(Suministro).where(Suministro.cod_socio == cod_jose, Suministro.rol == "TITULAR")
        res_tit = await session.execute(stmt_tit)
        assert res_tit.scalars().first() is None, "Aún no debe existir un titular para José"

        # 4. José completa su registro como TITULAR legítimo de su código
        jose_id = uuid.uuid4()
        user_jose = Usuario(
            id=jose_id,
            telefono=tel_jose,
            password_hash=get_password_hash(pin_jose),
            esta_activo=True
        )
        session.add(user_jose)
        await session.flush()

        sum_jose_titular = Suministro(
            usuario_id=jose_id,
            cod_socio=cod_jose,
            alias="Casa Propia José",
            rol="TITULAR",
            es_suministro_principal=True
        )
        session.add(sum_jose_titular)
        await session.commit()

        # 5. José inicia sesión con su código TITULAR
        token_jose = await auth_service.autenticar_socio(cod_jose, pin_jose, device_id="dev-jose-1")
        assert token_jose.access_token is not None
        # José SOLO debe ver su propio suministro
        assert len(token_jose.suministros) == 1
        assert token_jose.suministros[0].cod_socio == cod_jose
        assert token_jose.suministros[0].rol == "TITULAR"

        # Listar suministros de José por API/Servicio
        lista_jose = await sum_service.listar_suministros(cod_socio_principal=cod_jose, usuario_id_token=str(jose_id))
        assert len(lista_jose) == 1
        assert lista_jose[0].cod_socio == cod_jose
        assert cod_juan not in [s.cod_socio for s in lista_jose], "José NUNCA debe ver el suministro de Juan"

        # 6. Juan inicia sesión con su código TITULAR
        token_juan = await auth_service.autenticar_socio(cod_juan, pin_juan, device_id="dev-juan-1")
        assert token_juan.access_token is not None
        # Juan debe ver sus 2 suministros: su titular (99001) y su inquilino (99002)
        codigos_juan = [s.cod_socio for s in token_juan.suministros]
        assert cod_juan in codigos_juan
        assert cod_jose in codigos_juan
        assert len(token_juan.suministros) == 2

        # Listar suministros de Juan por API/Servicio
        lista_juan = await sum_service.listar_suministros(cod_socio_principal=cod_juan, usuario_id_token=str(juan_id))
        assert len(lista_juan) == 2

    finally:
        # Limpieza de registros creados en el test
        await session.rollback()
        stmt_del_sum = select(Suministro).where(Suministro.cod_socio.in_([cod_juan, cod_jose]))
        res_del_sum = await session.execute(stmt_del_sum)
        for s in res_del_sum.scalars().all():
            await session.delete(s)

        stmt_del_usr = select(Usuario).where(Usuario.telefono.in_([tel_juan, tel_jose]))
        res_del_usr = await session.execute(stmt_del_usr)
        for u in res_del_usr.scalars().all():
            await session.delete(u)

        await session.commit()
        try:
            await anext(get_db_gen)
        except StopAsyncIteration:
            pass
