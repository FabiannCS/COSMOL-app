# Tarea 03: Repositorio Digital de Documentos (PDFs de Facturas y Avisos)

> **Estado:** PENDIENTE  
> **Fase:** Fase 3 — Repositorio Digital de Documentos (PDFs de Facturas y Avisos)  
> **Fecha de creación:** Septiembre 2026  
> **Documentos de referencia:** `AGENTS.md` (Secciones 4.4, 7.4, 10.4, 12.3, 12.7.1) y `Docs/HOJA_DE_RUTA_DESARROLLO.md` (Fase 3)  
> **Entorno de ejecución:** Backend FastAPI en Docker (`cosmol-backend-api`, `cosmol-storage-minio`, `cosmol-db-postgres`)

---

## 1. Objetivo

Implementar el módulo de **Repositorio Digital de Documentos y Descarga en PDF** para los asociados de COSMOL R.L. Este módulo ataca de forma directa el problema #3 identificado en la cooperativa: los altos costos operativos, logísticos y de impacto ambiental derivados de la impresión física de avisos y facturas en papel.

El sistema debe:
1. Almacenar y servir de forma segura archivos binarios PDF mediante **MinIO Object Storage (S3-Compatible)** en el bucket privado `cosmol-docs`.
2. Contar con un **motor generador de PDFs on-demand** (con membrete institucional de COSMOL R.L., códigos SIAT/SIN, desglose en Bs y tablas de consumo) para aquellos documentos emitidos por el sistema comercial que no cuenten con archivo pre-generado.
3. Respetar la política estricta de **Privacidad Multicuenta**:
   * **Modo Titular:** Acceso completo a facturas con valor legal, avisos de cobranza y avisos de corte.
   * **Modo Inquilino (`CONSULTA_PAGO`):** Acceso restringido exclusivamente a **Avisos de Cobranza** para gestionar el pago. Bloqueo con `403 Forbidden` (`DOCUMENT_ACCESS_DENIED`) ante intentos de descarga de facturas fiscales o avisos de corte del titular.
4. Proveer descarga eficiente mediante flujo binario (`StreamingResponse` con `application/pdf`) y URLs seguras.

---

## 2. Reglas de Negocio Oficiales (AGENTS.md)

1. **Tipos de Documentos Oficiales (Sección 10.4 AGENTS.md):**
   * **`FACTURA`:** Documento fiscal oficial con valor legal (código SIAT/SIN, número de factura, titular, NIT/CI, mes/año, importe en Bs).
   * **`AVISO_COBRANZA`:** Aviso preventivo mensual de consumo previo a la fecha de vencimiento.
   * **`AVISO_CORTE`:** Notificación preventiva obligatoria generada cuando el socio acumula $\ge 2$ facturas impagas.

2. **Privacidad y Control de Acceso por Suministro (Sección 4.6 AGENTS.md):**
   * **Titular:** Consulta histórica y descarga de los 3 tipos de documentos.
   * **Inquilino / Pagador externo (`CONSULTA_PAGO`):** Solo puede consultar y descargar `AVISO_COBRANZA`. El backend debe rechazar peticiones a facturas o avisos de corte con código `DOCUMENT_ACCESS_DENIED` (HTTP 403).

3. **Almacenamiento de Objetos en MinIO S3 (Sección 12.7.1 AGENTS.md):**
   * Bucket: `cosmol-docs`.
   * Estructura de claves S3:
     * `facturas/{cod_socio}/{anio}_{mes}_{nro_factura}.pdf`
     * `avisos_cobranza/{cod_socio}/{anio}_{mes}_{nro_facip}.pdf`
     * `avisos_corte/{cod_socio}/{anio}_{mes}_{nro_facip}.pdf`

4. **Auditoría Externa Unidireccional (Secciones 6 y 12.3 AGENTS.md):**
   * Cada descarga exitosa despacha un evento `DOCUMENT_DOWNLOADED` (`usuario_id`, `cod_socio`, `doc_id`, `tipo_documento`, `timestamp`) en segundo plano hacia la base de datos del proyecto `ChatbotReportes`.

---

## 3. Asignación y División Modular de Trabajo

```
┌────────────────────────────────────────────────────────────────────────┐
│                   DIVISIÓN MODULAR FASE 3                              │
├───────────────────────────────────┬────────────────────────────────────┤
│    DEV 1 (Asignado / Activo)      │       DEV 2 (Backend Dev)          │
├───────────────────────────────────┼────────────────────────────────────┤
│ • Dependencias (minio, reportlab) │ • Esquemas Pydantic v2             │
│ • Cliente S3 MinIO                │   (`schemas/documento.py`)         │
│   (`minio_client.py` + bucket)    │ • Servicio de Negocio              │
│ • Motor Generador de PDFs         │   (`servicio_documentos.py`)       │
│   (`generador_pdf.py`)            │ • Control de permisos Multicuenta  │
│ • Modelo ORM Documento (Postgres) │   (Bloqueo fiscal a Inquilinos)    │
│ • Utilitarios Storage Documentos  │ • Endpoints REST (`documentos.py`) │
│ • Tests S3 y generador PDF        │ • Tests de endpoints y permisos    │
└───────────────────────────────────┴────────────────────────────────────┘
```

> **Rol Activo en este Turno:** **DEV 1 (Infraestructura, MinIO S3, Motor PDF y Modelo ORM)**.

---

## 4. Detalle de Entregables Técnicos

### 4.1 Entregables de DEV 1: Infraestructura, Storage S3, Generador PDF y BD (COMPLETADO POR DEV 1)

#### A. Dependencias y Configuración:
* [x] Agregar `minio>=7.2.0` y `reportlab>=4.2.0` a `backend/requirements.txt`.
* [x] Instalar paquetes en el contenedor `cosmol-backend-api`.
* [x] Validar variables en `app/core/config.py`: `MINIO_ENDPOINT`, `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`, `MINIO_BUCKET_NAME`.

#### B. Cliente de Integración MinIO S3 (`backend/app/integrations/minio_client.py`):
* [x] Implementar clase `CosmolMinioClient`:
  * Conexión asíncrona / cliente con `minio.Minio`.
  * Método `asegurar_bucket_existe(bucket_name: str)`.
  * Método `subir_archivo_bytes(bucket_name: str, object_name: str, data_bytes: bytes, content_type: str = "application/pdf") -> str`.
  * Método `obtener_archivo_stream(bucket_name: str, object_name: str) -> BinaryIO`.
  * Método `existe_archivo(bucket_name: str, object_name: str) -> bool`.
  * Método `generar_url_prefirmada(bucket_name: str, object_name: str, expires_seconds: int = 600) -> str`.
* [x] Singleton `minio_client` para uso global en la aplicación.

#### C. Motor Generador de PDFs Institucionales (`backend/app/services/generador_pdf.py`):
* [x] Implementar clase `GeneradorPdfDocumento`:
  * Generación de **Factura Oficial** con membrete institucional de COSMOL R.L. (NIT, Nro. Factura, Código de Autorización SIAT, Periodo, Razón Social, Detalle de Conceptos en Bs, Código QR SIAT simulado/oficial).
  * Generación de **Aviso de Cobranza** (resumen de cuenta, fecha límite, código de barras/pago).
  * Generación de **Aviso de Corte** (advertencia legal formal de suspensión del servicio para $\ge 2$ facturas impagas).
  * Retorno de flujo de bytes (`io.BytesIO`).

#### D. Modelo ORM y Migración PostgreSQL (`backend/app/db/models/documento.py`):
* [x] Crear modelo `Documento(BaseModel)`:
  * `id`: UUID (PK).
  * `suministro_id`: UUID (FK a `suministros.id`).
  * `cod_socio`: String(50), indexado.
  * `tipo_documento`: String(30) (`"FACTURA"`, `"AVISO_COBRANZA"`, `"AVISO_CORTE"`).
  * `nro_factura`: Optional[String(50)].
  * `nro_facip`: Optional[String(50)].
  * `cod_autorizacion`: Optional[String(100)].
  * `periodo`: String(20) (ej: `"08/2026"`).
  * `anio`: Integer.
  * `mes`: Integer.
  * `monto_bs`: Float.
  * `s3_key`: String(255).
  * `fecha_emision`: Date.
  * `fecha_vencimiento`: Optional[Date].
  * `estado_pago`: String(20) (`"PENDIENTE"`, `"PAGADO"`).
* [x] Registrar modelo en `app/db/models/__init__.py`.
* [x] Generar y ejecutar migración de Alembic: `add_documentos_table`.

#### E. Utilitarios de Almacenamiento (`backend/app/services/servicio_storage_documentos.py`):
* [x] Utilitarios para guardar en MinIO, registrar en la tabla `documentos` y asegurar que no se dupliquen archivos.

#### F. Batería de Pruebas DEV 1:
* [x] `backend/tests/test_minio_client.py`: Verificación de bucket, upload, download y verificación de existencia.
* [x] `backend/tests/test_generador_pdf.py`: Verificación de generación de PDF válido (bytes no vacíos, header `%PDF-1.4`).
* [x] `backend/tests/test_storage_documentos.py`: Verificación de caching, obtención y generación on-demand de PDFs en MinIO.
* [x] `backend/tests/test_models.py`: Verificación de creación y persistencia del modelo Documento en PostgreSQL.

---

### 4.2 Entregables de DEV 2: Esquemas, Lógica de Negocio y Endpoints (COMPLETADO POR DEV 2)

#### A. Esquemas Pydantic v2 en `backend/app/schemas/documento.py`:
* [x] `DocumentoResponse`: Metadatos del documento disponible para visualización.
* [x] `ListaDocumentosResponse`: Colección paginada o categorizada por pestañas (*Facturas*, *Avisos de Cobranza*, *Avisos de Corte*).

#### B. Lógica de Negocio en `backend/app/services/servicio_documentos.py`:
* [x] Clase `ServicioDocumentos`:
  * Inyección de `db: AsyncSession`, `minio_client: CosmolMinioClient`, `cosmol_client: CosmolLegacyClient`.
  * Método `listar_documentos_socio(usuario_id: UUID, cod_socio: str, tipo: Optional[str] = None)`:
    - Validación de permisos en PostgreSQL.
    - Si el rol es `CONSULTA_PAGO`, filtrar estrictamente y retornar **únicamente avisos de cobranza**.
  * Método `obtener_documento_para_descarga(usuario_id: UUID, doc_id: UUID)`:
    - Valida que el documento pertenezca a un suministro del usuario.
    - Si el documento es `FACTURA` o `AVISO_CORTE` y el rol es `CONSULTA_PAGO`, lanzar `ForbiddenException("DOCUMENT_ACCESS_DENIED")`.
    - Recupera el archivo de MinIO (o lo genera on-demand si aún no existe en S3).
    - Despacha evento de auditoría en background a `ChatbotReportes`.

#### C. Endpoints REST en `backend/app/api/v1/documentos.py`:
* [x] `GET /api/v1/documentos/{cod_socio}`: Listado de documentos del suministro.
* [x] `GET /api/v1/documentos/{doc_id}/descargar`: Transmisión del archivo binario PDF (`StreamingResponse`).
* [x] Registrar `documentos_router` en `backend/app/api/v1/router.py`.

---

## 5. Criterios de Aceptación y Validación

1. [x] **Almacenamiento S3 en MinIO:**
   * Los PDFs se persisten en el bucket `cosmol-docs` y pueden recuperarse íntegros.
2. [x] **Generación de PDFs Válidos:**
   * El generador de PDFs produce documentos con formato PDF estándar (`%PDF`) legibles por lectores de PDF y visores móviles.
3. [x] **Control de Privacidad y Seguridad:**
   * El rol `TITULAR` puede acceder a facturas, avisos de cobranza y avisos de corte.
   * El rol `CONSULTA_PAGO` recibe `403 Forbidden` al intentar descargar facturas fiscales o avisos de corte.
4. [x] **Persistencia en PostgreSQL:**
   * La tabla `documentos` almacena los metadatos y la ruta `s3_key` asociada a cada suministro.
5. [x] **Cobertura de Pruebas Automatizadas:**
   * Tests pasando al 100% en Docker (67 pruebas totales, 10 específicas de DEV 2 y 12 de DEV 1) sin alterar las pruebas previas del sistema.
