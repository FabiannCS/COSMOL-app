# Entregables DEV 2: Repositorio Digital de Documentos y Descarga en Streaming de PDFs

> **Fase:** Fase 3 — Repositorio Digital de Documentos (PDFs de Facturas y Avisos)  
> **Rol responsable:** DEV 2 (Eduardo - Backend Dev)  
> **Fecha de conclusión:** Septiembre 2026  
> **Documentos de referencia:** `Docs/pendiente/TASK-03-repositorio-documentos-pdf.md` y `AGENTS.md` (Secciones 4.4, 4.6, 7.4, 10.4, 12.3, 12.7.1)  
> **Estado:** COMPLETADO y certificado en Docker (10/10 tests propios y 67/67 tests totales del backend pasando al 100%)

---

## 1. Resumen Ejecutivo

En el marco de la **Fase 3 (Repositorio Digital de Documentos y Descargas)**, **DEV 2** construyó la capa de negocio, contratos Pydantic v2, control de acceso multicuenta y endpoints REST públicos para la visualización y descarga eficiente de documentos institucionales de COSMOL R.L.:

1. **Esquemas Pydantic v2 (`DocumentoResponse`, `ListaDocumentosResponse`):** DTOs estructurados y tipados con soporte nativo para visualización por pestañas en la aplicación cliente (*Facturas*, *Avisos de Cobranza*, *Avisos de Corte*).
2. **Servicio de Negocio y Privacidad Multicuenta (`ServicioDocumentos`):**  
   * **Modo Titular:** Acceso completo al historial de documentos fiscales con valor legal, avisos preventivos y advertencias de corte.
   * **Modo Inquilino / Pagador Externo (`CONSULTA_PAGO`):** Protección estricta de la privacidad fiscal del propietario. El inquilino únicamente puede consultar y descargar **Avisos de Cobranza** para pagar el servicio. Ante cualquier intento de solicitar facturas fiscales o avisos de corte, el backend bloquea con `403 Forbidden` (`DOCUMENT_ACCESS_DENIED`).
   * **Auto-sincronización y Caching Resiliente:** Si el socio consulta un suministro sin documentos previos en la base local, el servicio orquesta on-demand con el sistema comercial legado y el almacenamiento S3 de MinIO.
3. **Endpoints REST y Streaming Binario:**
   * `GET /api/v1/documentos/{cod_socio}`: Listado agrupado y categorizado para consumo en Flutter.
   * `GET /api/v1/documentos/{doc_id}/descargar`: Transmisión por bloques binarios (`StreamingResponse` con `media_type="application/pdf"` y cabeceras `Content-Disposition`) que permite abrir o descargar el PDF en teléfonos y navegadores sin sobrecargar la memoria RAM del servidor.
   * **Auditoría Asíncrona:** Despacho de eventos `DOCUMENT_DOWNLOADED` en segundo plano (`BackgroundTasks`) hacia `ChatbotReportes`.
4. **Batería de Pruebas Automatizadas:** 10 pruebas unitarias y de integración en Docker (`tests/test_documentos.py`) certificando la suite completa de 67 pruebas pasando en verde sin regresiones.

---

## 2. Detalle de Archivos Creados y Modificados

### 2.1 Esquemas Pydantic v2 (`backend/app/schemas/documento.py`)
* `DocumentoResponse`: Metadatos de cada documento digital:
  * `id`: UUID (identificador del documento).
  * `cod_socio`: Código del contrato o suministro.
  * `tipo_documento`: `"FACTURA"`, `"AVISO_COBRANZA"` o `"AVISO_CORTE"`.
  * `periodo`: Formato `MM/YYYY` (ej: `"08/2026"`).
  * `anio`, `mes`: Valores numéricos para ordenamiento.
  * `monto_bs`: Importe expresado en Bolivianos (Bs).
  * `nro_factura`, `nro_facip`, `cod_autorizacion`: Identificadores fiscales.
  * `fecha_emision`, `fecha_vencimiento`, `estado_pago`: Control de ciclo de vida.
  * `url_descarga`: Ruta relativa para descarga directa (`/api/v1/documentos/{id}/descargar`).
* `ListaDocumentosResponse`:
  * `cod_socio`: Código consultado.
  * `rol_acceso`: `"TITULAR"` o `"CONSULTA_PAGO"`.
  * `total_documentos`: Total de documentos accesibles para este rol.
  * `facturas`: Lista de facturas oficiales (vacía para inquilinos).
  * `avisos_cobranza`: Lista de avisos de cobranza preventivos.
  * `avisos_corte`: Lista de avisos de suspensión (vacía para inquilinos).
  * `documentos`: Lista consolidada para tablas o filtros directos.

### 2.2 Servicio de Lógica de Negocio (`backend/app/services/servicio_documentos.py`)
* Clase `ServicioDocumentos`:
  * `listar_documentos_socio(usuario_id, cod_socio, tipo)`:
    * Valida que el socio pertenezca al usuario en la tabla `suministros`.
    * Si el rol es `CONSULTA_PAGO` e intenta filtrar por `tipo="FACTURA"` o `tipo="AVISO_CORTE"`, arroja `ForbiddenException("DOCUMENT_ACCESS_DENIED")`.
    * Consulta PostgreSQL ordenando por año y mes descendente.
    * Si no existen registros locales, dispara la auto-sincronización con `cosmol_client` y `ServicioStorageDocumentos`.
    * Separa los documentos en colecciones independientes para alimentar las pestañas de Flutter.
  * `obtener_documento_para_descarga(usuario_id, doc_id)`:
    * Valida existencia del documento y pertenencia al usuario.
    * Bloquea con `403 Forbidden` (`DOCUMENT_ACCESS_DENIED`) si un inquilino intenta descargar una factura fiscal o un aviso de corte.
    * Verifica existencia del archivo físico en MinIO S3 y genera el stream por chunks (`s3_client.obtener_archivo_stream`).
    * Asigna nombres amigables al archivo (ej: `Factura_Oficial_COSMOL_102030_08-2026.pdf`).
  * `registrar_auditoria_descarga(usuario_id, cod_socio, doc_id, tipo_documento)`:
    * Registra traza estructurada y encola el evento `DOCUMENT_DOWNLOADED` para `ChatbotReportes`.

### 2.3 Endpoints REST (`backend/app/api/v1/documentos.py`)
* `GET /api/v1/documentos/{cod_socio}`:
  * Autenticación obligatoria con JWT Bearer.
  * Parámetros: `cod_socio` (path), `tipo` (query opcional).
  * Respuestas: `200 OK` (`ListaDocumentosResponse`), `401 Unauthorized`, `403 Forbidden` (`DOCUMENT_ACCESS_DENIED`), `404 Not Found`.
* `GET /api/v1/documentos/{doc_id}/descargar`:
  * Parámetros: `doc_id` (UUID en path).
  * Cabecera `Content-Disposition: attachment; filename="..."`.
  * Cabecera `Content-Type: application/pdf`.
  * `BackgroundTasks` para registro asíncrono de auditoría.
* Registro en router central:
  * Incluido en `backend/app/api/v1/router.py` bajo el prefijo `/documentos` y tag `"Documentos y Facturas Digitales"`.

### 2.4 Ajustes de Resiliencia en Almacenamiento (`backend/app/services/servicio_storage_documentos.py` y `generador_pdf.py`)
* Se robusteció la conversión de datos de tipo string a entero para campos de mes y año (`NMES`, `ANIO`) al formatear el periodo `MM/YYYY`, evitando errores de formateo en Python (`Unknown format code 'd' for object of type 'str'`).
* Se implementó auto-reparación entre S3 y Postgres: si un archivo PDF ya existe en el bucket de MinIO pero el registro fue eliminado de la base de datos, el servicio indexa automáticamente los metadatos en la tabla `documentos`.

---

## 3. Contrato de API para el Desarrollador de Frontend (Flutter)

### 3.1 Listar Documentos por Pestañas
**Petición:**
```http
GET /api/v1/documentos/540 HTTP/1.1
Host: localhost:8000
Authorization: Bearer <access_token>
```

**Respuesta 200 OK (Rol TITULAR):**
```json
{
  "cod_socio": "540",
  "rol_acceso": "TITULAR",
  "total_documentos": 3,
  "facturas": [
    {
      "id": "e8499bf2-72c6-43bf-895c-19602e1bdfc0",
      "cod_socio": "540",
      "tipo_documento": "FACTURA",
      "nro_factura": "7444051",
      "nro_facip": null,
      "cod_autorizacion": "465C3D0702C232069B9F771B83440D4217AF35B442086180BD081BF74",
      "periodo": "08/2026",
      "anio": 2026,
      "mes": 8,
      "monto_bs": 70.92,
      "fecha_emision": "2026-09-18",
      "fecha_vencimiento": null,
      "estado_pago": "PENDIENTE",
      "s3_key": "facturas/540/08_2026_7444051.pdf",
      "permite_descarga": true,
      "url_descarga": "/api/v1/documentos/e8499bf2-72c6-43bf-895c-19602e1bdfc0/descargar"
    }
  ],
  "avisos_cobranza": [
    {
      "id": "b3e020fa-0e7d-41a3-9ea9-b2c32cf961d1",
      "cod_socio": "540",
      "tipo_documento": "AVISO_COBRANZA",
      "nro_factura": null,
      "nro_facip": "1160026",
      "cod_autorizacion": null,
      "periodo": "08/2026",
      "anio": 2026,
      "mes": 8,
      "monto_bs": 70.92,
      "fecha_emision": "2026-09-18",
      "fecha_vencimiento": null,
      "estado_pago": "PENDIENTE",
      "s3_key": "avisos_cobranza/540/08_2026_1160026.pdf",
      "permite_descarga": true,
      "url_descarga": "/api/v1/documentos/b3e020fa-0e7d-41a3-9ea9-b2c32cf961d1/descargar"
    }
  ],
  "avisos_corte": [
    {
      "id": "c1f7b11d-2b4a-4632-a56e-82199b538e12",
      "cod_socio": "540",
      "tipo_documento": "AVISO_CORTE",
      "nro_factura": null,
      "nro_facip": null,
      "cod_autorizacion": null,
      "periodo": "09/2026",
      "anio": 2026,
      "mes": 9,
      "monto_bs": 132.34,
      "fecha_emision": "2026-09-18",
      "fecha_vencimiento": null,
      "estado_pago": "PENDIENTE",
      "s3_key": "avisos_corte/540/09_2026_corte_inminente.pdf",
      "permite_descarga": true,
      "url_descarga": "/api/v1/documentos/c1f7b11d-2b4a-4632-a56e-82199b538e12/descargar"
    }
  ],
  "documentos": [...]
}
```

**Respuesta 200 OK (Rol CONSULTA_PAGO - Inquilino):**
```json
{
  "cod_socio": "540",
  "rol_acceso": "CONSULTA_PAGO",
  "total_documentos": 1,
  "facturas": [],
  "avisos_cobranza": [
    {
      "id": "b3e020fa-0e7d-41a3-9ea9-b2c32cf961d1",
      "cod_socio": "540",
      "tipo_documento": "AVISO_COBRANZA",
      "nro_facip": "1160026",
      "periodo": "08/2026",
      "monto_bs": 70.92,
      "permite_descarga": true,
      "url_descarga": "/api/v1/documentos/b3e020fa-0e7d-41a3-9ea9-b2c32cf961d1/descargar"
    }
  ],
  "avisos_corte": [],
  "documentos": [...]
}
```

### 3.2 Descargar Documento en PDF
**Petición:**
```http
GET /api/v1/documentos/e8499bf2-72c6-43bf-895c-19602e1bdfc0/descargar HTTP/1.1
Host: localhost:8000
Authorization: Bearer <access_token>
```

**Respuesta 200 OK:**
* Cabeceras:
  * `Content-Type: application/pdf`
  * `Content-Disposition: attachment; filename="Factura_Oficial_COSMOL_540_08-2026.pdf"`
* Cuerpo: Flujo binario con el archivo PDF compilado.

**Respuesta 403 Forbidden (Inquilino intentando descargar Factura o Corte):**
```json
{
  "success": false,
  "error": {
    "code": "DOCUMENT_ACCESS_DENIED",
    "message": "Acceso denegado: solo el titular registrado puede descargar facturas fiscales y avisos de corte.",
    "details": null
  }
}
```

---

## 4. Resultados de las Pruebas Automatizadas

Se ejecutó la suite completa de pruebas dentro del contenedor Docker `cosmol-backend-api`:

```bash
docker compose exec backend-api pytest -v
```

### Resumen de Ejecución:
* **Pruebas Totales:** **67 pruebas automatizadas**.
* **Resultado:** **67 PASSED (100% verde) en 20.46 segundos**.
* **Regresiones:** **0**.

### Detalle de Pruebas de DEV 2 (`tests/test_documentos.py`):
1. `test_listar_documentos_titular_completo`: Certifica visualización de facturas, avisos de cobranza y avisos de corte.
2. `test_listar_documentos_inquilino_filtra_privacidad`: Certifica que se oculten facturas y cortes para el rol `CONSULTA_PAGO`.
3. `test_listar_documentos_inquilino_tipo_prohibido_retorna_403`: Certifica bloqueo con `DOCUMENT_ACCESS_DENIED` si el inquilino envía `?tipo=FACTURA` o `?tipo=AVISO_CORTE`.
4. `test_descargar_factura_titular_streaming_pdf`: Certifica la transmisión en streaming del binario con cabecera `Content-Disposition`.
5. `test_descargar_documentos_inquilino_permisos`: Certifica que el inquilino pueda descargar avisos de cobranza pero no facturas ni avisos de corte.
6. `test_acceso_documentos_suministro_ajeno_retorna_403`: Certifica que un usuario no pueda acceder a documentos de otro socio.
7. `test_documento_inexistente_retorna_404`: Certifica manejo limpio de IDs inexistentes (`DOCUMENT_NOT_FOUND`).
8. `test_auditoria_descarga_despacha_evento`: Certifica la tarea asíncrona de auditoría para `ChatbotReportes`.
9. `test_documentos_sin_token_retorna_401`: Certifica protección estricta con JWT Bearer.
10. `test_listar_documentos_auto_sincroniza_con_sistema_legado`: Certifica el auto-poblado en vivo al consultar un suministro sin documentos locales previos.
