# Guía de Investigación Técnica y Económica: Servicios OTP (WhatsApp vs. SMS) y Paso a Producción

> **Proyecto:** COSMOL R.L. — Plataforma Web y Móvil para Asociados  
> **Módulo:** Identidad, Onboarding, Recuperación de Contraseña y Seguridad OTP  
> **Ubicación:** `Docs/backend/guias/GUIA_INVESTIGACION_OTP_COSTOS_Y_PRODUCCION.md`  
> **Destinatarios:** Desarrolladores Backend/Frontend, Líder Técnico y Directiva de COSMOL R.L.  
> **Estado:** Documento de Definición Técnica y Proyección Financiera  

---

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        DIAGNÓSTICO EJECUTIVO DE SERVICIOS OTP                          │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ • ESTADO ACTUAL: Los códigos OTP están en modo SIMULACIÓN ("de adorno / mock").        │
│ • CAUSA TÉCNICA: La variable MOCK_MESSAGING=true en el archivo .env bloquea envíos     │
│   externos para evitar gastos durante el desarrollo y pruebas internas.                │
│ • CANAL PRINCIPAL RECOMENDADO: WhatsApp Cloud API de Meta (~0.08 Bs por OTP).          │
│ • CANAL ALTERNATIVO: SMS Tradicional (~1.54 Bs vía Twilio vs ~0.15 Bs con Entel/Tigo). │
│ • DISPONIBILIDAD: El backend ya está 100% programado; solo falta la plantilla de Meta. │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 1. ¿Por qué actualmente están "de adorno"?

En el archivo de configuración `.env` y en la configuración del backend (`config.py`), el sistema opera bajo la siguiente bandera:

```env
# En desarrollo local: MOCK_MESSAGING=true (los OTP se muestran en logs y en debug_codigo_otp)
MOCK_MESSAGING=true
```

### ¿Qué hace esta variable en el código?

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                      COMPORTAMIENTO INTERNO EN MODO MOCK                               │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ 1. Cero Peticiones Externas:                                                           │
│    El backend NO contacta a Meta ni a ninguna telefónica. No gasta saldo ni crédito.   │
│                                                                                        │
│ 2. Generación en Memoria y Base de Datos:                                              │
│    Genera el código de 6 dígitos, lo guarda en Redis con TTL de 5 minutos (300s) y lo  │
│    registra en la tabla de auditoría PostgreSQL.                                       │
│                                                                                        │
│ 3. Impresión en Consola de Docker:                                                     │
│    El código se visualiza en tiempo real en los logs del contenedor:                   │
│    INFO: [DEV MOCK WHATSAPP] Despachando OTP '849201' al número '+59170011223'         │
│                                                                                        │
│ 4. Facilidad para Frontend (Flutter):                                                  │
│    El backend devuelve el código en la respuesta HTTP:                                 │
│    "debug_codigo_otp": "849201"                                                        │
│    permitiendo que las pantallas de Onboarding y Recuperación funcionen de inmediato.  │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. WhatsApp OTP (Meta WhatsApp Cloud API) — El Canal Principal

Este es el canal más económico, seguro y con mayor penetración en Bolivia (utilizado por más del 98% de los usuarios de telefonía móvil).

### 2.1 ¿Cómo funciona en la vida real?
COSMOL no manda un mensaje desde un teléfono celular físico. Se comunica por internet mediante peticiones HTTPS directas a la **Graph API v21.0 de Meta**:

```
┌─────────────────┐      HTTPS POST      ┌──────────────────┐      WhatsApp      ┌─────────────────┐
│ Backend FastAPI │ ───────────────────► │ Meta Cloud API   │ ─────────────────► │ Celular Socio   │
│ (COSMOL Server) │                      │ (Servidores Meta)│                    │ (Montero, Bol.) │
└─────────────────┘                      └──────────────────┘                    └─────────────────┘
```

### 2.2 Requisitos Obligatorios de Meta para Salir a Producción

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        REQUISITOS OBLIGATORIOS DE META                                 │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ 1. Cuenta Empresarial (WABA - WhatsApp Business Account):                              │
│    COSMOL ya cuenta con una WABA oficial y número corporativo verificado, reutilizable │
│    directamente del proyecto hermano Cosmol-Chatbot.                                   │
│                                                                                        │
│ 2. Plantilla Aprobada de Categoría "Autenticación" (AUTHENTICATION):                   │
│    Meta prohíbe enviar texto libre para códigos de seguridad. Se debe crear la         │
│    plantilla oficial codigo_autenticacion_cosmol con el texto predefinido:             │
│    "{{1}} es tu código de verificación de COSMOL R.L. No compartas este código."       │
│    [ Botón: Copiar código ]                                                            │
│    *Meta la aprueba mediante robots automáticos en 1 a 5 minutos.*                     │
│                                                                                        │
│ 3. Método de Pago en Meta Business Suite:                                              │
│    Vincular una tarjeta de crédito o débito internacional habilitada para compras por  │
│    internet en dólares en la sección de Facturación de Meta Business Suite.            │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.3 ¿Cuánto cuesta realmente WhatsApp OTP en Bolivia?

Meta factura bajo el esquema **por mensaje de plantilla entregado**. Para Bolivia aplica la tarifa regional oficial de **Rest of Latin America**:

| Concepto | Costo en Dólares (USD) | Costo en Bolivianos (TC aprox. 6.96) |
|---|---|---|
| **Costo por 1 código OTP entregado** | **$0.0113 USD** | **~0.08 Bs.** *(8 centavos de Boliviano)* |
| **Volumen de 1,000 registros u OTPs** | **$11.30 USD** | **~78.65 Bs.** |
| **Volumen de 5,000 registros u OTPs** | **$56.50 USD** | **~393.24 Bs.** |
| **Volumen de 10,000 registros u OTPs** | **$113.00 USD** | **~786.48 Bs.** |

* **Regla de cobro:** Si el número no existe o no se entrega el mensaje, Meta **no genera cobro**.
* **Impacto Económico:** Con un presupuesto mensual de apenas **100 a 150 Bs.**, la cooperativa cubre más de 1,500 registros y recuperaciones de contraseña al mes.

---

## 3. Mensaje de Texto Tradicional (SMS) — El Canal Alternativo

El SMS tradicional fue diseñado en la aplicación como canal de contingencia para socios en zonas rurales sin cobertura de internet o que no tengan WhatsApp instalado.

Existen 3 opciones técnicas en el mercado con diferencias críticas de costo:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        OPCIONES DE PROVEEDORES SMS                                     │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ OPCIÓN A: Pasarela Internacional en la Nube (Twilio / Infobip)                         │
│ • Costo oficial Twilio hacia Bolivia: $0.2215 USD por SMS (~1.54 Bs por mensaje).      │
│ • 1,000 SMS costarían $221.50 USD (~1,540 Bs).                                         │
│ • Desventaja: Es casi 20 VECES MÁS CARO que WhatsApp. Además, las operadoras           │
│   nacionales a veces filtran o demoran los mensajes extranjeros.                       │
│                                                                                        │
│ OPCIÓN B: Pasarela Nacional Corporativa (Entel Bolivia / Tigo Business)                │
│ • Costo aproximado por SMS: Entre 0.10 Bs. y 0.20 Bs. por mensaje.                     │
│ • 1,000 SMS costarían entre 100 y 200 Bs.                                              │
│ • Ventajas: Facturado en Bolivianos con crédito fiscal y remitente oficial ("COSMOL"). │
│ • Requisito: Trámite comercial institucional para firma de contrato y credenciales API.│
│                                                                                        │
│ OPCIÓN C: Gateway GSM Local con Módem y SIM Prepago                                    │
│ • Módem 4G USB en el servidor de COSMOL con un chip Entel/Tigo prepago.                │
│ • Costo: Paquetes de SMS corporativos de 20 a 50 Bs. al mes.                           │
│ • Limitación: Capacidad de envío limitada (1 SMS cada 2 a 3 segundos).                 │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Cuadro Comparativo Resumen: WhatsApp vs. SMS

| Criterio | WhatsApp Cloud API (Meta) | SMS Nacional (Entel/Tigo) | SMS Internacional (Twilio) |
|---|:---:|:---:|:---:|
| **Costo por OTP** | **~0.08 Bs.** ($0.0113 USD) | **~0.15 Bs.** | **~1.54 Bs.** ($0.2215 USD) |
| **Costo por 1,000 OTPs** | **~79 Bs.** | **~150 Bs.** | **~1,540 Bs.** |
| **Facilidad para el usuario** | Alta (botón directo "Copiar código") | Media (lectura manual) | Media (lectura manual) |
| **Tasa de entrega en Bolivia** | > 98% (casi todos usan WhatsApp) | ~ 95% | ~ 85% (bloqueos anti-spam) |
| **Infraestructura en COSMOL** | **Ya existe (WABA de Cosmol-Chatbot)** | Requiere convenio | Requiere cuenta en dólares |
| **Recomendación para Producción** | ⭐ **CANAL PRINCIPAL (95% tráfico)** | **RESPALDO (Fase 2)** | ❌ **DESCARTADO POR COSTO** |

---

## 5. ¿Qué se necesita exactamente para que deje de estar de adorno?

El código del backend en `whatsapp_client.py` **ya está 100% programado**. Para activarlo en vivo, solo se requiere el siguiente procedimiento:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                   PASO A PASO PARA ACTIVACIÓN EN VIVO (WHATSAPP)                       │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ 1. Crear y Aprobar la Plantilla en Meta Business Suite:                                │
│    • Ingresar a Meta WhatsApp Manager con la cuenta administradora de COSMOL.          │
│    • Ir a Plantillas de mensajes -> Crear plantilla.                                   │
│    • Nombre: codigo_autenticacion_cosmol                                               │
│    • Categoría: Autenticación | Idioma: Español.                                       │
│    • Botón: Copiar código.                                                             │
│    • Tiempo estimado de aprobación por Meta: 1 a 5 minutos.                            │
│                                                                                        │
│ 2. Obtener Credenciales de Meta:                                                       │
│    • WHATSAPP_PHONE_NUMBER_ID (ID del número oficial de COSMOL).                       │
│    • WHATSAPP_ACCESS_TOKEN (Token de sistema permanente, reutilizable de Chatbot).     │
│                                                                                        │
│ 3. Actualizar el archivo .env en el servidor:                                          │
│    MOCK_MESSAGING=false                                                                │
│    WHATSAPP_PHONE_NUMBER_ID=PONER_AQUI_ID_DEL_NUMERO                                   │
│    WHATSAPP_ACCESS_TOKEN=PONER_AQUI_TOKEN_PERMANENTE                                   │
│    WHATSAPP_OTP_TEMPLATE_NAME=codigo_autenticacion_cosmol                              │
│                                                                                        │
│ 4. Reiniciar el Backend:                                                               │
│    docker compose restart backend-api                                                  │
│                                                                                        │
│ ¡Listo! Desde ese instante, cada socio que solicite un código recibirá un WhatsApp     │
│ real de la línea oficial de COSMOL R.L. con el botón de copiado directo.               │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Conclusiones y Recomendaciones Estratégicas para la Directiva

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        RECOMENDACIONES PARA LOS EJECUTIVOS                             │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ 1. NO HAY QUE PAGAR FORTUNAS:                                                          │
│    WhatsApp cobra centavos de boliviano (~0.08 Bs por socio). Un presupuesto mensual   │
│    de 100 a 150 Bs cubre completamente la operación de miles de socios en Montero.     │
│                                                                                        │
│ 2. EL SOFTWARE YA ESTÁ LISTO:                                                          │
│    No se requiere desarrollo adicional. El backend normaliza teléfonos (+591), maneja  │
│    timeouts, gestiona TTLs en Redis y procesa respuestas de Meta automáticamente.      │
│                                                                                        │
│ 3. ESTRATEGIA CON SMS:                                                                 │
│    Descartar Twilio por su costo exorbitante (1.54 Bs por SMS). Se aconseja ocultar     │
│    temporalmente el botón de SMS en Flutter y trabajar al 100% con WhatsApp. Si se     │
│    desea SMS más adelante, gestionar un paquete local con Entel o Tigo Business.       │
│                                                                                        │
│ 4. PROTECCIÓN ANTI-ABUSO YA INCORPORADA:                                               │
│    El backend ya cuenta con un límite estricto de máximo 3 solicitudes de OTP por hora │
│    por número, impidiendo ataques o consumo desmedido de saldo en Meta.                │
└────────────────────────────────────────────────────────────────────────────────────────┘
```
