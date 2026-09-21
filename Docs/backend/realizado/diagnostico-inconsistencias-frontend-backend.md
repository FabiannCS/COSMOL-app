# Diagnóstico de Integración e Inconsistencias: Frontend (Flutter) vs Backend (FastAPI)

> **Fecha:** Septiembre 2026  
> **Autor del Diagnóstico:** DEV 2 (Eduardo - Backend Dev)  
> **Ramas analizadas:** `devFabian` (Frontend Flutter) frente a `devEduardo` / `devAireyu` (Backend FastAPI)  
> **Documentos de referencia:** `AGENTS.md`, `Docs/HOJA_DE_RUTA_DESARROLLO.md`, y entregables en `Docs/realizado/` (Tasks 1, 2 y 3).  
> **Estado general de integración:** ⚠️ **INCOMPATIBLE / REQUIERE CORRECCIONES CRÍTICAS EN FRONTEND ANTES DE AVANZAR**

---

## 1. Resumen Ejecutivo

Se realizó una auditoría técnica profunda y exhaustiva entre el código fuente implementado por el desarrollador de Frontend (`devFabian`) en el directorio `frontend/lib/` y los contratos, endpoints, modelos ORM y reglas de negocio del Backend FastAPI construidos durante las **Fases 0, 1, 2 y 3**.

### Conclusión Principal:
El frontend tiene una estructura de carpetas muy limpia (Clean Architecture con Riverpod, GoRouter y Dio) y configuró adecuadamente los interceptores de token JWT y `X-Device-Id`. Sin embargo, **presenta 4 discrepancias bloqueantes que impiden la comunicación real con el Backend**, además de que **aún no implementó nada de las Fases 2 (Deuda) y 3 (Documentos PDF)**:

1. **Longitud del OTP:** El Frontend renderiza **4 cajas de texto** y valida 4 dígitos, mientras que el Backend, Redis y los requerimientos oficiales de COSMOL exigen un código de seguridad de **6 dígitos**.
2. **Flujo de Onboarding Invertido:** El Frontend solicita el teléfono celular primero (con un código de socio hardcodeado `'104523'`), omitiendo en la UI la llamada al endpoint oficial `POST /verificar-socio` (`cod_socio + CI`).
3. **Login Desconectado (Dummy/Simulación):** En `login_screen.dart`, el botón de inicio de sesión solo ejecuta un `Future.delayed` de 1.6 segundos; no llama a la API ni al Provider, por lo que nadie puede autenticarse.
4. **Fase 2 y Fase 3 Inexistentes en Frontend:** Mientras el Backend ya tiene implementado y probado al 100% el dashboard de deuda (<20ms con Redis) y el repositorio de facturas y avisos en PDF (MinIO S3), el Frontend solo tiene una pantalla vacía (`dashboard_screen.dart`).

---

## 2. Matriz Comparativa de Endpoints y Contratos

| Módulo / Fase | Endpoint en Backend | Método | Estado en Backend | Estado en Frontend (`devFabian`) | Diagnóstico de Compatibilidad |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Fase 1: Auth** | `/api/v1/autenticacion/verificar-socio` | `POST` | ✅ 100% Funcional | ⚠️ Existe en Datasource pero **no se usa en ninguna pantalla** | **Inconsistencia de Flujo:** No se llama desde la interfaz de onboarding. |
| **Fase 1: Auth** | `/api/v1/autenticacion/solicitar-otp` | `POST` | ✅ 100% Funcional | ⚠️ Se llama con `cod_socio` hardcodeado (`'104523'`) | **Bug Crítico:** Solicita OTP sin saber a qué socio pertenece. |
| **Fase 1: Auth** | `/api/v1/autenticacion/verificar-otp` | `POST` | ✅ Exige 6 dígitos | ❌ Frontend solo envía **4 dígitos** | **Bloqueo Crítico:** Backend rechaza con HTTP 422 por longitud. |
| **Fase 1: Auth** | `/api/v1/autenticacion/establecer-pin` | `POST` | ✅ 100% Funcional | ⚠️ Envía campos extraños (`username`, `ci`) no esperados | **Desalineación:** Backend solo requiere `telefono`, `token_otp_valido` y `nuevo_pin`. |
| **Fase 1: Auth** | `/api/v1/autenticacion/login` | `POST` | ✅ 100% Funcional | ❌ Método en UI no llama al endpoint (Simulación) | **Bloqueo:** El botón de Login no conecta con el backend. |
| **Fase 1: Auth** | `/api/v1/autenticacion/renovar-token` | `POST` | ✅ 100% Funcional | ✅ Integrado en `AuthInterceptor` | **Compatible:** Ambos esperan `refresh_token` y `device_id`. |
| **Fase 1: Multi** | `/api/v1/autenticacion/suministros` | `GET` | ✅ 100% Funcional | ❌ No implementado en Frontend | **Faltante:** No hay selector de suministros en Flutter. |
| **Fase 1: Multi** | `/api/v1/autenticacion/suministros/vincular` | `POST` | ✅ 100% Funcional | ❌ No implementado en Frontend | **Faltante:** No hay pantalla para vincular medidores extras. |
| **Fase 2: Deuda** | `/api/v1/deuda/dashboard/resumen` | `GET` | ✅ 100% Funcional | ❌ No implementado en Frontend | **Faltante:** Dashboard solo muestra texto estático. |
| **Fase 2: Deuda** | `/api/v1/deuda/{cod_socio}` | `GET` | ✅ 100% Funcional | ❌ No implementado en Frontend | **Faltante:** No hay visualización de Bs ni semáforo de mora. |
| **Fase 2: Deuda** | `/api/v1/deuda/{cod_socio}/invalidar-cache` | `POST` | ✅ 100% Funcional | ❌ No implementado en Frontend | **Faltante:** No existe botón de refresco forzado. |
| **Fase 3: Docs** | `/api/v1/documentos/{cod_socio}` | `GET` | ✅ 100% Funcional | ❌ No implementado en Frontend | **Faltante:** No existen pestañas de Facturas / Avisos. |
| **Fase 3: Docs** | `/api/v1/documentos/{doc_id}/descargar` | `GET` | ✅ 100% Streaming PDF | ❌ No implementado en Frontend | **Faltante:** No hay visor PDF ni llamada de descarga. |

---

## 3. Detalle Exhaustivo de Inconsistencias Críticas

---

### 🔴 INCONSISTENCIA 1: Longitud del Código OTP (4 dígitos en UI vs 6 dígitos en Backend)

* **Ubicación en Frontend:**
  * [`frontend/lib/features/auth/presentation/widgets/otp_verification_area.dart`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/frontend/lib/features/auth/presentation/widgets/otp_verification_area.dart#L24-L26):
    ```dart
    final List<TextEditingController> _controllers =
        List.generate(4, (_) => TextEditingController()); // Solo 4 casillas
    ```
  * [`frontend/lib/features/auth/presentation/screens/onboarding_screen.dart`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/frontend/lib/features/auth/presentation/screens/onboarding_screen.dart#L53-L58):
    ```dart
    if (_enteredOtp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese el código de verificación de 4 dígitos.')),
      );
      return;
    }
    ```
  * [`frontend/lib/features/auth/presentation/providers/onboarding_provider.dart`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/frontend/lib/features/auth/presentation/providers/onboarding_provider.dart#L178):
    Usa el valor quemado `'4821'` como simulación.
* **Ubicación en Backend y Reglas Oficiales:**
  * `AGENTS.md` (Sección 4.1 y 11): *"código de seguridad de 6 dígitos (TTL 5 min)"*.
  * [`backend/app/schemas/usuario.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/app/schemas/usuario.py#L71-L85):
    ```python
    codigo: str = Field(..., min_length=6, max_length=6)
    # Valida: len(v) != 6 -> "El código OTP debe contener exactamente 6 dígitos numéricos."
    ```
  * [`backend/app/services/servicio_autenticacion.py`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/backend/app/services/servicio_autenticacion.py#L125):
    Genera códigos aleatorios entre 100000 y 999999 (`6 dígitos`).
* **Impacto:** **Bloqueo Total del Onboarding.** El socio recibe un SMS o WhatsApp con un código de 6 dígitos (ej. `582910`), pero la pantalla solo le permite tipear 4 números. Al presionar continuar, el backend devuelve error `422 Unprocessable Entity`.
* **Solución requerida en Frontend:**
  1. Cambiar `List.generate(4, ...)` a `List.generate(6, ...)` en `otp_verification_area.dart`.
  2. Ajustar la validación a `_enteredOtp.length == 6` en `onboarding_screen.dart` y `onboarding_provider.dart`.

---

### 🔴 INCONSISTENCIA 2: Flujo Invertido del Onboarding de Primer Acceso

* **Flujo Oficial de Negocio (AGENTS.md Sección 4.1):**
  Dado que COSMOL no tiene teléfonos en su sistema legado, el saneamiento de identidad exige:
  1. **Paso 1:** El socio ingresa su `Código de Socio + C.I.` para demostrar que es el dueño de la cuenta.
  2. **Paso 2:** Si los datos coinciden, se muestra el nombre del titular y se solicita asociar su **celular**, eligiendo si quiere OTP por **WhatsApp** o **SMS**.
  3. **Paso 3:** Se verifica el OTP de 6 dígitos.
  4. **Paso 4:** Se crea la Contraseña/PIN personal segura, invalidando el CI como clave para siempre.

* **Flujo Implementado en Frontend (`devFabian`):**
  * En la pantalla 1 ([`onboarding_screen.dart`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/frontend/lib/features/auth/presentation/screens/onboarding_screen.dart)), pide **Número de Teléfono** directamente.
  * Al solicitar OTP en [`onboarding_provider.dart`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/frontend/lib/features/auth/presentation/providers/onboarding_provider.dart#L157) y [`auth_remote_datasource.dart`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/frontend/lib/features/auth/data/datasources/auth_remote_datasource.dart#L49), envía un código de socio hardcodeado:
    ```dart
    'cod_socio': codSocio.isNotEmpty ? codSocio : '104523'
    ```
  * En la pantalla 2 ([`onboarding_step2_screen.dart`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/frontend/lib/features/auth/presentation/screens/onboarding_step2_screen.dart)), recién pide el Código de Socio, CI, "Usuario" y contraseña, e intenta enviarlos al endpoint `/establecer-pin`.
* **Impacto:**
  1. El endpoint `POST /autenticacion/verificar-socio` **nunca se ejecuta**.
  2. Cualquiera puede ingresar cualquier teléfono y pedir OTP a nombre del socio hardcodeado `'104523'`.
  3. Al final, en `establecer-pin`, el backend rechaza la petición si el teléfono verificado en el paso previo no coincide.
* **Solución requerida en Frontend:**
  Reordenar las pantallas:
  * **Pantalla 1:** Formulario con `Código de Socio` y `Carnet de Identidad (C.I.)`. Botón "Verificar Socio" que llama a `POST /autenticacion/verificar-socio`.
  * **Pantalla 2:** Muestra el nombre verificado (*"Hola, Victor Hugo Suarez"*), solicita el número de celular y el selector de canal (WhatsApp / SMS) y despacha `POST /autenticacion/solicitar-otp`.
  * **Pantalla 3:** Casillas para los 6 dígitos del OTP (`POST /autenticacion/verificar-otp`).
  * **Pantalla 4:** Creación del nuevo PIN de 4 a 6 dígitos (`POST /autenticacion/establecer-pin`).

---

### 🔴 INCONSISTENCIA 3: Botón de Login Desconectado en `login_screen.dart`

* **Ubicación en Frontend:**
  [`frontend/lib/features/auth/presentation/screens/login_screen.dart`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/frontend/lib/features/auth/presentation/screens/login_screen.dart#L33-L48):
  ```dart
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isLoading = true; });

    // Simulación del flujo de verificación o integración con authProvider
    await Future.delayed(const Duration(milliseconds: 1600));

    if (mounted) {
      setState(() { _isLoading = false; });
    }
  }
  ```
  Además, en [`auth_provider.dart`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/frontend/lib/features/auth/presentation/providers/auth_provider.dart), la clase `AuthNotifier` **no tiene ningún método `login()`**.
* **Ubicación en Backend:**
  Endpoint `POST /api/v1/autenticacion/login` plenamente probado, con control de intentos fallidos (bloqueo progresivo tras 3 fallos) y entrega de tokens JWT (`access_token`, `refresh_token`, `suministros`).
* **Impacto:** La pantalla de login es un cascarón visual. El usuario tipea sus credenciales, presiona "Ingresar", la rueda gira 1.6 segundos y **no pasa nada** (ni autentica ni navega).
* **Solución requerida en Frontend:**
  1. Agregar el método `login({required String codSocio, required String password})` a `AuthNotifier` en `auth_provider.dart`.
  2. Obtener el `deviceId` a través de `deviceServiceProvider`.
  3. Guardar los tokens recibidos en `storageServiceProvider.saveTokens()`.
  4. Actualizar el estado a `AuthStatus.authenticated` para que GoRouter redirija automáticamente a `/dashboard`.

---

### 🔴 INCONSISTENCIA 4: Terminología "Usuario" vs "Código de Socio"

* **En Frontend:**
  * En `login_screen.dart`, el campo de texto tiene `label: 'Usuario'` y `hint: 'Ingrese su Usuario'`.
  * En `onboarding_step2_screen.dart`, pide ingresar un campo `username`.
* **En Reglas COSMOL y Backend:**
  * Los socios de COSMOL **no tienen un "username"**. Son usuarios de una cooperativa de agua identificados por su **Código de Socio** numérico (`cod_socio`, ej. `540`, `556`, `1001`, `102030`), el cual figura en sus facturas y avisos impresos.
  * El backend no almacena ningún campo `username` en la tabla `usuarios` ni en `suministros`.
* **Impacto:** Confusión total para el socio de Montero y desajuste de datos en el payload enviado al backend.
* **Solución requerida en Frontend:**
  Renombrar el campo a **"Código de Socio"** y eliminar el input de `username`.

---

### 🟠 INCONSISTENCIA 5: Falta Total de Implementación para Fase 2 (Deuda) y Fase 3 (Documentos)

El Backend ya completó y certificó las Fases 2 y 3 con 67 tests automatizados en Docker. Sin embargo, en el Frontend:

1. **Dashboard de Deuda (Fase 2):**
   * [`frontend/lib/features/home/presentation/screens/dashboard_screen.dart`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/frontend/lib/features/home/presentation/screens/dashboard_screen.dart) solo contiene un `Text('Hola, socio')` estático.
   * No existe cliente ni provider para `GET /api/v1/deuda/dashboard/resumen` (saldo total en Bs, cantidad de suministros en mora).
   * No existe visualización del semáforo de vencimiento (texto normal si está vigente, **color rojo destacado** si expiró la fecha de pago).
   * No existe el selector desplegable superior para alternar entre suministros (*"Mi Casa"*, *"Alquiler"*).
2. **Repositorio de Documentos PDF (Fase 3):**
   * No existe pantalla ni pestañas para visualizar *Facturas*, *Avisos de Cobranza* y *Avisos de Corte* consumiendo `GET /api/v1/documentos/{cod_socio}`.
   * No existe botón para descargar o abrir el PDF vía streaming (`GET /api/v1/documentos/{doc_id}/descargar`).
   * No está integrado `flutter_pdfview` ni utilitarios para compartir por WhatsApp.

---

## 4. Aspectos Bien Diseñados en el Frontend (Puntos Fuertes)

Es importante reconocer los aciertos de la arquitectura de DEV Fabian que **deben conservarse**:

1. **Gestión de Errores Estructurados:**
   En `auth_remote_datasource.dart` (líneas 131-159) y `auth_interceptor.dart`, se parsea adecuadamente el formato oficial de error de nuestro backend:
   ```json
   { "error": { "code": "ACCOUNT_LOCKED", "message": "...", "details": { "bloqueado_segundos_restantes": 60 } } }
   ```
2. **Renovación Silenciosa con `AuthInterceptor`:**
   La intercepción de peticiones HTTP con inyección automática de `Authorization: Bearer <token>` y el reintento transparente con `/autenticacion/renovar-token` al recibir un HTTP 401 está excelentemente diseñado.
3. **Persistencia Segura:**
   Uso adecuado de `flutter_secure_storage` con opciones de cifrado para almacenar `access_token`, `refresh_token` y `device_id`.
4. **Diseño Visual e Identidad:**
   Paleta de colores institucional de COSMOL (azul cooperativo, acentos cian, tipografía Inter) y componentes reutilizables (`CosmolCard`, `CosmolButton`, `CosmolTextField`).

---

## 5. Plan de Acción Recomendado para el Equipo

Para que el Frontend y el Backend queden sincronizados al 100%, se recomienda la siguiente secuencia de trabajo con DEV Fabian:

### Prioridad 1: Corregir Autenticación y Onboarding (Fase 1)
1. **Ampliar el widget OTP a 6 dígitos:** Modificar `otp_verification_area.dart` para que genere 6 controladores en lugar de 4.
2. **Reordenar el flujo de Onboarding:**
   * Crear la pantalla de Paso 1 (`cod_socio + CI`) llamando a `/autenticacion/verificar-socio`.
   * En el Paso 2 capturar el celular real del socio y llamar a `/autenticacion/solicitar-otp` con ese socio verificado.
   * En el Paso 3 validar los 6 dígitos con `/autenticacion/verificar-otp`.
   * En el Paso 4 establecer el PIN con `/autenticacion/establecer-pin`.
3. **Conectar el Login:** Conectar el formulario de `login_screen.dart` con `authProvider.login()` y guardar la sesión en el almacenamiento local.

### Prioridad 2: Construir el Dashboard de Consulta de Deuda (Fase 2)
1. Crear el `DeudaRemoteDataSource` y `DeudaProvider` en Flutter para consumir:
   * `GET /api/v1/deuda/dashboard/resumen`
   * `GET /api/v1/deuda/{cod_socio}`
2. Construir la tarjeta principal en `dashboard_screen.dart` con el saldo en **Bs** y el semáforo rojo de vencimiento.
3. Incorporar el selector superior de suministros alimentado por `GET /api/v1/autenticacion/suministros`.

### Prioridad 3: Construir el Repositorio de Documentos PDF (Fase 3)
1. Crear el `DocumentosRemoteDataSource` y `DocumentosProvider` para consumir:
   * `GET /api/v1/documentos/{cod_socio}`
   * `GET /api/v1/documentos/{doc_id}/descargar`
2. Crear la pantalla con las 3 pestañas (*Facturas*, *Avisos de Cobranza*, *Avisos de Corte*).
3. Implementar el visor/descarga de PDF con cabeceras `application/pdf`.
