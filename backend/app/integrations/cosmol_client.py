import logging
from typing import Any, Dict, List, Optional
import httpx

from app.core.config import settings
from app.core.exceptions import ServiceUnavailableException
from app.integrations.base_client import BaseApiClient

logger = logging.getLogger(__name__)


class CosmolLegacyClient(BaseApiClient):
    """
    Cliente asíncrono para consumir la API oficial de Consultas y Facturación de COSMOL R.L.
    Gestiona endpoints de socios, deudas, avisos e historial de facturas con normalización de Informix.
    """

    def __init__(self):
        super().__init__(
            base_url=settings.COSMOL_LEGACY_URL,
            timeout_seconds=settings.COSMOL_LEGACY_TIMEOUT_SECONDS
        )

    def _limpiar_campos_dict(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Aplica .strip() a todos los campos tipo string para eliminar el relleno
        de espacios en blanco propio de las tablas legadas de Informix.
        """
        return {
            k: (v.strip() if isinstance(v, str) else v)
            for k, v in data.items()
        }

    async def obtener_datos_socio(self, cod_socio: str) -> Optional[Dict[str, Any]]:
        """
        Consulta la información catastral y titular del socio en el sistema comercial.
        Endpoint oficial: GET /socios/{cod_socio}
        Retorna diccionario con campos limpios (CODIGO, NOMBRE, DIRECCION, NROCIONIT, ZONA, RUTA, etc.)
        o None si el socio no existe (HTTP 404).
        """
        codigo = str(cod_socio).strip()
        endpoint = f"/socios/{codigo}"

        try:
            response = await self.request("GET", endpoint)
            if response.status_code == 200:
                data = response.json()
                if data.get("estado") == "exito" and data.get("datos"):
                    return self._limpiar_campos_dict(data["datos"])
                logger.warning(f"Socio '{codigo}' no encontrado en COSMOL: {data.get('mensaje')}")
                return None
            elif response.status_code == 404:
                logger.warning(f"Socio '{codigo}' no encontrado en COSMOL (HTTP 404)")
                return None
            else:
                logger.error(f"Error inesperado al consultar socio '{codigo}' (HTTP {response.status_code}): {response.text}")
                return None
        except httpx.TimeoutException as exc:
            logger.error(f"Timeout al consultar socio '{codigo}' en COSMOL ({settings.COSMOL_LEGACY_URL}): {exc}")
            raise ServiceUnavailableException(
                message="El sistema comercial de COSMOL no respondió a tiempo. Intente nuevamente.",
                error_code="COSMOL_API_TIMEOUT"
            )
        except httpx.RequestError as exc:
            logger.error(f"Error de red al conectar con COSMOL ({settings.COSMOL_LEGACY_URL}): {exc}")
            raise ServiceUnavailableException(
                message="No se pudo establecer conexión con el sistema comercial de COSMOL.",
                error_code="COSMOL_API_NETWORK_ERROR"
            )

    async def validar_credenciales_socio(self, cod_socio: str, ci: str) -> Optional[Dict[str, Any]]:
        """
        Valida las credenciales oficiales de acceso (Código de Socio y Carnet de Identidad)
        mediante el endpoint específico de validación de COSMOL R.L.
        Endpoint oficial: POST /socios/validar
        Payload: {"codigo": "23807", "ci": "6259185"}
        Retorna diccionario con los datos del socio si las credenciales coinciden,
        o None si son inválidas (HTTP 401 / no coincide).
        """
        codigo = str(cod_socio).strip()
        carnet = str(ci).strip()
        endpoint = "/socios/validar"
        payload = {"codigo": codigo, "ci": carnet}

        try:
            response = await self.request("POST", endpoint, json=payload)
            if response.status_code == 200:
                data = response.json()
                if data.get("estado") == "exito" and data.get("datos", {}).get("valido") is True:
                    socio_data = data["datos"].get("socio", {})
                    return self._limpiar_campos_dict(socio_data)
                return None
            elif response.status_code in (400, 401, 404):
                logger.warning(
                    f"Validación de credenciales rechazada en COSMOL para socio '{codigo}' (HTTP {response.status_code})"
                )
                return None
            else:
                logger.error(
                    f"Error inesperado al validar credenciales de '{codigo}' (HTTP {response.status_code}): {response.text}"
                )
                return None
        except httpx.TimeoutException as exc:
            logger.error(f"Timeout al validar credenciales de '{codigo}' en COSMOL ({settings.COSMOL_LEGACY_URL}): {exc}")
            raise ServiceUnavailableException(
                message="El sistema comercial de COSMOL no respondió a tiempo. Intente nuevamente.",
                error_code="COSMOL_API_TIMEOUT"
            )
        except httpx.RequestError as exc:
            logger.error(f"Error de red al conectar con COSMOL para validar '{codigo}': {exc}")
            raise ServiceUnavailableException(
                message="No se pudo establecer conexión con el sistema comercial de COSMOL.",
                error_code="COSMOL_API_NETWORK_ERROR"
            )

    async def obtener_deudas_socio(self, cod_socio: str) -> List[Dict[str, Any]]:
        """
        Consulta las facturas impagas y saldos pendientes del socio.
        Endpoint oficial: GET /socios/{cod_socio}/deudas
        Retorna lista de facturas pendientes limpias:
        [
            {
                "NROFACIP": "1160026",
                "NROFACTURA": "7444051",
                "CODAUTORIZACION": "465C3D...",
                "RAZONSOCIAL": "DURAN ELOISA RIVERA DE",
                "TIPODOCUMENTO": "1",
                "NRODOCUMENTO": "2823231",
                "ANIO": "2026",
                "NMES": "8",
                "MONTOTOTAL": "70.92"
            }, ...
        ]
        Si el socio no tiene deudas (al día), retorna una lista vacía [].
        """
        codigo = str(cod_socio).strip()
        endpoint = f"/socios/{codigo}/deudas"

        try:
            response = await self.request("GET", endpoint)
            if response.status_code == 200:
                data = response.json()
                if data.get("estado") == "exito":
                    datos = data.get("datos", [])
                    if isinstance(datos, list):
                        return [self._limpiar_campos_dict(f) for f in datos if isinstance(f, dict)]
                return []
            elif response.status_code == 404:
                logger.info(f"Socio '{codigo}' sin registros de deuda (HTTP 404)")
                return []
            else:
                logger.error(f"Error al consultar deudas de socio '{codigo}' (HTTP {response.status_code}): {response.text}")
                return []
        except httpx.TimeoutException as exc:
            logger.error(f"Timeout al consultar deudas de socio '{codigo}' ({settings.COSMOL_LEGACY_URL}): {exc}")
            raise ServiceUnavailableException(
                message="El sistema de facturación de COSMOL no respondió a tiempo.",
                error_code="COSMOL_DEBT_TIMEOUT"
            )
        except httpx.RequestError as exc:
            logger.error(f"Error de red al consultar deudas con COSMOL: {exc}")
            raise ServiceUnavailableException(
                message="No se pudo conectar con el sistema de facturación de COSMOL.",
                error_code="COSMOL_DEBT_NETWORK_ERROR"
            )

    async def obtener_detalle_factura(self, nro_factura: str) -> Optional[Dict[str, Any]]:
        """
        Recupera el detalle fiscal completo de una factura emitida o pendiente de COSMOL.
        Endpoint oficial: GET /facturas/{nro_factura}
        Retorna diccionario con todos los campos SIAT y la lista 'detalle' de conceptos,
        o None si no existe o la API falla.
        """
        nro = str(nro_factura).strip()
        if not nro:
            return None

        endpoint = f"/facturas/{nro}"
        try:
            response = await self.request("GET", endpoint)
            if response.status_code == 200:
                data = response.json()
                if data.get("estado") == "exito":
                    datos = data.get("datos", {})
                    if isinstance(datos, dict):
                        clean_datos = self._limpiar_campos_dict(datos)
                        detalle = datos.get("detalle", [])
                        if isinstance(detalle, list):
                            clean_datos["detalle"] = [
                                self._limpiar_campos_dict(item)
                                for item in detalle
                                if isinstance(item, dict)
                            ]
                        return clean_datos
                return None
            elif response.status_code == 404:
                logger.info(f"Factura '{nro}' no encontrada en el sistema comercial (HTTP 404)")
                return None
            else:
                logger.warning(
                    f"Error al consultar detalle de factura '{nro}' (HTTP {response.status_code}): {response.text}"
                )
                return None
        except httpx.TimeoutException as exc:
            logger.warning(f"Timeout al consultar factura '{nro}' en COSMOL ({settings.COSMOL_LEGACY_URL}): {exc}")
            return None
        except httpx.RequestError as exc:
            logger.warning(f"Error de red al consultar factura '{nro}' con COSMOL: {exc}")
            return None
        except Exception as exc:
            logger.error(f"Error inesperado al consultar factura '{nro}': {exc}")
            return None

    def _normalizar_consumo_legado(self, item: Dict[str, Any]) -> Dict[str, Any]:
        """
        Normaliza un registro de consumo devuelto por la API oficial de COSMOL
        (GET /socios/{cod_socio}/historial-facturas).
        Extrae las claves reales:
        - Mes: 'MES', 'NMES', 'NRO_MES'
        - Año: 'ANIO', 'GESTION', 'AÑO'
        - Volumen m3: 'CONSUMO', 'CONSUMO_M3', 'VOLUMEN', 'M3'
        - Lectura Actual: 'LECTURA_ACTUAL', 'LECT_ACT', 'LECTACTUAL'
        - Lectura Anterior: 'LECTURA_ANTERIOR', 'LECT_ANT', 'LECTANTERIOR'
        - Monto Bs: 'MONTO', 'MONTOTOTAL', 'IMPORTE', 'MONTO_BS', 'TOTAL'
        - Estado: 'ESTADO_LECTURA', 'ESTADO', 'TIPO_LECTURA' (ej: '1' -> 'NORMAL')
        - Fecha: 'FECHA_LECTURA', 'FECHA'
        Limpia espacios en blanco y asegura tipos correctos (int, float, str).
        """
        clean = self._limpiar_campos_dict(item)

        raw_mes = clean.get("MES") or clean.get("NMES") or clean.get("NRO_MES") or 1
        try:
            mes = int(raw_mes)
        except (ValueError, TypeError):
            mes = 1

        raw_anio = clean.get("ANIO") or clean.get("GESTION") or clean.get("AÑO") or 2026
        try:
            anio = int(raw_anio)
        except (ValueError, TypeError):
            anio = 2026

        periodo = f"{str(mes).zfill(2)}/{anio}"

        raw_lect_act = (
            clean.get("LECTURA_ACTUAL")
            or clean.get("LECT_ACT")
            or clean.get("LECTACTUAL")
            or 0.0
        )
        raw_lect_ant = (
            clean.get("LECTURA_ANTERIOR")
            or clean.get("LECT_ANT")
            or clean.get("LECTANTERIOR")
            or 0.0
        )
        try:
            lectura_actual = round(float(raw_lect_act), 2)
        except (ValueError, TypeError):
            lectura_actual = 0.0

        try:
            lectura_anterior = round(float(raw_lect_ant), 2)
        except (ValueError, TypeError):
            lectura_anterior = 0.0

        raw_m3 = (
            clean.get("CONSUMO")
            or clean.get("CONSUMO_M3")
            or clean.get("VOLUMEN")
            or clean.get("M3")
            or clean.get("CANTIDAD_M3")
        )
        if raw_m3 is not None:
            try:
                consumo_m3 = round(float(raw_m3), 2)
            except (ValueError, TypeError):
                consumo_m3 = max(0.0, round(lectura_actual - lectura_anterior, 2))
        else:
            consumo_m3 = max(0.0, round(lectura_actual - lectura_anterior, 2))

        raw_monto = (
            clean.get("MONTO")
            or clean.get("MONTOTOTAL")
            or clean.get("IMPORTE")
            or clean.get("MONTO_BS")
            or clean.get("TOTAL")
            or 0.0
        )
        try:
            monto_bs = round(float(raw_monto), 2)
        except (ValueError, TypeError):
            monto_bs = 0.0

        raw_estado = (
            clean.get("ESTADO_LECTURA")
            or clean.get("ESTADO")
            or clean.get("TIPO_LECTURA")
            or "NORMAL"
        )
        estado_str = str(raw_estado).strip().upper()
        if estado_str in ["1", "NORMAL"]:
            estado_lectura = "NORMAL"
        else:
            estado_lectura = estado_str

        fecha_lectura = clean.get("FECHA_LECTURA") or clean.get("FECHA")
        if fecha_lectura is not None:
            fecha_lectura = str(fecha_lectura).strip()

        nro_factura = str(clean.get("NROFACTURA") or clean.get("nro_factura") or "").strip() or None
        cod_socio = str(clean.get("CODIGO") or clean.get("cod_socio") or "").strip() or None
        nombre = str(clean.get("NOMBRE") or clean.get("nombre") or "").strip() or None

        return {
            "periodo": periodo,
            "mes": mes,
            "anio": anio,
            "nro_factura": nro_factura,
            "NROFACTURA": nro_factura,
            "cod_socio": cod_socio,
            "CODIGO": cod_socio,
            "nombre": nombre,
            "NOMBRE": nombre,
            "lectura_anterior": lectura_anterior,
            "lectura_actual": lectura_actual,
            "consumo_m3": consumo_m3,
            "monto_bs": monto_bs,
            "estado_lectura": estado_lectura,
            "fecha_lectura": fecha_lectura,
            "fecha_pago": fecha_lectura,
            "fecha": fecha_lectura,
            "FECHA": fecha_lectura,
            "estado": clean.get("ESTADO"),
        }

    async def obtener_historial_consumo(
        self,
        cod_socio: str,
        meses: int = 12
    ) -> List[Dict[str, Any]]:
        """
        Consulta el historial mensual de lecturas y consumo facturado en m3 del socio
        directamente desde el endpoint oficial de facturas históricas de COSMOL.
        Endpoint oficial: GET /socios/{cod_socio}/historial-facturas
        Retorna lista de diccionarios ordenados cronológicamente:
        [
            {
                "periodo": "08/2026",
                "mes": 8,
                "anio": 2026,
                "lectura_anterior": 0.0,
                "lectura_actual": 0.0,
                "consumo_m3": 15.0,
                "monto_bs": 58.01,
                "estado_lectura": "NORMAL",
                "fecha_lectura": "2026-08-13"
            }, ...
        ]
        """
        codigo = str(cod_socio).strip()
        endpoint = f"/socios/{codigo}/historial-facturas"

        try:
            response = await self.request("GET", endpoint)
            if response.status_code == 200:
                data = response.json()
                if data.get("estado") == "exito":
                    datos = data.get("datos", [])
                    if isinstance(datos, list):
                        normalizados = [
                            self._normalizar_consumo_legado(item)
                            for item in datos
                            if isinstance(item, dict)
                        ]
                        # Ordenar cronológicamente por año y mes ascendente
                        normalizados.sort(key=lambda x: (x["anio"], x["mes"]))
                        if meses > 0 and len(normalizados) > meses:
                            return normalizados[-meses:]
                        return normalizados
                return []
            elif response.status_code == 404:
                logger.info(f"Socio '{codigo}' sin historial de facturas (HTTP 404)")
                return []
            else:
                logger.error(
                    f"Error al consultar historial de socio '{codigo}' (HTTP {response.status_code}): {response.text}"
                )
                return []
        except httpx.TimeoutException as exc:
            logger.error(f"Timeout al consultar historial de socio '{codigo}' ({settings.COSMOL_LEGACY_URL}): {exc}")
            raise ServiceUnavailableException(
                message="El sistema de medición y consumo de COSMOL no respondió a tiempo.",
                error_code="COSMOL_CONSUMO_TIMEOUT"
            )
        except httpx.RequestError as exc:
            logger.error(f"Error de red al consultar historial con COSMOL: {exc}")
            raise ServiceUnavailableException(
                message="No se pudo conectar con el sistema de medición de COSMOL.",
                error_code="COSMOL_CONSUMO_NETWORK_ERROR"
            )


# Instancia singleton para uso en toda la aplicación
cosmol_client = CosmolLegacyClient()
