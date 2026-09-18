# Tarea 04 (Fabian): Módulo de Gestión Multicuenta (Suministros)

> **Asignado a:** Desarrollador Frontend (Fabian)  
> **Estado:** PENDIENTE  
> **Fase:** Fase 1 — Identidad y Autenticación Multicuenta  
> **Fecha de creación:** Septiembre 2026  
> **Documentos de referencia:** `AGENTS.md` (Sección 4.6), `Docs/HOJA_DE_RUTA_DESARROLLO.md` y `Docs/GUIA_INTEGRACION_FRONTEND.md`

---

## 1. Objetivo

Implementar el módulo de **Gestión Multicuenta** en Flutter. Este módulo permite a un único Usuario Digital (1 número de celular verificado) administrar múltiples contratos o suministros de agua (`cod_socio`), alternar rápidamente entre ellos desde la cabecera de la aplicación y vincular nuevos contratos en **Modo Titular** (acceso completo a facturas oficiales e historial) o **Modo Consulta y Pago** (inquilinos o terceros con datos sensibles enmascarados).

---

## 2. Entregables Técnicos

### 2.1 Capa de Datos de Multicuenta (`features/multicuenta/`)
- [ ] **Data Source:** `multicuenta_remote_datasource.dart`:
  - `listarSuministros()`: Petición `GET /api/v1/autenticacion/suministros`.
  - `vincularSuministro(VincularSuministroRequest)`: Petición `POST /api/v1/autenticacion/suministros/vincular`.
- [ ] **Modelo & Entidad:** `suministro_model.dart` (id, cod_socio, alias, rol: `"TITULAR"` / `"CONSULTA_PAGO"`, es_suministro_principal).

### 2.2 Gestión de Estado (`features/multicuenta/presentation/providers/`)
- [ ] `multicuenta_notifier.dart`:
  - Mantiene la lista completa de suministros vinculados.
  - Mantiene el suministro seleccionado actualmente en el Dashboard (`activeSuministro`).
  - Proporciona la función para vincular nuevos suministros y actualizar el estado global.

### 2.3 Componentes UI de Multicuenta (`features/multicuenta/presentation/`)
- [ ] **Selector Superior de Suministro (`suministro_selector_dropdown.dart`):**
  - Widget compacto para la app bar / header del Dashboard.
  - Muestra el alias activo (ej: *"Mi Casa"*, *"Alquiler Bolívar"*) y el `cod_socio`.
  - Muestra un badge visual de rol: **TITULAR** (Azul) o **CONSULTA / PAGO** (Gris / Naranja).
  - Al pulsar, despliega un menú modal inferior (*BottomSheet*) para cambiar de suministro al instante.
  - Incluye botón *" + Agregar nuevo suministro"*.
- [ ] **Pantalla de Lista de Suministros (`supplies_list_screen.dart`):**
  - Lista de tarjetas estilizadas con todos los contratos asociados.
  - Muestra el rol, el estado principal y opción para editar alias personal.
- [ ] **Pantalla para Vincular Suministro (`bind_supply_screen.dart`):**
  - Selector con 2 pestañas (*TabBar*):
    - **Pestaña 1: Modo Titular** (Inputs: Código de Socio, CI o N° Medidor del titular, Alias). Permite ver facturas oficiales y avisos de corte.
    - **Pestaña 2: Modo Consulta y Pago** (Inputs: Código de Socio, Alias). Permite ver saldo y pagar con QR, enmascarando el nombre del titular e historial confidencial.
  - Envío de formulario y confirmación de vinculación exitosa.

---

## 3. Criterios de Aceptación
1. El socio puede cambiar de suministro activo en el selector y toda la aplicación actualiza el contexto del `cod_socio` seleccionado.
2. Al vincular un nuevo suministro en Modo Consulta y Pago (sin CI), el backend lo registra como `CONSULTA_PAGO` y la UI ajusta los permisos de visualización.
