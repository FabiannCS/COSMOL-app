# Documento de Entrega Backend: Blindaje Multicuenta y Recuperación Segura de Contraseña

> **Módulo:** Autenticación, Identidad y Gestión de Suministros Multicuenta  
> **Ubicación:** `Docs/backend/realizado/implementacion_multicuenta_y_recuperacion_password.md`  
> **Responsable:** Eduardo (Backend Developer — `COSMOL-app`)  
> **Fuentes Guía:** [`Docs/backend/guias/PLAN_LOGICA_MULTICUENTA_Y_LOGIN_TITULAR.md`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/Docs/backend/guias/PLAN_LOGICA_MULTICUENTA_Y_LOGIN_TITULAR.md) y [`Docs/backend/guias/PLAN_RECUPERACION_PASSWORD_BACKEND.md`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/Docs/backend/guias/PLAN_RECUPERACION_PASSWORD_BACKEND.md)  
> **Estado:** 🟢 COMPLETADO Y VALIDADO AL 100% (128/128 tests pasando)  
> **Fecha:** Octubre 2026  

---

## 1. Resumen Ejecutivo

En cumplimiento de los requerimientos arquitectónicos y directivas técnicas de COSMOL R.L., se completó con éxito la implementación de dos pilares críticos para la seguridad y privacidad de la plataforma:

1. **Blindaje Multicuenta y Login Exclusivo Titular:**
   * Se garantiza la privacidad unidireccional y el aislamiento absoluto por `usuario_id`.
   * Se eliminó el bloqueo de Onboarding cuando un inquilino o tercero vinculaba un código de socio con anterioridad.
   * Se restringió el inicio de sesión diario únicamente a códigos de socio con rol `TITULAR`.

2. **Recuperación Segura de Contraseña / PIN (Zero-Trust Phone Binding):**
   * Se erradicó la vulnerabilidad de suplantación de identidad con facturas físicas ajenas.
   * Flujo de 4 pasos donde el socio solo proporciona `cod_socio` y `ci`; el backend despacha el código OTP **exclusivamente al número de teléfono verificado y persistido en PostgreSQL**.
   * Gestión de sesiones y tokens temporales en Redis con TTLs estrictos, rate limiting de 3 peticiones por hora, control de fuerza bruta (máximo 3 intentos de OTP) y revocación de sesiones previas al cambiar el PIN.

---

## 2. Lógica Multicuenta y Login Exclusivo Titular

### 2.1 Principio de Privacidad y Aislamiento Unidireccional
La vinculación de suministros es **estrictamente privada y desacoplada**:

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                   ESTRUCTURA DE AISLAMIENTO EN BASE DE DATOS                     │
├──────────────────────────────────────────────────────────────────────────────────┤
│ USUARIO A (Juan - Celular 71000001):                                             │
│  ├─ Suministro 1001 (Casa de Juan)  -> Rol: TITULAR (Principal)                  │
│  └─ Suministro 2002 (Alquiler José) -> Rol: CONSULTA_PAGO (Secundario)           │
│                                                                                  │
│ USUARIO B (José - Celular 72000002):                                             │
│  └─ Suministro 2002 (Casa de José)  -> Rol: TITULAR (Principal)                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

* **Privacidad garantizada:** José nunca verá el suministro `1001` de Juan.
* **Aislamiento por token:** Toda consulta a base de datos filtra por `WHERE suministros.usuario_id = :usuario_autenticado_id`.

### 2.2 Modificaciones en `servicio_autenticacion.py`

#### A) Desbloqueo de Onboarding para Titulares Legítimos
* **Método:** `verificar_primer_acceso(cod_socio, ci)`
* **Cambio:** Se ajustó la consulta para verificar existencia previa evaluando únicamente registros con rol `TITULAR`:
  ```python
  stmt = (
      select(Suministro)
      .where(
          Suministro.cod_socio == cod_socio,
          Suministro.rol == "TITULAR"
      )
  )
  res = await self.db.execute(stmt)
  if res.scalars().first():
      es_recuperacion = True
  ```
* **Impacto:** Si un inquilino ya registró el código con rol `CONSULTA_PAGO`, al dueño legítimo **NO se le deriva a recuperación erróneamente**, permitiéndole completar su Onboarding como Titular.

#### B) Login Restringido Exclusivamente a Cuentas Titulares
* **Método:** `autenticar_socio(cod_socio, pin_password, device_id, ...)`
* **Cambio:** Se agregó validación obligatoria sobre el rol del suministro al momento de autenticarse:
  ```python
  stmt = (
      select(Suministro)
      .options(selectinload(Suministro.usuario))
      .where(
          Suministro.cod_socio == cod_socio,
          Suministro.rol == "TITULAR"
      )
  )
  ```
  Si el código provisto solo existe vinculado como secundario (`CONSULTA_PAGO`), el backend deniega el acceso con `401 Unauthorized`:
  ```json
  {
    "detail": "El código provisto no corresponde a una cuenta titular. Inicie sesión con su código de socio titular.",
    "error_code": "LOGIN_TITULAR_REQUIRED"
  }
  ```

### 2.3 Modificaciones en `servicio_suministros.py`
* En `listar_suministros(usuario_id, cod_socio_principal)`:
  * Se garantiza que la consulta primaria se ejecute estrictamente por `Suministro.usuario_id == usuario_id`.
  * Si por herencia de sesión no se encuentran registros directos por `usuario_id`, se hace fallback buscando el suministro con rol `TITULAR` asociado al `cod_socio_principal`.
  * Se enmascara determinísticamente la información de suministros con rol `CONSULTA_PAGO`.

---

## 3. Módulo de Recuperación Segura de Contraseña (Zero-Trust)

### 3.1 Arquitectura del Flujo (4 Pasos)

```
[ FRONTEND ]                                             [ BACKEND FASTAPI + REDIS + DB ]
     │                                                                  │
     │── 1. POST /validar-titular (cod_socio, ci) ────────────────────►│ Valida en COSMOL Legado
     │                                                                  │ Obtiene Celular de PostgreSQL
     │◄── { session_id, telefono_enmascarado, nombre_titular } ─────────│ Guarda session en Redis (TTL 5m)
     │                                                                  │
     │── 2. POST /solicitar-otp (session_id, canal) ───────────────────►│ Rate limit (máx 3/hora)
     │                                                                  │ Genera OTP 6 dígitos
     │◄── { mensaje, canal, ttl_segundos: 300 } ────────────────────────│ Despacha a Celular de BD
     │                                                                  │
     │── 3. POST /verificar-otp (session_id, codigo) ──────────────────►│ Valida OTP (máx 3 intentos)
     │                                                                  │ Emite token_recuperacion
     │◄── { mensaje, token_recuperacion: "rst_..." } ───────────────────│ Destruye OTP
     │                                                                  │
     │── 4. POST /cambiar-pin (token_recuperacion, nuevo_pin) ─────────►│ Valida token_recuperacion
     │                                                                  │ Actualiza hash bcrypt en DB
     │◄── { mensaje: "PIN actualizado exitosamente" } ──────────────────│ Limpia bloqueos y sesiones
```

### 3.2 Contratos de API (Endpoints y Payloads)

Ambos prefijos de ruta son soportados de forma transparente:
* `/api/v1/auth/recuperar-password/*` (Estándar de la guía)
* `/api/v1/autenticacion/recuperar-password/*` (Compatibilidad con router previo)

#### Paso 1: Validar Titular y Obtener Celular Enmascarado
* **URL:** `POST /api/v1/auth/recuperar-password/validar-titular`
* **Request:**
  ```json
  {
    "cod_socio": "1001",
    "ci": "1234567"
  }
  ```
* **Response exitoso (`200 OK`):**
  ```json
  {
    "session_id": "c7a8e291-...",
    "cod_socio": "1001",
    "nombre_titular": "JUAN PEREZ",
    "telefono_enmascarado": "+591 7*** **001",
    "mensaje": "Titular verificado exitosamente. Seleccione el canal para el código OTP."
  }
  ```
* **Errores controlados:**
  * `401 Unauthorized`: CI o código de socio no coincide en el sistema comercial.
  * `404 Not Found`: El socio no cuenta con un usuario registrado en la app (debe realizar Onboarding previo).

#### Paso 2: Solicitar Despacho de OTP
* **URL:** `POST /api/v1/auth/recuperar-password/solicitar-otp`
* **Request:**
  ```json
  {
    "session_id": "c7a8e291-...",
    "canal": "WHATSAPP"
  }
  ```
* **Response exitoso (`200 OK`):**
  ```json
  {
    "mensaje": "Código de verificación enviado exitosamente.",
    "canal": "WHATSAPP",
    "telefono_enmascarado": "+591 7*** **001",
    "ttl_segundos": 300,
    "debug_codigo_otp": "123456"
  }
  ```
* **Seguridad en Redis:**
  * Almacenamiento: `otp_recuperacion:{session_id}` (TTL: 300 segundos).
  * Rate limit: `rate_otp_recuperacion:{telefono}` (máximo 3 peticiones por hora con ventana de 3600s). `429 Too Many Requests` si se excede.

#### Paso 3: Verificar Código OTP
* **URL:** `POST /api/v1/auth/recuperar-password/verificar-otp`
* **Request:**
  ```json
  {
    "session_id": "c7a8e291-...",
    "codigo": "123456"
  }
  ```
* **Response exitoso (`200 OK`):**
  ```json
  {
    "mensaje": "Código OTP verificado correctamente.",
    "token_recuperacion": "rst_4f89b1c2...",
    "cod_socio": "1001"
  }
  ```
* **Manejo de Errores y Fuerza Bruta:**
  * Contador de fallos: `otp_recuperacion_fallos:{session_id}`.
  * Al 3er intento fallido consecutivo: se elimina la clave OTP y se responde con `401 Unauthorized`: *"Ha superado el número máximo de intentos fallidos. Solicite un nuevo código OTP."*

#### Paso 4: Establecer Nuevo PIN / Contraseña
* **URL:** `POST /api/v1/auth/recuperar-password/cambiar-pin`
* **Request:**
  ```json
  {
    "token_recuperacion": "rst_4f89b1c2...",
    "nuevo_pin": "654321"
  }
  ```
* **Response exitoso (`200 OK`):**
  ```json
  {
    "mensaje": "Su contraseña/PIN ha sido actualizada exitosamente. Ya puede iniciar sesión con su nuevo PIN.",
    "cod_socio": "1001"
  }
  ```
* **Efectos colaterales de seguridad ejecutados:**
  1. Validación y consumo único de `token_recuperacion` en Redis (se borra inmediatamente).
  2. Generación de nuevo hash `bcrypt` y actualización de `password_hash` en PostgreSQL.
  3. Limpieza de bloqueos en Redis: `bloqueado:{cod_socio}`, `bloqueo_progresivo:{cod_socio}`, `intentos_fallidos:{cod_socio}`.
  4. Revocación de sesiones activas en otros dispositivos (`sesion_activa:{usuario_id}`).
  5. Auditoría asíncrona despachada hacia `ChatbotReportes` con acción `PASSWORD_RECOVERY_SUCCESS`.

---

## 4. Matriz de Archivos Modificados y Creados

| Archivo | Tipo de Cambio | Responsabilidad y Lógica Implementada |
|---|---|---|
| [`backend/app/schemas/usuario.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/app/schemas/usuario.py) | **Modificado** | Añadidos 8 esquemas Pydantic v2 de Request y Response para los 4 endpoints de recuperación. |
| [`backend/app/services/servicio_autenticacion.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/app/services/servicio_autenticacion.py) | **Modificado** | 1. Filtro `rol == TITULAR` en Onboarding y Login.<br>2. Métodos de recuperación: `validar_titular_recuperacion`, `solicitar_otp_recuperacion`, `verificar_otp_recuperacion` y `cambiar_pin_recuperacion`. |
| [`backend/app/services/servicio_suministros.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/app/services/servicio_suministros.py) | **Modificado** | Aislamiento estricto por `usuario_id` y soporte fallback a suministro titular. |
| [`backend/app/api/v1/autenticacion.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/app/api/v1/autenticacion.py) | **Modificado** | Endpoints REST bajo `/recuperar-password/*` con inyección de `BackgroundTasks` para auditoría. |
| [`backend/app/api/v1/router.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/app/api/v1/router.py) | **Modificado** | Enrutamiento dual del router de autenticación bajo `/auth` y `/autenticacion`. |
| [`backend/tests/test_multicuenta_aislamiento.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/tests/test_multicuenta_aislamiento.py) | **Nuevo** | Suite de pruebas del Caso Juan y José (aislamiento de suministros y restricción de login titular). |
| [`backend/tests/test_recuperar_password.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/tests/test_recuperar_password.py) | **Nuevo** | Suite de 5 pruebas integrales e2e del flujo de recuperación de contraseña. |
| [`Docs/backend/pendiente/PLAN_IMPLEMENTACION_MULTICUENTA_Y_RECUPERACION.md`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/Docs/backend/pendiente/PLAN_IMPLEMENTACION_MULTICUENTA_Y_RECUPERACION.md) | **Nuevo** | Plan de trabajo y checklist formal completado. |

---

## 5. Resultados de Pruebas y Validación (Pytest en Docker)

Se ejecutó la suite completa en el entorno de contenedores:
```bash
docker compose exec backend-api pytest tests/ -v
```

### Resumen de Ejecución
```text
============================= 128 passed in 41.38s =============================
```

### Detalle por Módulos Verificados:
* **Autenticación e Identidad (`test_auth_service.py`, `test_recuperar_password.py`, `test_multicuenta_aislamiento.py`):** **35 tests PASSED**
* **Deuda y Avisos de Cobranza (`test_deuda.py`, `test_cache_deuda.py`):** **13 tests PASSED**
* **Consumo Histórico y Fuga Atípica (`test_consumo.py`, `test_cache_consumo.py`, `test_cosmol_client_consumo.py`):** **17 tests PASSED**
* **Documentos PDF y Storage MinIO (`test_documentos.py`, `test_storage_documentos.py`, `test_generador_pdf.py`, `test_minio_client.py`):** **18 tests PASSED**
* **Pagos QR y Conciliación (`test_pagos.py`, `test_cache_pagos.py`):** **14 tests PASSED**
* **Integración Base, Modelos y OTP Core (`test_integration_empalme.py`, `test_models.py`, `test_otp_services.py`, `test_base_components.py`, `test_health.py`):** **31 tests PASSED**

**Tasa de éxito:** **100% (128/128 passed)** sin una sola advertencia de regresión o quiebre de contratos.

---

## 6. Recomendaciones de Integración para el Frontend Flutter

1. **Pantalla de Login Habitual:**
   * Recordar que solo suministros titulares pueden autenticarse.
   * Si el usuario intenta loguearse con un suministro secundario, manejar el error `LOGIN_TITULAR_REQUIRED` mostrando un diálogo que le indique ingresar con el código de su medidor principal.
2. **Pantalla de Olvidé mi Contraseña / PIN:**
   * Paso 1: Pedir `cod_socio` y `ci`. Al recibir la respuesta exitosa, mostrar el teléfono enmascarado (`+591 7*** **384`) para dar certeza visual al socio.
   * Paso 2: Permitir elegir entre WhatsApp y SMS. Despachar petición a `/solicitar-otp`.
   * Paso 3: Solicitar el código de 6 dígitos con un timer visual de 5 minutos.
   * Paso 4: Solicitar el nuevo PIN de 4 a 6 dígitos con confirmación y enviar el `token_recuperacion`. Al finalizar, redirigir automáticamente a la pantalla de Login con mensaje de éxito.
