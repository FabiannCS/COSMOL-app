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


# Instancia singleton para uso en toda la aplicación
cosmol_client = CosmolLegacyClient()
