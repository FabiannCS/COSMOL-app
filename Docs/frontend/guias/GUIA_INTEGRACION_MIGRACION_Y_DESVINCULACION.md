# Guía de Integración Frontend: Desvinculación, Migración de Celular y Pendientes

> **Módulos:** Autenticación, Onboarding, Multicuenta y Seguridad (`features/auth`, `features/multicuenta`, `core/network`)  
> **Proyecto:** COSMOL RL — Plataforma Web y Móvil (Flutter Clean Architecture)  
> **Fecha:** Octubre 2026  
> **Ubicación:** `Docs/frontend/guias/GUIA_INTEGRACION_MIGRACION_Y_DESVINCULACION.md`  
> **Estado:** Guía Oficial de Conexión de Endpoints Backend

---

## 1. Estado Actual de la API Backend

El backend FastAPI ya tiene implementados, compilados y verificados al 100% todos los endpoints necesarios bajo el prefijo unificado `/api/v1/autenticacion/*`:

| Endpoint Backend | Método | Auth Requerida | Propósito |
|---|---|---|---|
| `/api/v1/autenticacion/suministros/{cod_socio}` | `DELETE` | Sí (Bearer JWT) | Desvinculación persistente de suministro secundario en PostgreSQL. |
| `/api/v1/autenticacion/verificar-socio` | `POST` | No | Paso 1 Onboarding: devuelve `cuenta_existente: bool` y `telefono_enmascarado`. |
| `/api/v1/autenticacion/migrar-telefono/iniciar` | `POST` | No | Inicia cambio de celular con validación previa de PIN titular. Despacha OTP al nuevo número. |
| `/api/v1/autenticacion/migrar-telefono/confirmar` | `POST` | No | Valida OTP del nuevo celular, actualiza BD, revoca sesiones previas y emite JWTs. |
| `/api/v1/autenticacion/recuperar-password/validar-titular` | `POST` | No | Paso 1 Recuperar PIN: devuelve teléfono enmascarado registrado en BD. |
| `/api/v1/autenticacion/recuperar-password/solicitar-otp` | `POST` | No | Paso 2 Recuperar PIN: envía OTP al celular registrado en BD. |
| `/api/v1/autenticacion/recuperar-password/verificar-otp` | `POST` | No | Paso 3 Recuperar PIN: valida OTP y entrega `token_recuperacion`. |
| `/api/v1/autenticacion/recuperar-password/cambiar-pin` | `POST` | No | Paso 4 Recuperar PIN: actualiza contraseña con bcrypt y resetea bloqueos. |

---

## 2. Tareas de Implementación en Frontend (Paso a Paso con Código)

---

### 🛠️ Tarea F1: Retirar Fallback y Conectar Desvinculación Real en Multicuenta

#### Problema actual en Flutter:
En `MulticuentaNotifier.desvincularSuministro`, se capturaba el error con un `try/catch (_)` asumiendo que el backend no tenía el endpoint. Esto borraba el suministro solo en memoria local: al reiniciar la app, el suministro volvía a aparecer.

#### Archivo: `frontend/lib/features/multicuenta/presentation/providers/multicuenta_provider.dart`

**Reemplazar el método `desvincularSuministro` por:**

```dart
Future<bool> desvincularSuministro(String codSocio) async {
  if (!mounted) return false;
  state = state.copyWith(isLoading: true, errorMessage: null);
  try {
    // 1. Llamada real a la API (DELETE /api/v1/autenticacion/suministros/{codSocio})
    await repository.desvincularSuministro(codSocio);

    // 2. Si el backend responde exitoso, remover del estado local
    final nuevaLista = state.suministros.where((s) => s.codSocio != codSocio).toList();

    // 3. Si el que se desvinculó era el activo, reasignar el principal
    SuministroModel? nuevoActivo = state.activeSuministro;
    if (state.activeSuministro?.codSocio == codSocio) {
      nuevoActivo = nuevaLista.isNotEmpty ? nuevaLista.first : null;
      if (nuevoActivo != null) {
        await storageService.saveActiveCodSocio(nuevoActivo.codSocio);
      }
    }

    if (!mounted) return true;
    state = state.copyWith(
      suministros: nuevaLista,
      activeSuministro: nuevoActivo,
      isLoading: false,
    );
    return true;
  } on AppException catch (e) {
    if (!mounted) return false;
    state = state.copyWith(
      isLoading: false,
      errorMessage: e.message,
    );
    return false;
  } catch (e) {
    if (!mounted) return false;
    state = state.copyWith(
      isLoading: false,
      errorMessage: 'Error al desvincular el socio de su cuenta.',
    );
    return false;
  }
}
```

---

### 🛠️ Tarea F2: Guarda Anti-401 al Iniciar la Aplicación

#### Problema actual:
Al abrir la app en `SplashScreen` o `LoginScreen`, `MulticuentaNotifier` se instancia sin suministros y dispara `cargarSuministros()` sin token Bearer, provocando en el backend:
`cosmol-backend-api | INFO: ... GET /api/v1/autenticacion/suministros 401 Unauthorized`

#### Archivo: `frontend/lib/features/multicuenta/presentation/providers/multicuenta_provider.dart`

**En `cargarSuministros()`, añadir la comprobación de token antes de la llamada HTTP:**

```dart
Future<void> cargarSuministros() async {
  if (!mounted) return;

  // GUARDA ANTI-401: No disparar petición si el usuario aún no tiene sesión activa
  final token = await storageService.getAccessToken();
  if (token == null || token.trim().isEmpty) {
    state = state.copyWith(isLoading: false);
    return;
  }

  state = state.copyWith(isLoading: true, errorMessage: null);
  try {
    final lista = await repository.listarSuministros();
    // ... resto del método existente ...
```

---

### 🛠️ Tarea F3: Diálogo de "Cuenta Ya Registrada" en Paso 1 Onboarding

#### Comportamiento:
Cuando el socio ingresa su Código de Socio y CI en `OnboardingStep1Screen`, el backend responde:
```json
{
  "cod_socio": "104523",
  "nombre_titular": "JUAN PEREZ ROCHA",
  "cuenta_existente": true,
  "telefono_enmascarado": "+591 7*** **384",
  "mensaje": "Socio verificado. Su cuenta ya se encuentra registrada..."
}
```

#### Archivo: `frontend/lib/features/auth/presentation/screens/onboarding_step1_screen.dart`

**Si `cuenta_existente == true`, mostrar modal:**

```dart
if (respuesta.cuentaExistente) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Cuenta Ya Registrada'),
      content: Text(
        'Este código de socio ya tiene una cuenta activa vinculada al celular ${respuesta.telefonoEnmascarado ?? "registrado"}.\n\n'
        '¿Deseas iniciar sesión habitualmente o cambiaste de celular y necesitas migrar tu cuenta?',
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            context.go('/login');
          },
          child: const Text('Iniciar Sesión'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            // Navegar a la pantalla de Migración de Celular pasando cod_socio y CI
            context.push('/auth/migrar-celular', extra: {
              'cod_socio': codSocio,
              'ci': ci,
            });
          },
          child: const Text('Cambiar Celular'),
        ),
      ],
    ),
  );
} else {
  // Flujo normal: continuar a Onboarding Paso 2
  context.push('/onboarding/step2');
}
```

---

### 🛠️ Tarea F4: Pantalla y Flujo de Migración de Celular (Celular Nuevo)

#### Formulario (`MigrarCelularScreen`):
* Muestra el `cod_socio` y nombre del titular en solo lectura.
* Solicita:
  1. **PIN / Contraseña actual** (Campo seguro).
  2. **Nuevo número de celular** (Campo numérico boliviano de 8 dígitos).
  3. Selector de canal: WhatsApp o SMS.
* Dispara `POST /api/v1/autenticacion/migrar-telefono/iniciar`.
* Al recibir `session_id`, navega a la pantalla de verificación OTP.
* Tras verificar el código de 6 dígitos con `POST /api/v1/autenticacion/migrar-telefono/confirmar`, guarda el `access_token` y `refresh_token` en `StorageService` y navega directo al `/home` (Dashboard).

---

### 🛠️ Tarea F5: Conexión de Recuperación de PIN en Login

#### Ubicación:
En `LoginScreen`, en el botón `¿Olvidaste tu contraseña / PIN?`:
1. Navega a `RecuperarPasswordScreen`.
2. El socio ingresa `cod_socio` + `CI`.
3. Llama a `POST /api/v1/autenticacion/recuperar-password/validar-titular`.
4. El backend le muestra el celular registrado enmascarado (`+591 7*** **384`).
5. El socio pulsa *"Enviar código"* (`/solicitar-otp`).
6. Ingresa el código de 6 dígitos (`/verificar-otp`).
7. Ingresa su nuevo PIN de 4 dígitos (`/cambiar-pin`).
8. Mensaje de éxito y redirección a login.

---

### 🛠️ Tarea F6: Ajuste de Red a Puerto 443 en `app_config.dart`

#### Archivo: `frontend/lib/core/network/app_config.dart`

Para que cualquier build o prueba en teléfono físico funcione sin ser bloqueada por el firewall FortiGate:
* Establecer `APP_EXTERNAL_PORT` default en `'443'`.
* Asegurar que `remoteBaseUrl` use `https://$_envDomain/api/v1` cuando el puerto sea 443.

---

## 3. Aspectos Pendientes por Analizar e Implementar (Roadmap Futuro)

| Componente | Estado Actual | Pendiente por Analizar / Implementar | Responsable |
|---|---|---|---|
| **Auditoría hacia COSMOL-Reportes** | Deshabilitada (`REPORTES_ENABLED=false`) para evitar lags de red en la app móvil. | Conectar worker asíncrono en segundo plano (`BackgroundTasks`) para sincronizar logs de auditoría sin bloquear la respuesta al usuario. | Backend / DevOps |
| **Pasarelas de Pago Oficiales** | Mock de enlaces externos y QR estático. | Integración formal con los contratos bancarios de Multipago y Pago al Paso para QR interbancario dinámico y Webhook de conciliación. | Backend / Entidades Bancarias |
| **Meta Cloud API Oficial** | Operando en modo `MOCK_MESSAGING=true`. | Al obtener la aprobación empresarial de Meta para COSMOL R.L., cambiar a `false` e inyectar el Access Token permanente de WhatsApp. | Backend / Meta Business |
| **Pruebas E2E de Migración Móvil** | Endpoints probados y certificados en backend. | Probar el flujo completo en Flutter compilado para Android físico: migrar cuenta, verificar que el token anterior se revoca y que el nuevo celular ingresa al Dashboard. | Frontend / QA |
