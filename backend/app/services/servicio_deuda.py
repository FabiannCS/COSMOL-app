"""
Servicio de lógica de negocio para Consulta de Deuda y Dashboard Multicuenta (COSMOL R.L.).
Aplica validación de permisos en PostgreSQL, semaforización de mora, enmascaramiento de privacidad
y caché de alta velocidad en Redis (<20ms).
"""
import calendar
from datetime import date, datetime, timezone
import logging
from typing import Any, Dict, List, Optional
from uuid import UUID

from redis.asyncio import Redis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.exceptions import ForbiddenException, NotFoundException
from app.db.models import Suministro
from app.integrations.cosmol_client import cosmol_client, CosmolLegacyClient
from app.schemas.deuda import (
    DashboardMultiSuministroResponse,
    DetalleSuministroResponse,
    FacturaPendienteResponse,
    ResumenDeudaResponse,
)
from app.services.servicio_cache_deuda import (
    guardar_deuda_cache,
    invalidar_deuda_cache,
    obtener_deuda_cache,
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


def enmascarar_nombre_titular(nombre: str) -> str:
    """
    Enmascara el nombre del titular para inquilinos y pagadores externos.
    Ejemplo: 'DURAN ELOISA RIVERA DE' -> 'D**** E**** R**** D****'
    """
    if not nombre:
        return "S****"
    partes = nombre.strip().split()
    return " ".join(f"{p[0]}****" for p in partes if p)


def enmascarar_ci_nit(ci: str) -> str:
    """
    Enmascara la cédula de identidad o NIT.
    Ejemplo: '2823231' -> '***231'
    """
    if not ci:
        return "****"
    limpio = ci.strip()
    if len(limpio) <= 3:
        return "****"
    return f"***{limpio[-3:]}"


def enmascarar_direccion(direccion: str) -> str:
    """
    Enmascara parcialmente la dirección del predio.
    Ejemplo: 'SANTA CRUZ 117' -> 'SANTA CRUZ ***'
    """
    if not direccion:
        return "Dirección no disponible"
    partes = direccion.strip().split()
    if len(partes) > 1:
        return f"{' '.join(partes[:-1])} ***"
    return f"{partes[0][:3]}***"


class ServicioDeuda:
    """
    Controlador de negocio para la consulta de deudas, semaforización y dashboard.
    """

    def __init__(
        self,
        db: AsyncSession,
        redis_client: Redis,
        client_legado: Optional[CosmolLegacyClient] = None
    ):
        self.db = db
        self.redis = redis_client
        self.cosmol_client = client_legado or cosmol_client

    def _calcular_vencimiento_factura(self, anio: int, mes: int) -> date:
        """
        Calcula la fecha de vencimiento oficial de una factura de agua.
        Regla COSMOL: la factura emitida por el periodo (mes/año) tiene como
        fecha de vencimiento el último día de dicho mes de emisión.
        """
        ultimo_dia = calendar.monthrange(anio, mes)[1]
        return date(anio, mes, ultimo_dia)

    def _procesar_facturas(
        self, deudas_raw: List[Dict[str, Any]]
    ) -> List[FacturaPendienteResponse]:
        """
        Convierte las facturas crudas del sistema legado a modelos Pydantic normalizados
        calculando si ya vencieron y cuántos días de mora tienen.
        """
        hoy = date.today()
        facturas: List[FacturaPendienteResponse] = []

        # Ordenar cronológicamente por año y mes
        deudas_ordenadas = sorted(
            deudas_raw,
            key=lambda f: (int(f.get("ANIO", 0)), int(f.get("NMES", 0)))
        )

        for item in deudas_ordenadas:
            try:
                anio = int(item.get("ANIO", hoy.year))
                mes = int(item.get("NMES", hoy.month))
                monto_bs = round(float(item.get("MONTOTOTAL", 0.0)), 2)
            except (ValueError, TypeError):
                continue

            fecha_vencimiento = self._calcular_vencimiento_factura(anio, mes)
            esta_vencida = hoy > fecha_vencimiento
            dias_mora = (hoy - fecha_vencimiento).days if esta_vencida else 0

            factura = FacturaPendienteResponse(
                nro_facip=str(item.get("NROFACIP", "")).strip(),
                nro_factura=str(item.get("NROFACTURA", "")).strip(),
                cod_autorizacion=str(item.get("CODAUTORIZACION", "")).strip(),
                periodo=f"{mes:02d}/{anio}",
                mes_lectura=f"{MESES_ESPANOL.get(mes, '')} {anio}",
                anio=anio,
                mes=mes,
                monto_bs=monto_bs,
                esta_vencida=esta_vencida,
                dias_mora=dias_mora,
            )
            facturas.append(factura)

        return facturas

    def _aplicar_enmascaramiento(
        self, detalle: DetalleSuministroResponse, rol_usuario: str
    ) -> DetalleSuministroResponse:
        """
        Si el usuario es inquilino o pagador externo (CONSULTA_PAGO),
        enmascara nombre, cédula y dirección para proteger la privacidad.
        """
        if rol_usuario == "CONSULTA_PAGO":
            return DetalleSuministroResponse(
                cod_socio=detalle.cod_socio,
                nombre_titular=enmascarar_nombre_titular(detalle.nombre_titular),
                ci_nit=enmascarar_ci_nit(detalle.ci_nit),
                direccion=enmascarar_direccion(detalle.direccion),
                ubicacion=detalle.ubicacion,
                categoria=detalle.categoria,
                rol_usuario="CONSULTA_PAGO",
            )
        return detalle

    async def obtener_deuda_suministro(
        self,
        usuario_id: UUID,
        cod_socio: str,
        forzar_refresco: bool = False
    ) -> ResumenDeudaResponse:
        """
        Consulta la deuda y estado de un suministro específico:
        1. Valida permisos en PostgreSQL (multicuenta).
        2. Verifica si existe respuesta en caché de Redis (<20ms).
        3. En caso de cache-miss o refresco forzado, consulta al sistema comercial legado.
        4. Normaliza los datos, calcula semáforo de mora y alerta de corte.
        5. Guarda en Redis por 10 minutos (600s).
        6. Aplica enmascaramiento de privacidad según el rol del usuario.
        """
        codigo = str(cod_socio).strip()

        # 1. Validación de permisos en PostgreSQL
        stmt = select(Suministro).where(
            Suministro.usuario_id == usuario_id,
            Suministro.cod_socio == codigo
        )
        res = await self.db.execute(stmt)
        suministro_db = res.scalar_one_or_none()

        if not suministro_db:
            logger.warning(
                f"[SEGURIDAD MULTICUENTA] Usuario {usuario_id} intentó consultar suministro no vinculado '{codigo}'"
            )
            raise ForbiddenException(
                message=f"No tiene permisos para consultar el suministro '{codigo}' o no está vinculado a su cuenta.",
                error_code="SUPPLY_ACCESS_DENIED"
            )

        rol_usuario = suministro_db.rol  # "TITULAR" o "CONSULTA_PAGO"

        # 2. Comprobar caché de Redis si no se forzó refresco
        if not forzar_refresco:
            cached_data = await obtener_deuda_cache(self.redis, codigo)
            if cached_data:
                try:
                    resumen_base = ResumenDeudaResponse(**cached_data)
                    # Ajustar rol y enmascaramiento al rol del usuario actual
                    detalle_ajustado = self._aplicar_enmascaramiento(
                        resumen_base.suministro, rol_usuario
                    )
                    return ResumenDeudaResponse(
                        cod_socio=resumen_base.cod_socio,
                        suministro=detalle_ajustado,
                        moneda=resumen_base.moneda,
                        saldo_pendiente_bs=resumen_base.saldo_pendiente_bs,
                        cantidad_facturas_pendientes=resumen_base.cantidad_facturas_pendientes,
                        fecha_proximo_vencimiento=resumen_base.fecha_proximo_vencimiento,
                        esta_vencido=resumen_base.esta_vencido,
                        alerta_corte=resumen_base.alerta_corte,
                        mensaje_alerta=resumen_base.mensaje_alerta,
                        facturas_pendientes=resumen_base.facturas_pendientes,
                        fecha_consulta=datetime.now(timezone.utc),
                        origen_datos="CACHE",
                    )
                except Exception as exc:
                    logger.warning(f"[CACHE DEUDA] Fallo al deserializar caché de '{codigo}': {exc}")

        # 3. Consulta al Sistema Comercial Legado de COSMOL
        datos_socio = await self.cosmol_client.obtener_datos_socio(codigo)
        if not datos_socio:
            raise NotFoundException(
                message=f"El suministro con código '{codigo}' no fue encontrado en el sistema comercial de COSMOL.",
                error_code="SUPPLY_NOT_FOUND"
            )

        deudas_raw = await self.cosmol_client.obtener_deudas_socio(codigo)

        # 4. Normalización y cálculo de semáforo de deuda
        facturas_pendientes = self._procesar_facturas(deudas_raw)
        saldo_pendiente_bs = round(sum(f.monto_bs for f in facturas_pendientes), 2)
        cantidad_facturas = len(facturas_pendientes)

        esta_vencido = any(f.esta_vencida for f in facturas_pendientes)
        alerta_corte = cantidad_facturas >= 2

        # Mensaje institucional preventivo
        if alerta_corte:
            mensaje_alerta = (
                f"Posee {cantidad_facturas} facturas pendientes. "
                "Evite el corte del servicio cancelando a la brevedad."
            )
        elif esta_vencido:
            mensaje_alerta = "Posee facturas vencidas. Regularice su pago para evitar corte del servicio."
        elif cantidad_facturas == 1:
            mensaje_alerta = "Tiene 1 factura pendiente de pago dentro del plazo reglamentario."
        else:
            mensaje_alerta = "¡Felicidades! Su servicio se encuentra al día sin deudas pendientes."

        # Fecha de próximo vencimiento
        proximo_vencimiento: Optional[date] = None
        if facturas_pendientes:
            no_vencidas = [f for f in facturas_pendientes if not f.esta_vencida]
            if no_vencidas:
                proximo_vencimiento = self._calcular_vencimiento_factura(
                    no_vencidas[0].anio, no_vencidas[0].mes
                )
            else:
                proximo_vencimiento = self._calcular_vencimiento_factura(
                    facturas_pendientes[-1].anio, facturas_pendientes[-1].mes
                )

        # Construcción de ubicación catastral ZONA.RUTA.NROC.NROI
        zona = datos_socio.get("ZONA", "1")
        ruta = datos_socio.get("RUTA", "1")
        nroc = datos_socio.get("NROC", "0")
        nroi = datos_socio.get("NROI", "0")
        ubicacion_str = f"{zona}.{ruta}.{nroc}.{nroi}"

        detalle_titular_completo = DetalleSuministroResponse(
            cod_socio=codigo,
            nombre_titular=datos_socio.get("NOMBRE", "").strip(),
            ci_nit=datos_socio.get("NROCIONIT", "").strip(),
            direccion=datos_socio.get("DIRECCION", "").strip(),
            ubicacion=ubicacion_str,
            categoria="DOMESTICA",
            rol_usuario="TITULAR",
        )

        resumen_completo = ResumenDeudaResponse(
            cod_socio=codigo,
            suministro=detalle_titular_completo,
            moneda="Bs",
            saldo_pendiente_bs=saldo_pendiente_bs,
            cantidad_facturas_pendientes=cantidad_facturas,
            fecha_proximo_vencimiento=proximo_vencimiento,
            esta_vencido=esta_vencido,
            alerta_corte=alerta_corte,
            mensaje_alerta=mensaje_alerta,
            facturas_pendientes=facturas_pendientes,
            fecha_consulta=datetime.now(timezone.utc),
            origen_datos="SISTEMA_LEGADO",
        )

        # 5. Persistir en Redis con los datos completos
        await guardar_deuda_cache(
            self.redis,
            codigo,
            resumen_completo.model_dump(mode="json"),
            ttl_seconds=settings.DEBT_CACHE_TTL_SECONDS
        )

        # 6. Retornar aplicando enmascaramiento si corresponde al rol del usuario
        detalle_para_usuario = self._aplicar_enmascaramiento(
            detalle_titular_completo, rol_usuario
        )
        return ResumenDeudaResponse(
            cod_socio=codigo,
            suministro=detalle_para_usuario,
            moneda="Bs",
            saldo_pendiente_bs=saldo_pendiente_bs,
            cantidad_facturas_pendientes=cantidad_facturas,
            fecha_proximo_vencimiento=proximo_vencimiento,
            esta_vencido=esta_vencido,
            alerta_corte=alerta_corte,
            mensaje_alerta=mensaje_alerta,
            facturas_pendientes=facturas_pendientes,
            fecha_consulta=datetime.now(timezone.utc),
            origen_datos="SISTEMA_LEGADO",
        )

    async def obtener_dashboard_general(
        self, usuario_id: UUID
    ) -> DashboardMultiSuministroResponse:
        """
        Compila el resumen consolidado de todos los suministros vinculados
        al usuario digital para la pantalla de inicio de la aplicación.
        """
        stmt = (
            select(Suministro)
            .where(Suministro.usuario_id == usuario_id)
            .order_by(Suministro.es_suministro_principal.desc(), Suministro.created_at.asc())
        )
        res = await self.db.execute(stmt)
        suministros_db = res.scalars().all()

        resumenes: List[ResumenDeudaResponse] = []
        total_consolidado_bs = 0.0

        for sum_db in suministros_db:
            try:
                resumen = await self.obtener_deuda_suministro(
                    usuario_id=usuario_id,
                    cod_socio=sum_db.cod_socio,
                    forzar_refresco=False
                )
                resumenes.append(resumen)
                total_consolidado_bs += resumen.saldo_pendiente_bs
            except Exception as exc:
                logger.error(f"[DASHBOARD] Error al compilar deuda de suministro '{sum_db.cod_socio}': {exc}")

        return DashboardMultiSuministroResponse(
            usuario_id=usuario_id,
            deuda_total_consolidada_bs=round(total_consolidado_bs, 2),
            cantidad_suministros=len(resumenes),
            suministros=resumenes,
        )

    async def invalidar_cache_socio(self, cod_socio: str) -> bool:
        """
        Invalida la caché de deuda del socio en Redis.
        """
        return await invalidar_deuda_cache(self.redis, cod_socio)
