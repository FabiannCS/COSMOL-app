import asyncio
import json
import logging
from datetime import datetime, timezone, timedelta
from typing import Any, Dict, Optional

from app.core.config import settings
from app.core.redis import get_redis
from app.integrations.reportes_client import ReportesApiClient

logger = logging.getLogger(__name__)

REDIS_KEY_COLA_PENDIENTES = "auditoria:cola_pendientes"


async def encolar_evento_en_redis(payload: Dict[str, Any]) -> bool:
    """
    Almacena un evento en la cola de resiliencia de Redis cuando COSMOL-Reportes está caído.
    Conserva la fecha y hora originales del momento del suceso.
    """
    if not settings.REPORTES_ENABLED or not settings.REPORTES_API_URL:
        return False

    try:
        redis = await get_redis()
        raw_json = json.dumps(payload, ensure_ascii=False)
        total = await redis.rpush(REDIS_KEY_COLA_PENDIENTES, raw_json)
        logger.warning(
            f"[AUDITORIA ENCOLADA] COSMOL-Reportes offline. Evento '{payload.get('tipo_consulta')}' "
            f"para socio {payload.get('codigo_socio')} almacenado en Redis. (Pendientes en cola: {total})"
        )
        return True
    except Exception as exc:
        logger.error(f"[AUDITORIA COLA REDIS ERROR] No se pudo encolar evento en Redis: {exc}")
        return False


async def vaciar_cola_pendientes(limite: int = 20) -> int:
    """
    Expulsa eventos pendientes de la cola de Redis hacia COSMOL-Reportes.
    Si detecta que el servidor sigue fuera de línea, suspende la expulsión sin penalizar los eventos.
    """
    if not settings.REPORTES_ENABLED or not settings.REPORTES_API_URL:
        return 0

    try:
        redis = await get_redis()
        total_pendientes = await redis.llen(REDIS_KEY_COLA_PENDIENTES)
        if total_pendientes == 0:
            return 0

        client = ReportesApiClient()
        sincronizados = 0

        for _ in range(min(limite, total_pendientes)):
            raw_item = await redis.lpop(REDIS_KEY_COLA_PENDIENTES)
            if not raw_item:
                break

            try:
                payload = json.loads(raw_item)
            except Exception:
                logger.error(f"[AUDITORIA COLA CORRUPTA] Elemento inválido descartado: {raw_item}")
                continue

            enviado = await client.enviar_payload_directo(payload)

            if enviado:
                sincronizados += 1
            else:
                if client.esta_servidor_offline():
                    # Reinsertar al inicio de la cola para preservar orden cronológico
                    await redis.lpush(REDIS_KEY_COLA_PENDIENTES, raw_item)
                    logger.warning(
                        f"[AUDITORIA FLUSHER] COSMOL-Reportes sigue offline. Deteniendo vaciado de cola. "
                        f"(Sincronizados en esta ráfaga: {sincronizados})"
                    )
                    break
                else:
                    # El servidor respondió pero rechazó el formato (error 4xx/5xx).
                    logger.warning(
                        f"[AUDITORIA FLUSHER] Evento rechazado por Reportes (no reintentable): "
                        f"socio={payload.get('codigo_socio')}, tipo={payload.get('id_tipo')}"
                    )

        if sincronizados > 0:
            restantes = await redis.llen(REDIS_KEY_COLA_PENDIENTES)
            logger.info(
                f"[AUDITORIA COLA EXPULSADA] Sincronizados exitosamente {sincronizados} eventos con Reportes. "
                f"(Restantes en cola: {restantes})"
            )

        return sincronizados
    except Exception as exc:
        logger.warning(f"[AUDITORIA FLUSHER ERROR] Excepción al vaciar cola de Redis: {exc}")
        return 0


async def worker_flusher_auditoria(intervalo_segundos: int = 30) -> None:
    """
    Bucle en segundo plano que periódicamente verifica si hay eventos acumulados en Redis
    y los expulsa hacia COSMOL-Reportes en cuanto el servicio esté disponible.
    """
    logger.info(f"[AUDITORIA WORKER] Worker de sincronización y reintentos iniciado (intervalo: {intervalo_segundos}s).")
    try:
        while True:
            await asyncio.sleep(intervalo_segundos)
            try:
                redis = await get_redis()
                if await redis.llen(REDIS_KEY_COLA_PENDIENTES) > 0:
                    await vaciar_cola_pendientes(limite=50)
            except Exception as exc:
                logger.debug(f"[AUDITORIA WORKER TICK ERROR] {exc}")
    except asyncio.CancelledError:
        logger.info("[AUDITORIA WORKER] Worker de sincronización detenido limpiamente.")


async def despachar_auditoria_reportes(
    codigo_socio: int,
    nombres: str,
    telefono: Optional[str] = None,
    id_tipo: int = 2,
    tipo_consulta: Optional[str] = None,
    tipo_ubicacion: str = "APP_MOVIL",
) -> None:
    """
    Función asíncrona inyectada en FastAPI BackgroundTasks:
    1. Prepara el payload con timestamp exacto de Montero (UTC-4).
    2. Intenta el despacho directo a COSMOL-Reportes.
    3. Si tiene éxito: Aprovecha la conexión viva para expulsar eventos acumulados en Redis.
    4. Si falla (Reportes caído/timeout): Guarda el evento en la cola de Redis de forma no bloqueante.
    """
    if not settings.REPORTES_ENABLED or not settings.REPORTES_API_URL:
        return

    try:
        # 1. Normalización de datos
        try:
            cod_socio_int = int(str(codigo_socio).strip())
        except (ValueError, TypeError):
            cod_socio_int = 0

        tel_normalizado = str(telefono).strip() if telefono and str(telefono).strip() else None
        nombres_limpio = str(nombres or f"SOCIO {cod_socio_int}").strip()
        tipo_consulta_str = tipo_consulta or ReportesApiClient.CATALOGO_EVENTOS.get(id_tipo, "Consulta General")

        tz_bolivia = timezone(timedelta(hours=-4))
        ahora = datetime.now(tz_bolivia)
        fecha_consulta = ahora.strftime("%Y-%m-%d")
        hora_consulta = ahora.strftime("%H:%M:%S")

        payload: Dict[str, Any] = {
            "codigo_socio": cod_socio_int,
            "nombres": nombres_limpio,
            "telefono": tel_normalizado,
            "id_usuario": int(settings.REPORTES_ID_USUARIO_APP),
            "id_tipo": int(id_tipo),
            "tipo_consulta": tipo_consulta_str,
            "tipo_ubicacion": tipo_ubicacion,
            "fecha_consulta": fecha_consulta,
            "hora_consulta": hora_consulta,
        }

        client = ReportesApiClient()
        enviado = await client.enviar_payload_directo(payload)

        if enviado:
            # Vaciado oportunista: aprovechar la conexión activa para drenar pendientes
            await vaciar_cola_pendientes(limite=5)
        else:
            # Almacenar en cola de Redis ante caída del servidor
            await encolar_evento_en_redis(payload)

    except Exception as exc:
        logger.warning(
            f"[BACKGROUND TASK AUDITORIA] Error inesperado en despacho: {exc}. "
            f"El error no afecta la respuesta al socio."
        )
