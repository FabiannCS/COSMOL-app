"""
Rutas y Endpoints REST para Autenticación, Onboarding Dual OTP y Multicuenta.
"""
from typing import Any, Dict, List
from fastapi import APIRouter, BackgroundTasks, Depends, status
from redis.asyncio import Redis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_db, get_redis, get_token_payload
from app.db.models import Suministro, Usuario
from app.schemas.suministro import (
    DesvincularSuministroResponse,
    SuministroResponse,
    VincularSuministroRequest,
)
from app.schemas.usuario import (
    CrearPinPasswordRequest,
    LoginRequest,
    MigrarTelefonoConfirmarRequest,
    MigrarTelefonoConfirmarResponse,
    MigrarTelefonoIniciarRequest,
    MigrarTelefonoIniciarResponse,
    PrimerAccesoResponse,
    RecuperarCambiarPinRequest,
    RecuperarCambiarPinResponse,
    RecuperarSolicitarOtpRequest,
    RecuperarSolicitarOtpResponse,
    RecuperarValidarTitularRequest,
    RecuperarValidarTitularResponse,
    RecuperarVerificarOtpRequest,
    RecuperarVerificarOtpResponse,
    RenovarTokenRequest,
    SolicitarOtpRequest,
    TokenResponse,
    VerificarOtpRequest,
    VerificarSocioRequest,
)
from app.services.servicio_autenticacion import ServicioAutenticacion
from app.services.servicio_suministros import ServicioSuministros
from app.tasks.auditoria_reportes import despachar_auditoria_reportes

router = APIRouter()


@router.post(
    "/verificar-socio",
    response_model=PrimerAccesoResponse,
    status_code=status.HTTP_200_OK,
    summary="Paso 1 Onboarding: Verificar código de socio y CI",
    description="Valida la coincidencia del código de socio y carnet contra el sistema comercial legado de COSMOL e informa si ya existe cuenta previa."
)
@router.post(
    "/verificar-primer-acceso",
    response_model=PrimerAccesoResponse,
    status_code=status.HTTP_200_OK,
    include_in_schema=False
)
async def verificar_socio(
    datos: VerificarSocioRequest,
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis)
) -> PrimerAccesoResponse:
    servicio = ServicioAutenticacion(redis, db=db)
    res = await servicio.verificar_primer_acceso(
        cod_socio=datos.cod_socio,
        ci=datos.ci
    )
    return PrimerAccesoResponse(**res)



@router.post(
    "/solicitar-otp",
    status_code=status.HTTP_200_OK,
    summary="Paso 2 Onboarding: Solicitar código OTP dual (WhatsApp o SMS)",
    description="Genera y envía un código de seguridad de 6 dígitos con vigencia de 5 minutos al celular indicado."
)
async def solicitar_otp(
    datos: SolicitarOtpRequest,
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis)
) -> Dict[str, Any]:
    servicio = ServicioAutenticacion(redis, db=db)
    return await servicio.solicitar_otp(
        cod_socio=datos.cod_socio,
        telefono=datos.telefono,
        canal=datos.canal
    )


@router.post(
    "/verificar-otp",
    status_code=status.HTTP_200_OK,
    summary="Paso 3 Onboarding: Validar código OTP de 6 dígitos",
    description="Verifica el código ingresado. Al tener éxito, invalida el código y emite un token de autorización temporal."
)
async def verificar_otp(
    datos: VerificarOtpRequest,
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis)
) -> Dict[str, Any]:
    servicio = ServicioAutenticacion(redis, db=db)
    return await servicio.verificar_otp(
        telefono=datos.telefono,
        codigo=datos.codigo
    )


@router.post(
    "/establecer-pin",
    status_code=status.HTTP_201_CREATED,
    summary="Paso 4 Onboarding: Crear PIN personal y cerrar onboarding",
    description="Crea la credencial segura hasheada en bcrypt. A partir de este momento la CI queda deshabilitada como contraseña."
)
async def establecer_pin(
    datos: CrearPinPasswordRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis)
) -> Dict[str, Any]:
    servicio = ServicioAutenticacion(redis, db=db)
    resultado = await servicio.establecer_pin(
        telefono=datos.telefono,
        token_otp_valido=datos.token_otp_valido,
        nuevo_pin=datos.nuevo_pin
    )
    # Despachar evento de Onboarding exitoso a COSMOL-Reportes en segundo plano
    cod_socio_val = resultado.get("cod_socio", 0)
    try:
        cod_socio_int = int(str(cod_socio_val).strip())
    except (ValueError, TypeError):
        cod_socio_int = 0
    background_tasks.add_task(
        despachar_auditoria_reportes,
        codigo_socio=cod_socio_int,
        nombres=f"SOCIO {cod_socio_int}" if cod_socio_int else "NUEVO SOCIO",
        telefono=datos.telefono,
        id_tipo=1,
        tipo_consulta="Autenticación / Acceso",
    )
    return resultado


@router.post(
    "/login",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
    summary="Login Diario: Autenticación con Código de Socio + PIN",
    description="Inicia sesión, evalúa bloqueo progresivo tras 3 intentos fallidos y emite tokens JWT (Access 15m, Refresh 7d)."
)
async def login(
    datos: LoginRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis)
) -> TokenResponse:
    servicio = ServicioAutenticacion(redis, db=db)
    respuesta = await servicio.autenticar_socio(
        cod_socio=datos.cod_socio,
        pin_password=datos.pin_password,
        device_id=datos.device_id,
        modelo_dispositivo=datos.modelo_dispositivo
    )
    # Despachar evento de Login exitoso a COSMOL-Reportes en segundo plano con datos enriquecidos
    try:
        cod_socio_int = int(str(datos.cod_socio).strip())
    except (ValueError, TypeError):
        cod_socio_int = 0

    # Rescatar nombre oficial del socio desde los suministros vinculados
    nombre_titular = f"SOCIO {cod_socio_int}"
    if respuesta.suministros:
        for s in respuesta.suministros:
            if str(s.cod_socio) == str(datos.cod_socio) and s.nombre:
                nombre_titular = s.nombre
                break
        if nombre_titular == f"SOCIO {cod_socio_int}" and respuesta.suministros[0].nombre:
            nombre_titular = respuesta.suministros[0].nombre

    # Rescatar número celular personal verificado del usuario
    telefono_socio = None
    try:
        stmt_tel = (
            select(Usuario.telefono)
            .join(Suministro, Suministro.usuario_id == Usuario.id)
            .where(Suministro.cod_socio == datos.cod_socio)
            .limit(1)
        )
        res_tel = await db.execute(stmt_tel)
        telefono_socio = res_tel.scalar_one_or_none()
    except Exception:
        pass

    background_tasks.add_task(
        despachar_auditoria_reportes,
        codigo_socio=cod_socio_int,
        nombres=nombre_titular,
        telefono=telefono_socio,
        id_tipo=1,
        tipo_consulta="Autenticación / Acceso",
    )
    return respuesta


@router.post(
    "/renovar-token",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
    summary="Renovación silenciosa de sesión (Refresh Token)",
    description="Emite un nuevo Access Token verificando que el hardware no haya sido revocado por otro inicio de sesión."
)
async def renovar_token(
    datos: RenovarTokenRequest,
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis)
) -> TokenResponse:
    servicio = ServicioAutenticacion(redis, db=db)
    return await servicio.renovar_token(
        refresh_token=datos.refresh_token,
        device_id=datos.device_id
    )


@router.post(
    "/logout",
    status_code=status.HTTP_200_OK,
    summary="Cerrar sesión activa",
    description="Revoca la sesión del usuario en Redis y limpia el registro de hardware activo."
)
async def logout(
    token_payload: Dict[str, Any] = Depends(get_token_payload),
    redis: Redis = Depends(get_redis)
) -> Dict[str, Any]:
    user_id = str(token_payload.get("sub", ""))
    device_id = token_payload.get("device_id")
    servicio = ServicioAutenticacion(redis)
    return await servicio.cerrar_sesion(user_id=user_id, device_id=device_id)


@router.post(
    "/suministros/vincular",
    response_model=SuministroResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Multicuenta: Vincular nuevo suministro (Titular o Inquilino)",
    description="Vincula un suministro adicional. Si incluye CI o medidor oficial otorga rol TITULAR, si no, otorga CONSULTA_PAGO."
)
async def vincular_suministro(
    datos: VincularSuministroRequest,
    token_payload: Dict[str, Any] = Depends(get_token_payload),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis)
) -> SuministroResponse:
    cod_socio_principal = str(token_payload.get("cod_socio", ""))
    usuario_id = str(token_payload.get("sub", ""))
    servicio = ServicioSuministros(redis, db=db)
    return await servicio.vincular_suministro(
        cod_socio_principal=cod_socio_principal,
        datos=datos,
        usuario_id_token=usuario_id
    )


@router.get(
    "/suministros",
    response_model=List[SuministroResponse],
    status_code=status.HTTP_200_OK,
    summary="Multicuenta: Listar todos los suministros vinculados",
    description="Devuelve el catálogo de suministros del socio para alimentar el selector de cuentas del Dashboard."
)
async def listar_suministros(
    token_payload: Dict[str, Any] = Depends(get_token_payload),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis)
) -> List[SuministroResponse]:
    cod_socio_principal = str(token_payload.get("cod_socio", ""))
    usuario_id = str(token_payload.get("sub", ""))
    servicio = ServicioSuministros(redis, db=db)
    return await servicio.listar_suministros(
        cod_socio_principal=cod_socio_principal,
        usuario_id_token=usuario_id
    )


@router.delete(
    "/suministros/{cod_socio}",
    response_model=DesvincularSuministroResponse,
    status_code=status.HTTP_200_OK,
    summary="Multicuenta: Desvincular suministro secundario",
    description="Desvincula un suministro en modo consulta o inquilino. Prohibido para el titular principal."
)
async def desvincular_suministro(
    cod_socio: str,
    token_payload: Dict[str, Any] = Depends(get_token_payload),
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis)
) -> DesvincularSuministroResponse:
    cod_socio_principal = str(token_payload.get("cod_socio", ""))
    usuario_id = str(token_payload.get("sub", ""))
    servicio = ServicioSuministros(redis, db=db)
    res = await servicio.desvincular_suministro(
        cod_socio_principal=cod_socio_principal,
        cod_socio_a_desvincular=cod_socio,
        usuario_id_token=usuario_id
    )
    return DesvincularSuministroResponse(**res)


# ==============================================================================
# MIGRACIÓN SEGURA DE TELÉFONO (CAMBIO DE CHIP / CELULAR NUEVO)
# ==============================================================================

@router.post(
    "/migrar-telefono/iniciar",
    response_model=MigrarTelefonoIniciarResponse,
    status_code=status.HTTP_200_OK,
    summary="Migración: Iniciar cambio de número celular con validación de PIN titular",
    description="Valida las credenciales y el PIN actual del titular antes de enviar el OTP de verificación al nuevo celular."
)
async def migrar_telefono_iniciar(
    datos: MigrarTelefonoIniciarRequest,
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis)
) -> MigrarTelefonoIniciarResponse:
    servicio = ServicioAutenticacion(redis, db=db)
    res = await servicio.iniciar_migracion_telefono(
        cod_socio=datos.cod_socio,
        ci=datos.ci,
        pin_actual=datos.pin_actual,
        nuevo_telefono=datos.nuevo_telefono,
        canal=datos.canal
    )
    return MigrarTelefonoIniciarResponse(**res)


@router.post(
    "/migrar-telefono/confirmar",
    response_model=MigrarTelefonoConfirmarResponse,
    status_code=status.HTTP_200_OK,
    summary="Migración: Confirmar OTP del nuevo número y finalizar traspaso",
    description="Valida el código de seguridad recibido en el nuevo teléfono, actualiza la BD y emite nuevos tokens JWT."
)
async def migrar_telefono_confirmar(
    datos: MigrarTelefonoConfirmarRequest,
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis)
) -> MigrarTelefonoConfirmarResponse:
    servicio = ServicioAutenticacion(redis, db=db)
    res = await servicio.confirmar_migracion_telefono(
        session_id=datos.session_id,
        codigo_otp=datos.codigo_otp
    )
    return MigrarTelefonoConfirmarResponse(**res)


# ==============================================================================
# RECUPERACIÓN SEGURA DE CONTRASEÑA / PIN (ZERO-TRUST)
# ==============================================================================

@router.post(
    "/recuperar-password/validar-titular",
    response_model=RecuperarValidarTitularResponse,
    status_code=status.HTTP_200_OK,
    summary="Recuperar PIN Paso 1: Validar titular y obtener celular enmascarado",
    description="Comprueba titularidad en COSMOL y retorna el número celular registrado en BD para recepción de OTP."
)
async def recuperar_validar_titular(
    datos: RecuperarValidarTitularRequest,
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis)
) -> RecuperarValidarTitularResponse:
    servicio = ServicioAutenticacion(redis, db=db)
    res = await servicio.validar_titular_recuperacion(
        cod_socio=datos.cod_socio,
        ci=datos.ci
    )
    return RecuperarValidarTitularResponse(**res)


@router.post(
    "/recuperar-password/solicitar-otp",
    response_model=RecuperarSolicitarOtpResponse,
    status_code=status.HTTP_200_OK,
    summary="Recuperar PIN Paso 2: Despachar código OTP al número registrado",
    description="Genera y envía un código de 6 dígitos con vigencia de 5 minutos al teléfono asociado a la cuenta."
)
async def recuperar_solicitar_otp(
    datos: RecuperarSolicitarOtpRequest,
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis)
) -> RecuperarSolicitarOtpResponse:
    servicio = ServicioAutenticacion(redis, db=db)
    res = await servicio.solicitar_otp_recuperacion(
        session_id=datos.session_id,
        canal=datos.canal
    )
    return RecuperarSolicitarOtpResponse(**res)


@router.post(
    "/recuperar-password/verificar-otp",
    response_model=RecuperarVerificarOtpResponse,
    status_code=status.HTTP_200_OK,
    summary="Recuperar PIN Paso 3: Validar OTP y emitir token de recuperación",
    description="Valida el código de 6 dígitos y emite un token temporal de un solo uso para autorizar el cambio de PIN."
)
async def recuperar_verificar_otp(
    datos: RecuperarVerificarOtpRequest,
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis)
) -> RecuperarVerificarOtpResponse:
    servicio = ServicioAutenticacion(redis, db=db)
    res = await servicio.verificar_otp_recuperacion(
        session_id=datos.session_id,
        codigo=datos.codigo
    )
    return RecuperarVerificarOtpResponse(**res)


@router.post(
    "/recuperar-password/cambiar-pin",
    response_model=RecuperarCambiarPinResponse,
    status_code=status.HTTP_200_OK,
    summary="Recuperar PIN Paso 4: Establecer nuevo PIN y desbloquear cuenta",
    description="Actualiza el hash bcrypt del PIN en base de datos, revoca sesiones previas y resetea contadores de bloqueo."
)
async def recuperar_cambiar_pin(
    datos: RecuperarCambiarPinRequest,
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis)
) -> RecuperarCambiarPinResponse:
    servicio = ServicioAutenticacion(redis, db=db)
    res = await servicio.cambiar_pin_recuperacion(
        token_recuperacion=datos.token_recuperacion,
        nuevo_pin=datos.nuevo_pin
    )
    return RecuperarCambiarPinResponse(**res)


