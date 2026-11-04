"""
Batería de pruebas automatizadas para el Módulo de Reconexión de Servicios y Gestión de PIN (Cambios de Fabián).
Valida las 5 reglas de negocio técnicas y comerciales:
1. No duplicidad de trámites activos (estado PENDIENTE).
2. Límite de morosidad (máximo 2 facturas adeudadas).
3. Resolución de ubicación técnica catastral ZONA.RUTA.NROC.NROI.
4. Ensamblado de parámetros de campo (GPS, foto MinIO, tipo y glosa).
5. Despacho asíncrono y resiliente de auditoría a COSMOL-Reportes (id_tipo: 5).
6. Casos borde: socio no encontrado, rechazo en solicitud por mora previa o duplicidad.
7. Almacenamiento de fotografías en MinIO con prefijo reconexiones/.
8. Cambio voluntario de PIN autenticado con control de intentos y bloqueo en Redis.
"""
import uuid
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from fastapi import BackgroundTasks

from app.core.exceptions import BadRequestException, ForbiddenException, NotFoundException
from app.core.security import get_password_hash, verify_password
from app.schemas.reconexion import (
    SolicitudReconexionCreate,
    TipoReconexionEnum,
)
from app.services.servicio_reconexion import ServicioReconexion
from app.services.servicio_autenticacion import ServicioAutenticacion, USUARIOS_REGISTRADOS_DB


@pytest.fixture
def mock_socio_datos():
    return {
        "CODIGO": "267657",
        "NOMBRE": "JUAN PEREZ GUTIERREZ",
        "DIRECCION": "BARRIO CENTRAL C/ BOLIVAR #120",
        "ZONA": "1",
        "RUTA": "4",
        "NROC": "120",
        "NROI": "0"
    }


# ==============================================================================
# 1. PRUEBAS DE ELEGIBILIDAD (REGLAS 1, 2 Y 3)
# ==============================================================================

@pytest.mark.asyncio
async def test_elegibilidad_bloqueada_por_tramite_pendiente(mock_socio_datos):
    """Regla 1: Trámite previo con estado PENDIENTE bloquea la solicitud."""
    servicio = ServicioReconexion()

    with patch("app.services.servicio_reconexion.cosmol_client.obtener_datos_socio", new_callable=AsyncMock) as mock_datos, \
         patch("app.services.servicio_reconexion.cosmol_client.obtener_reconexiones_socio", new_callable=AsyncMock) as mock_rec:
        
        mock_datos.return_value = mock_socio_datos
        mock_rec.return_value = [
            {
                "id_reconexion": 1284,
                "fecha": "2026-10-15 09:30:00",
                "tipo": "Corte normal",
                "estado": "PENDIENTE",
                "glosa": "Portón blanco"
            }
        ]

        resp = await servicio.verificar_elegibilidad("267657")
        assert resp.es_elegible is False
        assert resp.motivo_bloqueo == "TRAMITE_DUPLICADO"
        assert resp.tramite_pendiente_id == 1284
        assert "ya cuenta con una solicitud de reconexión en estado PENDIENTE" in resp.mensaje_usuario


@pytest.mark.asyncio
async def test_elegibilidad_bloqueada_por_alta_morosidad(mock_socio_datos):
    """Regla 2: Más de 1 factura pendiente bloquea la solicitud (2 o más facturas)."""
    servicio = ServicioReconexion()

    with patch("app.services.servicio_reconexion.cosmol_client.obtener_datos_socio", new_callable=AsyncMock) as mock_datos, \
         patch("app.services.servicio_reconexion.cosmol_client.obtener_reconexiones_socio", new_callable=AsyncMock) as mock_rec, \
         patch("app.services.servicio_reconexion.cosmol_client.obtener_deudas_socio", new_callable=AsyncMock) as mock_deudas:
        
        mock_datos.return_value = mock_socio_datos
        mock_rec.return_value = []
        mock_deudas.return_value = [
            {"NROFACTURA": "101", "MONTOTOTAL": 50.0},
            {"NROFACTURA": "102", "MONTOTOTAL": 60.0},  # 2 facturas > 1
        ]

        resp = await servicio.verificar_elegibilidad("267657")
        assert resp.es_elegible is False
        assert resp.motivo_bloqueo == "ALTA_MOROSIDAD"
        assert resp.facturas_pendientes == 2
        assert resp.total_deuda_bs == 110.0
        assert "registra 2 facturas pendientes" in resp.mensaje_usuario


@pytest.mark.asyncio
async def test_elegibilidad_exitosa_con_una_factura_pendiente(mock_socio_datos):
    """Regla 2 y 3: Con 1 factura pendiente (o 0), es elegible y compone ZONA.RUTA.NROC.NROI."""
    servicio = ServicioReconexion()

    with patch("app.services.servicio_reconexion.cosmol_client.obtener_datos_socio", new_callable=AsyncMock) as mock_datos, \
         patch("app.services.servicio_reconexion.cosmol_client.obtener_reconexiones_socio", new_callable=AsyncMock) as mock_rec, \
         patch("app.services.servicio_reconexion.cosmol_client.obtener_deudas_socio", new_callable=AsyncMock) as mock_deudas:
        
        mock_datos.return_value = mock_socio_datos
        mock_rec.return_value = [
            {"id_reconexion": 900, "estado": "FINALIZADO"}
        ]
        mock_deudas.return_value = [
            {"NROFACTURA": "101", "MONTOTOTAL": 45.50},  # 1 factura <= 1 (Elegible)
        ]

        resp = await servicio.verificar_elegibilidad("267657")
        assert resp.es_elegible is True
        assert resp.motivo_bloqueo is None
        assert resp.facturas_pendientes == 1
        assert resp.total_deuda_bs == 45.50
        assert resp.ubicacion_catastral == "1.4.120.0"
        assert resp.zona == 1
        assert resp.ruta == 4


@pytest.mark.asyncio
async def test_elegibilidad_socio_no_encontrado():
    """Regla borde: Si el socio no existe en el sistema central comercial."""
    servicio = ServicioReconexion()

    with patch("app.services.servicio_reconexion.cosmol_client.obtener_datos_socio", new_callable=AsyncMock) as mock_datos:
        mock_datos.return_value = None

        resp = await servicio.verificar_elegibilidad("9999999")
        assert resp.es_elegible is False
        assert resp.motivo_bloqueo == "SOCIO_NO_ENCONTRADO"
        assert "No se encontró ningún socio" in resp.mensaje_usuario


# ==============================================================================
# 2. PRUEBAS DE SOLICITUD DE RECONEXIÓN (REGLAS 4 Y 5)
# ==============================================================================

@pytest.mark.asyncio
async def test_solicitar_reconexion_exitosa(mock_socio_datos):
    """Reglas 4 y 5: Registro exitoso con usuario_registro=2 y auditoría a Reportes (id_tipo=5)."""
    servicio = ServicioReconexion()
    background_tasks = MagicMock(spec=BackgroundTasks)

    solicitud = SolicitudReconexionCreate(
        codigo_socio="267657",
        id_tipo_reconexion=TipoReconexionEnum.CORTE_NORMAL,
        coordenadas_gps="-17.345678, -63.254123",
        glosa="Casa frente a la plaza, rejas blancas",
        foto_url="https://servidor.cosmol.com/uploads/reconexiones/foto.jpg?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=test"
    )

    with patch("app.services.servicio_reconexion.cosmol_client.obtener_datos_socio", new_callable=AsyncMock) as mock_datos, \
         patch("app.services.servicio_reconexion.cosmol_client.obtener_reconexiones_socio", new_callable=AsyncMock) as mock_rec, \
         patch("app.services.servicio_reconexion.cosmol_client.obtener_deudas_socio", new_callable=AsyncMock) as mock_deudas, \
         patch("app.services.servicio_reconexion.cosmol_client.registrar_solicitud_reconexion", new_callable=AsyncMock) as mock_sai:
        
        mock_datos.return_value = mock_socio_datos
        mock_rec.return_value = []
        mock_deudas.return_value = [{"NROFACTURA": "101", "MONTOTOTAL": 40.0}]
        mock_sai.return_value = {
            "id_reconexion": 4921,
            "estado": "PENDIENTE",
            "facturas_pendientes": 1
        }

        resp = await servicio.solicitar_reconexion(
            datos=solicitud,
            background_tasks=background_tasks,
            telefono="71234567"
        )

        assert resp.id_reconexion == 4921
        assert resp.estado == "PENDIENTE"
        assert "#4921" in resp.mensaje

        mock_sai.assert_called_once_with(
            "267657",
            {
                "usuario_registro": 2,
                "coordenadas_gps": "-17.345678, -63.254123",
                "id_tipo_reconexion": 1,
                "ubicacion": "1.4.120.0",
                "zona": 1,
                "ruta": 4,
                "glosa": "Casa frente a la plaza, rejas blancas",
                "foto": "https://servidor.cosmol.com/uploads/reconexiones/foto.jpg",
            }
        )

        assert background_tasks.add_task.called
        args, kwargs = background_tasks.add_task.call_args
        assert kwargs["codigo_socio"] == 267657
        assert kwargs["id_tipo"] == 5
        assert kwargs["tipo_consulta"] == "Solicitud de Reconexión"


@pytest.mark.asyncio
async def test_solicitar_reconexion_rechazada_por_tramite_duplicado(mock_socio_datos):
    """Regla de seguridad: Si al solicitar ya tiene PENDIENTE, se rechaza con BadRequestException."""
    servicio = ServicioReconexion()
    background_tasks = MagicMock(spec=BackgroundTasks)

    solicitud = SolicitudReconexionCreate(
        codigo_socio="267657",
        id_tipo_reconexion=TipoReconexionEnum.CORTE_NORMAL,
        coordenadas_gps="-17.345678, -63.254123",
        glosa="Casa frente a la plaza",
        foto_url="https://servidor.cosmol.com/foto.jpg"
    )

    with patch("app.services.servicio_reconexion.cosmol_client.obtener_datos_socio", new_callable=AsyncMock) as mock_datos, \
         patch("app.services.servicio_reconexion.cosmol_client.obtener_reconexiones_socio", new_callable=AsyncMock) as mock_rec:
        
        mock_datos.return_value = mock_socio_datos
        mock_rec.return_value = [{"id_reconexion": 1284, "estado": "PENDIENTE"}]

        with pytest.raises(BadRequestException) as exc_info:
            await servicio.solicitar_reconexion(
                datos=solicitud,
                background_tasks=background_tasks
            )
        assert exc_info.value.error_code == "TRAMITE_DUPLICADO"


@pytest.mark.asyncio
async def test_solicitar_reconexion_rechazada_por_alta_morosidad(mock_socio_datos):
    """Regla de seguridad: Si al solicitar tiene > 2 facturas en mora, se rechaza."""
    servicio = ServicioReconexion()
    background_tasks = MagicMock(spec=BackgroundTasks)

    solicitud = SolicitudReconexionCreate(
        codigo_socio="267657",
        id_tipo_reconexion=TipoReconexionEnum.CON_MEDIDOR,
        coordenadas_gps="-17.345678, -63.254123",
        glosa="Acometida esquina",
        foto_url="https://servidor.cosmol.com/foto.jpg"
    )

    with patch("app.services.servicio_reconexion.cosmol_client.obtener_datos_socio", new_callable=AsyncMock) as mock_datos, \
         patch("app.services.servicio_reconexion.cosmol_client.obtener_reconexiones_socio", new_callable=AsyncMock) as mock_rec, \
         patch("app.services.servicio_reconexion.cosmol_client.obtener_deudas_socio", new_callable=AsyncMock) as mock_deudas:
        
        mock_datos.return_value = mock_socio_datos
        mock_rec.return_value = []
        mock_deudas.return_value = [
            {"NROFACTURA": "1", "MONTOTOTAL": 10.0},
            {"NROFACTURA": "2", "MONTOTOTAL": 20.0},
            {"NROFACTURA": "3", "MONTOTOTAL": 30.0},
        ]

        with pytest.raises(BadRequestException) as exc_info:
            await servicio.solicitar_reconexion(
                datos=solicitud,
                background_tasks=background_tasks
            )
        assert exc_info.value.error_code == "ALTA_MOROSIDAD"


# ==============================================================================
# 3. PRUEBAS DE HISTORIAL Y ALMACENAMIENTO MINIO
# ==============================================================================

@pytest.mark.asyncio
async def test_obtener_historial_reconexiones():
    """Valida la consulta y normalización del historial de trámites técnicos."""
    servicio = ServicioReconexion()

    with patch("app.services.servicio_reconexion.cosmol_client.obtener_reconexiones_socio", new_callable=AsyncMock) as mock_rec:
        mock_rec.return_value = [
            {
                "id_reconexion": 501,
                "fecha": "2026-09-01 10:00:00",
                "tipo": "Corte normal",
                "estado": "FINALIZADO",
                "glosa": "Reconectado con éxito"
            },
            {
                "id_reconexion": 502,
                "fecha": "2026-10-01 14:00:00",
                "tipo": "Con medidor",
                "estado": "PENDIENTE",
                "glosa": "En inspección"
            }
        ]

        historial = await servicio.obtener_historial("267657")
        assert len(historial) == 2
        assert historial[0].id_reconexion == 501
        assert historial[0].estado == "FINALIZADO"
        assert historial[1].id_reconexion == 502
        assert historial[1].estado == "PENDIENTE"


def test_subir_foto_evidencia_minio():
    """Valida el método de subida de fotos a MinIO para evidencias de reconexión."""
    from app.integrations.minio_client import minio_client

    with patch.object(minio_client, "subir_archivo_bytes") as mock_subir:
        mock_subir.return_value = "reconexiones/reconexion_267657_12345.jpg"

        obj_name = minio_client.subir_foto_evidencia_reconexion(
            cod_socio="267657",
            data_bytes=b"fake_image_bytes",
            extension="jpg",
            content_type="image/jpeg"
        )

        assert "reconexion_267657_" in obj_name
        assert obj_name.endswith(".jpg")
        assert obj_name.startswith("reconexiones/")
        assert mock_subir.called


# ==============================================================================
# 4. PRUEBAS DE CAMBIO VOLUNTARIO DE PIN (SERVICIO AUTENTICACIÓN)
# ==============================================================================

@pytest.mark.asyncio
async def test_cambiar_pin_autenticado_exitoso():
    """Valida el cambio voluntario de PIN con PIN actual correcto."""
    user_id = uuid.uuid4()
    cod_socio = "3001"
    pin_original = "1234"
    pin_nuevo = "5678"

    USUARIOS_REGISTRADOS_DB[cod_socio] = {
        "user_id": str(user_id),
        "password_hash": get_password_hash(pin_original),
        "suministros": [{"cod_socio": cod_socio, "es_suministro_principal": True}]
    }

    mock_redis = AsyncMock()
    mock_redis.ttl.return_value = -2  # No bloqueado

    servicio_auth = ServicioAutenticacion(redis_client=mock_redis)

    res = await servicio_auth.cambiar_pin_autenticado(
        usuario_id=user_id,
        pin_actual=pin_original,
        nuevo_pin=pin_nuevo
    )

    assert res["exito"] is True
    assert "actualizado exitosamente" in res["mensaje"]

    # Verificar que el hash se actualizó
    nuevo_hash = USUARIOS_REGISTRADOS_DB[cod_socio]["password_hash"]
    assert verify_password(pin_nuevo, nuevo_hash) is True


@pytest.mark.asyncio
async def test_cambiar_pin_autenticado_pin_actual_erroneo_y_bloqueo():
    """Valida que un PIN actual incorrecto reduzca intentos y bloquee tras 3 fallos."""
    user_id = uuid.uuid4()
    cod_socio = "3002"
    pin_original = "1234"

    USUARIOS_REGISTRADOS_DB[cod_socio] = {
        "user_id": str(user_id),
        "password_hash": get_password_hash(pin_original),
        "suministros": [{"cod_socio": cod_socio, "es_suministro_principal": True}]
    }

    mock_redis = AsyncMock()
    mock_redis.ttl.return_value = -2

    servicio_auth = ServicioAutenticacion(redis_client=mock_redis)

    # Intento 1 fallido
    mock_redis.incr.return_value = 1
    with pytest.raises(BadRequestException) as exc1:
        await servicio_auth.cambiar_pin_autenticado(
            usuario_id=user_id,
            pin_actual="9999",
            nuevo_pin="5678"
        )
    assert exc1.value.error_code == "INVALID_CURRENT_PIN"
    assert "Le quedan 2 intento(s)" in exc1.value.message

    # Intento 3 fallido (Bloqueo de 5 min)
    mock_redis.incr.return_value = 3
    with pytest.raises(ForbiddenException) as exc3:
        await servicio_auth.cambiar_pin_autenticado(
            usuario_id=user_id,
            pin_actual="9999",
            nuevo_pin="5678"
        )
    assert exc3.value.error_code == "ACCOUNT_LOCKED"
    assert mock_redis.set.called  # Clave de bloqueo seteada en Redis
