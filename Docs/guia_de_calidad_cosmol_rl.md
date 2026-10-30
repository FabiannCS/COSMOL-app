# Guía de Calidad, Integridad y Optimización — COSMOL RL App

> **Documento Operativo de Calidad de Software para la Fase de Entrega**  
> Adaptado de la norma internacional ISO/IEC 25010 al contexto específico de la plataforma web y móvil de **COSMOL RL** (Flutter + FastAPI + PostgreSQL + Redis + MinIO + Caddy).

---

## 1. Funcionalidad (Adecuación Funcional)

El sistema debe satisfacer todas las necesidades del socio y usuario de COSMOL RL sin inconsistencias lógicas en cobros, consumos ni visualización de contratos.

### Implementación en COSMOL RL
- **Partición de Casos de Uso:** Separar estrictamente la lógica de negocio en casos de uso de responsabilidad única en Flutter (`features/{feature}/domain/usecases/`) y servicios en FastAPI (`app/services/`).
- **Validación de Roles y Permisos (Titular vs. Inquilino):**
  - **Modo Titular:** Si el socio vincula con `cod_socio` + CI válida, se habilita el acceso total (descarga de facturas legales, historial completo, avisos de corte).
  - **Modo Inquilino/Consulta:** Si solo cuenta con `cod_socio`, la API oculta/enmascara los datos sensibles del titular (CI parcial, nombre confidencial) y restringe la vista únicamente a saldo adeudado y generación de QR de pago.
- **Manejo Exhaustivo de Estados de UI:**
  - Estados reactivos en Riverpod (`AsyncValue`): carga (`loading`), éxito con datos (`data`), error amigable (`error`), y listas vacías (`empty state`).

### Criterios de Evaluación y Pruebas
- [ ] **Happy Path Onboarding:** Validación correcta de `cod_socio` + CI, recepción y validación de OTP (WhatsApp/SMS) y creación de PIN de seguridad.
- [ ] **Manejo de Deuda Cero vs. Deuda Vencida:** Comprobar que los suministros al día muestren estado "Al día" y los suministros con mora destaquen la fecha de vencimiento en **rojo**.
- [ ] **Casos Borde:** Ingreso de códigos de socio inexistentes, pérdida de conectividad durante la generación del QR, o ingreso de PIN incorrecto.

---

## 2. Seguridad (Confidencialidad, Integridad y Cero Confianza)

Protección de datos personales de los socios, prevención de ataques de fuerza bruta y garantía de que la plataforma no procese directamente transacciones financieras (cero alcance PCI-DSS).

### Implementación en COSMOL RL
- **Autenticación Fuerte & Revocación de CI como Clave:**
  - La cédula de identidad queda permanentemente descartada como credencial de acceso tras el onboarding.
  - Almacenamiento de contraseñas/PIN con hash **bcrypt** en PostgreSQL.
- **Protección contra Fuerza Bruta (`slowapi` + Redis):**
  - Bloqueo progresivo por IP y cuenta tras 3 intentos fallidos consecutivos (1 min → 5 min → 15 min → 30 min → 1 hora), desbloqueable inmediatamente completando verificación OTP al celular.
- **Almacenamiento Local Seguro (Flutter):**
  - `flutter_secure_storage` con respaldo de hardware (Android KeyStore y iOS KeyChain) para Access Tokens (~15 min) y Refresh Tokens (~7 días). Nunca en SharedPreferences o localStorage no cifrado.
- **Cero Alcance PCI-DSS:**
  - COSMOL nunca almacena ni solicita números de tarjetas de débito/crédito; el pago se delega a redirección bancaria oficial y QR interbancario estándar generado con `qr_flutter`.
- **Sanitización y Validación en Backend:**
  - Modelos estrictos con **Pydantic v2** que rechazan inyecciones SQL, XSS y tipos de datos incompatibles antes de tocar la base de datos o el sistema legado.

### Criterios de Evaluación y Pruebas
- [ ] **Prueba de Intrusión a Endpoints Protegidos:** Verificar que endpoints como `/api/v1/deuda` o `/api/v1/documentos` retornen `401 Unauthorized` si no viaja el header `Authorization: Bearer <token>` o si el token expiró.
- [ ] **Verificación de Enmascaramiento:** Confirmar que un usuario en modo Consulta no reciba en el JSON del backend el número de carnet o teléfono del titular.
- [ ] **Simulación de 3 Intentos Fallidos:** Probar que el 4to intento de login sea bloqueado por el backend con HTTP `429 Too Many Requests`.

---

## 3. Rendimiento y Eficiencia

Tiempos de respuesta inmediatos (<20 ms en consultas cacheadas), bajo consumo de batería y datos móviles, y mínima carga sobre el sistema legado de COSMOL.

### Implementación en COSMOL RL
- **Capa de Caché Estratégica (Redis 7):**
  - Almacenamiento en caché de la consulta de deuda consolidada con TTL corto/medio, permitiendo lecturas ultrarrápidas (<20 ms) e impidiendo que miles de usuarios concurrentes saturen el sistema legado.
- **Consultas Asíncronas e Índices en PostgreSQL 16:**
  - Conexión no bloqueante vía `asyncpg` + `SQLAlchemy 2.0 async`.
  - Índices B-Tree en columnas de búsqueda frecuente: `usuario.celular`, `suministro.cod_socio`, `dispositivo.device_id`.
- **Renderizado Eficiente en Flutter:**
  - Uso de `ref.watch(provider.select(...))` en Riverpod para evitar reconstrucciones de pantalla innecesarias al cambiar propiedades no visibles.
  - Uso de `ListView.builder` para historiales de consumo y facturas con reciclaje de vistas.
- **Optimización de Assets y Fuentes:**
  - SVGs para íconos vectoriales y compresión de imágenes estáticas.

### Criterios de Evaluación y Pruebas
- [ ] **Medición de Latencia en Swagger / Postman:** Verificar que las rutas cacheadas en Redis respondan en menos de 50 ms.
- [ ] **Rendimiento de Gráficos de Consumo (`fl_chart`):** Comprobar que la animación del histórico de los últimos 6 meses corra a 60 fps estables en emuladores y dispositivos físicos sin tirones (jank).

---

## 4. Mantenibilidad

Facilidad para que cualquier miembro del equipo entienda, audite, corrija o agregue nuevas funcionalidades sin provocar efectos secundarios.

### Implementación en COSMOL RL
- **Clean Architecture en Flutter:**
  - Separación estricta entre `core/` (configuración, red, utilidades) y `features/{modulo}/` con sus capas `data`, `domain` y `presentation`.
  - Prohibido acoplar Widgets UI directamente con llamadas HTTP o modelos de base de datos.
- **Backend-For-Frontend (BFF) Desacoplado:**
  - El frontend solo consume el contrato expuesto por FastAPI (`/api/v1/*`); desconoce por completo la estructura del sistema legado de COSMOL.
- **Consistencia de Estilo y Nombres:**
  - Código y comentarios autoexplicativos en inglés para variables y funciones (`fetchPendingInvoices`, `validateOtpCode`), manteniendo términos de dominio claros (`codSocio`, `montoDeudaBs`).
- **Herramientas de Análisis Estático:**
  - `flutter analyze` en frontend sin warnings ni linter errors.
  - `ruff` o `flake8` + `black` en backend para asegurar formato PEP 8 homogéneo.

### Criterios de Evaluación y Pruebas
- [ ] **Ejecución de `flutter analyze`:** Debe concluir con `No issues found!`.
- [ ] **Revisión de Dependencias Cruzadas:** Asegurar que una feature (ej. `consumo`) no importe datasources privados de otra feature (ej. `auth`). Toda comunicación transversal pasa por el estado global o usecases.

---

## 5. Usabilidad y Experiencia de Usuario (UX/UI)

Diseño intuitivo, accesible para personas de todas las edades en Montero, con identidad visual corporativa de COSMOL RL.

### Implementación en COSMOL RL
- **Feedback Inmediato al Usuario:**
  - Spinners o esqueletos (`shimmer`) en cargas de datos.
  - Botones con estado de progreso deshabilitados durante la petición para evitar doble toque (ej. al solicitar OTP o pagar).
  - Snackbars descriptivos con colores semánticos (verde: éxito, rojo: error crítico, ámbar: advertencia).
- **Consistencia Visual y Accesibilidad:**
  - Tipografía moderna legible (Inter / Roboto) con tamaños de fuente proporcionales.
  - Alerta de vencimiento: contraste alto con rojo destacado cuando una factura está en mora.
  - Selector ágil de cuentas en el AppBar con alias claros (*"Mi Casa"*, *"Local Comercial"*).
- **Diseño Adaptativo / Responsivo:**
  - Layout adaptado tanto para pantallas compactas de celulares Android/iOS como para visualización en Flutter Web sin desbordes (`A RenderFlex overflowed`).

### Criterios de Evaluación y Pruebas
- [ ] **Prueba de Cero Overflows:** Inspeccionar en múltiples resoluciones (desde 360px de ancho hasta escritorio) asegurando ausencia de barras amarillas y negras de overflow.
- [ ] **Verificación de Teclados:** Asegurar que los formularios de celular o PIN desplieguen teclado numérico (`TextInputType.number`) y no alfanumérico.

---

## 6. Escalabilidad

Capacidad de la plataforma para absorber picos masivos de consultas (ej. días de corte o emisión de facturación mensual).

### Implementación en COSMOL RL
- **Backend Stateless (Sin Estado en Servidor):**
  - FastAPI no almacena sesiones en memoria RAM del proceso; toda la autenticación viaja firmada en JWTs criptográficos y el rate limiting se centraliza en Redis.
- **Desacoplamiento de Almacenamiento de Archivos (MinIO):**
  - Los PDFs de facturas y avisos no se guardan en la base de datos relacional ni en el disco local efímero del backend, sino en MinIO (Object Storage S3-compatible).
  - El backend entrega streams o URLs firmadas temporales para no agotar la RAM del servidor.
- **Tareas Asíncronas en Segundo Plano (`BackgroundTasks`):**
  - Los eventos de auditoría hacia la base de datos de **ChatbotReportes** se envían en segundo plano sin retrasar el tiempo de respuesta HTTP al socio.

### Criterios de Evaluación y Pruebas
- [ ] **Descarga Simultánea de Documentos:** Probar que la descarga de 5 PDFs seguidos no aumente el consumo de memoria del proceso de FastAPI.
- [ ] **Escalado Horizontal:** Verificar que se puedan levantar múltiples réplicas del contenedor `backend-api` detrás de Caddy sin romper la autenticación del usuario.

---

## 7. Fiabilidad (Confiabilidad y Resiliencia)

El software debe tolerar fallos de red, caídas del sistema legado y degradarse de manera elegante sin cerrarse inesperadamente (cero crashes).

### Implementación en COSMOL RL
- **Resiliencia y Modo Offline (Hive + Riverpod):**
  - `hive_flutter` almacena localmente en el teléfono la última consulta exitosa de saldos y suministros.
  - Si el socio abre la app sin internet o con señal inestable, la app muestra los datos cacheados con un banner informativo: *"Sin conexión. Mostrando última actualización"*.
- **Timeouts Controlados en HTTP (`httpx` y `dio`):**
  - Conexiones a servicios externos y sistema legado con timeouts explícitos (ej. `connect: 5s`, `read: 10s`) para evitar peticiones colgadas de forma infinita.
- **Manejo Centralizado de Excepciones:**
  - Middleware global de excepciones en FastAPI que captura errores no controlados y devuelve un JSON uniforme (`{ "success": false, "code": "INTERNAL_ERROR", "message": "..." }`) sin exponer trazas de código (*stack traces*) al usuario.
  - En Flutter, uso de clases `Failure` en la capa de dominio en lugar de lanzar excepciones descontroladas a la interfaz.

### Criterios de Evaluación y Pruebas
- [ ] **Prueba de Modo Avión:** Abrir la app con datos guardados, activar modo avión y verificar que la interfaz no crashee y permita ver la información previamente cargada.
- [ ] **Prueba de Caída del Sistema Legado:** Simular fallo de respuesta del sistema legado de COSMOL; el backend debe responder un error HTTP `503 Service Unavailable` controlado con mensaje amigable para el socio.

---

## 8. Portabilidad y Despliegue

Capacidad de compilar y desplegar idénticamente en cualquier entorno (desarrollo local, staging y producción en servidores de COSMOL).

### Implementación en COSMOL RL
- **Base de Código Única Flutter:**
  - El mismo código en `frontend/lib/` compila para Android (APK/AAB), iOS y Web sin bifurcaciones sucias de código (`kIsWeb` usado únicamente para adaptaciones de descarga o visor de PDF).
- **Orquestación con Docker Compose:**
  - Servicios orquestados y reproducibles: `backend-api`, `gateway-caddy`, `db-postgres`, `cache-redis` y `storage-minio`.
- **Variables de Entorno Centralizadas:**
  - Configuración mediante `.env` (puertos, credenciales, secretos JWT, endpoints de APIs externas). Ninguna IP fija o credencial cableada en el código fuente.
- **Reverse Proxy Caddy con TLS Automático:**
  - Caddy gestiona automáticamente certificados HTTPS Let's Encrypt y sirve tanto el build web de Flutter como el proxy inverso a FastAPI.

### Criterios de Evaluación y Pruebas
- [ ] **Despliegue Limpio:** Ejecutar `docker compose up -d` en un servidor limpio y verificar que todos los contenedores inicien en estado `healthy` sin intervención manual.
- [ ] **Build Exitoso de Flutter:** Verificar que `flutter build apk` y `flutter build web` se generen sin errores de librerías nativas incompatibles.

---

## Resumen de la Matriz de Calidad para Entrega

| Factor | Componente Clave COSMOL RL | Métrica de Aceptación |
|---|---|---|
| **1. Funcionalidad** | Onboarding OTP, Deuda, QR, Consumo, Multicuenta | 100% flujos Happy Path completados sin desbordes ni cálculos erróneos. |
| **2. Seguridad** | bcrypt, JWT en KeyStore, `slowapi`, Rol Titular vs Inquilino | Cero exposición de datos sensibles y bloqueo a los 3 intentos fallidos. |
| **3. Rendimiento** | Redis (<20 ms), asyncpg, `select` en Riverpod | Navegación fluida a 60 fps y latencia en backend < 100 ms promedio. |
| **4. Mantenibilidad** | Clean Architecture, BFF FastAPI, `flutter analyze` | 0 errores de análisis estático y desacoplamiento total del sistema legado. |
| **5. Usabilidad** | Identidad COSMOL, estados de mora en rojo, feedbacks | Interfaz amigable, sin overflows y con teclados contextuales. |
| **6. Escalabilidad** | Backend stateless, MinIO S3, BackgroundTasks | Soporte concurrente sin aumento desmedido de RAM ni saturación de BD. |
| **7. Fiabilidad** | Hive offline, timeouts httpx, `Failure` objects | Cero cierres inesperados de la app ante caídas de red o servidor. |
| **8. Portabilidad** | Docker Compose, Caddy TLS, Flutter multi-target | Levantamiento automatizado en producción con `.env`. |
