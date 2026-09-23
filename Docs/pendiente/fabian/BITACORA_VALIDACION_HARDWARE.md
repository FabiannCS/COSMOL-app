# Bitácora de Validación de Integración en Hardware Real (Móvil Android USB)

> **Proyecto:** App de Socios COSMOL R.L. (Móvil + Web)  
> **Fase:** Fase 1 — Cierre de Fase e Integración Móvil USB  
> **Fecha:** Septiembre 2026  
> **Autor:** Desarrollador Frontend (Fabian)  

---

## 1. Requisitos Previos de Entorno y Hardware

1. Smartphone Android físico conectado a la computadora mediante cable USB original o de datos.
2. Modo **Depuración por USB (USB Debugging)** activado en las opciones de desarrollador del teléfono.
3. Entorno Docker con la API Backend (FastAPI + PostgreSQL + Redis) en ejecución escuchando en el puerto local `8000`.

---

## 2. Configuración del Túnel ADB (`adb reverse`)

Para que la aplicación en el dispositivo físico acceda al backend local de desarrollo en Docker sin problemas de red ni IPs cambiantes, ejecutamos el comando de redirección de puertos de Android Debug Bridge:

```bash
# 1. Verificar detección del smartphone físico por USB
adb devices

# Respuesta esperada:
# List of devices attached
# 19281FDE90023B    device

# 2. Configurar el túnel reverso de puertos
adb reverse tcp:8000 tcp:8000
```

Con `adb reverse tcp:8000 tcp:8000`, la aplicación Flutter ejecutándose en el teléfono físico consulta `http://localhost:8000/api/v1` de forma transparente.

---

## 3. Compilación y Ejecución en Dispositivo Físico

```bash
# Compilar e instalar la app Flutter en el smartphone Android
cd frontend
flutter run -d <device_id>
```

---

## 4. Guía de Prueba E2E Manual (Paso a Paso)

| Paso | Acción | Resultado Esperado | Estado |
|---|---|---|---|
| **1. Primer Acceso** | Iniciar app en el teléfono, ingresar Socio `104523` + CI `8392019`. | Avance automático al Paso 2 de asociación de celular. | PASADO |
| **2. OTP Dual** | Seleccionar canal **WhatsApp Cloud API**, ingresar celular `77012345` y recibir/digitar OTP de 6 dígitos. | Validación de código OTP exitosa y avance a pantalla de creación de PIN. | PASADO |
| **3. Creación de PIN** | Digitar PIN seguro `4455` y confirmar. | Registro completado y redirección automática al Dashboard. | PASADO |
| **4. Login Regular** | Cerrar sesión, e iniciar sesión con `104523` + PIN `4455`. | Ingreso inmediato al Dashboard. | PASADO |
| **5. Bloqueo de Cuenta** | Intentar login con PIN erróneo 3 veces seguidas. | Disparo de respuesta `ACCOUNT_LOCKED` de la API y visualización del modal con contador regresivo. | PASADO |
| **6. Navegación Fija** | Probar las 5 pestañas de la barra inferior (*Deuda*, *Consumo*, *Documentos*, *Suministros*, *Perfil*). | Transición fluida entre vistas sin parpadeos ni pérdidas de estado. | PASADO |
| **7. Multicuenta** | Vincular segundo suministro `104524` en Modo Consulta y Pago. | Adición inmediata a la lista y cambio de medidor activo en tiempo real. | PASADO |
