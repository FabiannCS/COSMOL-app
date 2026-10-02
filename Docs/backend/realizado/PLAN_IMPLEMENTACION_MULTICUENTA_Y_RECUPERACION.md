# Plan de Implementación Backend: Multicuenta Blindada y Recuperación Segura de Contraseña
> **Módulo:** Autenticación e Identidad / Multicuenta  
> **Ubicación:** `Docs/backend/pendiente/PLAN_IMPLEMENTACION_MULTICUENTA_Y_RECUPERACION.md`  
> **Fuentes:** `Docs/backend/guias/PLAN_LOGICA_MULTICUENTA_Y_LOGIN_TITULAR.md` y `Docs/backend/guias/PLAN_RECUPERACION_PASSWORD_BACKEND.md`  
> **Responsable:** Eduardo (Backend Develop> **Estado:** COMPLETADO CON ÉXITO (128/128 tests pasando)  

---

## 1. Visión General y Objetivos

Este plan unifica y operacionaliza dos componentes arquitectónicos esenciales para la plataforma de socios de **COSMOL R.L.**:

1. **Módulo Multicuenta y Login Exclusivo Titular:**
   * Garantizar aislamiento absoluto y privacidad unidireccional de suministros.
   * Evitar que la vinculación de un suministro por parte de un inquilino bloquee el Onboarding legítimo del dueño titular.
   * Restringir el inicio de sesión diario a códigos de socio asociados con rol **`TITULAR`**.

2. **Módulo de Recuperación Segura de Contraseña / PIN (Zero-Trust Phone Binding):**
   * Eliminar la vulnerabilidad de suplantación mediante facturas físicas ajenas.
   * El socio solo ingresa `cod_socio` y `ci`; el backend despacha el código OTP **única y exclusivamente al número de celular previamente registrado y verificado en la base de datos**.
   * Emisión de token temporal criptográfico (`token_recuperacion`) para actualizar el hash bcrypt del PIN, revocando sesiones activas anteriores y reseteando contadores de bloqueo.

---

## 2. Mapa de Fases y Tareas de Implementación

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                   MAPA DE IMPLEMENTACIÓN BACKEND (EDUARDO)                       │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  FASE 1: Blindaje Multicuenta y Login Titular                         [COMPLETADO]│
│  ├── Tarea 1.1: Filtro Suministro.rol == 'TITULAR' en verificar_primer_acceso [✓] │
│  ├── Tarea 1.2: Login diario restringido exclusivamente a cuentas TITULARES   [✓] │
│  ├── Tarea 1.3: Aislamiento estricto por usuario_id en listar_suministros     [✓] │
│  └── Tarea 1.4: Suite de pruebas unitarias "Caso Juan y José" en pytest       [✓] │
│                                                                                  │
│  FASE 2: Recuperación Segura de Contraseña / PIN (Zero-Trust)        [COMPLETADO]│
│  ├── Tarea 2.1: Definición de Esquemas Pydantic v2 en schemas/usuario.py      [✓] │
│  ├── Tarea 2.2: Métodos de negocio y claves Redis en servicio_autenticacion.py [✓] │
│  ├── Tarea 2.3: Endpoints REST bajo /recuperar-password/* en autenticacion.py [✓] │
│  └── Tarea 2.4: Suite de pruebas e2e en tests/test_recuperar_password.py      [✓] │
│                                                                                  │
│  FASE 3: Verificación Global y Regresión 100%                         [COMPLETADO]│
│  ├── Tarea 3.1: Ejecución completa de pytest dentro del contenedor Docker     [✓] │
│  └── Tarea 3.2: Actualización de checklist y documentación                    [✓] │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Desglose Detallado por Fase

### 🔵 FASE 1: Blindaje Multicuenta y Login Exclusivo Titular

#### 📋 Tarea 1.1: Filtro de Titularidad en Primer Acceso (Onboarding)
* **Archivo:** [`backend/app/services/servicio_autenticacion.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/app/services/servicio_autenticacion.py)
* **Método:** `verificar_primer_acceso(cod_socio, ci)`
* **Acción:**
  Modificar la consulta a PostgreSQL para comprobar si ya existe una cuenta activa como **`TITULAR`**:
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
* **Efecto:** Si un inquilino agregó el código previamente con rol `CONSULTA_PAGO`, al titular legítimo NO se le bloquea el Onboarding.

#### 📋 Tarea 1.2: Restricción Estricta en Login Diario
* **Archivo:** [`backend/app/services/servicio_autenticacion.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/app/services/servicio_autenticacion.py)
* **Método:** `autenticar_socio(cod_socio, pin_password, ...)`
* **Acción:**
  Filtrar la búsqueda del suministro por `Suministro.rol == "TITULAR"`. Si el código provisto solo existe vinculado como secundario (`CONSULTA_PAGO`), rechazar con:
  ```python
  raise UnauthorizedException(
      message="El código provisto no corresponde a una cuenta titular. Inicie sesión con su código de socio titular.",
      error_code="LOGIN_TITULAR_REQUIRED"
  )
  ```

#### 📋 Tarea 1.3: Aislamiento Estricto por `usuario_id`
* **Archivo:** [`backend/app/services/servicio_suministros.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/app/services/servicio_suministros.py)
* **Acción:**
  En `listar_suministros` y `vincular_suministro`, asegurar que la búsqueda en la base de datos se ejecute filtrando por `Suministro.usuario_id == usuario_id_token`.
  Preservar el enriquecimiento de `nombre` oficial del socio mediante `cosmol_client.obtener_datos_socio`.

#### 📋 Tarea 1.4: Suite de Pruebas "Caso Juan y José"
* **Archivo:** [`backend/tests/test_multicuenta_aislamiento.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/tests/test_multicuenta_aislamiento.py)
* **Validación:**
  1. Juan registra su cuenta Titular (código 1001) y agrega como inquilino el código 2002.
  2. José registra exitosamente su código 2002 como Titular (sin interferencia de Juan).
  3. José inicia sesión y solo ve el suministro 2002.
  4. Juan inicia sesión y ve el suministro 1001 y el 2002 enmascarado.
  5. Ninguno tiene acceso a datos sensibles del otro.

---

### 🟢 FASE 2: Recuperación Segura de Contraseña / PIN (Zero-Trust)

#### 📋 Tarea 2.1: Esquemas Pydantic v2
* **Archivo:** [`backend/app/schemas/usuario.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/app/schemas/usuario.py)
* **Modelos incorporados:**
  * `RecuperarValidarTitularRequest` (`cod_socio: str`, `ci: str`)
  * `RecuperarValidarTitularResponse` (`session_id: str`, `cod_socio: str`, `nombre_titular: str`, `telefono_enmascarado: str`, `mensaje: str`)
  * `RecuperarSolicitarOtpRequest` (`session_id: str`, `canal: Literal["WHATSAPP", "SMS"]`)
  * `RecuperarSolicitarOtpResponse` (`mensaje: str`, `canal: str`, `telefono_enmascarado: str`, `ttl_segundos: int`, `debug_codigo_otp: Optional[str]`)
  * `RecuperarVerificarOtpRequest` (`session_id: str`, `codigo: str`)
  * `RecuperarVerificarOtpResponse` (`mensaje: str`, `token_recuperacion: str`, `cod_socio: str`)
  * `RecuperarCambiarPinRequest` (`token_recuperacion: str`, `nuevo_pin: str`)
  * `RecuperarCambiarPinResponse` (`mensaje: str`, `cod_socio: str`)

#### 📋 Tarea 2.2: Métodos de Negocio y Ciclo de Vida Redis
* **Archivo:** [`backend/app/services/servicio_autenticacion.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/app/services/servicio_autenticacion.py)
* **Lógica implementada:**
  1. `validar_titular_recuperacion(cod_socio, ci)`:
     * Valida en sistema comercial (`cosmol_client.validar_credenciales_socio`).
     * Busca el `Usuario` titular registrado en PostgreSQL.
     * Enmascara el teléfono (`+591 7*** **384`).
     * Guarda sesión en Redis: `recuperacion_sesion:{session_id}` (TTL: 300s).
  2. `solicitar_otp_recuperacion(session_id, canal)`:
     * Recupera los datos de la sesión de Redis.
     * Valida rate limit (máximo 3 peticiones por hora).
     * Genera código de 6 dígitos criptográfico y lo almacena: `otp_recuperacion:{session_id}` (TTL: 300s).
     * Despacha el OTP al celular del usuario mediante `whatsapp_client` o `sms_client`.
  3. `verificar_otp_recuperacion(session_id, codigo)`:
     * Compara contra Redis. Controla máximo 3 intentos fallidos (`otp_recuperacion_fallos:{session_id}`).
     * Al acertar, destruye el OTP y emite: `token_recuperacion_valido:{token}` (TTL: 600s).
  4. `cambiar_pin_recuperacion(token_recuperacion, nuevo_pin)`:
     * Valida `token_recuperacion` en Redis.
     * Genera hash `bcrypt` del nuevo PIN y actualiza `usuario.password_hash` en PostgreSQL.
     * Limpia bloqueos e intentos fallidos en Redis (`bloqueado:{cod_socio}`, `intentos_fallidos:{cod_socio}`).
     * Revoca sesiones activas en otros dispositivos (`sesion_activa:{user_id}`).
     * Elimina el `token_recuperacion`.

#### 📋 Tarea 2.3: Endpoints REST en Router de Autenticación
* **Archivo:** [`backend/app/api/v1/autenticacion.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/app/api/v1/autenticacion.py)
* **Endpoints:**
  * `POST /auth/recuperar-password/validar-titular` (también `/autenticacion/recuperar-password/...`)
  * `POST /auth/recuperar-password/solicitar-otp`
  * `POST /auth/recuperar-password/verificar-otp`
  * `POST /auth/recuperar-password/cambiar-pin`
* Con despacho asíncrono a `BackgroundTasks` para auditoría en `ChatbotReportes`.

#### 📋 Tarea 2.4: Pruebas Automatizadas de Recuperación
* **Archivo:** [`backend/tests/test_recuperar_password.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/tests/test_recuperar_password.py)
* **Casos de prueba implementados y pasando al 100%:**
  * Flujo e2e completo de recuperación con éxito y posterior login con el nuevo PIN.
  * Rechazo con CI inválido o código de socio inexistente.
  * Rechazo si el socio no tiene cuenta registrada (debe hacer onboarding).
  * Rate limit de solicitudes OTP (max 3/hora).
  * Código OTP incorrecto y cancelación al tercer fallo.
  * Token de recuperación inválido o expirado.

---

### 🟣 FASE 3: Verificación Global y Regresión

#### 📋 Tarea 3.1: Ejecución Integral de Pruebas
* **Comando ejecutado:**
  ```bash
  docker compose exec backend-api pytest tests/ -v
  ```
* **Resultado:**
  ```
  ============================= 128 passed in 41.38s =============================
  ```
* 100% de la suite de pruebas del backend (128 pruebas) aprobadas sin errores ni regresiones.

---

## 4. Checklist de Aceptación para Eduardo

- [x] **Fase 1: Multicuenta y Login Titular**
  - [x] `verificar_primer_acceso` filtrado con `Suministro.rol == 'TITULAR'`.
  - [x] `autenticar_socio` restringido a rol `TITULAR`.
  - [x] `listar_suministros` aislado determinísticamente por `usuario_id`.
  - [x] Test `test_multicuenta_aislamiento.py` pasando al 100%.
- [x] **Fase 2: Recuperación de Contraseña (Zero-Trust)**
  - [x] Esquemas Pydantic v2 en `schemas/usuario.py`.
  - [x] Métodos de negocio en `servicio_autenticacion.py`.
  - [x] Rutas `/recuperar-password/*` en `api/v1/autenticacion.py`.
  - [x] Test `test_recuperar_password.py` pasando al 100%.
- [x] **Fase 3: Verificación Global**
  - [x] Suite completa de pruebas ejecutada y pasando al 100% sin regresiones (128/128 passed).

