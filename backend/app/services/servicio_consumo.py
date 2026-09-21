"""
Servicio de negocio para la Analítica e Historial de Consumo Mensual (COSMOL R.L.).
Orquesta la validación de titularidad en PostgreSQL, caché de alto rendimiento en Redis (<20 ms),
cálculo de métricas analíticas (promedios, máximos, mínimos) y detección preventiva
de consumos atípicos o fugas internas (>= +30%).
"""
import logging
from typing import Any, Dict, List, Optional
from uuid import UUID
from redis.asyncio import Redis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ForbiddenException, NotFoundException
from app.db.models.suministro import Suministro
from app.integrations.cosmol_client import CosmolLegacyClient, cosmol_client
from app.schemas.consumo import (
    ConsumoPeriodoResponse,
    EstadisticasConsumoResponse,
    HistorialConsumoResponse,
)
from app.services.servicio_cache_consumo import (
    guardar_consumo_cache,
    invalidar_consumo_cache,
    obtener_consumo_cache,
)

logger = logging.getLogger(__name__)

MESES_ESPANOL = {
    1: "Enero",
    2: "Febrero",
    3: "Marzo",
    4: "Abril",
    5: "Mayo",
    6: "Junio",
    7: "Julio",
    8: "Agosto",
    9: "Septiembre",
    10: "Octubre",
    11: "Noviembre",
    12: "Diciembre",
}


def enmascarar_numero_medidor(nro_medidor: Optional[str]) -> Optional[str]:
    """
    Enmascara el número de medidor para inquilinos y pagadores externos (CONSULTA_PAGO).
    Ejemplo: 'MED-00540' -> 'MED-***-40'
    """
    if not nro_medidor:
        return "MED-***-00"
    limpio = str(nro_medidor).strip()
    if len(limpio) <= 4:
        return "MED-****"
    return f"MED-***-{limpio[-2:]}"


class ServicioConsumo:
    """
    Controlador de negocio para la gestión analítica del historial de consumo.
    """

    def __init__(
        self,
        db: AsyncSession,
        redis_client: Redis,
        client_legado: Optional[CosmolLegacyClient] = None,
    ):
        self.db = db
        self.redis = redis_client
        self.cosmol_client = client_legado or cosmol_client

    def _calcular_estadisticas(
        self, periodos: List[ConsumoPeriodoResponse]
    ) -> EstadisticasConsumoResponse:
        """
        Calcula indicadores estadísticos y evalúa el criterio oficial de consumo atípico
        (>= +30% sobre el promedio histórico) para alertar sobre posibles fugas internas.
        """
        if not periodos:
            return EstadisticasConsumoResponse(
                promedio_m3=0.0,
                consumo_maximo_m3=0.0,
                mes_consumo_maximo="N/A",
                consumo_minimo_m3=0.0,
                mes_consumo_minimo="N/A",
                consumo_ultimo_mes_m3=0.0,
                consumo_atipico=False,
                porcentaje_variacion_ultimo_mes=None,
                mensaje_alerta=None,
                tendencia="ESTABLE",
            )

        total_volumen = sum(p.consumo_m3 for p in periodos)
        cantidad = len(periodos)
        promedio_m3 = round(total_volumen / cantidad, 2)

        p_max = max(periodos, key=lambda p: p.consumo_m3)
        p_min = min(periodos, key=lambda p: p.consumo_m3)

        ultimo = periodos[-1]
        ultimo_m3 = ultimo.consumo_m3

        # Variación porcentual del último mes frente al promedio
        porcentaje_variacion = None
        if promedio_m3 > 0:
            porcentaje_variacion = round(
                ((ultimo_m3 - promedio_m3) / promedio_m3) * 100.0, 1
            )

        # Criterio oficial COSMOL: salto de >= 30% respecto al promedio
        # Exige al menos 2 periodos históricos registrados para validar anomalía
        consumo_atipico = False
        mensaje_alerta = None
        if cantidad >= 2 and promedio_m3 > 0 and ultimo_m3 >= round(1.30 * promedio_m3, 2):
            consumo_atipico = True
            mensaje_alerta = (
                f"Detectamos un consumo de {ultimo_m3} m³, un {porcentaje_variacion:+0.1f}% superior "
                f"a su promedio habitual ({promedio_m3} m³). Le sugerimos revisar sus instalaciones "
                "internas para descartar fugas de agua no visibles."
            )

        # Tendencia respecto al mes inmediatamente anterior
        tendencia = "ESTABLE"
        if cantidad >= 2:
            penultimo = periodos[-2]
            diferencia = round(ultimo_m3 - penultimo.consumo_m3, 2)
            if diferencia > 1.0:
                tendencia = "SUBIENDO"
            elif diferencia < -1.0:
                tendencia = "BAJANDO"

        return EstadisticasConsumoResponse(
            promedio_m3=promedio_m3,
            consumo_maximo_m3=p_max.consumo_m3,
            mes_consumo_maximo=p_max.periodo,
            consumo_minimo_m3=p_min.consumo_m3,
            mes_consumo_minimo=p_min.periodo,
            consumo_ultimo_mes_m3=ultimo_m3,
            consumo_atipico=consumo_atipico,
            porcentaje_variacion_ultimo_mes=porcentaje_variacion,
            mensaje_alerta=mensaje_alerta,
            tendencia=tendencia,
        )

    def _procesar_periodos_crudos(
        self, datos_raw: List[Dict[str, Any]]
    ) -> List[ConsumoPeriodoResponse]:
        """
        Transforma y valida los registros devueltos por el conector legado a modelos Pydantic.
        """
        periodos: List[ConsumoPeriodoResponse] = []
        for reg in datos_raw:
            try:
                mes = int(reg.get("mes", 1))
                anio = int(reg.get("anio", 2026))
                periodo_str = str(reg.get("periodo", f"{mes:02d}/{anio}")).strip()
                mes_nombre = f"{MESES_ESPANOL.get(mes, '')} {anio}"

                item = ConsumoPeriodoResponse(
                    periodo=periodo_str,
                    mes=mes,
                    mes_nombre=mes_nombre,
                    anio=anio,
                    consumo_m3=round(float(reg.get("consumo_m3", 0.0)), 2),
                    monto_bs=round(float(reg.get("monto_bs", 0.0)), 2),
                    lectura_anterior=round(float(reg.get("lectura_anterior", 0.0)), 2),
                    lectura_actual=round(float(reg.get("lectura_actual", 0.0)), 2),
                    fecha_lectura=reg.get("fecha_lectura"),
                    estado_lectura=str(reg.get("estado_lectura", "NORMAL")).strip().upper(),
                )
                periodos.append(item)
            except (ValueError, TypeError) as exc:
                logger.warning(f"[CONSUMO] Error al normalizar registro de consumo: {exc}")
                continue

        # Ordenar cronológicamente por año y mes
        periodos.sort(key=lambda p: (p.anio, p.mes))
        return periodos

    async def consultar_historial(
        self,
        usuario_id: UUID,
        cod_socio: str,
        forzar_refresco: bool = False,
        meses: int = 12,
    ) -> HistorialConsumoResponse:
        """
        Consulta el historial mensual y analítica de consumo del socio:
        1. Valida permisos y titularidad en PostgreSQL (`suministros`).
        2. Revisa la caché de Redis (<20 ms).
        3. Si hay cache-miss o refresco forzado, consulta al conector legado Informix.
        4. Calcula indicadores estadísticos y alerta de fuga (+30%).
        5. Aplica enmascaramiento según rol (TITULAR vs CONSULTA_PAGO).
        6. Almacena en Redis con TTL de 15 minutos (900 s).
        """
        codigo = str(cod_socio).strip()

        # 1. Validación de seguridad multicuenta en PostgreSQL
        stmt = select(Suministro).where(
            Suministro.usuario_id == usuario_id,
            Suministro.cod_socio == codigo,
        )
        res = await self.db.execute(stmt)
        suministro_db = res.scalar_one_or_none()

        if not suministro_db:
            logger.warning(
                f"[SEGURIDAD MULTICUENTA] Usuario '{usuario_id}' intentó consultar consumos de suministro no vinculado '{codigo}'"
            )
            raise ForbiddenException(
                message=f"No tiene permisos para consultar el historial del suministro '{codigo}' o no está vinculado a su cuenta.",
                error_code="SUPPLY_ACCESS_DENIED",
            )

        rol_usuario = suministro_db.rol  # "TITULAR" o "CONSULTA_PAGO"
        alias = suministro_db.alias or "Mi Suministro"
        nro_medidor_base = f"MED-{codigo.zfill(5)}"

        # 2. Comprobar caché de Redis si no se fuerza el refresco
        if not forzar_refresco:
            cached = await obtener_consumo_cache(self.redis, codigo)
            if cached and isinstance(cached, dict):
                try:
                    # Ajustar enmascaramiento y alias según el usuario actual
                    periodos_cached = [
                        ConsumoPeriodoResponse(**p) for p in cached.get("periodos", [])
                    ]
                    estadisticas_cached = EstadisticasConsumoResponse(
                        **cached.get("estadisticas", {})
                    )
                    medidor_ajustado = (
                        enmascarar_numero_medidor(nro_medidor_base)
                        if rol_usuario == "CONSULTA_PAGO"
                        else nro_medidor_base
                    )

                    return HistorialConsumoResponse(
                        cod_socio=codigo,
                        alias=alias,
                        rol_acceso=rol_usuario,
                        nro_medidor=medidor_ajustado,
                        total_periodos=len(periodos_cached),
                        periodos=periodos_cached,
                        estadisticas=estadisticas_cached,
                    )
                except Exception as exc:
                    logger.warning(f"[CACHE CONSUMO] Error al deserializar caché de '{codigo}': {exc}")

        # 3. Consulta al sistema legado mediante el conector de DEV 1
        datos_crudos = await self.cosmol_client.obtener_historial_consumo(
            cod_socio=codigo, meses=meses
        )

        # 4. Procesar periodos y calcular analítica
        periodos = self._procesar_periodos_crudos(datos_crudos)
        estadisticas = self._calcular_estadisticas(periodos)

        # 5. Guardar en Redis (TTL 15 min / 900 s)
        payload_cache = {
            "cod_socio": codigo,
            "periodos": [p.model_dump() for p in periodos],
            "estadisticas": estadisticas.model_dump(),
        }
        await guardar_consumo_cache(self.redis, codigo, payload_cache)

        # 6. Enmascarar medidor si corresponde
        nro_medidor = (
            enmascarar_numero_medidor(nro_medidor_base)
            if rol_usuario == "CONSULTA_PAGO"
            else nro_medidor_base
        )

        return HistorialConsumoResponse(
            cod_socio=codigo,
            alias=alias,
            rol_acceso=rol_usuario,
            nro_medidor=nro_medidor,
            total_periodos=len(periodos),
            periodos=periodos,
            estadisticas=estadisticas,
        )

    async def invalidar_cache_consumo(self, cod_socio: str) -> bool:
        """
        Elimina la clave de consumo en Redis.
        """
        return await invalidar_consumo_cache(self.redis, cod_socio)
