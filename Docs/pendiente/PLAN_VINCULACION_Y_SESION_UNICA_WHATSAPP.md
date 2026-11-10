# Plan de Implementación: Corrección Integral de Sesión Única, Error 500 y Navegación en COSMOL R.L.

## 1. Análisis de los Nuevos Casos de Uso y Problemas Reportados

### Caso A: Dispositivo 2 ingresa pero genera Error 500 en Deuda/Consumo/Documentos
- **Síntoma:** El segundo dispositivo se registra/inicia con éxito y abre el Dashboard, pero al tocar en cualquier otra pestaña o consultar deudas y consumos, la pantalla falla con **Error 500**.
- **Causa Raíz en Backend:**  
  En `backend/app/services/servicio_autenticacion.py` (dentro de `confirmar_migracion_telefono`):
  ```python
  # ❌ ERROR: Pasa un diccionario como primer parámetro (subject):
  access_token = create_access_token({"sub": user_id_str, "cod_socio": cod_socio})
  ```
  `create_access_token` en `security.py` hace `str(subject)`. El claim `"sub"` del JWT quedó guardado como la cadena:
  ```text
  "{'sub': '96d90566-2b96-470a-af37-de45c7017d77', 'cod_socio': '11543'}"
  ```
  Al consultar `/api/v1/deuda/...`, `/api/v1/consumo/...` y `/api/v1/documentos/...`, el backend ejecuta `UUID(current_user_id)`. Al recibir una cadena con llaves y comillas, Python arroja:
  ```text
  ValueError: badly formed hexadecimal UUID string (HTTP 500)
  ```
- **Solución:**
  1. Corregir `servicio_autenticacion.py` para emitir `subject=user_id_str` (string plano) y colocar `"cod_socio"` y `"nombre"` en `extra_claims`.
  2. Blindar `backend/app/core/security.py` para que, ante cualquier llamada futura con diccionario, extraiga automáticamente el `sub` limpio.

---

### Caso B: Dispositivo 1 sigue logueado tras el registro del Dispositivo 2
- **Síntoma:** El Dispositivo 2 completó el registro/traspaso, pero el Dispositivo 1 sigue navegando y viendo información como si nada hubiera pasado.
- **Causa Raíz en Backend:**  
  En `backend/app/api/deps.py`, la dependencia `get_current_user_id` **solo valida la firma criptográfica local del JWT**. Jamás consulta Redis en las peticiones normales.  
  Por tanto, el token del Dispositivo 1 (con 15 minutos de vida útil) sigue siendo aceptado por `/deuda`, `/consumo`, etc., sin importar que en Redis la sesión activa pertenezca al Dispositivo 2.
- **Solución Estilo WhatsApp:**  
  En `backend/app/api/deps.py`, consultar en Redis `sesion_activa:{user_id}` en cada petición protegida:
  - Si `sesion_activa:{user_id} != token_device_id`, el backend responde inmediatamente `401 Unauthorized` con código `SESSION_REVOKED_NEW_DEVICE`.
  - El interceptor de Flutter en el Dispositivo 1 captura el error, borra los tokens locales y expulsa al usuario al login con el mensaje: *"Su sesión ha sido iniciada en otro dispositivo"*.

---

### Caso C: Bloqueo de Navegación en Pantalla de Validación de Socio (Frontend)
- **Síntoma:** Al colocar un socio que ya está registrado, la app envía a la pantalla de validación/onboarding, pero se **deshabilita el botón volver** (tanto el de la app como el gesto/botón de Android) y tampoco funciona el botón **"Iniciar Sesión"**, obligando al usuario a matar la app en segundo plano.
- **Causa Raíz en Frontend:**  
  En `frontend/lib/core/router/app_router.dart` (líneas 49-51):
  ```dart
  // ❌ BLOQUEO EN GOROUTER:
  if (status == AuthStatus.onboardingRequired) {
    return isOnboarding ? null : '/onboarding';
  }
  ```
  Cuando el login detecta que falta registro o se deriva a validación, `authProvider` coloca `status = AuthStatus.onboardingRequired`.  
  A partir de ese instante, **el guard de GoRouter bloquea cualquier intento de navegar a `/login`**.  
  - Si el usuario presiona "Iniciar Sesión" (`context.go('/login')`), GoRouter dice: *"No puedes ir a login porque tu status es onboardingRequired"* y lo regresa a `/onboarding`.
  - Si el usuario presiona la flecha atrás o el botón físico de Android (`PopScope`), intenta hacer pop a `/login`, pero GoRouter lo cancela y lo devuelve a `/onboarding`.
- **Solución:**
  1. En `app_router.dart`, permitir que el usuario pueda volver a `/login` o `/recuperar-password` aun cuando `status == AuthStatus.onboardingRequired`:
     ```dart
     if (status == AuthStatus.onboardingRequired) {
       return isLoggingIn || isOnboarding || isRecuperarPassword || isMigrarCelular ? null : '/onboarding';
     }
     ```
  2. En `onboarding_screen.dart`, al presionar "Iniciar Sesión" o el botón volver, reiniciar el estado con `ref.read(authProvider.notifier).resetStatus()` a `AuthStatus.unauthenticated`, liberando la navegación por completo.

---

## 2. Diagrama del Flujo Unificado (WhatsApp Handover + Navegación Libre)

```
                       [ Login / Onboarding ]
                                 │
     ¿Usuario desea volver atrás o ir a "Iniciar Sesión"?
                                 │
                                 ├── SÍ ──► Resetea status a unauthenticated
                                 │          Navega a /login SIN BLOQUEOS
                                 │
                                 └── NO (Prosigue con nuevo dispositivo "B")
                                             │
                                             ▼
                             [ Dispositivo B confirma OTP ]
                                             │
               ┌─────────────────────────────┴─────────────────────────────┐
               ▼                                                           ▼
     [ En BACKEND + REDIS ]                                       [ DISPOSITIVO A (Viejo) ]
  1. sesion_activa = "B"                                                       │
  2. Emite JWT sub=UUID limpio (Sin Error 500)                                 │
               │                                                               │
               ▼                                                               ▼
     [ DISPOSITIVO B ]                                            Siguiente petición a la API
     Dashboard, Deuda, Consumo                                    (GET /deuda, GET /consumo):
     cargan al 100% (200 OK).                                     deps.py detecta token "A" != activa "B"
                                                                  Responde 401: SESSION_REVOKED.
                                                                  App en A expulsa a Login de inmediato.
```

---

## 3. Plan de Acción por Tareas

### Tarea 1: Corrección de Emisión JWT y Blindaje Criptográfico (Backend)
- **Archivos:**
  - `backend/app/services/servicio_autenticacion.py`:
    En `confirmar_migracion_telefono`, pasar `subject=user_id_str` (string UUID plano) y los claims adicionales en `extra_claims`.
  - `backend/app/core/security.py`:
    En `create_access_token` y `create_refresh_token`, agregar desempaquetado defensivo para que, si alguna vez recibe un diccionario, extraiga automáticamente `"sub"` o `"id"`.
- **Resultado:** Elimina definitivamente el `ValueError: badly formed hexadecimal UUID string` (Error 500) en `/deuda`, `/consumo` y `/documentos`.

---

### Tarea 2: Revocación Inmediata del Dispositivo 1 en Tiempo Real (Backend)
- **Archivo:** `backend/app/api/deps.py`
- **Acción:**
  En `get_current_user_id`:
  1. Inyectar `redis: Redis = Depends(get_redis)`.
  2. Leer `device_id` de los claims del token.
  3. Consultar `sesion_activa:{user_id}` en Redis.
  4. Si existe y es distinto a `device_id`, lanzar:
     ```python
     raise UnauthorizedException(
         message="Su sesión ha sido iniciada en otro dispositivo.",
         error_code="SESSION_REVOKED_NEW_DEVICE"
     )
     ```
- **Resultado:** El Dispositivo 1 queda desconectado inmediatamente en cuanto el Dispositivo 2 confirma el OTP.

---

### Tarea 3: Desbloqueo de Navegación en Pantalla de Validación (Frontend)
- **Archivos:**
  - `frontend/lib/core/router/app_router.dart`:
    Actualizar el guard de `onboardingRequired` para permitir acceso sin restricciones a `/login`, `/migrar-celular` y `/recuperar-password`.
  - `frontend/lib/features/auth/presentation/providers/auth_provider.dart`:
    Añadir método `resetStatus()` para restaurar el estado a `AuthStatus.unauthenticated`.
  - `frontend/lib/features/auth/presentation/screens/onboarding_screen.dart`:
    - En el botón "Iniciar Sesión" del modal, ejecutar `resetStatus()` antes de `context.go('/login')`.
    - En `CosmolAppBar.onBackPressed` y en `PopScope`, ejecutar `resetStatus()` y permitir volver limpiamente a `/login`.
- **Resultado:** El usuario nunca más queda atrapado en la pantalla de validación ni se ve forzado a cerrar la app en segundo plano.

---

### Tarea 4: Verificación Integral
1. **Frontend:**
   - Ejecutar `flutter analyze` (0 errores).
   - Ejecutar suite de pruebas unitarias (`auth_provider_test.dart`, `error_parser_test.dart`).
2. **Backend:**
   - Compilación sintáctica con `python -m py_compile`.
   - Ejecutar `test_transferencia_dispositivo.py` validando la desconexión del equipo anterior y la validez del token UUID.
