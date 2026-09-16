# Contexto de Proyecto — App de Socios COSMOL RL
> Documento de referencia para un agente de IA de desarrollo. Resume el problema, el alcance y las decisiones pendientes para construir la plataforma web y móvil de consulta para socios de COSMOL RL (cooperativa de agua/saneamiento, Montero, Bolivia).

> [!CAUTION]
> ### REGLA ESTRICTA DE MODIFICACIÓN Y GOBERNANZA
> **Este archivo constituye la BASE ARQUITECTÓNICA Y CONCEPTUAL DEL PROYECTO.**
> **Queda estrictamente prohibido modificar este archivo o alterar su lógica sin la confirmación y autorización expresa del desarrollador / líder técnico.** Cualquier cambio, ajuste o refactorización de requerimientos debe ser consultado previamente y aprobado por el desarrollador antes de editar este documento.

## 1. Resumen del proyecto

| **Nombre** | Plataforma Web y Móvil para Asociados de COSMOL RL |
| **Cliente** | COSMOL RL — cooperativa de servicios públicos, Montero, Bolivia |
| **Usuario final** | Socios de la cooperativa (no personal interno de COSMOL) |
| **Frontend** | Flutter (una sola base de código para app móvil y web) |
| **Backend** | **Por definir** — ver sección 7 |
| **Tipo de entregable** | App omnicanal: móvil + web, disponible 24/7 |

## 2. Problema a resolver

Hoy los socios de COSMOL dependen de canales presenciales o telefónicos para gestionar su servicio, lo que genera tres problemas concretos:

1. **Pérdida de tiempo y saturación física**: para consultar su deuda o pedir la reimpresión de un aviso, el socio debe ir a oficinas o llamar, generando filas y saturando atención al cliente.
2. **Dificultad para pagar → aumento de mora**: no existe una vía rápida para conocer la deuda ni un enlace directo de pago; el socio pospone el pago por falta de tiempo para ir al banco/cooperativa, lo que eleva la mora.
3. **Costos operativos y ambientales**: la impresión y distribución física de avisos de cobranza, de corte y facturas es un gasto continuo en papel y logística.

Contexto adicional: alta penetración de smartphones e internet en Montero — los socios ya están habituados a resolver trámites por apps 24/7. Esa es la oportunidad que la app debe capturar.

## 3. Solución propuesta

Una app omnicanal en Flutter que centraliza la información del socio y cierra el ciclo de atención al cliente conectándolo con el pago, sin que COSMOL tenga que procesar pagos directamente (solo redirige a pasarelas externas).

## 4. Alcance funcional (core del negocio)

Estas son las 5 funcionalidades principales descritas en la propuesta original. Cada una debe tratarse como un módulo independiente del backend, consumido por Flutter vía API.

### 4.1 Autenticación segura y gestión de identidad (Decidido)
- **Modelo de Identidad:** Separación entre el *Usuario Digital* (la persona que usa la app, identificada por su teléfono celular verificado) y el *Código de Socio* (el contrato/suministro en el sistema comercial de COSMOL).
- **Flujo de Primer Acceso / Onboarding (Saneamiento de base de datos):**
  - Dado que la base de datos de COSMOL no cuenta con números telefónicos consolidados, el socio ingresa por primera vez con su **Código de Socio + CI** (respetando el requerimiento oficial de COSMOL).
  - La API valida la coincidencia con el sistema legado y solicita de inmediato al socio asociar su **número de teléfono celular**.
  - **Canal OTP Dual a elección del usuario:** El socio selecciona si desea recibir el código de seguridad de 6 dígitos (TTL 5 min) vía **WhatsApp Cloud API** (canal prioritario/económico, reutilizando la WABA y línea del Chatbot existente de COSMOL) o vía **SMS tradicional** (canal alternativo para falta de conexión a WhatsApp).
  - Tras verificar el OTP, el socio crea una **Contraseña o PIN personal** seguro. A partir de ese momento, la CI queda invalidada como contraseña, eliminando la vulnerabilidad de que un tercero con una factura física en mano pueda vulnerar la privacidad del socio.
- **Login Diario Habitual:**
  - Acceso mediante **Código de Socio + Contraseña/PIN personal**.
  - Soporte de autenticación biométrica en Flutter (`local_auth`: Huella dactilar o Face ID) para ingresar de inmediato sin tipear credenciales ni incurrir en costos de mensajería.
- **Recuperación de Contraseña y Cambio de Dispositivo:**
  - Flujo de recuperación mediante OTP (WhatsApp o SMS a elección) enviado al celular registrado.
  - Al iniciar sesión en un nuevo dispositivo (nuevo Device ID verificado por OTP), se revoca la sesión previa en el equipo anterior (modelo de sesión única estilo WhatsApp).
- **Bloqueo por intentos fallidos:**
  - Rate limiting por IP en el backend (FastAPI + `slowapi`) para mitigar ataques de fuerza bruta / credential stuffing.
  - Bloqueo progresivo por cuenta tras **3 intentos fallidos consecutivos** (1 min → 5 min → 15 min → 30 min → 1 hora). Desbloqueo inmediato completando la verificación OTP por celular.
  - Registro de auditoría de cada intento fallido (cuenta, IP, timestamp) hacia la base de datos de `ChatbotReportes`.

### 4.2 Módulo de consulta de deuda (dashboard principal)
- Visualización clara de: saldo pendiente, monto exacto a pagar, fechas de vencimiento.
- Debe ser la pantalla de aterrizaje post-login (es el "core" que resuelve el problema #1).

### 4.3 Redirección a plataformas de pago
- Botón "Pagar Ahora" que redirige de forma segura a pasarelas externas: banca móvil, pago con tarjeta, o generación de códigos QR interbancarios.
- COSMOL **no procesa pagos dentro de la app** — solo redirige. Esto evita a COSMOL el alcance de cumplimiento PCI-DSS, pero exige definir cómo se confirma el pago y se actualiza el saldo (ver sección 7).

### 4.4 Gestión y descarga de facturas y avisos
- Repositorio digital con historial descargable en PDF: facturas con valor legal, avisos de cobranza, avisos de corte.

### 4.5 Historial de consumo analítico
- Gráficos de barras o líneas con consumo mensual, para que el socio compare sus hábitos de consumo.

### 4.6 Gestión Multicuenta (Múltiples Códigos de Socio bajo un mismo Perfil)
- Un único usuario digital (1 número de celular verificado) puede vincular múltiples códigos de socio (`cod_socio`) para administrar diversos suministros (casa, alquiler, negocio o familiares) sin necesidad de cerrar sesión.
- **Roles y Niveles de Acceso por Suministro:**
  - **Modo Titular:** Requiere validación de CI o número de medidor del titular. Permite ver histórico completo, gráficos, descargas de facturas oficiales con valor legal (PDF) y avisos de corte.
  - **Modo Consulta y Pago (Inquilino / Pagador externo):** Solo requiere el `cod_socio`. Permite consultar el saldo adeudado, fecha de vencimiento y realizar el pago con QR. **Enmascara y oculta datos sensibles del titular** (CI, histórico confidencial, reclamos) protegiendo la confidencialidad.
- **Experiencia en Flutter:** Selector desplegable / carrusel superior en el Dashboard que permite alternar de suministro al instante y asignar alias personalizados (*"Mi Casa"*, *"Alquiler Bolívar"*).

## 5. Beneficios esperados (criterio de éxito del proyecto)

**Para COSMOL:**
- Aumento de recaudación (menos mora, al facilitar el pago digital).
- Ahorro de costos (menos papel y logística de distribución de avisos).
- Descongestionamiento de oficinas (menos filas por reclamos/consultas menores).
- Modernización de la imagen institucional.

**Para el socio:**
- Comodidad: acceso 24/7 desde el celular.
- Transparencia: control total sobre histórico de consumo y cobros.
- Ahorro de tiempo: elimina traslados y esperas innecesarias.

Cualquier decisión de diseño o priorización debe evaluarse contra esta lista: si una funcionalidad no mueve alguno de estos indicadores, no es prioritaria para el MVP.

## 6. Fuera de alcance (explícito, para evitar scope creep)

- Procesamiento de pagos dentro de la app (solo redirección a pasarelas externas).
- Creación/gestión de reclamos técnicos — COSMOL ya tiene un canal separado para esto (chatbot de WhatsApp con backend propio); no duplicar ese flujo aquí salvo que se decida integrarlo explícitamente.
- Panel administrativo interno para personal de COSMOL — no se construye aquí. El backend de esta app solo **envía** eventos de auditoría a la base de datos del proyecto **ChatbotReportes**; la visualización de reportes/administración es responsabilidad exclusiva de ese otro proyecto.

## 7. Backend: decisiones pendientes

La propuesta deja el backend abierto. Puntos que el agente debe resolver o escalar antes de avanzar en implementación:

1. **Stack y lenguaje del backend**: sin definir. Debe exponerse como API REST documentada (OpenAPI/Swagger) para que Flutter la consuma de forma desacoplada.
2. **Fuente de datos de deuda/consumo**: ¿de dónde vienen el saldo, las fechas de vencimiento y el historial de consumo? Debe conectarse al sistema de facturación/medición existente de COSMOL. Si esa fuente es una base de datos legada (p. ej. Informix), la API actúa como capa intermedia — no se accede directamente desde Flutter.
3. **Confirmación de pago y actualización de saldo**: como el pago ocurre fuera de la app, se necesita un mecanismo (webhook de la pasarela, conciliación por lote, o consulta periódica) para que el saldo mostrado se actualice tras un pago exitoso. Este punto no está resuelto en la propuesta y es crítico para que el dashboard sea confiable.
4. **Generación/almacenamiento de PDFs**: ¿las facturas y avisos ya existen como PDF en algún sistema, o hay que generarlos on-demand? Define si el backend solo sirve archivos existentes o necesita un motor de generación de PDF.
5. **Autenticación (Definido)**: JWT (access token ~15 min + refresh token ~7 días) sobre HTTPS. Modelo de activación híbrido resuelto: primer ingreso con `cod_socio + CI`, captura y verificación de celular mediante OTP dual seleccionable (WhatsApp Cloud API reutilizando WABA del Chatbot / SMS), creación obligatoria de Contraseña/PIN personal para blindar la confidencialidad, y revocación de sesión por dispositivo (estilo WhatsApp). Política de bloqueo progresivo tras 3 intentos fallidos.

## 8. Notas y recomendaciones para el agente de IA

- **Prioriza un contrato de API estable primero.** Con el backend indefinido, el trabajo de mayor apalancamiento es diseñar y documentar los endpoints (auth, saldo, facturas, consumo) para que el desarrollo Flutter no quede bloqueado esperando decisiones de backend.
- **Diseña un MVP en dos fases** en lugar de construir las 5 funcionalidades a la vez:
  - Fase 1 (lectura): autenticación + consulta de deuda + descarga de facturas/avisos. Ya resuelve el problema de "socio saturando oficinas para consultas simples".
  - Fase 2 (cierre del ciclo): redirección a pago + historial de consumo con gráficas.
- **Considera modo offline/baja conectividad** en Flutter (caché local del último saldo conocido) — Montero puede tener conectividad variable y el valor central de la app (ver el saldo) no debería depender de estar siempre online.
- **Evalúa notificaciones push** como extensión natural del objetivo "reducir mora": recordatorios de vencimiento próximo o aviso de corte inminente atacan directamente ese indicador, aunque no están en el alcance original.
- **Seguridad de datos personales**: el login usa CI o número de medidor, que son datos sensibles. Vale la pena revisar si conviene desacoplar el identificador de login de esos datos (p. ej. usar solo código de socio + verificación adicional en el primer registro).
- **Actualizado**: este proyecto sigue siendo independiente en cuanto a codebase y base de datos propia — **no tendrá vista de administración propia**. Sin embargo, sí existe un punto de integración de un solo sentido: el backend envía eventos de auditoría (login, pago iniciado, descarga de factura) hacia la base de datos del proyecto **ChatbotReportes**, que ya centraliza reportes y datos de otros módulos de COSMOL. La app de socios es únicamente emisora de esos datos, nunca consumidora ni administradora de esa base — el panel de reportes vive por completo en ChatbotReportes.

## 10. Requerimientos funcionales oficiales

> Fuente: documento **“Requerimientos Funcionales”** entregado para el proyecto. Esta sección conserva el contenido funcional y los criterios de aceptación tal como fueron definidos en el documento fuente.

### 10.1 Autenticación
**Necesidad del socio:** Iniciar sesión de forma segura usando **Código de Socio + CI como contraseña**.

**Criterios de aceptación:**
- El sistema debe validar los datos de acceso.
- Debe permitir recuperar la contraseña.
- Debe bloquear el acceso tras **3 intentos fallidos**.

### 10.2 Dashboard de Deuda
**Necesidad del socio:** Visualizar de manera clara:
- Saldo pendiente.
- Monto exacto a pagar.
- Fechas de vencimiento.

**Criterios de aceptación:**
- El monto debe mostrarse en moneda local (**Bs**).
- La fecha de vencimiento debe cambiar a color rojo si ya expiró.

### 10.3 Redirección a Pagos
**Necesidad del socio:** Usar botones de **“Pagar Ahora”** que redirijan de forma segura a:
- Pasarelas externas.
- Banca móvil.
- Generación de códigos QR.

**Criterios de aceptación:**
- El botón debe abrir la aplicación bancaria del usuario o generar un **QR interbancario válido y escaneable**.

### 10.4 Gestión de Documentos
**Necesidad del socio:** Contar con un repositorio digital para consultar su historial y descargar:
- Facturas.
- Avisos de cobranza.
- Avisos de corte.

Los documentos deben estar disponibles en **PDF**.

**Criterios de aceptación:**
- La aplicación debe generar o recuperar un PDF con valor legal.
- El archivo debe poder guardarse en el dispositivo local.

### 10.5 Historial de Consumo
**Necesidad del socio:** Visualizar gráficos de barras o líneas con el consumo mensual para evaluar sus hábitos.

**Criterios de aceptación:**
- El gráfico debe mostrar datos precisos de al menos los últimos **6 meses**.
- Los ejes deben ser claros: **meses vs. volumen consumido**.

## 11. Reconciliación de decisiones y puntos abiertos (Actualizado y Resuelto)

Los puntos de discrepancia identificados entre el contexto inicial y el documento oficial de requerimientos han sido **reconciliados y formalizados**:

| Tema | Contexto previo | Requerimientos funcionales | Decisión Final Aprobada | Estado |
|---|---|---|---|---|
| **Credencial de Acceso** | Código de Socio + contraseña | Código de Socio + CI como contraseña | **Flujo Híbrido de 2 Fases:** El primer acceso se realiza con `cod_socio + CI` para validar contra el sistema legado de COSMOL; inmediatamente se solicita vincular el número de celular con OTP y se exige crear una **Contraseña/PIN personal** para blindar la cuenta ante terceros con facturas impresas. En el día a día se usa `cod_socio + Contraseña/PIN` o biometría. | **Resuelto** |
| **Intentos fallidos y bloqueo** | Bloqueo progresivo desde intento 5 | Bloqueo tras 3 intentos | **Bloqueo progresivo desde el intento 3:** 3 intentos fallidos bloquean la cuenta por 1 min → 5 min → 15 min → 30 min → 1 hora. Rate limiting por IP en backend. Desbloqueo inmediato completando validación OTP por celular. | **Resuelto** |
| **Recuperación de contraseña y OTP** | Canal alterno verificado (celular/OTP, posible WhatsApp/n8n) | Debe permitir recuperar contraseña | **Canal OTP Dual a Elección:** El socio elige entre **WhatsApp Cloud API** (usando la WABA y línea oficial ya operada en el Chatbot de COSMOL) o **SMS tradicional** como alternativa. Recuperación mediante código de 6 dígitos (TTL 5 min). | **Resuelto** |
| **Gestión Multicuenta** | Consulta exclusiva de un solo socio | No especificado | **Arquitectura Multicuenta:** 1 Usuario Digital = N Códigos de Socio enlazados, con diferenciación de roles (*Titular* con acceso a facturas oficiales vs *Inquilino/Pago* con datos confidenciales ocultos). | **Resuelto** |

## 12. Stack recomendado: Flutter de desarrollo a producción

### 12.1 Aplicación cliente
- **Flutter + Dart**: aplicación principal para Android, iOS y web desde una base de código compartida. Flutter soporta estos destinos y ofrece compilación optimizada para producción; para web se puede generar una build de release y desplegarla en un hosting web. 
- **Arquitectura por capas**: separar UI y Data Layer, con responsabilidades claras y dependencias controladas. La guía oficial de arquitectura de Flutter recomienda separación de responsabilidades y una estructura mantenible. 
- **State management**: Riverpod o Bloc/Cubit. Elegir **uno** y mantenerlo consistente en todo el proyecto.
- **Routing**: go_router.
- **HTTP/API**: Dio.
- **Modelos/serialización**: freezed + json_serializable.
- **Almacenamiento local**: secure storage para tokens y una base/caché local para el último estado consultado.
- **Gráficos**: una librería Flutter de charts para el historial de consumo.
- **Deep links / enlaces de pago**: soporte para abrir URLs y aplicaciones externas de banca/pago.
- **Entornos**: development / staging / production mediante flavors/configuración por entorno.

### 12.2 Backend
El backend debe ser una API independiente de Flutter.

**Recomendación final: FastAPI, no Django + DRF.** El borrador inicial de esta sección proponía Django+DRF; se reemplaza por lo siguiente porque encaja mejor con los dos requisitos que definen este proyecto: (1) esta app **no tiene vista de administración propia** — la razón de ser de Django (su admin panel y ORM orientado a CRUD) no aplica aquí, ese rol ya lo cumple ChatbotReportes; y (2) el objetivo explícito es que **cada vista responda rápido** consultando un sistema legado externo (COSMOL) — eso exige I/O asíncrono no bloqueante, que es nativo en FastAPI (ASGI) y requiere trabajo adicional en Django.

- **FastAPI (Python 3.12+)** como framework — actúa como BFF (Backend-for-Frontend): desacopla a Flutter de la API interna de COSMOL y de la base de datos de ChatbotReportes.
- **uvicorn[standard]** como servidor ASGI, con workers concurrentes en el contenedor Docker.
- **httpx** (cliente async, con connection pooling) para consultar la API interna/legada de COSMOL sin bloquear el event loop.
- **pydantic v2** para validación de entrada/salida (núcleo en Rust, más rápido que Django REST's serializers para este volumen de tráfico).
- **PostgreSQL** como base de datos propia (credenciales, estado de cuentas, auditoría local, tokens de dispositivos FCM), con **asyncpg + SQLAlchemy (modo async)** como driver — conexión no bloqueante.
- **alembic** para migraciones.
- **Redis** con doble rol: (a) caché de respuestas de deuda/historial con TTL corto (p. ej. 10 min) para que una consulta repetida responda en <20 ms en vez de volver a golpear el sistema legado, y (b) contador de intentos fallidos + rate limiting por IP (vía **slowapi**).
- **pyjwt + passlib[bcrypt]** para emitir JWT (access/refresh) y hashear credenciales de forma segura.
- **JWT** con access token de vida corta (p. ej. 15 min) + refresh token (p. ej. 7 días).
- **OpenAPI/Swagger** — generado automáticamente por FastAPI, sin trabajo manual adicional.
- **Despacho de auditoría a ChatbotReportes**: usar `BackgroundTasks` de FastAPI para no demorar la respuesta al socio al escribir el evento en la base de ChatbotReportes. Advertencia: `BackgroundTasks` vive en el mismo proceso y **no persiste ni reintenta** si el proceso muere a mitad de la tarea — aceptable para un log de auditoría de baja criticidad, pero si ese registro debe ser confiable al 100% (por ejemplo con fines de cobranza legal), conviene sustituirlo por una cola durable (Redis Streams o Celery+Redis) que sí reintente ante fallos.

**Importante:** la app no debe conectarse directamente a la base de datos o al sistema legado de COSMOL. El backend debe actuar como capa de integración y aplicar autenticación, autorización, validación, auditoría y transformación de datos.

### 12.3 Integración con sistemas existentes de COSMOL
Debe definirse un **Integration Layer** entre la API nueva y las fuentes existentes de COSMOL.

Responsabilidades:
- Consultar saldo y vencimientos.
- Obtener historial de consumo.
- Obtener o generar facturas/avisos.
- Registrar o consultar el estado de pagos externos.
- Normalizar datos del sistema legado al formato de la API pública.

Si COSMOL utiliza una base de datos legada, la aplicación móvil no debe conocer ni depender de su esquema interno.

**Segundo punto de integración — ChatbotReportes (solo escritura):** además de leer del sistema COSMOL, el backend **escribe** eventos de auditoría hacia la base de datos del proyecto ChatbotReportes (login, pago iniciado, descarga de factura). Es una integración de un solo sentido: esta app nunca lee ni administra esa base, solo despacha eventos. No confundir con la fuente de datos de COSMOL (que es de solo lectura para deuda/consumo/facturas).

### 12.4 Pagos externos
La app **no procesa directamente tarjetas ni pagos** dentro de Flutter.

Flujo recomendado:
1. Flutter consulta la deuda.
2. El socio pulsa **Pagar Ahora**.
3. Backend genera/obtiene la operación de pago.
4. Usuario es enviado a la plataforma bancaria/pasarela/QR.
5. La plataforma externa confirma el resultado.
6. Backend recibe un **webhook** o ejecuta conciliación.
7. El saldo se actualiza.
8. Flutter refresca el dashboard.

Este flujo es necesario para que un pago realizado fuera de la app termine reflejándose correctamente en el saldo del socio.

### 12.5 Notificaciones
- **Firebase Cloud Messaging (FCM)** para notificaciones push en Flutter.
- Casos de uso previstos:
  - Recordatorio de vencimiento.
  - Confirmación o actualización de pago.
  - Aviso de corte.
  - Comunicaciones importantes de COSMOL.

FCM dispone de integración oficial para Flutter y contempla Android, iOS y web, con requisitos específicos por plataforma. 

### 12.6 Seguridad
- HTTPS obligatorio en producción.
- JWT con refresh token y expiraciones controladas.
- Rate limiting.
- Bloqueo por intentos fallidos según la política que finalmente apruebe COSMOL.
- Registro de auditoría de accesos y eventos sensibles.
- Protección de secretos mediante variables de entorno/secret manager.
- No almacenar CI ni contraseñas en texto plano en Flutter.
- Cifrado/almacenamiento seguro de credenciales locales.
- Validación de entradas tanto en Flutter como en backend.
- Revisar la aplicación con **OWASP MASVS**, estándar de referencia para seguridad de aplicaciones móviles. 

### 12.7 Contenedores y despliegue (Docker y orquestación de servicios)

Para garantizar consistencia entre entornos de desarrollo, pruebas y producción, los servicios centrales del backend y su infraestructura auxiliar se desplegarán y gestionarán mediante **Docker** y **Docker Compose**.

#### 12.7.1 Servicios empaquetados en Docker
El entorno de servicios se compone de los siguientes contenedores independientes:

1. **`backend-api` (FastAPI / Uvicorn)**:
   - Contenedor con Python 3.12+ que ejecuta la API REST (BFF) con ASGI `uvicorn[standard]`.
   - Contiene la lógica de negocio, validación Pydantic v2, autenticación JWT, conexión a COSMOL legado y orquestación de servicios.
2. **`db-postgres` (PostgreSQL 16+)**:
   - Base de datos relacional propia del proyecto (credenciales, metadatos de socios, bloqueos, tokens FCM y auditoría local).
   - Gestionada con migraciones de `alembic` y almacenamiento persistente mediante volúmenes Docker (`postgres_data`).
3. **`cache-redis` (Redis 7+)**:
   - Almacén en memoria para:
     - Caché de respuestas de consulta de deuda e historial (<20 ms).
     - Rate limiting por IP y control de fuerza bruta vía `slowapi`.
     - Contador de intentos fallidos para la política de bloqueo progresivo.
   - Persistencia configurada con snapshots RDB / AOF montados en volumen (`redis_data`).
4. **`storage-minio` (MinIO S3-Compatible)**:
   - Object Storage para repositorios de documentos PDF (facturas, avisos de cobranza y corte).
   - Evita saturar PostgreSQL con blobs binarios. Volumen persistente (`minio_data`).
5. **`proxy-nginx` (Nginx Reverse Proxy / Gateway)**:
   - Punto único de entrada exterior (puertos públicos 80 y 443).
   - Terminación SSL/TLS (certificados Let's Encrypt / certificados gestionados).
   - Enrutamiento inverso (Reverse Proxy) hacia `backend-api` para endpoints `/api/*`.
   - Servido de archivos estáticos para la versión **Flutter Web**.
   - Reglas de cabeceras de seguridad, CORS estricto y compresión gzip/brotli.

#### 12.7.2 Modelo de red y topología de comunicación

Los servicios se comunican bajo una arquitectura segmentada y de mínimo privilegio:

```
                                  [ INTERNET ]
                                       │
                    ┌──────────────────┴──────────────────┐
                    │      HTTPS (443) / HTTP (80)        │
                    ▼                                     ▼
        [ App Móvil Flutter ]                     [ Navegador Web ]
      (Android / iOS vía API)                    (Build Flutter Web)
                    │                                     │
                    └──────────────────┬──────────────────┘
                                       │
                                       ▼
                       ╔═══════════════════════════════════╗
                       ║        proxy-nginx (Docker)       ║
                       ║   - Terminación SSL / Headers     ║
                       ║   - Sirve estáticos Flutter Web   ║
                       ╚═════════════════╤═════════════════╝
                                         │ Proxy Pass interno (HTTP :8000)
    ╔════════════════════════════════════╪════════════════════════════════════╗
    ║ RED INTERNA DOCKER (`cosmol_net` - aislada de internet directo)          ║
    ║                                    ▼                                     ║
    ║                         ╔═════════════════════╗                          ║
    ║                         ║ backend-api (FastAPI║                          ║
    ║                         ║   Puerto 8000)      ║                          ║
    ║                         ╚═══╤═════════╤═════╤═╝                          ║
    ║      SQL Async (:5432)      │         │     │     S3 API (:9000)         ║
    ║   ┌─────────────────────────┘         │     └────────────────────────┐   ║
    ║   ▼                                   ▼                              ▼   ║
    ║ ╔═══════════════╗           ╔═══════════════╗              ╔═══════════╗ ║
    ║ ║  db-postgres  ║           ║  cache-redis  ║              ║storage-   ║ ║
    ║ ║  (Port 5432)  ║           ║  (Port 6379)  ║              ║minio:9000 ║ ║
    ║ ╚═══════════════╝           ╚═══════════════╝              ╚═══════════╝ ║
    ╚════════════════════════════════════╪════════════════════════════════════╝
                                         │
                    Salida saliente (Egress) desde backend-api:
                    ├────► Sistema Legado COSMOL (API/BD Lectura)
                    ├────► BD ChatbotReportes (Solo escritura auditoría)
                    └────► Pasarelas de Pago / Banca Externa (Webhooks/Redirects)
```

1. **Red interna privada de Docker (`cosmol_net`)**:
   - Los contenedores `db-postgres`, `cache-redis` y `storage-minio` **NO exponen puertos a internet** en producción (no tienen mapeo de host directo público).
   - Se comunican exclusivamente a través del DNS interno de Docker por el nombre del servicio:
     - Conexión BD: `postgresql+asyncpg://user:pass@db-postgres:5432/cosmol_db`
     - Conexión Caché: `redis://cache-redis:6379/0`
     - Conexión Storage S3: `http://storage-minio:9000` con credenciales de servicio (boto3).
   - Solo `proxy-nginx` expone los puertos estándar `80` y `443` hacia el exterior.

2. **Comunicación Cliente (Flutter) ↔ Infraestructura Backend**:
   - El cliente Flutter (móvil o web) **nunca tiene acceso directo** a PostgreSQL, Redis ni MinIO.
   - Toda interacción pasa por `proxy-nginx`, que valida TLS y reenvía las solicitudes a `backend-api:8000`.
   - Las peticiones se autentican mediante cabecera HTTP `Authorization: Bearer <JWT_ACCESS_TOKEN>`.
   - Para la descarga de documentos PDF: Flutter solicita la descarga al backend; `backend-api` autoriza al socio y genera una URL prefirmada temporal de MinIO (o transmite el flujo binario protegido), asegurando que un socio no pueda acceder a documentos ajenos.

3. **Comunicación Backend ↔ Sistemas Externos**:
   - **Sistema de Facturación/Medición COSMOL**: `backend-api` realiza peticiones HTTPS/HTTP internas asíncronas con `httpx` (connection pooling, timeouts estrictos y circuit breaker) para obtener deuda y consumos sin bloquear el event loop.
   - **Proyecto ChatbotReportes**: `backend-api` abre una conexión de solo escritura hacia la base de datos de ChatbotReportes mediante `BackgroundTasks` asíncronas para asentar eventos de auditoría (login, descargas, intentos de pago) sin penalizar el tiempo de respuesta al socio.
   - **Pasarelas de Pago y Banca**: `backend-api` se comunica por HTTPS con las APIs bancarias para inicializar transacciones o generar strings QR; las pasarelas notifican el resultado a través de endpoints de Webhooks expuestos en Nginx/FastAPI.

#### 12.7.3 Matriz de comunicación entre componentes

| Componente Origen | Componente Destino | Canal / Protocolo | Puerto | Rol de la Comunicación |
|---|---|---|---|---|
| Flutter Client | `proxy-nginx` | HTTPS / WSS | 443 | Peticiones API REST y consumo de la versión Web |
| `proxy-nginx` | `backend-api` | HTTP (Proxy Pass interno) | 8000 | Reenvío de llamadas `/api/*` al servidor ASGI |
| `proxy-nginx` | Flutter Web Assets | Filesystem local montado | N/A | Servido de estáticos HTML/JS/WASM de Flutter Web |
| `backend-api` | `db-postgres` | TCP / asyncpg | 5432 | Consultas y persistencia de cuentas, sesiones y auditoría local |
| `backend-api` | `cache-redis` | TCP / Redis Protocol | 6379 | Consulta/escritura de caché, rate limits y conteo de fallos |
| `backend-api` | `storage-minio` | HTTP / S3 API (boto3) | 9000 | Subida, lectura y generación de URLs firmadas de PDFs |
| `backend-api` | Sistema COSMOL | HTTPS / REST interno | Específico | Extracción de deudas, consumos y metadatos de medidor |
| `backend-api` | BD ChatbotReportes | TCP / Conexión BD async | Específico | Despacho asíncrono de eventos de auditoría (solo INSERT) |
| Pasarelas de Pago | `proxy-nginx` → `backend-api` | HTTPS (Webhook entrante) | 443 → 8000 | Confirmación de transacciones y conciliación de saldos |

### 12.8 CI/CD
- **GitHub** para repositorio y control de versiones.
- Pull Requests + revisión de código.
- **GitHub Actions** para:
  - Ejecutar tests.
  - Analizar código.
  - Construir Flutter.
  - Crear artefactos.
  - Construir imágenes Docker.
  - Desplegar backend.
  - Preparar releases móviles.

Flutter mantiene documentación oficial para automatizar builds y releases, incluyendo Android, iOS y web. 

### 12.9 Monitoreo, errores y observabilidad
Para una aplicación usada por muchas personas se debe poder responder:
- ¿La API está caída?
- ¿Qué endpoint está fallando?
- ¿Cuántos usuarios están afectados?
- ¿Qué versión de la app tiene el problema?
- ¿Está fallando el login o el pago?
- ¿Cuánto tarda cada petición?

Stack sugerido:
- **Sentry** para errores y crashes de Flutter/backend.
- Logs centralizados del backend.
- Métricas de infraestructura.
- Health checks.
- Alertas.
- Dashboard de disponibilidad y latencia.

### 12.10 Almacenamiento de PDFs
No conviene guardar grandes cantidades de PDFs directamente dentro de PostgreSQL.

Recomendación:
- **Object Storage** compatible con S3 para facturas y avisos.
- PostgreSQL almacena metadatos, permisos, fechas y referencias.
- Backend entrega URLs firmadas o controla la descarga.

### 12.11 Pruebas
La estrategia debe cubrir:
- **Unit tests**: lógica Dart y backend.
- **Widget tests**: componentes Flutter.
- **Integration tests**: flujos completos.
- **API tests**.
- **Load testing** para estimar concurrencia.
- Pruebas de seguridad.
- Pruebas de recuperación ante errores.
- Pruebas de pagos y conciliación.

### 12.12 Publicación
**Android**
- Google Play Console.
- Generar builds de producción y gestionar firma de la aplicación.

**iOS**
- Apple Developer + App Store Connect.
- TestFlight para beta.
- Proceso de revisión y publicación.

App Store Connect permite gestionar builds, distribución beta mediante TestFlight y el proceso de publicación. 

## 13. Arquitectura recomendada por fases

### Fase 0 — Diseño técnico
- Contrato de API.
- Modelo de datos.
- Política final de autenticación.
- Definición de fuente de datos COSMOL.
- Definición de integración de pagos.
- Definición de documentos PDF.
- Ambientes dev/staging/prod.

### Fase 1 — MVP de consulta
- Flutter.
- Login.
- Dashboard de deuda.
- Facturas/avisos PDF.
- Caché local.
- Backend REST.
- Integración con datos COSMOL.

### Fase 2 — Cierre del ciclo
- Pago externo.
- Webhooks/conciliación.
- Actualización automática de saldo.
- Historial de consumo de 6+ meses.
- Gráficos.

### Fase 3 — Producción robusta
- Push notifications.
- Observabilidad.
- Rate limiting.
- Auditoría.
- Backups.
- CI/CD.
- Load testing.
- Seguridad.
- Publicación Android/iOS/Web.

## 14. Decisiones tecnológicas propuestas para el proyecto

| Área | Recomendación |
|---|---|
| App | Flutter 3.x + Dart |
| Arquitectura Flutter | Clean/Layered (Presentación / Dominio / Datos) |
| Estado | flutter_riverpod (o flutter_bloc) |
| Routing | go_router (con guards de autenticación) |
| HTTP | dio + dio_cache_interceptor |
| Modelos | freezed + json_serializable |
| Almacenamiento seguro (tokens) | flutter_secure_storage |
| Biometría (cliente) | local_auth (Huella dactilar / Face ID) |
| Caché offline | hive_flutter (o isar) |
| QR | qr_flutter |
| PDF (cliente) | flutter_pdfview + path_provider + open_filex |
| Push | firebase_messaging + flutter_local_notifications |
| **Backend** | **FastAPI (Python 3.12+)** — ver 12.2 para la justificación del cambio frente a Django+DRF |
| Servidor ASGI | uvicorn[standard] |
| Cliente HTTP backend→COSMOL | httpx (async) |
| Validación | pydantic v2 |
| API | REST + OpenAPI (autogenerado por FastAPI) |
| Auth | pyjwt + passlib[bcrypt] + JWT (access + refresh token) |
| Proveedores OTP | WhatsApp Cloud API (Meta Graph API) + Pasarela SMS (Fallback) |
| Base de datos | PostgreSQL + alembic |
| Driver BD | asyncpg + sqlalchemy[asyncio] |
| Caché y rate limiting | Redis + slowapi |
| Auditoría hacia ChatbotReportes | BackgroundTasks (FastAPI) — ver caveat de durabilidad en 12.2 |
| Almacenamiento de PDFs | MinIO (S3-compatible) + boto3; PostgreSQL solo guarda metadatos |
| Reverse proxy / TLS | Nginx |
| Contenedores | Docker + Docker Compose |
| CI/CD | GitHub Actions |
| Monitoreo | sentry_flutter + sentry-sdk[fastapi] + métricas + logs |
| Seguridad móvil | OWASP MASVS |
| Android | Google Play Console |
| iOS | App Store Connect + TestFlight |
| Web | Nginx sirviendo el build de Flutter Web / Firebase Hosting |

### 14.1 Tabla maestra detallada (capa por capa)

| Capa / Módulo | Herramienta / Paquete | Rol técnico y justificación |
|---|---|---|
| App base | Flutter 3.x + Dart | Base de código única compilada para Android, iOS y Web (plataforma omnicanal 24/7) |
| Arquitectura frontend | Clean / Layered Architecture | Separación en capas: Presentación (UI/Widgets), Dominio (casos de uso/entidades) y Datos (repositorios/data sources) |
| Gestión de estado | flutter_riverpod (o flutter_bloc) | Reactividad para sesión, intentos de login, expiración de tokens y actualización del dashboard |
| Enrutamiento | go_router | Rutas declarativas, guards de autenticación (redirección si no está logueado o está bloqueado), soporte de URLs en Web y deep links |
| Cliente HTTP | dio + dio_cache_interceptor | Interceptores para inyección automática de Bearer JWT, renovación silenciosa con refresh token, timeouts y reintentos ante mala conectividad |
| Modelado/inmutabilidad | freezed + json_serializable | Modelos inmutables generados desde los esquemas JSON de la API, evita errores de tipado en runtime |
| Almacenamiento seguro | flutter_secure_storage | Cifrado a nivel de hardware (Android Keystore / iOS Keychain) para el Access y Refresh Token |
| Caché offline | hive_flutter (o isar) | Almacenamiento local rápido para consultar el último saldo conocido y facturas descargadas sin conexión |
| Dashboard de deuda (4.2 / 10.2) | Componentes nativos Flutter | Renderizado en moneda local (Bs) y color rojo condicional si la fecha de vencimiento ya expiró |
| Redirección a pagos (4.3 / 10.3) | url_launcher | Apertura de pasarelas de pago web, apps de banca móvil y esquemas de llamada externos |
| Generación de QR (4.3 / 10.3) | qr_flutter | Renderizado del QR interbancario cuando la pasarela retorna la cadena de pago |
| Gestión de PDFs (4.4 / 10.4) | flutter_pdfview + path_provider + open_filex | Visualización de facturas/avisos con valor legal y descarga directa al almacenamiento local |
| Historial analítico (4.5 / 10.5) | fl_chart | Gráficos de barras/líneas de consumo vs. meses (mínimo 6 meses) |
| Notificaciones push | firebase_messaging + flutter_local_notifications | Avisos de corte, vencimientos y confirmación de pagos vía FCM |
| Backend framework | FastAPI (Python 3.12+) | BFF asíncrono; desacopla a Flutter de la API interna de COSMOL y de la base de datos de ChatbotReportes |
| Servidor ASGI | uvicorn[standard] | Servidor HTTP de alto rendimiento con workers concurrentes en el contenedor Docker |
| Cliente upstream API | httpx (async) | Conexión no bloqueante con connection pooling hacia la API interna de COSMOL |
| Validación de datos | pydantic v2 | Parsing/validación de esquemas de entrada y salida (núcleo Rust) |
| Caché y throttling | Redis | Caché de respuestas de deuda/historial (<20 ms), rate limiting por IP y conteo de intentos fallidos |
| Base de datos propia | PostgreSQL + alembic | Credenciales, estado de cuentas, auditoría de accesos y tokens de dispositivo (FCM) |
| Driver de BD asíncrono | asyncpg + sqlalchemy[asyncio] | Conexión no bloqueante a PostgreSQL |
| Seguridad y cifrado | pyjwt + passlib[bcrypt] + slowapi | JWT (access/refresh), hashing seguro de credenciales, rate limiting por IP/cuenta |
| Despacho asíncrono | BackgroundTasks (FastAPI) | Envío en segundo plano de eventos de auditoría hacia ChatbotReportes sin demorar la respuesta al socio |
| Almacenamiento de PDFs | MinIO (S3-compatible) + boto3 | Almacenamiento desacoplado de objetos para facturas y avisos |
| Reverse proxy / gateway | Nginx | Terminación SSL/TLS, balanceo hacia FastAPI y servido estático del build de Flutter Web |
| Monitoreo y errores | sentry_flutter + sentry-sdk[fastapi] | Trazabilidad de fallos en producción, tanto en el cliente como en el backend |
| Contenedores | Docker + Docker Compose | Empaquetado de FastAPI, Redis, PostgreSQL, MinIO y Nginx |

### 14.2 Mapeo funcional → implementación

- **Autenticación (4.1 / 10.1)**: Flutter envía las credenciales vía `dio`. En el primer acceso (`cod_socio + CI`), FastAPI valida contra el sistema legado de COSMOL, genera un código OTP de 6 dígitos en Redis (TTL 5 min) y lo despacha al canal elegido por el usuario (WhatsApp Cloud API oficial o SMS). Tras verificar el OTP, el usuario define su Contraseña/PIN personal (hasheada con `passlib[bcrypt]` en PostgreSQL), cerrando la brecha de confidencialidad de la CI. Para accesos habituales, el socio ingresa con su PIN o biometría local (`local_auth`). Si hay fallos reiterados, `slowapi` + Redis imponen el bloqueo progresivo desde el 3er intento. FastAPI emite Access Token (~15 min) y Refresh Token (~7 días), que Flutter almacena en `flutter_secure_storage`.
- **Dashboard de deuda (4.2 / 10.2)**: Flutter consulta `GET /api/v1/socio/dashboard`. FastAPI revisa Redis primero (respuesta cacheada, TTL ~10 min, <20 ms); si no hay caché, consulta de forma asíncrona con `httpx` la API interna de COSMOL. Flutter aplica el estilo rojo si la fecha ya venció.
- **Redirección a pagos (4.3 / 10.3)**: el socio pulsa "Pagar Ahora"; FastAPI solicita el enlace/código a la pasarela bancaria; Flutter usa `url_launcher` para abrir la app del banco o la web externa, o dibuja el QR con `qr_flutter` si la respuesta trae un string QR.
- **Gestión de documentos (4.4 / 10.4)**: Flutter solicita la descarga; FastAPI recupera el archivo de la API de COSMOL o de MinIO (URL firmada o flujo binario); `path_provider` lo descarga temporalmente y `flutter_pdfview`/`open_filex` lo abre en el dispositivo.
- **Historial de consumo (4.5 / 10.5)**: `fl_chart` procesa el arreglo de consumo de los últimos 6+ meses que entrega FastAPI y dibuja el gráfico con los ejes definidos.
- **Integración con ChatbotReportes**: en cada login, pago iniciado o descarga de factura, FastAPI dispara una `BackgroundTask` que despacha el registro de auditoría a la base de datos de ChatbotReportes, sin añadir latencia a la respuesta del socio (ver caveat de durabilidad en 12.2).

## 15. Principio de escalabilidad

La aplicación debe diseñarse para que **Flutter sea únicamente el cliente** y toda regla de negocio crítica viva en el backend.

Esto permite:
- agregar futuras versiones móviles sin duplicar reglas;
- incorporar una web de socios;
- cambiar de proveedor de pagos;
- cambiar la fuente de datos de COSMOL;
- escalar servidores independientemente del número de usuarios;
- aplicar seguridad y auditoría en un punto central;
- incorporar nuevas funcionalidades sin romper las existentes.

El objetivo no es empezar con una infraestructura excesivamente compleja, sino construir desde el inicio una base que pueda pasar de un MVP a producción sin rehacer el sistema completo.
