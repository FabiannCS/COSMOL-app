# Tarea 04: Analítica e Historial de Consumo (6 a 12 meses)

> **Estado:** PENDIENTE  
> **Fase:** Fase 4 — Analítica de Consumo Histórico  
> **Fecha de creación:** Septiembre 2026  
> **Documentos de referencia:** `AGENTS.md` (Secciones 4.5, 7.2, 10.5, 12.1, 12.2, 12.3) y `Docs/backend/guias/HOJA_DE_RUTA_DESARROLLO.md` (Fase 4)  
> **Entorno de ejecución:** Backend FastAPI en Docker (`cosmol-backend-api`, `cosmol-cache-redis`, `cosmol-db-postgres`)

---

## 1. Objetivo

Implementar el módulo de **Analítica e Historial de Consumo Mensual** para los asociados de COSMOL R.L. Este módulo da respuesta directa al requerimiento funcional oficial #10.5 y al objetivo de transparencia de la cooperativa: permitir al socio auditar sus hábitos de consumo mensual en metros cúbicos ($m^3$), comparar meses anteriores, evitar sorpresas en su facturación y detectar fugas o consumos atípicos a tiempo.

El sistema debe:
1. Extraer y estructurar el historial de lecturas y volúmenes facturados de los últimos **6 a 12 meses** desde el sistema comercial legado de COSMOL.
2. Implementar una estrategia de **caché en Redis (<20 ms)** con clave `consumo:{cod_socio}` y TTL de 15 minutos para proteger la base de datos legada ante consultas repetidas desde la app móvil.
3. Calcular métricas estadísticas clave: consumo promedio en $m^3$, mes de mayor y menor consumo, y activación automática de una bandera de alerta (`consumo_atipico = True`) cuando el consumo mensual supere en un **30% o más** el promedio habitual.
4. Respetar la arquitectura **Multicuenta**:
   * **Modo Titular:** Acceso completo al histórico, números de medidor, lecturas anteriores y actuales.
   * **Modo Consulta y Pago (Inquilino):** Acceso a los volúmenes en $m^3$ e importes en Bs para control de gastos, enmascarando cualquier dato personal o tributario confidencial del propietario.
5. Proveer un contrato REST optimizado para el renderizado directo de gráficos de barras o líneas en Flutter (`fl_chart`).

---

## 2. Reglas de Negocio Oficiales (AGENTS.md)

1. **Rango Temporal Mínimo (Sección 10.5 AGENTS.md):**
   * El servicio debe entregar datos precisos de **al menos los últimos 6 meses** (idealmente hasta 12 meses según disponibilidad del sistema legado).
   * Los periodos deben ordenarse cronológicamente de forma clara para su representación gráfica (ejes: **Meses vs. Volumen consumido en $m^3$**).

2. **Variables Requeridas por Periodo de Consumo:**
   * `periodo`: Cadena formateada `MM/YYYY` (ej: `"08/2026"`).
   * `mes`: Entero del mes (1 - 12).
   * `anio`: Entero del año (ej: 2026).
   * `consumo_m3`: Volumen facturado en metros cúbicos ($m^3$).
   * `monto_bs`: Importe facturado asociado al periodo en Bolivianos (`Bs`).
   * `lectura_anterior`: Valor numérico registrado en el medidor al inicio del ciclo.
   * `lectura_actual`: Valor numérico registrado en el medidor al cierre del ciclo.
   * `fecha_lectura`: Fecha oficial de toma de lectura por el personal de COSMOL.
   * `estado_lectura`: Estado de la medición (`"NORMAL"`, `"ESTIMADA"`, `"REMEDICION"`).

3. **Detección de Consumos Atípicos (Fase 4 HOJA DE RUTA):**
   * El backend debe calcular el promedio mensual de consumo:
     $$\text{Promedio } m^3 = \frac{\sum_{i=1}^{N} \text{consumo\_m3}_i}{N}$$
   * Si en el último mes registrado:
     $$\text{consumo\_m3}_{\text{actual}} \ge 1.30 \times \text{Promedio } m^3$$
     Se debe encender la bandera `consumo_atipico = True` y generar un mensaje preventivo de posible fuga o exceso de consumo.

4. **Caché Resiliente en Redis (Sección 12.2 AGENTS.md):**
   * Clave Redis: `consumo:{cod_socio}`.
   * TTL: 900 segundos (15 minutos).
   * Tiempo de respuesta esperado en *cache-hit*: **< 20 milisegundos**.

5. **Privacidad y Control de Acceso (Sección 4.6 AGENTS.md):**
   * El socio solo puede consultar consumos de suministros vinculados a su cuenta en PostgreSQL (`suministros`).
   * Consultas a códigos de socio ajenos deben ser rechazadas con `403 Forbidden` (`FORBIDDEN_SUPPLY_ACCESS`).

---

## 3. Asignación y División Modular de Trabajo

```
┌────────────────────────────────────────────────────────────────────────┐
│                   DIVISIÓN MODULAR FASE 4                              │
├───────────────────────────────────┬────────────────────────────────────┤
│       DEV 1 (Aireyu)              │       DEV 2 (Eduardo)              │
├───────────────────────────────────┼────────────────────────────────────┤
│ • Cliente Legado COSMOL           │ • Esquemas Pydantic v2             │
│   (`obtener_historial_consumo`)   │   (`schemas/consumo.py`)           │
│ • Mock de datos deterministas     │ • Servicio de Negocio              │
│   (6 a 12 meses para socios test) │   (`servicio_consumo.py`)          │
│ • Integración de Caché Redis      │ • Algoritmo de Consumo Atípico     │
│   (TTL 15 min con fallback)       │   (+30% sobre promedio histórico)  │
│ • Tests de integración DEV 1      │ • Endpoint REST (`consumo.py`)     │
│   (Cliente legado + Redis cache)  │ • Tests de endpoints y permisos    │
└───────────────────────────────────┴────────────────────────────────────┘
```

---

## 4. Detalle de Entregables Técnicos

### 4.1 Entregables de DEV 1: Integración con Sistema Legado y Caché Redis

#### A. Integración en `backend/app/integrations/cosmol_client.py` (Preparado para API Real):
- [x] Incorporar el método `obtener_historial_consumo(cod_socio: str, meses: int = 12) -> List[Dict[str, Any]]`:
  - **Modo Real (`MOCK_COSMOL_LEGACY = False`):** Consumo del endpoint legado `GET /socios/{cod_socio}/consumos` con timeout estricto (4s) y fallback seguro en modo desarrollo.
  - **Normalizador Tolerante (`_normalizar_consumo_legado`):** Mapeo defensivo de variantes de campos legados Informix (`CONSUMO_M3`/`VOLUMEN`/`M3`, `ANIO`/`GESTION`, `MES`/`NMES`, `LECTURA_ACTUAL`/`LECT_ACT`, `MONTOTOTAL`/`IMPORTE`), limpieza de espacios en blanco (`.strip()`) y redondeo.
  - **Modo Simulación (`MOCK_COSMOL_LEGACY = True` / `MOCK_COSMOL_CONSUMO = True`):** Dataset determinista enriquecido `MOCK_CONSUMOS_LEGADO` con 6 a 12 meses para socios de prueba (`556`, `540`, `1001`, `1002`, `1003`):
    - Variaciones estacionales realistas de Montero (15 $m^3$ a 28 $m^3$).
    - Caso de prueba con pico atípico (>30% de incremento) en el socio `540` para validar alertas de fugas.

#### B. Servicio de Caché en Redis:
- [x] Implementar funciones de caché para consumos en `backend/app/services/servicio_cache_consumo.py`:
  - `obtener_consumo_cache(redis: Redis, cod_socio: str) -> Optional[Dict[str, Any]]` (<20ms).
  - `guardar_consumo_cache(redis: Redis, cod_socio: str, datos: Dict[str, Any], ttl: int = 900) -> None` (TTL 15 min).
  - `invalidar_consumo_cache(redis: Redis, cod_socio: str) -> None`.

#### C. Batería de Pruebas DEV 1:
- [x] `backend/tests/test_cosmol_client_consumo.py`:
  - Consulta exitosa de historial de consumo (retorno de $\ge 6$ meses).
  - Normalización de variaciones de claves de Informix y limpieza de espacios.
  - Verificación del pico atípico (+75%) en el socio `540` para alerta de fuga.
  - Generación sintética determinista para socios no listados.
- [x] `backend/tests/test_cache_consumo.py`:
  - Verificación de *cache-hit* en Redis con latencia <20 ms.
  - Verificación de expiración por TTL (900s) e invalidación manual.
  - Resiliencia y degradación suave ante desconexión de Redis.

---

### 4.2 Entregables de DEV 2: Esquemas, Lógica de Negocio y Endpoints REST

#### A. Esquemas Pydantic v2 (`backend/app/schemas/consumo.py`):
- [ ] `ConsumoPeriodoResponse`:
  - `periodo`: str (ej. `"08/2026"`).
  - `mes`: int.
  - `anio`: int.
  - `consumo_m3`: float.
  - `monto_bs`: float.
  - `lectura_anterior`: float.
  - `lectura_actual`: float.
  - `fecha_lectura`: Optional[str].
  - `estado_lectura`: str.
- [ ] `EstadisticasConsumoResponse`:
  - `promedio_m3`: float.
  - `consumo_maximo_m3`: float.
  - `mes_consumo_maximo`: str.
  - `consumo_minimo_m3`: float.
  - `mes_consumo_minimo`: str.
  - `consumo_ultimo_mes_m3`: float.
  - `consumo_atipico`: bool.
  - `mensaje_alerta`: Optional[str].
  - `tendencia`: str (`"SUBIENDO"`, `"BAJANDO"`, `"ESTABLE"`).
- [ ] `HistorialConsumoResponse`:
  - `cod_socio`: str.
  - `rol_acceso`: str (`"TITULAR"` o `"CONSULTA_PAGO"`).
  - `nro_medidor`: Optional[str] (enmascarado para inquilinos).
  - `total_periodos`: int.
  - `periodos`: List[ConsumoPeriodoResponse].
  - `estadisticas`: EstadisticasConsumoResponse.

#### B. Servicio de Negocio (`backend/app/services/servicio_consumo.py`):
- [ ] Implementar clase `ServicioConsumo`:
  - `consultar_historial_consumo(usuario_id: UUID, cod_socio: str, forzar_refresco: bool = False) -> HistorialConsumoResponse`.
  - Validación de suministro en PostgreSQL (`db: AsyncSession`): comprobación de titularidad y rol.
  - Orquestación de caché: consulta a Redis antes de invocar al cliente legado.
  - Algoritmo de cálculo estadístico y detección de consumos atípicos ($\ge +30\%$).
  - Enmascaramiento de datos confidenciales para roles de solo pago.

#### C. Endpoints REST (`backend/app/api/v1/consumo.py`):
- [ ] `GET /api/v1/consumo/{cod_socio}`:
  - Parámetro opcional: `forzar_refresco: bool = False`.
  - Seguridad: Requiere Bearer JWT (`get_current_user`).
  - Respuestas documentadas: `200 OK`, `401 Unauthorized`, `403 Forbidden`, `404 Not Found`.
- [ ] `POST /api/v1/consumo/{cod_socio}/invalidar-cache`:
  - Endpoint administrativo/refresco manual para forzar nueva lectura.
- [ ] Registrar `consumo_router` en `backend/app/api/v1/router.py`.

#### D. Batería de Pruebas DEV 2 (`backend/tests/test_consumo.py`):
- [ ] Prueba de cálculo estadístico exacto (promedio, máximos y mínimos).
- [ ] Prueba de detección de anomalía (+30% activa `consumo_atipico = True`).
- [ ] Prueba de control de acceso multicuenta: suministro propio vs suministro ajeno (retorno de 403).
- [ ] Prueba de endpoint HTTP `GET /api/v1/consumo/{cod_socio}` con cliente de pruebas.

---

## 5. Criterios de Aceptación y Validación

1. [ ] **Cobertura Histórica:** La API retorna al menos **6 meses consecutivos** de lecturas y consumos en $m^3$ ordenados cronológicamente.
2. [ ] **Rendimiento (<20 ms):** Las consultas repetidas se sirven directamente desde Redis con latencia inferior a 20 ms.
3. [ ] **Detección de Fugas / Anomalías:** Si el último consumo supera en 30% o más el promedio histórico, la respuesta incluye `consumo_atipico: true` y un mensaje de recomendación de inspección de instalaciones.
4. [ ] **Seguridad Multicuenta:** Solo los usuarios autenticados con suministros asociados pueden consultar su historial; cualquier intento de consulta a códigos no vinculados devuelve `403 Forbidden`.
5. [ ] **Compatibilidad con Flutter:** El payload JSON responde a la estructura esperada por `fl_chart` para pintar de inmediato gráficos de barras o líneas sin transformaciones pesadas en el cliente móvil.
6. [ ] **Suite de Pruebas en Verde:** Los tests de Fase 4 pasan al 100% en Docker, sumándose a los 70 tests ya existentes sin regresiones.
