import logging
from typing import Optional, Tuple
from redis.asyncio import Redis

logger = logging.getLogger(__name__)

# Escala de bloqueo progresivo en segundos según el número consecutivo de intentos fallidos
# Intento 3: 1 minuto (60s)
# Intento 4: 5 minutos (300s)
# Intento 5: 15 minutos (900s)
# Intento 6: 30 minutos (1800s)
# Intento 7+: 1 hora (3600s)
ESCALA_BLOQUEO = {
    3: 60,
    4: 300,
    5: 900,
    6: 1800,
}
TIEMPO_BLOQUEO_MAXIMO = 3600  # 1 hora


def calcular_segundos_bloqueo(intentos: int) -> Optional[int]:
    """
    Calcula los segundos de bloqueo según la escala progresiva aprobada.
    Retorna None si aún no alcanza el umbral de 3 intentos.
    """
    if intentos < 3:
        return None
    return ESCALA_BLOQUEO.get(intentos, TIEMPO_BLOQUEO_MAXIMO)


async def verificar_bloqueo_activo(redis: Redis, identificador: str) -> Optional[int]:
    """
    Verifica si una cuenta o número de socio se encuentra bloqueado actualmente.
    Retorna el número de segundos restantes de penalización, o None si no está bloqueado.
    """
    clave_bloqueo = f"bloqueo:{identificador}"
    bloqueado = await redis.exists(clave_bloqueo)

    if not bloqueado:
        return None

    ttl_restante = await redis.ttl(clave_bloqueo)
    return max(ttl_restante, 1) if ttl_restante > 0 else None


async def registrar_intento_fallido(
    redis: Redis,
    identificador: str
) -> Tuple[int, Optional[int]]:
    """
    Registra un intento fallido de autenticación para el identificador (ej. cod_socio o teléfono).
    Retorna una tupla: (intentos_acumulados, segundos_bloqueados_si_aplica).
    """
    clave_intentos = f"intentos_fallidos:{identificador}"

    # Incrementar contador en Redis con TTL de 2 horas para expirar memoria de fallos inactivos
    intentos = await redis.incr(clave_intentos)
    if intentos == 1:
        await redis.expire(clave_intentos, 7200)

    segundos_penalizacion = calcular_segundos_bloqueo(intentos)

    if segundos_penalizacion:
        clave_bloqueo = f"bloqueo:{identificador}"
        await redis.set(clave_bloqueo, intentos, ex=segundos_penalizacion)
        logger.warning(
            f"Cuenta '{identificador}' bloqueada temporalmente por {segundos_penalizacion}s "
            f"tras {intentos} intentos fallidos."
        )

    return intentos, segundos_penalizacion


async def limpiar_bloqueo_e_intentos(redis: Redis, identificador: str) -> None:
    """
    Limpia los contadores de fallos y levanta cualquier bloqueo activo en Redis
    tras una autenticación exitosa o verificación por OTP.
    """
    clave_intentos = f"intentos_fallidos:{identificador}"
    clave_bloqueo = f"bloqueo:{identificador}"
    await redis.delete(clave_intentos, clave_bloqueo)
    logger.info(f"Contador de intentos y bloqueos limpiados para '{identificador}'")
