import json
import logging
import secrets
from typing import Optional
from redis.asyncio import Redis

from app.core.config import settings
from app.core.exceptions import BadRequestException
from app.integrations.whatsapp_client import whatsapp_client
from app.integrations.sms_client import sms_client

logger = logging.getLogger(__name__)


def generar_codigo_otp(longitud: int = 6) -> str:
    """
    Genera un código OTP numérico aleatorio criptográficamente seguro de N dígitos.
    """
    digitos = "0123456789"
    return "".join(secrets.choice(digitos) for _ in range(longitud))


async def validar_limite_envios_redis(redis: Redis, telefono: str) -> bool:
    """
    Controla que no se soliciten más de N códigos OTP por hora para el mismo número celular.
    Retorna True si la solicitud está permitida, False si se superó el límite.
    """
    clave_rate = f"otp_rate:{telefono}"
    solicitudes = await redis.get(clave_rate)

    if solicitudes and int(solicitudes) >= settings.OTP_MAX_REQUESTS_PER_HOUR:
        return False

    if not solicitudes:
        # Primera solicitud en la ventana: crear clave con TTL de 1 hora (3600s)
        await redis.set(clave_rate, 1, ex=3600)
    else:
        await redis.incr(clave_rate)

    return True


async def guardar_otp_en_redis(
    redis: Redis,
    telefono: str,
    codigo: str,
    proposito: str = "ONBOARDING"
) -> None:
    """
    Almacena el código OTP en memoria Redis con TTL de 5 minutos (300 segundos).
    """
    clave_otp = f"otp:{telefono}"
    datos = {
        "codigo": codigo,
        "proposito": proposito,
        "intentos_fallidos": 0
    }
    await redis.set(
        clave_otp,
        json.dumps(datos),
        ex=settings.OTP_EXPIRE_SECONDS
    )


async def verificar_otp_en_redis(
    redis: Redis,
    telefono: str,
    codigo_ingresado: str
) -> bool:
    """
    Valida el código OTP ingresado contra Redis.
    Aplica el principio de un solo uso (consume-once): si es válido, se elimina de inmediato.
    Si se falla 3 veces en la verificación, se invalida el código para evitar fuerza bruta.
    """
    clave_otp = f"otp:{telefono}"
    registro_raw = await redis.get(clave_otp)

    if not registro_raw:
        return False

    registro = json.loads(registro_raw)
    codigo_esperado = str(registro.get("codigo", "")).strip()

    if codigo_ingresado.strip() == codigo_esperado:
        # Código correcto: eliminar inmediatamente para evitar ataques de repetición
        await redis.delete(clave_otp)
        return True

    # Código incorrecto: registrar fallo de verificación
    intentos = registro.get("intentos_fallidos", 0) + 1
    if intentos >= 3:
        # Superó los intentos de tipeo del código: quemar el OTP
        await redis.delete(clave_otp)
        logger.warning(f"OTP para {telefono} quemado por 3 intentos erróneos de tipeo")
    else:
        registro["intentos_fallidos"] = intentos
        # Preservar el TTL restante
        ttl_restante = await redis.ttl(clave_otp)
        if ttl_restante > 0:
            await redis.set(clave_otp, json.dumps(registro), ex=ttl_restante)

    return False


async def despachar_otp(
    redis: Redis,
    telefono: str,
    canal: str = "WHATSAPP",
    proposito: str = "ONBOARDING"
) -> str:
    """
    Servicio de alto nivel:
    1. Verifica rate limiting (máx 3 envíos por hora).
    2. Genera código de 6 dígitos.
    3. Guarda en Redis con TTL de 5 minutos.
    4. Envía mediante WhatsApp Cloud API o SMS.
    Retorna el código generado.
    """
    # 1. Validar límite de solicitudes
    puede_enviar = await validar_limite_envios_redis(redis, telefono)
    if not puede_enviar:
        raise BadRequestException(
            message=f"Ha superado el límite de solicitudes de código ({settings.OTP_MAX_REQUESTS_PER_HOUR} por hora). Por favor, espere antes de intentar de nuevo.",
            error_code="OTP_RATE_LIMIT_EXCEEDED"
        )

    # 2. Generar código
    codigo = generar_codigo_otp(settings.OTP_CODE_LENGTH)

    # 3. Guardar en Redis
    await guardar_otp_en_redis(redis, telefono, codigo, proposito)

    # 4. Despachar según canal
    canal_upper = canal.upper()
    if canal_upper == "WHATSAPP":
        await whatsapp_client.enviar_otp(telefono, codigo)
    elif canal_upper == "SMS":
        await sms_client.enviar_sms_otp(telefono, codigo)
    else:
        raise BadRequestException(
            message=f"Canal de mensajería '{canal}' no soportado. Elija 'WHATSAPP' o 'SMS'.",
            error_code="UNSUPPORTED_OTP_CHANNEL"
        )

    return codigo
