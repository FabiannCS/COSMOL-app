# Guía de Creación y Configuración de Plantilla WhatsApp OTP — COSMOL R.L.

> **Destinatario:** Administrador de Meta / Líder Técnico / Dev 1 Backend
> **Fecha:** Septiembre 2026  
> **Ubicación:** `Docs/GUIA_CONFIGURACION_PLANTILLAS_WHATSAPP.md`  
> **Ecosistema:** Meta WhatsApp Business Platform (Cloud API)

---

## 1. Contexto y Por Qué se Requiere la Plantilla

Para enviar mensajes a un socio que **aún no tiene una conversación abierta** con la línea oficial de COSMOL en las últimas 24 horas (como el envío de un código de seguridad para iniciar sesión o registrarse), Meta exige obligatoriamente el uso de una **Plantilla Aprobada de Categoría Autenticación (`AUTHENTICATION Template`)**.

En este proyecto:
* Reutilizamos la misma **WABA (WhatsApp Business Account)** y el mismo número telefónico oficial que ya opera en el proyecto **Cosmol-Chatbot**.
* Como actualmente no se cuenta con una plantilla de autenticación aprobada, este documento detalla cómo crearla en Meta Business Suite y cómo se prueba en modo desarrollo.

---

## 2. Dónde se Ven los Códigos OTP de Prueba en Desarrollo (Modo Mock)

Para que el equipo de desarrollo (Dev 1, Dev 2 y Flutter) pueda programar y probar el flujo completo **hoy mismo sin esperar a Meta ni incurrir en costos**:

* El backend cuenta con la variable **`MOCK_MESSAGING=true`** en el archivo `.env`.
* **¿Dónde se visualiza el código OTP generado?:**
  1. **En los logs en tiempo real del contenedor de Docker:**
     ```bash
     docker compose logs -f backend-api
     ```
     Verás una línea clara como esta:
     ```text
     INFO: [DEV MOCK WHATSAPP] Enviando OTP '849201' al número '+59170011223' (Propósito: ONBOARDING, Expira en 300s)
     ```
  2. **En la memoria de Redis:**
     El código queda guardado con TTL de 5 minutos bajo la clave:
     ```text
     otp:+59170011223
     ```
  3. **En la tabla de auditoría `otps` de PostgreSQL:**
     Se registra el número, canal (`WHATSAPP`), propósito y fecha para control histórico.

---

## 3. Paso a Paso para Crear y Aprobar la Plantilla Oficial en Meta

Cuando se decida activar el envío real de WhatsApp, el administrador de la cuenta de COSMOL debe realizar este procedimiento único (toma menos de 5 minutos):

### Paso 1: Ingresar al Administrador de WhatsApp de Meta
1. Acceder a [Meta Business Suite](https://business.facebook.com/).
2. Ir a **Configuración del Negocio** ➔ **Cuentas de WhatsApp** ➔ Seleccionar la WABA de COSMOL.
3. Abrir el **Administrador de WhatsApp** (*WhatsApp Manager*).
4. En el menú izquierdo, hacer clic en **Herramientas de la cuenta** ➔ **Plantillas de mensajes** (*Message Templates*).

---

### Paso 2: Crear la Plantilla de Autenticación
1. Clic en el botón azul **Crear plantilla**.
2. Configurar los campos iniciales:
   * **Categoría:** Seleccionar obligatoriamente **`Autenticación`** (*Authentication*).  
     *(Nota: Meta ofrece precios preferenciales y aprobación inmediata en esta categoría).*
   * **Nombre de la plantilla:** `codigo_autenticacion_cosmol` (solo minúsculas y guiones bajos).
   * **Idioma:** Seleccionar **Español** (`es` o `es_LA`).
3. Clic en **Continuar**.

---

### Paso 3: Configuración del Contenido (Predefinido por Meta)
Meta bloquea la edición arbitraria de texto en plantillas de autenticación para garantizar seguridad. Se debe configurar:

* **Tipo de código:** Código de acceso de un solo uso (OTP).
* **Texto base (automático):**
  > *"{{1}} es tu código de verificación de COSMOL R.L. Por razones de seguridad, no compartas este código con nadie."*
* **Configuración del Botón:**
  * Seleccionar **Botón de copiar código** (*Copy Code Button*).
  * Texto del botón: *"Copiar código"*.
  *(Esto permite que en el celular del socio aparezca un botón directo que copia el número de 6 dígitos al portapapeles con un solo toque).*
* **Tiempo de expiración:** Configurar en **5 minutos** (coincidiendo con nuestro TTL en Redis).

---

### Paso 4: Envío y Aprobación
1. Clic en **Enviar a revisión**.
2. **Tiempo de aprobación:** Al ser una plantilla estándar de la categoría *Autenticación*, la aprobación de Meta es procesada por sistemas automatizados y suele estar aprobada en **1 a 5 minutos** con estado verde **`Activa` (Approved)**.

---

## 4. Activación en el Backend (Paso a Producción)

Una vez aprobada la plantilla en Meta, el cambio en nuestro backend es inmediato y sin tocar código:

1. Abrir el archivo `.env`:
   ```env
   # Desactivar simulación para envíos reales
   MOCK_MESSAGING=false

   # Credenciales de Meta WhatsApp Cloud API (reutilizadas del Chatbot)
   WHATSAPP_API_URL=https://graph.facebook.com/v21.0
   WHATSAPP_PHONE_NUMBER_ID=109283746501928
   WHATSAPP_ACCESS_TOKEN=EAAX...tu_token_permanente_de_meta...
   WHATSAPP_OTP_TEMPLATE_NAME=codigo_autenticacion_cosmol
   ```
2. Reiniciar el contenedor:
   ```bash
   docker compose restart backend-api
   ```
3. A partir de ese momento, cualquier solicitud de OTP saldrá directamente al WhatsApp del socio desde la línea oficial de COSMOL.
