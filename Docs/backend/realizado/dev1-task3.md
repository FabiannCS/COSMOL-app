# Entregables DEV 1: Infraestructura MinIO S3, Motor Generador PDF y Modelo ORM

> **Fase:** Fase 3 — Repositorio Digital de Documentos (PDFs de Facturas y Avisos)  
> **Rol responsable:** DEV 1 (Infraestructura, MinIO S3 Client, Motor PDF ReportLab, Modelo ORM y Storage Service)  
> **Fecha de conclusión:** Septiembre 2026  
> **Documento de referencia:** `Docs/pendiente/TASK-03-repositorio-documentos-pdf.md` y `AGENTS.md` (Secciones 4.4, 7.4, 10.4, 12.3, 12.7.1)  
> **Estado:** COMPLETADO y certificado en Docker (12/12 tests propios y 57/57 tests totales del backend pasando al 100%)

---

## 1. Resumen Ejecutivo

En el marco de la **Fase 3 (Repositorio Digital de Documentos)**, **DEV 1** implementó la base arquitectónica y de infraestructura necesaria para el almacenamiento de objetos en la nube/on-premise y la generación dinámica de documentos institucionales para COSMOL R.L.:

1. **Dependencias Oficiales:** Incorporación de `minio>=7.2.0` (Object Storage S3) y `reportlab>=4.2.0` (Motor vectorial de generación de PDFs) en el entorno productivo Docker.
2. **Cliente MinIO S3 Asíncrono / Thread-Safe (`CosmolMinioClient`):** Conector desacoplado en `app/integrations/minio_client.py` con verificación y creación automática del bucket `cosmol-docs`, subida de binarios, descarga por streaming (chunked para `StreamingResponse`), verificación de existencia y generación de URLs prefirmadas seguras.
3. **Motor Generador de PDFs Institucionales (`GeneradorPdfDocumento`):** Diseñador e impresor digital en `app/services/generador_pdf.py` que produce documentos de calidad con membrete oficial de COSMOL R.L., desgloses monetarios en Bs y estándares legales:
   * **Factura Oficial:** Conforme a normativas SIAT (NIT, Número de Factura, Código de Autorización, Razón Social, desglose de consumo de agua potable y alcantarillado, y bloque QR SIAT).
   * **Aviso de Cobranza:** Notificación preventiva mensual con detalles de cuenta, fecha límite de pago y código de pago.
   * **Aviso de Corte:** Notificación formal con advertencia legal de suspensión del suministro para cuentas con $\ge 2$ facturas impagas.
4. **Modelo ORM y Persistencia en PostgreSQL (`Documento`):** Modelo relacional en `app/db/models/documento.py` indexado por `cod_socio`, `suministro_id` y `tipo_documento`, vinculado a la migración Alembic `e9a8ea64a0f8_add_documentos_table`.
5. **Capa de Almacenamiento Unificada (`ServicioStorageDocumentos`):** Servicio en `app/services/servicio_storage_documentos.py` que gestiona el ciclo de vida de los documentos: sube el binario a MinIO, persiste el registro en PostgreSQL y reutiliza el archivo si ya existe en S3 (caching de storage para evitar sobrecarga de CPU).
6. **Certificación de Pruebas:** 12 pruebas automatizadas directas para DEV 1 y validación de regresión total con 57/57 pruebas pasando en Docker.

---

## 2. Detalle de Archivos Creados y Modificados

### 2.1 Dependencias (`backend/requirements.txt`)
* Agregados:
  * `minio>=7.2.0`
  * `reportlab>=4.2.0`
* Instalados y validados dentro del contenedor `cosmol-backend-api`.

### 2.2 Cliente de Integración MinIO S3 (`backend/app/integrations/minio_client.py`)
* Clase `CosmolMinioClient`:
  * `asegurar_bucket_existe(bucket_name: str) -> None`: Crea el bucket en MinIO si no existe.
  * `subir_archivo_bytes(bucket_name, object_name, data_bytes, content_type) -> str`: Carga binarios a MinIO asignando metadatos HTTP adecuados.
  * `obtener_archivo_bytes(bucket_name, object_name) -> bytes`: Recupera el archivo completo en memoria.
  * `obtener_archivo_stream(bucket_name, object_name, chunk_size) -> Generator[bytes, None, None]`: Generador asíncrono/síncrono por chunks para transmisión fluida vía `StreamingResponse`.
  * `existe_archivo(bucket_name, object_name) -> bool`: Comprobación rápida vía `stat_object`.
  * `generar_url_prefirmada(bucket_name, object_name, expires_seconds) -> str`: Genera enlaces de descarga directa con caducidad configurada.
  * Instancia global singleton `minio_client`.

### 2.3 Motor Generador de PDFs (`backend/app/services/generador_pdf.py`)
* Clase `GeneradorPdfDocumento`:
  * `generar_factura_pdf(datos_factura: dict) -> bytes`: Genera PDF de Factura Oficial con membrete de COSMOL R.L., NIT `1028419024`, Autorización SIAT, tablas de consumo, subtotales en Bs y QR oficial.
  * `generar_aviso_cobranza_pdf(datos_aviso: dict) -> bytes`: Genera PDF de Aviso de Cobranza preventivo mensual.
  * `generar_aviso_corte_pdf(datos_corte: dict) -> bytes`: Genera PDF de Aviso de Corte con advertencia legal de suspensión de servicio conforme al reglamento de servicios de agua potable.

### 2.4 Modelo ORM y Migraciones (`backend/app/db/models/documento.py`)
* Modelo `Documento(BaseModel)` con campos:
  * `id`: UUID (Primary Key).
  * `suministro_id`: UUID (Foreign Key a `suministros.id`, nullable).
  * `cod_socio`: String(50), con índice para búsquedas ultra-rápidas.
  * `tipo_documento`: String(30) (`"FACTURA"`, `"AVISO_COBRANZA"`, `"AVISO_CORTE"`).
  * `nro_factura`: String(50), nullable.
  * `nro_facip`: String(50), nullable.
  * `cod_autorizacion`: String(100), nullable.
  * `periodo`: String(20) (ej: `"08/2026"`).
  * `anio`: Integer.
  * `mes`: Integer.
  * `monto_bs`: Numeric(10, 2).
  * `s3_key`: String(255) (clave única en bucket `cosmol-docs`).
  * `fecha_emision`: Date.
  * `fecha_vencimiento`: Date, nullable.
  * `estado_pago`: String(20) (`"PENDIENTE"`, `"PAGADO"`).
* Migración Alembic:
  * `backend/alembic/versions/e9a8ea64a0f8_add_documentos_table.py` aplicada exitosamente a PostgreSQL (`cosmol-db-postgres`).

### 2.5 Servicio de Almacenamiento (`backend/app/services/servicio_storage_documentos.py`)
* Clase `ServicioStorageDocumentos`:
  * `guardar_documento(db, minio_client, cod_socio, tipo_documento, s3_key, pdf_bytes, ...) -> Documento`: Registra o actualiza el documento en PostgreSQL y MinIO.
  * `obtener_o_generar_pdf_factura(db, minio_client, cod_socio, datos_factura) -> (Documento, bytes)`: Resuelve desde S3 si ya existe, o genera el PDF y lo persiste automáticamente.
  * `obtener_o_generar_pdf_aviso_cobranza(db, minio_client, cod_socio, datos_aviso) -> (Documento, bytes)`: Gestión on-demand de avisos de cobranza.
  * `obtener_o_generar_pdf_aviso_corte(db, minio_client, cod_socio, datos_corte) -> (Documento, bytes)`: Gestión on-demand de avisos de corte.

---

## 3. Pruebas y Certificación en Docker

Se ejecutó la suite completa de pruebas en el contenedor `cosmol-backend-api`:

```bash
docker compose exec backend-api pytest -v
============================== 57 passed in 8.53s ===============================
```

### Detalle de Tests DEV 1:
* `tests/test_minio_client.py` (4 tests):
  1. `test_asegurar_bucket_existe`
  2. `test_subir_y_obtener_archivo_bytes`
  3. `test_obtener_archivo_stream`
  4. `test_generar_url_prefirmada_y_eliminar`
* `tests/test_generador_pdf.py` (3 tests):
  1. `test_generar_factura_pdf_valido`
  2. `test_generar_aviso_cobranza_pdf_valido`
  3. `test_generar_aviso_corte_pdf_valido`
* `tests/test_storage_documentos.py` (3 tests):
  1. `test_obtener_o_generar_pdf_factura`
  2. `test_reutilizacion_pdf_existente_en_s3`
  3. `test_obtener_o_generar_aviso_corte`
* `tests/test_models.py` (2 tests nuevos integrados):
  1. `test_crear_documento_modelo`
  2. `test_crear_suministro_con_documentos_relacionados`

---

## 4. Handover para DEV 2 (Siguientes Pasos)

Con esta base lista, DEV 2 puede implementar sin bloqueos:
1. **Esquemas Pydantic v2 (`app/schemas/documento.py`):**
   * Modelos `DocumentoResponse` y `ListaDocumentosResponse`.
2. **Servicio de Negocio (`app/services/servicio_documentos.py`):**
   * Filtrado multicuenta: `TITULAR` vs `CONSULTA_PAGO` (bloqueo `403 Forbidden` con error `DOCUMENT_ACCESS_DENIED` para Inquilinos que intenten acceder a Facturas o Avisos de Corte).
   * Integración con `BackgroundTasks` para despachar el evento `DOCUMENT_DOWNLOADED` a `ChatbotReportes`.
3. **Endpoints REST (`app/api/v1/documentos.py`):**
   * `GET /api/v1/documentos/{cod_socio}`
   * `GET /api/v1/documentos/{doc_id}/descargar` (usando `StreamingResponse(stream, media_type="application/pdf")`).
