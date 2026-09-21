import logging
from typing import Any, Dict, List, Optional
import httpx

from app.core.config import settings
from app.core.exceptions import ServiceUnavailableException
from app.integrations.base_client import BaseApiClient

logger = logging.getLogger(__name__)

# Datos simulados deterministas para pruebas y modo offline
MOCK_SOCIOS_LEGADO: Dict[str, Dict[str, Any]] = {
    "556": {
        "CODIGO": "556",
        "NOMBRE": "SUAREZ BALTAZAR VICTOR HUGO,CAROLINA",
        "DIRECCION": "ISAIAS PARADA",
        "NROCIONIT": "4638847",
        "ZONA": "1",
        "RUTA": "4",
        "NROC": "64",
        "NROI": "0"
    },
    "540": {
        "CODIGO": "540",
        "NOMBRE": "DURAN ELOISA RIVERA DE",
        "DIRECCION": "SANTA CRUZ 117",
        "NROCIONIT": "2823231",
        "ZONA": "1",
        "RUTA": "39",
        "NROC": "135",
        "NROI": "0"
    },
    "1001": {
        "CODIGO": "1001",
        "NOMBRE": "ALVAREZ FLORES ROBERTO",
        "DIRECCION": "AV. CIRCUNVALACION #45",
        "NROCIONIT": "7829103",
        "ZONA": "2",
        "RUTA": "12",
        "NROC": "10",
        "NROI": "0"
    },
    "1002": {
        "CODIGO": "1002",
        "NOMBRE": "PEREZ MIRANDA JUAN CARLOS",
        "DIRECCION": "BARRIO CENTRAL, C/ INDEPENDENCIA #120",
        "NROCIONIT": "8392019",
        "ZONA": "1",
        "RUTA": "5",
        "NROC": "22",
        "NROI": "0"
    },
    "1003": {
        "CODIGO": "1003",
        "NOMBRE": "GOMEZ ROJAS MARCELA",
        "DIRECCION": "BARRIO EL CARMEN, C/ BOLIVAR #500",
        "NROCIONIT": "5920192",
        "ZONA": "3",
        "RUTA": "8",
        "NROC": "77",
        "NROI": "0"
    }
}

MOCK_DEUDAS_LEGADO: Dict[str, List[Dict[str, Any]]] = {
    "556": [],  # Al día
    "1001": [], # Al día
    "540": [
        {
            "NROFACIP": "1160026",
            "NROFACTURA": "7444051",
            "CODAUTORIZACION": "465C3D0702C232069B9F771B83440D4217AF35B442086180BD081BF74",
            "RAZONSOCIAL": "DURAN ELOISA RIVERA DE",
            "TIPODOCUMENTO": "1",
            "NRODOCUMENTO": "2823231",
            "ANIO": "2026",
            "NMES": "8",
            "MONTOTOTAL": "70.92"
        },
        {
            "NROFACIP": "1189283",
            "NROFACTURA": "7473308",
            "CODAUTORIZACION": "465C3D0702C244BA722BB331A2F8F4742AA59857E45C98CCD2AE2BF74",
            "RAZONSOCIAL": "DURAN ELOISA RIVERA DE",
            "TIPODOCUMENTO": "1",
            "NRODOCUMENTO": "2823231",
            "ANIO": "2026",
            "NMES": "9",
            "MONTOTOTAL": "61.42"
        }
    ],
    "1002": [
        {
            "NROFACIP": "1186667",
            "NROFACTURA": "7470692",
            "CODAUTORIZACION": "465C3D0702C244B8E8F07735B5AD8DFFEC5E00A4E85C98CCD2AE2BF74",
            "RAZONSOCIAL": "PEREZ MIRANDA JUAN CARLOS",
            "TIPODOCUMENTO": "1",
            "NRODOCUMENTO": "8392019",
            "ANIO": "2026",
            "NMES": "9",
            "MONTOTOTAL": "84.50"
        }
    ],
    "1003": [
        {
            "NROFACIP": "1172010",
            "NROFACTURA": "7451002",
            "CODAUTORIZACION": "465C3D0702C232069B9F771B83440D4217AF35B442086180BD081BF74",
            "RAZONSOCIAL": "GOMEZ ROJAS MARCELA",
            "TIPODOCUMENTO": "1",
            "NRODOCUMENTO": "5920192",
            "ANIO": "2026",
            "NMES": "7",
            "MONTOTOTAL": "88.00"
        },
        {
            "NROFACIP": "1188099",
            "NROFACTURA": "7472144",
            "CODAUTORIZACION": "465C3D0702C244BA722BB331A2F8F4742AA59857E45C98CCD2AE2BF74",
            "RAZONSOCIAL": "GOMEZ ROJAS MARCELA",
            "TIPODOCUMENTO": "1",
            "NRODOCUMENTO": "5920192",
            "ANIO": "2026",
            "NMES": "8",
            "MONTOTOTAL": "84.00"
        }
    ]
}

MOCK_CONSUMOS_LEGADO: Dict[str, List[Dict[str, Any]]] = {
    "556": [  # Socio al día, consumo residencial estable (~16-17 m3)
        {"periodo": "10/2025", "mes": 10, "anio": 2025, "lectura_anterior": 2000.0, "lectura_actual": 2016.0, "consumo_m3": 16.0, "monto_bs": 62.40, "estado_lectura": "NORMAL", "fecha_lectura": "2025-10-22"},
        {"periodo": "11/2025", "mes": 11, "anio": 2025, "lectura_anterior": 2016.0, "lectura_actual": 2033.0, "consumo_m3": 17.0, "monto_bs": 66.30, "estado_lectura": "NORMAL", "fecha_lectura": "2025-11-21"},
        {"periodo": "12/2025", "mes": 12, "anio": 2025, "lectura_anterior": 2033.0, "lectura_actual": 2050.0, "consumo_m3": 17.0, "monto_bs": 66.30, "estado_lectura": "NORMAL", "fecha_lectura": "2025-12-20"},
        {"periodo": "01/2026", "mes": 1, "anio": 2026, "lectura_anterior": 2050.0, "lectura_actual": 2066.0, "consumo_m3": 16.0, "monto_bs": 62.40, "estado_lectura": "NORMAL", "fecha_lectura": "2026-01-21"},
        {"periodo": "02/2026", "mes": 2, "anio": 2026, "lectura_anterior": 2066.0, "lectura_actual": 2081.0, "consumo_m3": 15.0, "monto_bs": 58.50, "estado_lectura": "NORMAL", "fecha_lectura": "2026-02-20"},
        {"periodo": "03/2026", "mes": 3, "anio": 2026, "lectura_anterior": 2081.0, "lectura_actual": 2097.0, "consumo_m3": 16.0, "monto_bs": 62.40, "estado_lectura": "NORMAL", "fecha_lectura": "2026-03-21"},
        {"periodo": "04/2026", "mes": 4, "anio": 2026, "lectura_anterior": 2097.0, "lectura_actual": 2114.0, "consumo_m3": 17.0, "monto_bs": 66.30, "estado_lectura": "NORMAL", "fecha_lectura": "2026-04-20"},
        {"periodo": "05/2026", "mes": 5, "anio": 2026, "lectura_anterior": 2114.0, "lectura_actual": 2130.0, "consumo_m3": 16.0, "monto_bs": 62.40, "estado_lectura": "NORMAL", "fecha_lectura": "2026-05-21"},
        {"periodo": "06/2026", "mes": 6, "anio": 2026, "lectura_anterior": 2130.0, "lectura_actual": 2145.0, "consumo_m3": 15.0, "monto_bs": 58.50, "estado_lectura": "NORMAL", "fecha_lectura": "2026-06-20"},
        {"periodo": "07/2026", "mes": 7, "anio": 2026, "lectura_anterior": 2145.0, "lectura_actual": 2161.0, "consumo_m3": 16.0, "monto_bs": 62.40, "estado_lectura": "NORMAL", "fecha_lectura": "2026-07-21"},
        {"periodo": "08/2026", "mes": 8, "anio": 2026, "lectura_anterior": 2161.0, "lectura_actual": 2178.0, "consumo_m3": 17.0, "monto_bs": 66.30, "estado_lectura": "NORMAL", "fecha_lectura": "2026-08-20"},
        {"periodo": "09/2026", "mes": 9, "anio": 2026, "lectura_anterior": 2178.0, "lectura_actual": 2194.0, "consumo_m3": 16.0, "monto_bs": 62.40, "estado_lectura": "NORMAL", "fecha_lectura": "2026-09-20"},
    ],
    "540": [  # Socio con fuga atípica en mes 12 (salto a 32 m3 frente a promedio de 18 m3)
        {"periodo": "10/2025", "mes": 10, "anio": 2025, "lectura_anterior": 1100.0, "lectura_actual": 1118.0, "consumo_m3": 18.0, "monto_bs": 70.00, "estado_lectura": "NORMAL", "fecha_lectura": "2025-10-22"},
        {"periodo": "11/2025", "mes": 11, "anio": 2025, "lectura_anterior": 1118.0, "lectura_actual": 1135.0, "consumo_m3": 17.0, "monto_bs": 66.50, "estado_lectura": "NORMAL", "fecha_lectura": "2025-11-21"},
        {"periodo": "12/2025", "mes": 12, "anio": 2025, "lectura_anterior": 1135.0, "lectura_actual": 1154.0, "consumo_m3": 19.0, "monto_bs": 74.00, "estado_lectura": "NORMAL", "fecha_lectura": "2025-12-20"},
        {"periodo": "01/2026", "mes": 1, "anio": 2026, "lectura_anterior": 1154.0, "lectura_actual": 1172.0, "consumo_m3": 18.0, "monto_bs": 70.00, "estado_lectura": "NORMAL", "fecha_lectura": "2026-01-21"},
        {"periodo": "02/2026", "mes": 2, "anio": 2026, "lectura_anterior": 1172.0, "lectura_actual": 1189.0, "consumo_m3": 17.0, "monto_bs": 66.50, "estado_lectura": "NORMAL", "fecha_lectura": "2026-02-20"},
        {"periodo": "03/2026", "mes": 3, "anio": 2026, "lectura_anterior": 1189.0, "lectura_actual": 1208.0, "consumo_m3": 19.0, "monto_bs": 74.00, "estado_lectura": "NORMAL", "fecha_lectura": "2026-03-21"},
        {"periodo": "04/2026", "mes": 4, "anio": 2026, "lectura_anterior": 1208.0, "lectura_actual": 1226.0, "consumo_m3": 18.0, "monto_bs": 70.00, "estado_lectura": "NORMAL", "fecha_lectura": "2026-04-20"},
        {"periodo": "05/2026", "mes": 5, "anio": 2026, "lectura_anterior": 1226.0, "lectura_actual": 1243.0, "consumo_m3": 17.0, "monto_bs": 66.50, "estado_lectura": "NORMAL", "fecha_lectura": "2026-05-21"},
        {"periodo": "06/2026", "mes": 6, "anio": 2026, "lectura_anterior": 1243.0, "lectura_actual": 1261.0, "consumo_m3": 18.0, "monto_bs": 70.00, "estado_lectura": "NORMAL", "fecha_lectura": "2026-06-20"},
        {"periodo": "07/2026", "mes": 7, "anio": 2026, "lectura_anterior": 1261.0, "lectura_actual": 1279.0, "consumo_m3": 18.0, "monto_bs": 70.00, "estado_lectura": "NORMAL", "fecha_lectura": "2026-07-21"},
        {"periodo": "08/2026", "mes": 8, "anio": 2026, "lectura_anterior": 1279.0, "lectura_actual": 1299.0, "consumo_m3": 20.0, "monto_bs": 78.00, "estado_lectura": "NORMAL", "fecha_lectura": "2026-08-20"},
        {"periodo": "09/2026", "mes": 9, "anio": 2026, "lectura_anterior": 1299.0, "lectura_actual": 1331.0, "consumo_m3": 32.0, "monto_bs": 124.80, "estado_lectura": "NORMAL", "fecha_lectura": "2026-09-20"},
    ],
    "1001": [  # Socio Comercial
        {"periodo": f"{str(m).zfill(2)}/2026" if m <= 9 else f"{m}/2025", "mes": m, "anio": 2026 if m <= 9 else 2025, "lectura_anterior": 3000.0 + (i * 38), "lectura_actual": 3000.0 + ((i + 1) * 38), "consumo_m3": 38.0, "monto_bs": 152.00, "estado_lectura": "NORMAL", "fecha_lectura": "2026-09-18"}
        for i, m in enumerate([10, 11, 12, 1, 2, 3, 4, 5, 6, 7, 8, 9])
    ],
    "1002": [  # Socio Residencial
        {"periodo": f"{str(m).zfill(2)}/2026" if m <= 9 else f"{m}/2025", "mes": m, "anio": 2026 if m <= 9 else 2025, "lectura_anterior": 1500.0 + (i * 22), "lectura_actual": 1500.0 + ((i + 1) * 22), "consumo_m3": 22.0, "monto_bs": 85.80, "estado_lectura": "NORMAL", "fecha_lectura": "2026-09-19"}
        for i, m in enumerate([10, 11, 12, 1, 2, 3, 4, 5, 6, 7, 8, 9])
    ],
    "1003": [  # Socio Residencial Bajo
        {"periodo": f"{str(m).zfill(2)}/2026" if m <= 9 else f"{m}/2025", "mes": m, "anio": 2026 if m <= 9 else 2025, "lectura_anterior": 800.0 + (i * 15), "lectura_actual": 800.0 + ((i + 1) * 15), "consumo_m3": 15.0, "monto_bs": 58.50, "estado_lectura": "NORMAL", "fecha_lectura": "2026-09-19"}
        for i, m in enumerate([10, 11, 12, 1, 2, 3, 4, 5, 6, 7, 8, 9])
    ]
}


class CosmolLegacyClient(BaseApiClient):
    """
    Cliente asíncrono para consumir la API de Consultas y Facturación de COSMOL R.L.
    Gestiona endpoints de socios, deudas y avisos con normalización de espacios en blanco.
    """

    def __init__(self):
        super().__init__(
            base_url=settings.COSMOL_LEGACY_URL,
            timeout_seconds=settings.COSMOL_LEGACY_TIMEOUT_SECONDS
        )

    def _limpiar_campos_dict(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Aplica .strip() a todos los campos tipo string para eliminar el relleno
        de espacios en blanco propio de las tablas legadas (Informix).
        """
        return {
            k: (v.strip() if isinstance(v, str) else v)
            for k, v in data.items()
        }

    async def obtener_datos_socio(self, cod_socio: str) -> Optional[Dict[str, Any]]:
        """
        Consulta la información catastral y titular del socio en el sistema comercial.
        Endpoint: GET /socios/{cod_socio}
        Retorna diccionario con campos limpios (CODIGO, NOMBRE, DIRECCION, NROCIONIT, ZONA, RUTA, etc.)
        o None si el socio no existe.
        """
        codigo = str(cod_socio).strip()

        # 1. Modo Simulación / Mock Offline
        if settings.MOCK_COSMOL_LEGACY:
            logger.info(f"[MOCK COSMOL] Consultando datos del socio '{codigo}'")
            if codigo in MOCK_SOCIOS_LEGADO:
                return dict(MOCK_SOCIOS_LEGADO[codigo])
            # Generación sintética determinista para cualquier otro código
            return {
                "CODIGO": codigo,
                "NOMBRE": f"SOCIO DE PRUEBA {codigo}",
                "DIRECCION": f"BARRIO MONTERO, CALLE {codigo}",
                "NROCIONIT": f"{codigo}01",
                "ZONA": "1",
                "RUTA": "1",
                "NROC": "1",
                "NROI": "0"
            }

        # 2. Modo Real hacia la API de COSMOL
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
            # Si falla la red en desarrollo, fallback a mock para evitar bloqueo
            if settings.DEBUG and codigo in MOCK_SOCIOS_LEGADO:
                logger.warning(f"Aplicando fallback mock tras timeout para socio '{codigo}'")
                return dict(MOCK_SOCIOS_LEGADO[codigo])
            raise ServiceUnavailableException(
                message="El sistema comercial de COSMOL no respondió a tiempo. Intente nuevamente.",
                error_code="COSMOL_API_TIMEOUT"
            )
        except httpx.RequestError as exc:
            logger.error(f"Error de red al conectar con COSMOL ({settings.COSMOL_LEGACY_URL}): {exc}")
            if settings.DEBUG and codigo in MOCK_SOCIOS_LEGADO:
                logger.warning(f"Aplicando fallback mock tras error de red para socio '{codigo}'")
                return dict(MOCK_SOCIOS_LEGADO[codigo])
            raise ServiceUnavailableException(
                message="No se pudo establecer conexión con el sistema comercial de COSMOL.",
                error_code="COSMOL_API_NETWORK_ERROR"
            )

    async def obtener_deudas_socio(self, cod_socio: str) -> List[Dict[str, Any]]:
        """
        Consulta las facturas impagas y saldos pendientes del socio.
        Endpoint: GET /socios/{cod_socio}/deudas
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

        # 1. Modo Simulación / Mock Offline
        if settings.MOCK_COSMOL_LEGACY:
            logger.info(f"[MOCK COSMOL] Consultando deudas del socio '{codigo}'")
            if codigo in MOCK_DEUDAS_LEGADO:
                return [dict(f) for f in MOCK_DEUDAS_LEGADO[codigo]]
            return []

        # 2. Modo Real hacia la API de COSMOL
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
            if settings.DEBUG and codigo in MOCK_DEUDAS_LEGADO:
                logger.warning(f"Aplicando fallback mock tras timeout de deudas para socio '{codigo}'")
                return [dict(f) for f in MOCK_DEUDAS_LEGADO[codigo]]
            raise ServiceUnavailableException(
                message="El sistema de facturación de COSMOL no respondió a tiempo.",
                error_code="COSMOL_DEBT_TIMEOUT"
            )
        except httpx.RequestError as exc:
            logger.error(f"Error de red al consultar deudas con COSMOL: {exc}")
            if settings.DEBUG and codigo in MOCK_DEUDAS_LEGADO:
                logger.warning(f"Aplicando fallback mock tras error de red de deudas para socio '{codigo}'")
                return [dict(f) for f in MOCK_DEUDAS_LEGADO[codigo]]
            raise ServiceUnavailableException(
                message="No se pudo conectar con el sistema de facturación de COSMOL.",
                error_code="COSMOL_DEBT_NETWORK_ERROR"
            )

    def _normalizar_consumo_legado(self, item: Dict[str, Any]) -> Dict[str, Any]:
        """
        Normaliza un registro de consumo devuelto por la API o vista Informix de COSMOL.
        Tolera nombres alternativos de columnas y formatos heterogéneos de sistemas legados:
        - Mes: 'MES', 'NMES', 'NRO_MES'
        - Año: 'ANIO', 'GESTION', 'AÑO'
        - Volumen: 'CONSUMO_M3', 'VOLUMEN', 'M3', 'CANTIDAD_M3'
        - Lectura Actual: 'LECTURA_ACTUAL', 'LECT_ACT', 'LECTACTUAL'
        - Lectura Anterior: 'LECTURA_ANTERIOR', 'LECT_ANT', 'LECTANTERIOR'
        - Monto: 'MONTOTOTAL', 'IMPORTE', 'MONTO_BS', 'TOTAL'
        - Estado: 'ESTADO_LECTURA', 'ESTADO', 'TIPO_LECTURA' (por defecto 'NORMAL')
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

        raw_periodo = clean.get("PERIODO")
        if raw_periodo and "/" in str(raw_periodo):
            periodo = str(raw_periodo).strip()
        else:
            periodo = f"{str(mes).zfill(2)}/{anio}"

        raw_lect_act = clean.get("LECTURA_ACTUAL") or clean.get("LECT_ACT") or clean.get("LECTACTUAL") or 0.0
        raw_lect_ant = clean.get("LECTURA_ANTERIOR") or clean.get("LECT_ANT") or clean.get("LECTANTERIOR") or 0.0
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

        return {
            "periodo": periodo,
            "mes": mes,
            "anio": anio,
            "lectura_anterior": lectura_anterior,
            "lectura_actual": lectura_actual,
            "consumo_m3": consumo_m3,
            "monto_bs": monto_bs,
            "estado_lectura": estado_lectura,
            "fecha_lectura": fecha_lectura,
        }

    def _generar_consumos_sinteticos(self, codigo: str) -> List[Dict[str, Any]]:
        """
        Genera una serie temporal determinista de 12 meses para socios de prueba
        que no estén explícitamente en el diccionario MOCK_CONSUMOS_LEGADO.
        """
        base_hash = sum(ord(c) for c in codigo)
        volumen_base = 15.0 + (base_hash % 8)
        lectura_base = 1000.0 + (base_hash % 500)

        meses_ordenados = [
            (10, 2025), (11, 2025), (12, 2025),
            (1, 2026), (2, 2026), (3, 2026), (4, 2026),
            (5, 2026), (6, 2026), (7, 2026), (8, 2026), (9, 2026)
        ]

        registros: List[Dict[str, Any]] = []
        lectura_ant = lectura_base
        for idx, (m, y) in enumerate(meses_ordenados):
            delta = ((idx * 3 + base_hash) % 5) - 2
            consumo = round(max(5.0, volumen_base + delta), 2)
            lectura_act = round(lectura_ant + consumo, 2)
            monto = round(consumo * 3.9, 2)

            registros.append({
                "periodo": f"{str(m).zfill(2)}/{y}",
                "mes": m,
                "anio": y,
                "lectura_anterior": lectura_ant,
                "lectura_actual": lectura_act,
                "consumo_m3": consumo,
                "monto_bs": monto,
                "estado_lectura": "NORMAL",
                "fecha_lectura": f"{y}-{str(m).zfill(2)}-20"
            })
            lectura_ant = lectura_act

        return registros

    async def obtener_historial_consumo(
        self,
        cod_socio: str,
        meses: int = 12
    ) -> List[Dict[str, Any]]:
        """
        Consulta el historial mensual de lecturas y consumo facturado en m3 del socio.
        Endpoint real en COSMOL: GET /socios/{cod_socio}/consumos
        Retorna lista de diccionarios ordenados cronológicamente:
        [
            {
                "periodo": "09/2026",
                "mes": 9,
                "anio": 2026,
                "lectura_anterior": 1299.0,
                "lectura_actual": 1331.0,
                "consumo_m3": 32.0,
                "monto_bs": 124.80,
                "estado_lectura": "NORMAL",
                "fecha_lectura": "2026-09-20"
            }, ...
        ]
        """
        codigo = str(cod_socio).strip()

        # 1. Modo Simulación / Mock Offline
        if settings.MOCK_COSMOL_LEGACY or settings.MOCK_COSMOL_CONSUMO:
            logger.info(f"[MOCK COSMOL] Consultando historial de consumo del socio '{codigo}' (solicitados: {meses} meses)")
            if codigo in MOCK_CONSUMOS_LEGADO:
                registros = [dict(r) for r in MOCK_CONSUMOS_LEGADO[codigo]]
            else:
                registros = self._generar_consumos_sinteticos(codigo)

            if meses > 0 and len(registros) > meses:
                return registros[-meses:]
            return registros

        # 2. Modo Real hacia la API de COSMOL
        endpoint = f"/socios/{codigo}/consumos"
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
                        normalizados.sort(key=lambda x: (x["anio"], x["mes"]))
                        if meses > 0 and len(normalizados) > meses:
                            return normalizados[-meses:]
                        return normalizados
                return []
            elif response.status_code == 404:
                logger.info(f"Socio '{codigo}' sin historial de consumo (HTTP 404)")
                return []
            else:
                logger.error(
                    f"Error al consultar consumos de socio '{codigo}' (HTTP {response.status_code}): {response.text}"
                )
                if settings.DEBUG:
                    logger.warning(f"Endpoint de consumo no disponible aún en COSMOL (HTTP {response.status_code}). Aplicando fallback simulado para socio '{codigo}'")
                    if codigo in MOCK_CONSUMOS_LEGADO:
                        reg = [dict(r) for r in MOCK_CONSUMOS_LEGADO[codigo]]
                    else:
                        reg = self._generar_consumos_sinteticos(codigo)
                    return reg[-meses:] if meses > 0 else reg
                return []
        except httpx.TimeoutException as exc:
            logger.error(f"Timeout al consultar consumos de socio '{codigo}' ({settings.COSMOL_LEGACY_URL}): {exc}")
            if settings.DEBUG and codigo in MOCK_CONSUMOS_LEGADO:
                logger.warning(f"Aplicando fallback mock tras timeout de consumos para socio '{codigo}'")
                reg = [dict(r) for r in MOCK_CONSUMOS_LEGADO[codigo]]
                return reg[-meses:] if meses > 0 else reg
            raise ServiceUnavailableException(
                message="El sistema de medición y consumo de COSMOL no respondió a tiempo.",
                error_code="COSMOL_CONSUMO_TIMEOUT"
            )
        except httpx.RequestError as exc:
            logger.error(f"Error de red al consultar consumos con COSMOL: {exc}")
            if settings.DEBUG and codigo in MOCK_CONSUMOS_LEGADO:
                logger.warning(f"Aplicando fallback mock tras error de red de consumos para socio '{codigo}'")
                reg = [dict(r) for r in MOCK_CONSUMOS_LEGADO[codigo]]
                return reg[-meses:] if meses > 0 else reg
            raise ServiceUnavailableException(
                message="No se pudo conectar con el sistema de medición de COSMOL.",
                error_code="COSMOL_CONSUMO_NETWORK_ERROR"
            )


# Instancia singleton para uso en toda la aplicación
cosmol_client = CosmolLegacyClient()

