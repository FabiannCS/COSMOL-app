import logging
from typing import Any, Dict, List, Optional
from fastapi import BackgroundTasks

from app.core.exceptions import BadRequestException, NotFoundException
from app.integrations.cosmol_client import cosmol_client
from app.schemas.reconexion import (
    ElegibilidadReconexionResponse,
    ReconexionHistorialItem,
    SolicitudReconexionCreate,
    SolicitudReconexionResponse,
)
from app.tasks.auditoria_reportes import despachar_auditoria_reportes

logger = logging.getLogger(__name__)


class ServicioReconexion:
    """
    Servicio orquestador del Módulo de Reconexión de Servicios de COSMOL R.L.
    Implementa las 5 reglas de negocio técnicas y comerciales:
    1. Verificación de no duplicidad de trámites activos (estado PENDIENTE).
    2. Límite de morosidad (máximo 2 facturas pendientes de pago).
    3. Resolución y formateo de la ubicación técnica catastral ZONA.RUTA.NROC.NROI.
    4. Ensamblado de parámetros de campo (GPS, foto MinIO, tipo y glosa).
    5. Despacho asíncrono y resiliente de auditoría a COSMOL-Reportes (id_tipo: 5).
    """

    async def verificar_elegibilidad(self, cod_socio: str) -> ElegibilidadReconexionResponse:
        codigo = str(cod_socio).strip()

        # 1. Obtener datos maestros del socio (SAI)
        datos_socio = await cosmol_client.obtener_datos_socio(codigo)
        if not datos_socio:
            return ElegibilidadReconexionResponse(
                codigo_socio=codigo,
                es_elegible=False,
                motivo_bloqueo="SOCIO_NO_ENCONTRADO",
                mensaje_usuario="No se encontró ningún socio registrado con el código ingresado. Verifique su número de contrato.",
                facturas_pendientes=0,
                total_deuda_bs=0.0
            )

        nombres_titular = datos_socio.get("NOMBRE") or f"SOCIO {codigo}"

        # 2. Regla 1: Verificación de Trámites Previos (No duplicidad)
        reconexiones = await cosmol_client.obtener_reconexiones_socio(codigo)
        tramite_pendiente = None
        for item in reconexiones:
            estado = str(item.get("estado") or "").strip().upper()
            if estado == "PENDIENTE":
                tramite_pendiente = item
                break

        if tramite_pendiente:
            id_tramite = tramite_pendiente.get("id_reconexion")
            return ElegibilidadReconexionResponse(
                codigo_socio=codigo,
                es_elegible=False,
                motivo_bloqueo="TRAMITE_DUPLICADO",
                mensaje_usuario=(
                    f"Actualmente ya cuenta con una solicitud de reconexión en estado PENDIENTE "
                    f"(Ticket #{id_tramite}). Nuestro equipo técnico atenderá su caso a la brevedad."
                ),
                facturas_pendientes=0,
                total_deuda_bs=0.0,
                tramite_pendiente_id=id_tramite,
                nombres=nombres_titular
            )

        # 3. Regla 2: Límite de Morosidad (Máximo 2 meses de deuda)
        deudas = await cosmol_client.obtener_deudas_socio(codigo)
        facturas_pendientes = len(deudas)
        total_deuda_bs = sum(
            float(f.get("MONTOTOTAL") or f.get("monto") or 0.0)
            for f in deudas
        )

        if facturas_pendientes > 2:
            return ElegibilidadReconexionResponse(
                codigo_socio=codigo,
                es_elegible=False,
                motivo_bloqueo="ALTA_MOROSIDAD",
                mensaje_usuario=(
                    f"No es posible solicitar la reconexión porque registra {facturas_pendientes} facturas "
                    f"pendientes (Deuda total: Bs {total_deuda_bs:.2f}). La normativa permite un máximo de 2 facturas en mora. "
                    f"Por favor regularice su pago para habilitar este trámite."
                ),
                facturas_pendientes=facturas_pendientes,
                total_deuda_bs=round(total_deuda_bs, 2),
                nombres=nombres_titular
            )

        # 4. Regla 3: Resolución de la Ubicación Técnica Catastral {ZONA}.{RUTA}.{NROC}.{NROI}
        try:
            zona_int = int(str(datos_socio.get("ZONA") or "0").strip())
        except ValueError:
            zona_int = 0

        try:
            ruta_int = int(str(datos_socio.get("RUTA") or "0").strip())
        except ValueError:
            ruta_int = 0

        nroc_str = str(datos_socio.get("NROC") or "0").strip()
        nroi_str = str(datos_socio.get("NROI") or "0").strip()
        ubicacion_catastral = f"{zona_int}.{ruta_int}.{nroc_str}.{nroi_str}"

        return ElegibilidadReconexionResponse(
            codigo_socio=codigo,
            es_elegible=True,
            motivo_bloqueo=None,
            mensaje_usuario="Suministro elegible para trámite de reconexión.",
            facturas_pendientes=facturas_pendientes,
            total_deuda_bs=round(total_deuda_bs, 2),
            tramite_pendiente_id=None,
            ubicacion_catastral=ubicacion_catastral,
            zona=zona_int,
            ruta=ruta_int,
            nombres=nombres_titular
        )

    async def obtener_historial(self, cod_socio: str) -> List[ReconexionHistorialItem]:
        codigo = str(cod_socio).strip()
        datos_raw = await cosmol_client.obtener_reconexiones_socio(codigo)
        resultado: List[ReconexionHistorialItem] = []

        for item in datos_raw:
            try:
                id_rec = int(
                    item.get("id_reconexion")
                    or item.get("ID_RECONEXION")
                    or item.get("id")
                    or item.get("ID")
                    or 0
                )
                if id_rec > 0:
                    raw_tipo = (
                        item.get("tipo")
                        or item.get("TIPO")
                        or item.get("tipo_reconexion")
                        or item.get("TIPO_RECONEXION")
                        or item.get("id_tipo_reconexion")
                        or item.get("ID_TIPO_RECONEXION")
                        or ""
                    )
                    tipo_str = str(raw_tipo).strip()
                    if tipo_str == "1" or tipo_str.lower() == "corte normal":
                        tipo_desc = "Reconexión normal"
                    elif tipo_str == "2" or "medidor" in tipo_str.lower():
                        tipo_desc = "Reconexión con medidor"
                    elif tipo_str == "3" or "material" in tipo_str.lower():
                        tipo_desc = "Reconexión con material"
                    elif tipo_str == "4" or "otro" in tipo_str.lower():
                        tipo_desc = "Otros motivos"
                    elif tipo_str:
                        tipo_desc = tipo_str
                    else:
                        tipo_desc = "Reconexión normal"

                    resultado.append(
                        ReconexionHistorialItem(
                            id_reconexion=id_rec,
                            fecha=str(item.get("fecha") or item.get("FECHA") or "").strip() or None,
                            tipo=tipo_desc,
                            estado=str(item.get("estado") or item.get("ESTADO") or "DESCONOCIDO").strip().upper(),
                            glosa=str(item.get("glosa") or item.get("GLOSA") or "").strip() or None
                        )
                    )
            except (ValueError, TypeError):
                continue

        # Ordenar con el trámite más reciente primero si hay fechas
        return resultado

    async def solicitar_reconexion(
        self,
        datos: SolicitudReconexionCreate,
        background_tasks: BackgroundTasks,
        telefono: Optional[str] = None
    ) -> SolicitudReconexionResponse:
        codigo = str(datos.codigo_socio).strip()

        # 1. Validación estricta de precondiciones
        elegibilidad = await self.verificar_elegibilidad(codigo)
        if not elegibilidad.es_elegible:
            logger.warning(
                f"[RECONEXION BLOQUEADA] Socio {codigo} no elegible: {elegibilidad.motivo_bloqueo} - {elegibilidad.mensaje_usuario}"
            )
            raise BadRequestException(
                message=elegibilidad.mensaje_usuario,
                error_code=elegibilidad.motivo_bloqueo or "RECONEXION_NO_ELEGIBLE"
            )

        # 2. Regla 4: Construir payload oficial para API Central (SAI)
        payload_central: Dict[str, Any] = {
            "usuario_registro": 2,  # Identificador para registros automatizados / app
            "coordenadas_gps": datos.coordenadas_gps.strip(),
            "id_tipo_reconexion": int(datos.id_tipo_reconexion),
            "ubicacion": elegibilidad.ubicacion_catastral,
            "zona": elegibilidad.zona,
            "ruta": elegibilidad.ruta,
            "glosa": datos.glosa.strip(),
            "foto": (datos.foto_url or "").strip(),
        }

        # 3. Envío al sistema central de COSMOL
        resultado_sai = await cosmol_client.registrar_solicitud_reconexion(codigo, payload_central)
        id_reconexion = int(resultado_sai.get("id_reconexion") or 0)
        estado_emitido = str(resultado_sai.get("estado") or "PENDIENTE").strip().upper()

        if id_reconexion <= 0:
            logger.error(f"[RECONEXION ERROR] SAI no retornó id_reconexion válido: {resultado_sai}")
            raise BadRequestException(
                message="El sistema central no confirmó el identificador de la orden de reconexión.",
                error_code="RECONEXION_ID_INVALIDO"
            )

        logger.info(
            f"[RECONEXION EXITOSA] Orden registrada con ticket #{id_reconexion} para socio {codigo} (Estado: {estado_emitido})"
        )

        # 4. Regla 5: Despacho asíncrono y desacoplado hacia COSMOL-Reportes (id_tipo: 5)
        try:
            cod_socio_int = int(codigo)
        except ValueError:
            cod_socio_int = 0

        background_tasks.add_task(
            despachar_auditoria_reportes,
            codigo_socio=cod_socio_int,
            nombres=elegibilidad.nombres or f"Socio #{codigo}",
            telefono=telefono,
            id_tipo=5,
            tipo_consulta="Solicitud de Reconexión",
            tipo_ubicacion="APP_MOVIL"
        )

        return SolicitudReconexionResponse(
            id_reconexion=id_reconexion,
            estado=estado_emitido,
            facturas_pendientes=elegibilidad.facturas_pendientes,
            mensaje=f"✅ Solicitud de Reconexión registrada exitosamente. Su número de ticket es: #{id_reconexion}."
        )


servicio_reconexion = ServicioReconexion()

