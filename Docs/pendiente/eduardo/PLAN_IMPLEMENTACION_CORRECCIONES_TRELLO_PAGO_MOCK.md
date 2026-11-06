# Plan de Implementación: Ajustes Finales "Vista De Pago / Actualizar / Mock" (Trello)

> **Responsable:** Jose Eduardo Vidaurre  
> **Revisor / Feedback:** Carlos Daniel Guasase Aireyu  
> **Estado:** En Planificación / Pendiente de Aprobación  
> **Fecha:** 6 de Noviembre de 2026  
> **Objetivo:** Implementar con precisión milimétrica las observaciones indicadas por Aireyu en la tarjeta de Trello de TESTING, asegurando el orden cronológico estricto de facturas, la entidad de convenio "Jesús Nazareno", y la reducción puramente visual en memoria.

---

## 1. Análisis del Feedback de Trello

Del comentario oficial dejado por Aireyu:
```text
CORRECCIONES HECHAS
-se corrigio el mock para que funcione en cualquier cuenta, no se modifica ni manda nada a la base de datos de prueba (es solo vista del flujo)
-Solo añade a la cola el pago por QR del banco de convenio (el uso de esta funcion ya se contabiliza en Reportes)

FALTA
-Corregir los chips (cajas de seleccion) que obligue a pagar la primera factura, es decir, no se puede pagar la segunda si no se ha pagado la anterior, asi sucesivamente obligatoriamente
-Corregir el nombre del banco a: Jesus Nazareno

NOTAS
-Al hacer la prueba de pagar, el monto de deuda se reducirá SOLO VISUALMENTE, al recargar la pagina volverá a estar normal con las deudas (por eso no se tocara el servidor para hacer cambios en los registros, solo son pruebas superficiales y visual)
```

---

## 2. Componentes a Modificar

```
frontend/lib/features/deuda/
├── presentation/
│   ├── widgets/
│   │   └── pago_qr_mock_sheet.dart    # Lógica de selección estricta + Banco Jesús Nazareno
│   └── providers/
│       └── deuda_provider.dart        # Verificación y afine de reducción visual en memoria
└── test/features/deuda/
    ├── deuda_provider_test.dart       # Pruebas unitarias de reducción visual
    └── pagos_provider_test.dart       # Pruebas de simulación
```

---

## 3. Plan de Tareas Detallado

### Tarea 1: Lógica Estricta de Selección de Facturas (Prelación Cronológica Obligatoria)
* **Archivo:** `frontend/lib/features/deuda/presentation/widgets/pago_qr_mock_sheet.dart`
* **Regla de Negocio:**
  En las cooperativas de servicios básicos (COSMOL R.L.), las facturas pendientes siguen una regla estricta de orden cronológico (**FIFO** / la más antigua primero). Un socio jamás puede pagar el periodo de Octubre si aún tiene impago Septiembre.
* **Implementación:**
  1. **Ordenamiento Garantizado:** Asegurar que `_facturasDisponibles` esté ordenada cronológicamente (antigüedad de menor a mayor: la primera factura `[0]` es la más antigua con mayor mora).
  2. **Selección hacia adelante (Inclusión en cadena):**
     * Si el usuario pulsa la factura en el índice `i`, obligatoriamente se marcan todas las anteriores: `0, 1, ..., i`.
  3. **Deselección hacia atrás (Exclusión en cadena):**
     * Si el usuario desmarca la factura en el índice `i`, obligatoriamente se desmarcan todas las posteriores: `i, i+1, ..., n-1`.
  4. **Feedback visual en la UI:**
     * Agregar una nota o banner claro:  
       *ℹ️ "Por normativa, las facturas deben cancelarse en orden cronológico obligatorio (la más antigua primero)."*
     * Si una factura está deshabilitada para desmarcar porque tiene facturas posteriores seleccionadas, o al tocarla se le explica la selección en cascada.
  5. **Acción "Seleccionar todas":** Se mantiene para conveniencia rápida. Si se desmarca, se limpian todas las facturas.

### Tarea 2: Entidad Bancaria de Convenio Oficial "Jesús Nazareno"
* **Archivo:** `frontend/lib/features/deuda/presentation/widgets/pago_qr_mock_sheet.dart`
* **Cambio:**
  * Reemplazar las entidades genéricas (`Banco Unión`, `BCP`, `BNB`, `BMSC`) por la entidad de convenio oficial de COSMOL R.L. en Montero y Santa Cruz: **"Jesús Nazareno"** (*Cooperativa de Ahorro y Crédito Jesús Nazareno R.L.*).
* **Parámetros Institucionales:**
  * **Nombre:** `Cooperativa Jesús Nazareno` (y variante visual `Jesús Nazareno`).
  * **Sigla:** `CJN` (utilizada en `TRX-CJN-MOCK-...`).
  * **Colores oficiales:** Verde Nazareno Institucional (`Color(0xFF006837)`) con detalles dorados/blancos.
  * **Formato de Glosa Simple QR:** `COSMOL-JESUS-NAZARENO-SIMPLEQR`.
  * **Red:** `Simple QR Bolivia (ASOBAN / BCB)`.
  * **Actualización en el Comprobante Digital:** El ticket de simulación exitosa mostrará:
    * Entidad Receptora: `Cooperativa Jesús Nazareno (Convenio COSMOL)`.
    * Canal: `Simple QR Interbancario (Demo)`.

### Tarea 3: Reducción de Deuda SOLO VISUAL en Memoria (State Management)
* **Archivos:** 
  * `frontend/lib/features/deuda/presentation/providers/deuda_provider.dart`
  * `frontend/lib/features/deuda/presentation/widgets/pago_qr_mock_sheet.dart`
* **Comportamiento Requerido:**
  * Al pulsar *"Simular Pago Realizado"*:
    1. Se llama al endpoint mock (`simular-pago`) que despacha la auditoría a `COSMOL-Reportes` (`id_tipo: 12`).
    2. Se ejecuta `marcarDeudaComoPagadaSimulada`:
       * Se descuentan visualmente del saldo pendiente las facturas que el socio haya seleccionado.
       * Si el socio seleccionó solo 1 de 3 facturas, el saldo disminuye por el monto de esa factura, y esa factura desaparece de la lista pendiente.
       * Si seleccionó todas, el saldo pasa a `Bs 0.00` y `cantidadFacturasPendientes` pasa a `0`.
    3. **Persistencia Cero:** Ninguna mutación se guarda en backend, ni en la base de datos de COSMOL ni en PostgreSQL.
    4. **Comportamiento al Recargar:** Al hacer *Pull-to-refresh* o refrescar la página (F5 en web), el provider vuelve a consultar el API y la deuda real se restaura de inmediato a su estado original.

### Tarea 4: Pruebas Unitarias de Verificación
* **Archivos:**
  * `frontend/test/features/deuda/deuda_provider_test.dart`
  * `frontend/test/features/deuda/pagos_provider_test.dart`
* **Casos de prueba a verificar:**
  1. Reducción parcial de deuda visual (1 de varias facturas).
  2. Reducción total de deuda visual (saldo a 0).
  3. Lógica de selección de facturas consecutiva (sin saltos).

---

## 4. Criterios de Aceptación (Definición de Terminado)

| Criterio | Validación |
|---|---|
| **1. Prelación de Facturas** | Imposible seleccionar la factura 2 sin tener seleccionada la 1. Al marcar la 2, la 1 se marca automáticamente. Al desmarcar la 1, la 2 se desmarca automáticamente. |
| **2. Nombre del Banco** | El modal de pago y el recibo muestran explícitamente **"Jesús Nazareno"**. |
| **3. Reducción Solo Visual** | El saldo baja tras la simulación en la interfaz; al recargar la página la deuda vuelve al valor real. |
| **4. Integridad de Reportes** | El backend continúa enviando la telemetría a `COSMOL-Reportes` con `id_tipo: 12`. |
| **5. Cero mutaciones en BD** | La base de datos de COSMOL no sufre ningún descuento financiero ni alteración de registros. |

