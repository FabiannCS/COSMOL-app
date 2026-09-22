# Tarea 06: Repositorio Digital y Visor de Documentos PDF en Flutter (Fase 3 Frontend)

> **Estado:** COMPLETADO  
> **Fase:** Fase 3 — Repositorio Digital de Documentos (PDFs de Facturas y Avisos)  
> **Fecha de conclusión:** Septiembre 2026  
> **Documentos de referencia:** `AGENTS.md` (Secciones 4.4, 4.6, 10.4) y `Docs/backend/realizado/TASK-03-repositorio-documentos-pdf.md`  
> **Módulos implementados:** `frontend/lib/features/documentos/`  

---

## 1. Resumen de la Implementación

Se completó con éxito la implementación del **Repositorio Digital de Documentos y Visor de PDFs Oficiales** en Flutter, consumiendo los servicios del backend FastAPI y MinIO S3.

### Funcionalidades Entregadas:
1. **Pestañas por Tipo de Documento Oficial:**
   - **Facturas Oficiales:** Facturas fiscales con valor legal emitidas por COSMOL / SIAT.
   - **Avisos de Cobranza:** Avisos preventivos mensuales de deuda y vencimiento.
   - **Avisos de Corte:** Notificaciones de corte para suministros con $\ge 2$ facturas impagas.
2. **Tarjeta de Documento Interactiva (`DocumentCardWidget`):**
   - Distintivo por color e icono para cada tipo de documento.
   - Detalle de periodo (*"Agosto 2026"*), importe en **Bs**, fechas de emisión y vencimiento, y badge de estado (*PAGADO* vs *PENDIENTE*).
   - Acciones directas:
     - 👁️ **"Ver PDF"**: Abre el visor integrado a pantalla completa.
     - ⬇️ **"Descargar"**: Guarda el archivo en almacenamiento local y notifica con opción *"Abrir"*.
     - 🔗 **"Compartir"**: Despacha el diálogo nativo del sistema para enviar el PDF por WhatsApp u otras aplicaciones.
3. **Visor de PDF Integrado (`PdfViewerScreen`):**
   - Renderizado nativo con `flutter_pdfview`.
   - Soporte para zoom táctil, swipe horizontal/vertical, contador de páginas inferior y botones superiores de descarga y compartir.
4. **Seguridad y Privacidad Multicuenta:**
   - Si el suministro está en rol `CONSULTA_PAGO` (inquilino), se presenta un banner explicativo de confidencialidad y se restringe la vista únicamente a avisos de cobranza, protegiendo las facturas fiscales del titular.
5. **Calidad y Cobertura de Pruebas:**
   - **36/36 tests automatizados en Flutter aprobados al 100%**.
   - `flutter analyze`: **0 issues / 0 warnings**.

---

## 2. Archivos Creados y Modificados

- `frontend/pubspec.yaml`: Incorporación de `flutter_pdfview`, `path_provider`, `open_filex` y `share_plus`.
- `frontend/lib/features/documentos/data/models/documento_model.dart`: Modelos `DocumentoModel` y `ListaDocumentosModel`.
- `frontend/lib/features/documentos/data/datasources/documentos_remote_datasource.dart`: Data source para `GET /api/v1/documentos/{cod_socio}` y descarga streaming de bytes.
- `frontend/lib/features/documentos/domain/repositories/documentos_repository.dart`: Contrato abstracto.
- `frontend/lib/features/documentos/data/repositories/documentos_repository_impl.dart`: Implementación de repositorio.
- `frontend/lib/features/documentos/presentation/providers/documentos_provider.dart`: StateNotifier con control de pestañas, descargas y compartición.
- `frontend/lib/features/documentos/presentation/widgets/document_card_widget.dart`: Tarjeta estilizada con acciones.
- `frontend/lib/features/documentos/presentation/widgets/document_inquilino_banner.dart`: Banner de privacidad para rol inquilino.
- `frontend/lib/features/documentos/presentation/widgets/document_empty_widget.dart`: Estado vacío por pestaña.
- `frontend/lib/features/documentos/presentation/screens/pdf_viewer_screen.dart`: Visor interactivo de PDF.
- `frontend/lib/features/documentos/presentation/screens/documentos_screen.dart`: Pantalla principal por pestañas.
- `frontend/lib/core/router/app_router.dart`: Registro de ruta `/documentos/visor`.
- `frontend/test/features/documentos/documento_model_test.dart`: Pruebas de serialización y getters.
- `frontend/test/features/documentos/documentos_provider_test.dart`: Pruebas de estado y lógica de rol inquilino.
