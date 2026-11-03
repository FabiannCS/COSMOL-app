# Requisitos Esenciales para Lanzamiento a Producción y Publicación
## Ecosistema Omnicanal de Socios — COSMOL R.L. (App Móvil y Chatbot WhatsApp)

> **Documento Ejecutivo y Técnico de Solicitud de Insumos y Credenciales**  
> **Destinatarios:** Gerencia General, Departamento de Sistemas / TI, Asesoría Legal y Departamento Comercial de COSMOL R.L.  
> **Propósito:** Consolidar todos los requisitos, accesos, cuentas corporativas y definiciones legales indispensables para completar la fase final de despliegue, habilitar los servicios en producción y publicar tanto la aplicación móvil en tiendas oficiales (Google Play Store y App Store) como el Chatbot oficial de WhatsApp.

---

## 1. Resumen Ejecutivo y Matriz de Estado

Actualmente la plataforma cuenta con el 100% de la arquitectura base implementada en sus dos canales de atención directa:
1. **Aplicación Móvil y Web (Flutter / FastAPI):** Autenticación con separación de identidades, consulta de deudas en tiempo real, histórico de consumo analítico, descarga de documentos con valor legal (PDFs), vinculación multicuenta, cambio de PIN y módulo de reconexión con GPS y fotos.
2. **Chatbot Oficial de WhatsApp (PHP 7.3 / n8n / Caddy):** Atención automatizada de "fricción cero" (acceso únicamente con Código Fijo), consulta de deuda y enlaces de pago, registro de reclamos con georreferenciación nativa y fotos de evidencia, reconexiones con validación de mora y buffer de auditoría resiliente hacia COSMOL-Reportes.

Para la transición de **Entorno de Pruebas (Staging/Mock)** a **Entorno Productivo Oficial**, se requiere la tramitación y entrega de los insumos detallados en este documento:

| Módulo / Canal | Componente Requerido | Responsable Interno | Criticidad | Estado Actual |
|---|---|:---:|:---:|:---:|
| **Meta API (Ambos)** | Verificación Empresarial Meta Business Suite | TI / Legal / Gerencia | **Máxima** | Rechazado por Meta (Requiere Reintento) |
| **Meta API (Ambos)** | Token Permanente de Usuario del Sistema | TI / Sistemas | **Alta** | **Configurado y Operativo** |
| **Chatbot WhatsApp** | Línea Telefónica Oficial Dedicada (Chatbot) | Comercial / TI | **Alta** | Operando en Sandbox temporal |
| **App Móvil (OTP)** | Línea Telefónica Dedicada para OTP / SMS | Comercial / TI | **Media** | En modo simulado (`MOCK_MESSAGING=true`) |
| **Datos (Ambos)** | Endpoints REST de Producción (SAI Informix) | Sistemas / TI | **Alta** | Operando contra Mock PostgreSQL |
| **Tiendas Móviles** | Cuenta Google Play Console (Organización) | TI / Legal | **Alta** | Guía lista / Requiere D-U-N-S |
| **Tiendas Móviles** | Política de Privacidad Pública (Web) | Legal / TI | **Alta** | Redacción pendiente |
| **Tiendas Móviles** | Activos Gráficos Oficiales | Diseño / Marketing | **Media** | Mockups temporales |
| **Infraestructura** | Dominio y Certificados SSL (`cosmol.com.bo`) | TI / Redes | **Alta** | IP directa en VPS (Caddy configurado) |
| **Infraestructura** | Servidor MinIO Producción (Fotos / PDFs) | TI / Redes | **Alta** | Configuración local / almacenamiento en disco |
| **Notificaciones** | Proyecto Firebase Corporativo (FCM) | TI / Sistemas | **Media** | Claves de desarrollo |
| **Analítica** | Integración Eventos en COSMOL-Reportes | TI / Sistemas | **Media** | Totalmente integrado en backend y bot |
| **Pagos** | Pasarela QR / Multipago Integrado | Gerencia / Finanzas | **Baja** (Fase 2) | Redirección externa activa |

---

## 2. Requerimientos de Autenticación OTP (WhatsApp y SMS)

El sistema de seguridad de la aplicación móvil exige que todo socio confirme su número de celular mediante un código numérico temporal de un solo uso (OTP de 6 dígitos con vigencia de 5 minutos) antes de crear o recuperar sus credenciales.

> [!NOTE]
> En la fase de desarrollo actual, el backend opera bajo `MOCK_MESSAGING=true`, lo que genera el código internamente sin consumir saldo real. Para el pase a producción, se requiere activar los canales oficiales.

```
                  ┌─────────────────────────────────────────┐
                  │    Flujo OTP en Producción (BFF API)    │
                  └────────────────────┬────────────────────┘
                                       │
                    ┌──────────────────┴──────────────────┐
                    ▼                                     ▼
        [ Canal Principal: WhatsApp ]           [ Canal Respaldo: SMS ]
        - Alta tasa de entrega (>98%)           - Para usuarios sin datos/WhatsApp
        - Menor costo por sesión                - Proveedor nacional (Entel/Tigo)
        - Plantilla de autenticación            - Remitente corporativo ("COSMOL")
```

### 2.1 Canal Principal: WhatsApp Business Cloud API (Meta)
Para que los mensajes provengan de la cuenta verificada oficial de la cooperativa:

* [ ] **Subsanación de Verificación de Meta Business Suite:** Reintento formal con la documentación legal corporativa de COSMOL R.L. (ver detalle en la Sección 8.1).
* [ ] **Número de Teléfono Dedicado Exclusivo para OTP:** Un número telefónico que **no esté registrado** en ninguna aplicación convencional de WhatsApp ni WhatsApp Business, asignado como línea de solo emisión de notificaciones/códigos bajo la misma WABA.
* [ ] **Línea de Crédito o Tarjeta Corporativa en Meta:** Asociar método de pago en el Administrador Comercial para el consumo de conversaciones de autenticación (*Authentication Conversations*). Costo aproximado: ~$0.03 USD por entrega exitosa.
* [ ] **Credenciales de API (Ya provistas en entorno base):**
  - `WHATSAPP_TOKEN`: Token permanente de usuario del sistema (ya generado, requiere habilitación tras verificar la empresa).
  - `WHATSAPP_PHONE_NUMBER_ID`: Identificador del número de teléfono emisor de OTPs.
  - `WHATSAPP_WABA_ID`: Identificador de la cuenta de WhatsApp Business.
* [ ] **Aprobación de Plantilla de Autenticación:**
  - Nombre recomendado: `otp_codigo_verificacion`
  - Categoría obligatoria: `AUTHENTICATION`
  - Idioma: Español (`es`)
  - Formato: Contiene un botón directo de *"Copiar código"* y un aviso de caducidad en 5 minutos.

### 2.2 Canal Alternativo: Pasarela de SMS Nacional (Bolivia)
Como respaldo ante falta de conexión a internet o números sin WhatsApp:

* [ ] **Contrato con Proveedor de Mensajería Masiva:** Convenio con operadora (Entel, Tigo, Telecel) o pasarela agregadora autorizada en Bolivia (ej: Twilio, Infobip, etc.).
* [ ] **Sender ID Registrado:** Nombre del remitente oficial de hasta 11 caracteres alfanuméricos (ej: `COSMOL`).
* [ ] **Credenciales de API:** Endpoint REST, `SMS_API_KEY`, `SMS_API_SECRET` y saldo de mensajes disponible.

---

## 3. Requerimientos para Publicación en Google Play Store

Para que los usuarios puedan descargar la aplicación oficial desde teléfonos Android, Google Play impone estrictas directivas de cumplimiento corporativo.

> [!IMPORTANT]
> **No utilizar cuentas personales de desarrollador.** Las cuentas personales creadas después de noviembre de 2023 exigen obligatoriamente una prueba cerrada con 20 evaluadores durante 14 días antes de poder solicitar la publicación. **Las cuentas de Organización (Empresa) están exentas de este requisito.**

### 3.1 Cuenta de Google Play Console (Tipo Organización)
* [ ] **Número D-U-N-S® (Dun & Bradstreet):** Código internacional de 9 dígitos que identifica a personas jurídicas. COSMOL R.L. debe solicitarlo o consultarlo gratuitamente en el portal oficial de D&B.
* [ ] **Pago Único de Registro:** \$25 USD abonados con tarjeta de crédito corporativa a nombre de la cooperativa.
* [ ] **Correo Institucional Dedicado:** Ejemplo: `app.socios@cosmol.com.bo` o `sistemas@cosmol.com.bo` (no cuentas de correo personales `@gmail.com`).
* [ ] **Verificación de Identidad Empresarial:** Presentación del NIT, estatuto orgánico o poder notarial que acredite la existencia legal de COSMOL R.L.

### 3.2 Insumos Legales Obligatorios para la Ficha
* [ ] **URL Pública de Política de Privacidad:** Google exige un enlace web accesible y permanentemente en línea (ej: `https://cosmol.com.bo/privacidad-app`).
  - Debe detallar expresamente el tratamiento de datos de socios, ubicación geográfica (coordenadas GPS para trámites de corte y reconexión) y almacenamiento de fotos de acometidas.
* [ ] **Mecanismo de Eliminación de Cuenta:** Enlace o procedimiento dentro de la web donde un usuario pueda solicitar la baja o revocación de sus datos digitales en cumplimiento de las políticas de Google Play.
* [ ] **Credenciales de Prueba para Revisores de Google:**
  - Código de socio y contraseña de demostración con datos simulados (para que el equipo evaluador de Google pueda ingresar y auditar todas las pantallas sin bloquearse por OTP).

### 3.3 Activos Gráficos de Marca (Identidad Visual)
Los activos gráficos son todos los elementos visuales que componen la **presentación pública de la app** para que los socios puedan reconocerla e instalarla. Estos elementos se distribuyen en **dos ubicaciones esenciales**:

#### A. Ubicación 1: En Google Play Console (Escaparate Público de la Tienda)
Son los recursos obligatorios que exige Google antes de autorizar el botón *"Enviar a revisión"*. Se cargan directamente en la consola de Google Play (*Crecimiento* → *Presencia en Google Play Store* → *Ficha principal*):

| Activo Gráfico | Especificación Técnica | ¿Dónde se ve en la Play Store? | ¿Quién lo elabora? |
|---|---|---|:---:|
| **Ícono de la Aplicación** | 512 x 512 px • PNG 32-bit • Máx 1 MB • Sin esquinas redondeadas (Google aplica la máscara). | Es el logo que aparece en los resultados de búsqueda de la tienda y junto al botón *"Instalar"*. | Diseñador / Comunicación COSMOL |
| **Gráfico de Funciones (Banner)** | 1024 x 500 px • JPG o PNG • Sin canal alfa • Proporción panorámica. | Portada superior de la ficha de la app. Sirve como carta de presentación visual institucional. | Diseñador / Comunicación COSMOL |
| **Capturas de Pantalla (Móvil)** | Mínimo 4 capturas • Resolución 1080 x 1920 px (o ratio 16:9 / 18:9) • JPG o PNG 24-bit. | Galería deslizante donde el socio visualiza las funciones (Dashboard, saldo, consumo en m³, reconexión). | Equipo de Desarrollo (Capturas en emulador) |
| **Descripción Breve** | Máximo 80 caracteres. | Frase corta visible de primer vistazo en la tienda (ej: *"Consulta tu saldo, consumo de agua y gestiona tus servicios en Montero"*). | Comunicación / TI |
| **Descripción Completa** | Máximo 4000 caracteres. | Detalle de beneficios, funcionalidades, requisitos de acceso y soporte oficial. | Comunicación / TI |

#### B. Ubicación 2: Dentro del Código de la App (Empaquetado en el Teléfono)
Parte de estos mismos recursos gráficos se integran dentro de la base de código de Flutter para el funcionamiento diario en el celular del usuario:

* **Ícono de Inicio del Celular (`Launcher Icon`):**
  - **Ubicación en el código:** `frontend/android/app/src/main/res/mipmap-...` (generado automáticamente mediante `flutter_launcher_icons`).
  - **Función:** Es el acceso directo con el logo de COSMOL que queda visible en la pantalla principal del smartphone del socio tras descargar la app.
* **Pantalla de Bienvenida (`Splash Screen`):**
  - **Ubicación en el código:** `frontend/assets/images/` y `frontend/android/app/src/main/res/drawable/`.
  - **Función:** Logotipo centrado con fondo blanco que se renderiza durante los primeros 1.5 segundos mientras la app inicializa los tokens seguros y valida la conectividad.

### 3.4 Firma de Producción (Keystore de Lanzamiento)
* [ ] **Generación y Custodia del Keystore:** El equipo de desarrollo generará el archivo `cosmol-upload-key.jks`.
* [ ] **Resguardo Seguro:** Las contraseñas del almacén de claves (`storePassword`, `keyPassword`) y el certificado de carga deben ser custodiados en la bóveda de seguridad digital de TI de COSMOL.

---

## 4. Requerimientos de Infraestructura y Producción

Para garantizar alta disponibilidad 24/7 y tiempos de respuesta inferiores a 100 ms:

```
                            [ Tráfico Internet ]
                                     │
                             (HTTPS Puerto 443)
                                     ▼
                      ╔═════════════════════════════╗
                      ║   gateway-caddy (Proxy)     ║
                      ║   - Dominio oficial COSMOL  ║
                      ║   - Certificado Let's Encrypt║
                      ╚══════════════╤══════════════╝
                                     │
           ┌─────────────────────────┼─────────────────────────┐
           ▼                         ▼                         ▼
   [ backend-api:8000 ]      [ db-postgres:5432 ]      [ storage-minio:9000 ]
   FastAPI + Uvicorn         PostgreSQL 16             MinIO S3 Privado
   Workers concurrentes      Persistencia de datos     Fotos y Documentos PDF
```

### 4.1 Dominio y Certificados TLS/HTTPS
* [ ] **Asignación de Subdominios Oficiales:**
  - `app.cosmol.com.bo` o `socios.cosmol.com.bo` (App Móvil / FastAPI BFF).
  - `chatbot.cosmol.com.bo` (Webhook n8n y Chatbot WhatsApp).
* [ ] **Configuración DNS:** Registros Tipo `A` en los servidores DNS autoritativos de COSMOL apuntando a la IP pública estática del servidor de aplicaciones.
* [ ] **Puertos de Red Abiertos:** Puertos `80` (HTTP), `443` (HTTPS) y `8081` (Reportes) habilitados en el Firewall institucional con redirección al contenedor Caddy (que gestiona certificados SSL automáticos y gratuitos mediante Let's Encrypt).

### 4.2 Servidor y Almacenamiento MinIO (S3)
* [ ] **Capacidad en Disco:** Espacio mínimo reservado de **100 GB SSD** con política de ampliación para almacenamiento de:
  - Facturas digitales legalizadas en formato PDF.
  - Avisos de corte y avisos de cobranza.
  - Fotografías de evidencia técnica de reclamos y reconexiones (Chatbot y App).
* [ ] **Credenciales de Producción:** Modificar las claves por defecto en el archivo de variables de entorno `.env`:
  - `MINIO_ROOT_USER`: Usuario administrador seguro.
  - `MINIO_ROOT_PASSWORD`: Contraseña robusta (mínimo 32 caracteres generados aleatoriamente).
* [ ] **Política de Respaldos (Backups):** Plan de snapshots diarios del volumen persistente `minio_data` y de la base de datos `postgres_data`.

### 4.3 Claves Criptográficas y Seguridad
* [ ] **JWT Secret Key de Producción:** Configurar `SECRET_KEY` en el archivo `.env` de la App Móvil con una cadena criptográfica de al menos 64 caracteres generada con `openssl rand -hex 32`.
* [ ] **Internal Token del Chatbot:** Mantener sincronizado `API_INTERNAL_TOKEN` entre n8n y el backend PHP.

---

## 5. Requerimientos de Notificaciones Push (Firebase Cloud Messaging)

Para el envío de alertas automáticas sobre fechas de vencimiento, avisos de suspensión del servicio y confirmación de recepción de solicitudes de reconexión en la aplicación móvil:

* [ ] **Proyecto Corporativo en Google Firebase:** Crear un proyecto bajo la consola de Firebase (`https://console.firebase.google.com`) vinculado a la cuenta institucional de COSMOL.
* [ ] **Archivo `google-services.json`:** Descargar desde la configuración del proyecto de Firebase y colocarlo en el directorio `frontend/android/app/`.
* [ ] **Credencial de Cuenta de Servicio (Backend):** Generar una clave privada en formato JSON (*Firebase Admin SDK*) para que el backend FastAPI pueda despachar notificaciones push dirigidas por `device_token`.

---

## 6. Integración con ChatbotReportes (Métricas y Auditoría)

El módulo de auditoría desacoplado requiere que el sistema de reportes gerenciales reconozca la totalidad de eventos originados desde ambos canales:

* [ ] **Endpoint y Token de Producción:**
  - `REPORTES_API_URL`: URL oficial del backend de reportes (ej: `http://reportes.cosmol.com.bo/api` o interna `http://host.docker.internal:8082/api`).
  - `REPORTES_API_TOKEN`: Token de autenticación inter-servicio (`X-Reportes-Token`).
* [ ] **Catálogo Completo de Eventos en ChatbotReportes:**
  - `id_tipo: 1` $\rightarrow$ *"Autenticación / Login de Socio"*
  - `id_tipo: 2` $\rightarrow$ *"Consulta de Deuda"*
  - `id_tipo: 3` $\rightarrow$ *"Historial de Facturas"*
  - `id_tipo: 4` $\rightarrow$ *"Registro de Reclamo Técnico"*
  - `id_tipo: 5` $\rightarrow$ *"Solicitud de Reconexión de Suministro"*
  - `id_tipo: 6` $\rightarrow$ *"Información de Oficinas y Horarios"*
  - `id_tipo: 7` $\rightarrow$ *"Derivación con Agente Humano"*
  - `id_tipo: 8` $\rightarrow$ *"Consulta de Estado de Solicitudes/Trámites"*
* [ ] **Tipo de Ubicación Registrada:**
  - `APP_MOVIL`: Eventos despachados desde la aplicación de smartphones.
  - `WHATSAPP`: Eventos despachados desde el flujo del Chatbot.

---

## 7. Pasarela de Pagos (Definición para Fase Futura)

Conforme a las directivas del proyecto, COSMOL RL no procesa pagos directamente dentro de la aplicación ni en el bot para mantener **cero alcance PCI-DSS**. Actualmente, el botón *"Pagar Ahora"* realiza la redirección web/bancaria correspondiente hacia **Multipago** y **Pago al Paso**.

Para una futura integración con pagos QR dinámicos directos en pantalla:
* [ ] **Convenio Bancario / Pasarela:** Formalización de contrato comercial con pasarela de pagos (Multipago / Síntesis, Banco Unión, BMSC o pasarela autorizada ASFI).
* [ ] **Ambiente de Certificación (Sandbox):** Manual de integración, credenciales de prueba (`API_KEY`, `COMMERCE_ID`) y validación del formato QR Simple interbancario.
* [ ] **Webhook de Notificación de Cobro:** Definición de la URL de notificación para que la pasarela avise en tiempo real a COSMOL y el saldo en mora se liquide automáticamente.

---

## 8. Requerimientos Específicos para Chatbot COSMOL (WhatsApp Oficial)

El Chatbot de COSMOL R.L. atiende de forma automatizada consultas de deuda, reportes georreferenciados de averías y solicitudes de reconexión sin fricción de contraseñas. Para oficializar su operación productiva ante Meta y la infraestructura interna, se requieren los siguientes insumos técnicos y administrativos:

```
                     ╔══════════════════════════════════════════════╗
                     ║        Meta Business Suite (COSMOL R.L.)     ║
                     ║        * Estado: Rechazado (Requiere Reintento)║
                     ║        * Token Permanente: YA GENERADO       ║
                     ╚══════════════════════╤═══════════════════════╝
                                            │
                                            ▼
                     ╔══════════════════════════════════════════════╗
                     ║      WhatsApp Business Account (WABA)        ║
                     ╚══════════════════╤═══════════════════════════╝
                                        │
                 ┌──────────────────────┴──────────────────────┐
                 ▼                                             ▼
   ┌───────────────────────────┐                 ┌───────────────────────────┐
   │ Número 1: Chatbot Socios  │                 │   Número 2: OTP / App     │
   │ (Phone Number ID A)       │                 │   (Phone Number ID B)     │
   ├───────────────────────────┤                 ├───────────────────────────┤
   │ • Webhook activo en n8n   │                 │ • Solo salida de plantillas│
   │ • Sesiones de 24h ($0.00) │                 │ • Plantilla AUTHENTICATION│
   │ • Conversación interactiva│                 │ • No interfiere con el bot│
   └───────────────────────────┘                 └───────────────────────────┘
```

### 8.1 Plan de Subsanación y Reintento de Verificación en Meta Business
El entorno ya cuenta con un **Token Permanente de Usuario del Sistema**, pero el pase de número a producción se encuentra bloqueado debido al **rechazo inicial de la Verificación Empresarial** por parte de Meta.

Para garantizar la aprobación en el nuevo intento, el Departamento Legal y de Sistemas debe recopilar el siguiente **Dossier de Verificación**:

* [ ] **Coincidencia Exacta de la Razón Social:**
  - El nombre registrado en el Portfolio de Meta Business debe coincidir carácter por carácter con el NIT institucional:  
    `COOPERATIVA DE SERVICIOS PUBLICOS MONTERO "COSMOL" R.L.` (respetando comillas, puntos y siglas legales).
* [ ] **Certificado de Inscripción al Padrón Nacional de Contribuyentes (NIT Digital):**
  - Documento PDF descargado recientemente desde la plataforma del Servicio de Impuestos Nacionales (SIN), con código QR de verificación válido.
* [ ] **Personería Jurídica y Estatuto Orgánico:**
  - Resolución Administrativa de Reconocimiento de Personalidad Jurídica emitida por la Autoridad de Fiscalización y Control de Cooperativas (**AFCOOP**).
* [ ] **Prueba Oficial de Dirección y Teléfono Físico (Crítica):**
  - **Factura de Servicio Básico (Máximo 90 días):** Factura de energía eléctrica (CRE R.L.) o de telecomunicaciones (Entel / Tigo) emitida **a nombre exacto de COSMOL R.L.**, donde figure claramente la dirección de la sede central en Montero y coincida con los datos colocados en Meta.
  - Alternativamente: Extracto bancario corporativo emitido por entidad supervisada por la ASFI a nombre de la cooperativa.
* [ ] **Cumplimiento en el Sitio Web Oficial (`cosmol.com.bo`):**
  - Meta audita el dominio web declarado. En el pie de página (*footer*) de `cosmol.com.bo` debe figurar de forma visible: Razón social legal completa, NIT, dirección física en Montero, teléfono oficial y enlace a políticas de privacidad.
* [ ] **Correo Institucional para la Verificación:**
  - La verificación debe ser realizada exclusivamente por un usuario administrador con correo de dominio corporativo (ej. `gerencia@cosmol.com.bo` o `sistemas@cosmol.com.bo`). Meta rechaza sistemáticamente cuentas creadas con correos genéricos (`@gmail.com`).

### 8.2 Sinergia WABA: Arquitectura Dual (Línea Chatbot vs Línea OTP App)
Para evitar conflictos operativos, ambos sistemas convivirán en la misma cuenta de Meta bajo la siguiente arquitectura:
* **Misma Cuenta Empresarial y Misma WABA:** Ambos servicios comparten el mismo método de pago corporativo y el mismo Token Permanente de Usuario del Sistema.
* **Separación de Números Telefónicos (Recomendada):**
  - **Línea A (Chatbot):** Conectada al webhook de n8n. Gestiona menús interactivos, listas, fotos y ubicaciones bajo el modelo de conversación iniciada por el socio (*User-Initiated* dentro de la ventana de 24 horas, con costo \$0.00 USD).
  - **Línea B (OTP App):** Línea exclusiva para disparar plantillas de autenticación numérica. Si un socio intenta escribir a esta línea, no interferirá con los flujos ni la memoria de sesión del Chatbot.

### 8.3 Línea Telefónica Oficial del Chatbot y Migración
* [ ] **Número Telefónico Limpio:** Designación de la línea telefónica corporativa definitiva que se difundirá públicamente a los socios de Montero.
* [ ] **Desvinculación Previa Obligatoria:** Si el número asignado actualmente se encuentra funcionando en un teléfono móvil con la aplicación WhatsApp convencional o WhatsApp Business:
  - Se debe ingresar a *Ajustes* → *Cuenta* → *Eliminar mi cuenta* dentro de la app móvil.
  - Esto libera el número telefónico en los servidores de Meta, permitiendo su registro exitoso en la Meta Cloud API.

### 8.4 Integración Definitiva con el Sistema Central SAI (IBM Informix)
El backend PHP del Chatbot se diseñó bajo el **Patrón Repositorio**, permitiendo alternar entre el mock de pruebas (`app/Data/Repositories/Postgres/`) y los endpoints productivos (`app/Data/Repositories/Api/`) mediante variables en `.env`.

Para dar de baja la base de datos simulada y conectar el Chatbot con los datos reales de Informix, el Departamento de Sistemas / TI debe habilitar:

* [ ] **Endpoints REST Oficiales en el Servidor SAI:**
  - `GET /api-consultas/socios/{cod}`: Datos del socio (nombre completo, CI, teléfono registrado, estado de conexión).
  - `GET /api-consultas/socios/{cod}/deudas`: Detalle de facturas pendientes (períodos, montos individuales, fecha de vencimiento y total adeudado).
  - `GET /api-consultas/socios/{cod}/historial-facturas`: Últimas 6 facturas canceladas con desglose de consumo en $\text{m}^3$.
  - `POST /api-consultas/reclamos`: Registro de ticket de avería (tipo de reclamo, glosa, latitud/longitud GPS y URL de la foto de evidencia).
  - `POST /api-consultas/reconexiones`: Registro de orden de reconexión con georreferenciación y fotografía del medidor.
* [ ] **Apertura de Red y Enlace Seguro:**
  - Configuración de túnel VPN o lista blanca de IPs (*IP Whitelisting*) en el Firewall de COSMOL para permitir que el VPS externo donde corre Docker se comunique de forma segura con la IP interna del servidor Informix.
* [ ] **Variables de Producción en `.env`:**
  - Configurar `COSMOL_API_URL` (ej: `https://sai-api.cosmol.com.bo`) y `COSMOL_API_TOKEN`.

### 8.5 Almacenamiento y Ciclo de Vida de Evidencias Técnicas
El Chatbot descarga y procesa evidencias multimedia (fotografías del problema y del medidor enviadas por los socios):
* [ ] **Ruta de Carga Actual:** Servida directamente por el proxy Caddy en `./public/uploads` (`https://chatbot.cosmol.com.bo/uploads/...`).
* [ ] **Política de Retención y Respaldo:**
  - Definir política de almacenamiento: depuración automática de fotos con antigüedad superior a 180 días para evitar saturación de disco, o sincronización directa con el bucket S3 corporativo en **MinIO**.

### 8.6 Despachador de Resiliencia hacia COSMOL-Reportes
* [ ] **Activación del Cron de Sincronización:**
  - Confirmar la ejecución periódica del endpoint `public/api/cron_flush_reportes.php` cada 5 a 10 minutos (mediante el workflow importado en n8n `05_Cron_Sincronizador_Reportes.json` o un crontab del sistema operativo) para garantizar que ante cortes de red nunca se pierdan consultas ni estadísticas.

---

## 9. Cronograma Sugerido de Gestión de Requisitos (Consolidado Ecosistema)

```
Semana 1                      Semana 2                      Semana 3
[ Trámite D-U-N-S y Google ]  [ Aprobación Meta WhatsApp ]  [ Configuración DNS & SSL ]
[ Dossier Reintento Meta   ]  [ Endpoints SAI Informix   ]  [ Pruebas Integradas E2E ]
[ Desvinculación Teléfonos ]  [ Cuenta Firebase FCM      ]  [ Carga en Play Console   ]
[ Redacción Pol. Privacidad]  [ Activos Gráficos Finales ]  [ Despliegue en Producción]
```

> [!TIP]
> **Pasos Críticos Inmediatos:**
> 1. **Dossier de Meta:** Ensamblar hoy mismo el NIT, la personería jurídica de AFCOOP y la **factura de servicio básico (CRE/Telecomunicaciones) a nombre idéntico de COSMOL R.L.** para enviar la re-postulación en Meta Business Suite.
> 2. **D-U-N-S:** Iniciar el trámite gratuito del código D-U-N-S ante Dun & Bradstreet para la cuenta corporativa de Google Play Console.
> 3. **Definición de Números:** Identificar los dos números telefónicos corporativos (Chatbot interactivo y OTP de autenticación) y desvincularlos de WhatsApp personal.

---

*Documento técnico preparado por el equipo de ingeniería de software para COSMOL R.L. — Octubre/Noviembre 2026.*
