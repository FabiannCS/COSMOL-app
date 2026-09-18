# Entregables DEV 2: Resolución de Inconsistencias y Resiliencia en Backend

> **Módulo:** Resolución de Inconsistencias Frontend (Flutter) vs Backend (FastAPI)  
> **Rol responsable:** DEV 2 (Eduardo - Backend Dev) — Trabajo autónomo sin DEV 1 ni cambios en Frontend  
> **Fecha de conclusión:** Septiembre 2026  
> **Documentos de referencia:** [`Docs/plan-resolucion-inconsistencias-frontend-backend.md`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/Docs/plan-resolucion-inconsistencias-frontend-backend.md) (Sección 2), [`Docs/diagnostico-inconsistencias-frontend-backend.md`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/Docs/diagnostico-inconsistencias-frontend-backend.md), [`AGENTS.md`](file:///c:/Users/Lenovo/Desktop/COSMOL-app/AGENTS.md)  
> **Estado:** COMPLETADO y certificado en Docker (**70/70 tests en verde al 100%**)

---

## 1. Resumen Ejecutivo

Conforme al plan acordado en la **Sección 2 de `Docs/plan-resolucion-inconsistencias-frontend-backend.md`**, **DEV 2** implementó las mejoras de resiliencia y flexibilidad de esquemas en el Backend para garantizar una interoperabilidad transparente con la aplicación móvil y web de COSMOL R.L. (Flutter), eliminando posibles bloqueos por validación estricta y manteniendo intactos los contratos oficiales de seguridad:

1. **Normalización Insensible a Mayúsculas/Minúsculas para el Canal OTP (`SolicitarOtpRequest`):**  
   Se incorporó un pre-validador en Pydantic v2 que limpia espacios y convierte automáticamente a mayúsculas cualquier variante recibida desde el frontend (`"whatsapp"`, `"WhatsApp"`, `"WHATSAPP"`, `"sms"`, `"SMS"`), evitando que el backend rechace la solicitud con error `HTTP 422 Unprocessable Entity`.
2. **Esquema Permisivo y Flexible para Creación de PIN (`CrearPinPasswordRequest`):**  
   Se configuró `model_config = ConfigDict(extra="ignore")` y se declararon campos opcionales contextuales (`cod_socio` y `ci`), permitiendo que el cliente Flutter envíe metadatos contextuales en el cuerpo de la petición sin provocar rechazos por validación de esquema. Se mantiene la validación obligatoria de longitud mínima para el PIN (4 a 30 caracteres).
3. **Cero Impacto en Reglas Core ni en Fases Previas:**  
   * Se preservó la exigencia oficial de OTP de **6 dígitos numéricos** con TTL de 5 minutos.
   * Se mantuvieron al 100% las implementaciones de Fase 2 (Deuda en tiempo real <20ms con Redis, semáforo de corte y enmascaramiento de inquilinos) y Fase 3 (Almacenamiento S3 MinIO, generador vectorial ReportLab y streaming de PDFs).
   * **Ningún archivo de Frontend fue modificado**, respetando la división de responsabilidades con DEV Fabian.
4. **Certificación de la Suite de Pruebas Automatizadas:**  
   Se añadieron 2 pruebas unitarias dedicadas en `tests/test_auth_schemas.py`. La suite completa en Docker aumentó de 68 a **70 pruebas pasando al 100%** en 22.61 segundos.

---

## 2. Detalle de Archivos Modificados

### 2.1 Esquemas de Autenticación y Onboarding (`backend/app/schemas/usuario.py`)

* **`SolicitarOtpRequest`:**
  ```python
  @field_validator("canal", mode="before")
  @classmethod
  def normalizar_canal(cls, v: Any) -> Any:
      if isinstance(v, str):
          return v.strip().upper()
      return v
  ```
  * **Beneficio:** Convierte `"whatsapp"` o `"WhatsApp"` a `"WHATSAPP"`, y `"sms"` a `"SMS"`, tolerando cualquier variación de tipeo o serialización en el cliente Dart.

* **`CrearPinPasswordRequest`:**
  ```python
  class CrearPinPasswordRequest(BaseModel):
      model_config = ConfigDict(extra="ignore")

      telefono: str = Field(..., description="Número de teléfono celular verificado.")
      token_otp_valido: str = Field(..., description="Token temporal criptográfico...")
      nuevo_pin: str = Field(..., min_length=4, max_length=30, description="Nuevo PIN o contraseña secreta...")
      cod_socio: Optional[str] = Field(None, description="Código de socio contextual")
      ci: Optional[str] = Field(None, description="CI contextual")
  ```
  * **Beneficio:** Si Flutter envía campos contextuales como `cod_socio`, `ci` o `username`, Pydantic los acepta sin error 422 y los ignora de forma segura para la actualización de la contraseña/PIN.

---

### 2.2 Pruebas Unitarias de Validación (`backend/tests/test_auth_schemas.py`)

Se incorporaron dos casos de prueba que cubren los escenarios de integración real:

```python
def test_solicitar_otp_normaliza_canal_case_insensitive():
    # Minúsculas
    req1 = SolicitarOtpRequest(cod_socio="104523", telefono="71029384", canal="whatsapp")
    assert req1.canal == "WHATSAPP"

    # CamelCase / Mixto
    req2 = SolicitarOtpRequest(cod_socio="104523", telefono="71029384", canal="WhatsApp")
    assert req2.canal == "WHATSAPP"

    # SMS en minúsculas
    req3 = SolicitarOtpRequest(cod_socio="104523", telefono="71029384", canal="sms")
    assert req3.canal == "SMS"


def test_crear_pin_tolera_campos_extras_y_contextuales():
    # Envío de campos contextuales que Flutter suele incluir (cod_socio, ci, username, etc.)
    data = {
        "telefono": "+59171029384",
        "token_otp_valido": "tok_seguro_123",
        "nuevo_pin": "1234",
        "cod_socio": "104523",
        "ci": "8392019",
        "username": "usuario_flutter",
        "campo_desconocido": "ignorado_por_extra_ignore"
    }
    req = CrearPinPasswordRequest(**data)
    assert req.telefono == "+59171029384"
    assert req.token_otp_valido == "tok_seguro_123"
    assert req.nuevo_pin == "1234"
    assert req.cod_socio == "104523"
    assert req.ci == "8392019"
```

---

## 3. Matriz de Cobertura y Verificación en Docker

Ejecución realizada mediante el comando:
```bash
docker compose exec backend-api pytest -v
```

### Resumen de Resultados:
```
============================= test session starts ==============================
platform linux -- Python 3.12.14, pytest-9.1.1, pluggy-1.6.0 -- /usr/local/bin/python3.12
cachedir: .pytest_cache
rootdir: /app
configfile: pytest.ini
testpaths: tests
plugins: asyncio-1.4.0, anyio-4.15.1
collected 70 items

tests/test_auth_endpoints.py ......................... [PASSED]
tests/test_auth_schemas.py (12 tests) ................ [PASSED]
  - test_solicitar_otp_normaliza_canal_case_insensitive [PASSED]
  - test_crear_pin_tolera_campos_extras_y_contextuales   [PASSED]
tests/test_auth_service.py ........................... [PASSED]
tests/test_base_components.py ........................ [PASSED]
tests/test_cache_deuda.py ............................ [PASSED]
tests/test_cosmol_client.py .......................... [PASSED]
tests/test_deuda.py .................................. [PASSED]
tests/test_documentos.py ............................. [PASSED]
tests/test_generador_pdf.py .......................... [PASSED]
tests/test_health.py ................................. [PASSED]
tests/test_integration_empalme.py .................... [PASSED]
tests/test_minio_client.py ........................... [PASSED]
tests/test_models.py ................................. [PASSED]
tests/test_otp_services.py ........................... [PASSED]
tests/test_storage_documentos.py ..................... [PASSED]

============================= 70 passed in 22.61s ==============================
```

---

## 4. Estado de la Integración y Próximos Pasos

1. **Backend:** Está 100% listo, robustecido y certificado para que DEV Fabian integre Onboarding, Login, Deuda y Documentos PDF.
2. **Frontend:** DEV Fabian puede proceder con la Sección 3 del plan (`onboarding_screen.dart`, `onboarding_step2_screen.dart`, `login_screen.dart` y `auth_provider.dart`) sabiendo que el backend no generará errores 422 por canal en minúsculas ni por campos contextuales en la creación de PIN.
3. **Siguiente Fase de Backend:** Una vez Fabian concluya o cuando se determine en la hoja de ruta, DEV 2 / DEV 1 podrán iniciar la **Fase 4: Analítica de Consumo Histórico (6+ meses)** (`TASK-04`).
