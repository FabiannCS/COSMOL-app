# Guía de Implementación: Factores de Calidad en Proyectos de Software

El objetivo de este documento es servir como hoja de ruta para garantizar que los proyectos de software no solo cumplan con su función principal, sino que sean viables, seguros y escalables a largo plazo.

Para cada factor, se describe cómo aplicarlo durante el desarrollo y cómo evaluarlo de forma práctica.

## 1. Funcionalidad

El software debe cumplir exactamente con los requisitos del usuario sin presentar errores lógicos.

* **¿Cómo implementarlo en tus proyectos?**

  * Divide problemas grandes en funciones pequeñas y modulares de una sola responsabilidad.

  * Maneja correctamente los estados de error (ej. qué pasa si el usuario deja un campo vacío o se pierde la conexión).

* **¿Cómo evaluarlo?**

  * Verificación manual de los flujos principales del usuario (Happy Path) y de los casos extremos.

  * *(Opcional / Necesario en sistemas críticos)*: Implementar pruebas unitarias automatizadas para asegurar que la lógica base no se rompa al agregar nuevo código.

## 2. Seguridad

Protección de la información y restricción de accesos no autorizados.

* **¿Cómo implementarlo en tus proyectos?**

  * **Nunca** confíes en los datos que envía el usuario: valida y sanea siempre las entradas en el backend.

  * Usa variables de entorno (`.env`) para guardar contraseñas y credenciales; nunca las subas al repositorio.

  * Almacena contraseñas utilizando hashes seguros (ej. bcrypt).

* **¿Cómo evaluarlo?**

  * Intenta acceder a rutas protegidas sin estar logueado o ingresando caracteres extraños (`' OR 1=1`) en los formularios.

  * *(Opcional / Necesario en sistemas críticos)*: Auditorías de código automatizadas (SAST) y pruebas de penetración antes de lanzar a producción.

## 3. Rendimiento y Eficiencia

Respuesta rápida y consumo adecuado de recursos (CPU, memoria, base de datos).

* **¿Cómo implementarlo en tus proyectos?**

  * Asegúrate de poner índices a las tablas de tu base de datos en las columnas que usas para buscar (ej. por email o ID).

  * Optimiza las imágenes y recursos en el frontend.

  * Evita ciclos o bucles anidados (`for` dentro de `for`) innecesarios que procesen miles de registros al mismo tiempo.

* **¿Cómo evaluarlo?**

  * Mide el tiempo de carga de las páginas usando las herramientas de desarrollador del navegador (Network tab).

  * *(Opcional / Necesario en sistemas críticos)*: Herramientas de pruebas de carga para simular tráfico pesado si esperas picos altos de usuarios.

## 4. Mantenibilidad

Facilidad para leer, entender, corregir y mejorar el código en el futuro.

* **¿Cómo implementarlo en tus proyectos?**

  * Usa nombres descriptivos y en inglés para variables, funciones y clases (ej. usa `getUserById` en lugar de `getUsr2`).

  * Documenta el "por qué" de decisiones de código complejas, no lo obvio.

  * Mantén una estructura de carpetas coherente (separar rutas, controladores, modelos).

* **¿Cómo evaluarlo?**

  * Realiza revisiones de código (Code Reviews) con compañeros de equipo. Si a alguien más le cuesta entender tu código, hay que refactorizar.

  * *(Opcional / Necesario en sistemas críticos)*: Integrar "Linters" que fuercen un estilo de código estándar automáticamente.

## 5. Usabilidad

Diseño intuitivo, accesible y sin frustraciones para el usuario final.

* **¿Cómo implementarlo en tus proyectos?**

  * Proporciona retroalimentación visual clara (ej. un mensaje verde cuando se guarda algo, un "spinner" de carga mientras se espera una respuesta).

  * Asegúrate de que la aplicación sea responsiva (funcione bien en móviles y PC).

  * Mantén la navegación consistente en todas las pantallas.

* **¿Cómo evaluarlo?**

  * Pon el software en manos de usuarios reales (que no sean los desarrolladores) y observa dónde se confunden o atascan sin intervenir.

## 6. Escalabilidad

Capacidad de crecer para soportar más usuarios o datos sin tener que reescribir todo el sistema.

* **¿Cómo implementarlo en tus proyectos?**

  * Diseña el backend para que no guarde el estado de las sesiones en memoria del servidor local (usa tokens JWT o bases de datos como Redis para las sesiones).

  * Desacopla los servicios (por ejemplo, separa el frontend del backend mediante una API).

* **¿Cómo evaluarlo?**

  * Revisión de arquitectura: preguntarse "¿Qué parte colapsaría primero si los usuarios se multiplican por 100?".

## 7. Fiabilidad (Confiabilidad)

El software no debe caerse fácilmente y debe poder recuperarse de los errores.

* **¿Cómo implementarlo en tus proyectos?**

  * Implementa bloques `try / catch` robustos. Si una función falla, el sistema entero no debería caerse, sino mostrar un mensaje de error amigable y guardar un registro (log) del fallo.

  * Configura respaldos (backups) regulares de la base de datos.

* **¿Cómo evaluarlo?**

  * Apaga intencionalmente la base de datos y observa cómo reacciona el backend (¿Se cae o avisa que hay mantenimiento?).

## 8. Portabilidad

Capacidad de mover el proyecto fácilmente de un entorno a otro (de tu PC al servidor).

* **¿Cómo implementarlo en tus proyectos?**

  * Documenta todas las dependencias y bibliotecas necesarias (ej. `package.json`, `requirements.txt`).

  * No escribas rutas absolutas en el código (ej. `C:/usuarios/proyecto/archivo.png`), usa rutas relativas.

* **¿Cómo evaluarlo?**

  * Clona tu repositorio en una computadora diferente, sigue las instrucciones de instalación y verifica que se levante el entorno de desarrollo sin problemas.

  * *(Opcional / Necesario en sistemas críticos)*: Usar contenedores (Docker) para garantizar que el entorno de ejecución sea siempre idéntico.