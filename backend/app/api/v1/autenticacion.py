"""
Rutas y Endpoints REST para Autenticación, Onboarding Dual OTP y Multicuenta.
"""
from typing import Any, Dict, List
from fastapi import APIRouter, BackgroundTasks, Depends, status
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_db, get_redis, get_token_payload
from app.schemas.suministro import SuministroResponse, VincularSuministroRequest
from app.schemas.usuario import (
    CrearPinPasswordRequest,
    LoginRequest,
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
    status_code=status.HTTP_200_OK,
    summary="Paso 1 Onboarding: Verificar código de socio y CI",
    description="Valida la coincidencia del código de socio y carnet contra el sistema comercial legado de COSMOL."
)
async def verificar_socio(
    datos: VerificarSocioRequest,
    db: AsyncSession = Depends(get_db),
    redis: Redis = Depends(get_redis)
) -> Dict[str, Any]:
    servicio = ServicioAutenticacion(redis, db=db)
    return await servicio.verificar_primer_acceso(
        cod_socio=datos.cod_socio,
        ci=datos.ci
    )


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
    # Despachar evento de Login exitoso a COSMOL-Reportes en segundo plano
    try:
        cod_socio_int = int(str(datos.cod_socio).strip())
    except (ValueError, TypeError):
        cod_socio_int = 0
    background_tasks.add_task(
        despachar_auditoria_reportes,
        codigo_socio=cod_socio_int,
        nombres=f"SOCIO {cod_socio_int}",
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
    cod_socio_principal = token_payload.get("cod_socio", "")
    servicio = ServicioSuministros(redis, db=db)
    return await servicio.vincular_suministro(
        cod_socio_principal=cod_socio_principal,
        datos=datos
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
    cod_socio_principal = token_payload.get("cod_socio", "")
    servicio = ServicioSuministros(redis, db=db)
    return await servicio.listar_suministros(cod_socio_principal=cod_socio_principal)
