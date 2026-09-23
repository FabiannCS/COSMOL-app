# Guía de Implementación: Módulo de Reportes de la App de Socios en COSMOL-Reportes

> **Proyecto Destino:** `COSMOL-Reportes` (Sistema Web de Auditoría y Reportes de COSMOL R.L.)  
> **Ubicación del Documento:** `Docs/reportes/GUIA_VISTA_APP_SOCIOS_COSMOL_REPORTES.md`  
> **Fecha:** Septiembre 2026  
> **Objetivo:** Guía técnica para implementar la vista exclusiva **"App de Socios"** en la sección de **Reportes** de `COSMOL-Reportes`, visualizando en tiempo real los movimientos, logins, consultas de deuda, consumos y pagos generados desde la aplicación móvil.

---

> [!IMPORTANT]
> ### REGLA DE ARQUITECTURA: CERO CAMBIOS DE ESQUEMA EN BASE DE DATOS
> * **No se agregan nuevos atributos ni columnas:** Ninguna base de datos requiere `ALTER TABLE` ni cambios en sus tablas.
> * **Todo viaja en el body del JSON:** La App Móvil simplemente envía el número `3` en el body del `POST` (`id_usuario: 3`), exactamente de la misma manera que el Chatbot de WhatsApp envía el número `2`.
> * **El esquema existente ya lo soporta:** Tanto la tabla `consulta` como las columnas `id_usuario`, `tipo_ubicacion`, `codigo_socio`, etc., ya existen y están preparadas para recibir este valor.

---

## 1. Visión General de la Integración

```
┌─────────────────────────────────────────────────────────┐
│                 App de Socios (COSMOL-app)              │
│       [Login, Deuda, Facturas, Consumos, Pagos]         │
└────────────────────────────┬────────────────────────────┘
                             │
                             │ HTTP POST /api/consultas (Background)
                             │ Body JSON: { "id_usuario": 3, "tipo_ubicacion": "APP_MOVIL", ... }
                             │ Header: X-Reportes-Token: {TOKEN}
                             ▼
┌─────────────────────────────────────────────────────────┐
│                 COSMOL-Reportes (:8080)                 │
│  • Backend: ConsultaApiController::registrar()          │
│    Guarda el evento con id_usuario = 3 en tabla consulta│
│  • Frontend Web: Nueva vista en /reportes/app-socios    │
│    (Tarjetas KPI, Filtros interactivos y Tabla paginada)│
└─────────────────────────────────────────────────────────┘
```

---

# PARTE 1: CAMBIOS EN EL BACKEND

Los cambios a nivel de backend se encargan de la recepción de datos, el procesamiento de filtros y la consulta a la base de datos sin alterar ninguna estructura existente.

---

### 1.1 Contrato del Body JSON (Emisor: App / Receptor: Reportes)

El backend de la App despacha un `POST /api/consultas` con el número `3` en el payload:

* **Endpoint:** `POST /api/consultas`
* **Header de Autenticación:** `X-Reportes-Token: {REPORTES_API_TOKEN}`
* **Body JSON:**
  ```json
  {
    "codigo_socio": 23807,
    "nombres": "MISERICORDIA AGUANTA EDDY FRANCO",
    "telefono": "+59171029384",
    "id_usuario": 3,
    "id_tipo": 2,
    "tipo_consulta": "Consulta de Deuda",
    "tipo_ubicacion": "APP_MOVIL",
    "fecha_consulta": "2026-09-22",
    "hora_consulta": "15:30:00"
  }
  ```

---

### 1.2 Controlador Receptor de Eventos (`app/Controllers/ConsultaApiController.php`)

En el controlador existente de `COSMOL-Reportes`, asegurar que el valor `id_usuario` recibido en el body (número `3`) se persista en la columna `id_usuario` de la tabla `consulta`:

```php
// En app/Controllers/ConsultaApiController.php -> método registrar()

// Capturar id_usuario enviado en el body (3 para App Móvil, 2 para Chatbot)
$idUsuario = isset($input['id_usuario']) && !empty($input['id_usuario']) 
    ? (int)$input['id_usuario'] 
    : (($tipoUbicacion === 'APP_MOVIL') ? 3 : 2);

// Inserción en la tabla existente 'consulta' (sin modificar columnas):
$stmt = $db->prepare("
    INSERT INTO consulta (codigo_socio, nombres, telefono, tipo_ubicacion, fecha_consulta, hora_consulta, id_tipo, id_usuario)
    VALUES (:codigo_socio, :nombres, :telefono, :tipo_ubicacion, :fecha_consulta, :hora_consulta, :id_tipo, :id_usuario)
");

$stmt->execute([
    ':codigo_socio'   => $codigoSocio,
    ':nombres'        => $nombres,
    ':telefono'       => $telefono,
    ':tipo_ubicacion' => $tipoUbicacion,
    ':fecha_consulta' => $fecha,
    ':hora_consulta'  => $hora,
    ':id_tipo'        => $idTipo,
    ':id_usuario'     => $idUsuario
]);
```

---

### 1.3 Registro de Rutas Backend (`app/Config/routes.php`)

Registrar la ruta web que atenderá la petición del nuevo reporte en `COSMOL-Reportes`:

```php
// En app/Config/routes.php:
'/reportes/app-socios' => ['ReporteController', 'visualizarAppSocios', ['reportes.ver']],
```

---

### 1.4 Consultas y Lógica de Datos (`app/Models/Reporte.php`)

Incorporar en el modelo existente `Reporte.php` los métodos para consultar exclusivamente los datos de la App de Socios (`c.id_usuario = 3 OR c.tipo_ubicacion = 'APP_MOVIL'`):

```php
/**
 * Totales para las Tarjetas KPI agrupadas por tipo de evento de la App Móvil.
 */
public function getTotalesPorTipoConsultaApp($filtros = [])
{
    $sql = "SELECT 
                t.id_tipo,
                t.nombre,
                t.descripcion,
                COUNT(c.id_consulta) as total
            FROM tipo_consulta t
            LEFT JOIN consulta c ON t.id_tipo = c.id_tipo 
                 AND (c.id_usuario = 3 OR c.tipo_ubicacion = 'APP_MOVIL')";

    $params = [];
    $conditions = [];

    if (!empty($filtros['fecha_inicio'])) {
        $conditions[] = "c.fecha_consulta >= :fecha_inicio";
        $params[':fecha_inicio'] = $filtros['fecha_inicio'];
    }

    if (!empty($filtros['fecha_fin'])) {
        $conditions[] = "c.fecha_consulta <= :fecha_fin";
        $params[':fecha_fin'] = $filtros['fecha_fin'];
    }

    if (!empty($filtros['buscar'])) {
        $conditions[] = "(c.codigo_socio::text ILIKE :buscar OR c.nombres ILIKE :buscar OR c.telefono ILIKE :buscar)";
        $params[':buscar'] = '%' . $filtros['buscar'] . '%';
    }

    if (!empty($conditions)) {
        $sql .= " WHERE " . implode(" AND ", $conditions);
    }

    $sql .= " GROUP BY t.id_tipo, t.nombre, t.descripcion ORDER BY t.id_tipo ASC";

    $stmt = $this->db()->prepare($sql);
    $stmt->execute($params);
    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}

/**
 * Listado paginado de eventos exclusivos de la App de Socios.
 */
public function getConsultasAppPaginadas($filtros, $limit, $offset)
{
    $sql = "SELECT c.id_consulta, c.codigo_socio, c.nombres, c.telefono, c.tipo_ubicacion, 
                   c.fecha_consulta, c.hora_consulta, t.nombre as tipo, u.username
            FROM consulta c
            LEFT JOIN tipo_consulta t ON c.id_tipo = t.id_tipo
            LEFT JOIN usuario u ON c.id_usuario = u.id_usuario
            WHERE (c.id_usuario = 3 OR c.tipo_ubicacion = 'APP_MOVIL')";

    $params = [];

    if (!empty($filtros['fecha_inicio'])) {
        $sql .= " AND c.fecha_consulta >= :fecha_inicio";
        $params[':fecha_inicio'] = $filtros['fecha_inicio'];
    }

    if (!empty($filtros['fecha_fin'])) {
        $sql .= " AND c.fecha_consulta <= :fecha_fin";
        $params[':fecha_fin'] = $filtros['fecha_fin'];
    }

    if (!empty($filtros['id_tipo'])) {
        $sql .= " AND c.id_tipo = :id_tipo";
        $params[':id_tipo'] = $filtros['id_tipo'];
    }

    if (!empty($filtros['buscar'])) {
        $sql .= " AND (c.codigo_socio::text ILIKE :buscar OR c.nombres ILIKE :buscar OR c.telefono ILIKE :buscar)";
        $params[':buscar'] = '%' . $filtros['buscar'] . '%';
    }

    $sql .= " ORDER BY c.fecha_consulta DESC, c.hora_consulta DESC, c.id_consulta DESC";
    $sql .= " LIMIT :limit OFFSET :offset";

    $stmt = $this->db()->prepare($sql);
    foreach ($params as $key => $val) {
        $stmt->bindValue($key, $val);
    }
    $stmt->bindValue(':limit', (int)$limit, PDO::PARAM_INT);
    $stmt->bindValue(':offset', (int)$offset, PDO::PARAM_INT);

    $stmt->execute();
    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}

/**
 * Conteo total para calcular la paginación.
 */
public function getTotalConsultasApp($filtros)
{
    $sql = "SELECT COUNT(c.id_consulta) as total
            FROM consulta c
            WHERE (c.id_usuario = 3 OR c.tipo_ubicacion = 'APP_MOVIL')";

    $params = [];
    if (!empty($filtros['fecha_inicio'])) {
        $sql .= " AND c.fecha_consulta >= :fecha_inicio";
        $params[':fecha_inicio'] = $filtros['fecha_inicio'];
    }
    if (!empty($filtros['fecha_fin'])) {
        $sql .= " AND c.fecha_consulta <= :fecha_fin";
        $params[':fecha_fin'] = $filtros['fecha_fin'];
    }
    if (!empty($filtros['id_tipo'])) {
        $sql .= " AND c.id_tipo = :id_tipo";
        $params[':id_tipo'] = $filtros['id_tipo'];
    }
    if (!empty($filtros['buscar'])) {
        $sql .= " AND (c.codigo_socio::text ILIKE :buscar OR c.nombres ILIKE :buscar OR c.telefono ILIKE :buscar)";
        $params[':buscar'] = '%' . $filtros['buscar'] . '%';
    }

    $stmt = $this->db()->prepare($sql);
    $stmt->execute($params);
    $res = $stmt->fetch(PDO::FETCH_ASSOC);
    return (int)($res['total'] ?? 0);
}
```

---

### 1.5 Controlador de la Vista (`app/Controllers/ReporteController.php`)

Agregar el método que procesa la petición web, valida permisos y despacha los datos a la vista:

```php
public function visualizarAppSocios()
{
    $fechaInicio = isset($_GET['fecha_inicio']) && $_GET['fecha_inicio'] !== '' ? trim($_GET['fecha_inicio']) : null;
    $fechaFin    = isset($_GET['fecha_fin']) && $_GET['fecha_fin'] !== '' ? trim($_GET['fecha_fin']) : null;
    $idTipo      = isset($_GET['id_tipo']) && $_GET['id_tipo'] !== '' ? (int)$_GET['id_tipo'] : null;
    $buscar      = isset($_GET['buscar']) && $_GET['buscar'] !== '' ? trim($_GET['buscar']) : null;

    $filtros = [
        'fecha_inicio' => $fechaInicio,
        'fecha_fin'    => $fechaFin,
        'id_tipo'      => $idTipo,
        'buscar'       => $buscar,
    ];

    $pagina = isset($_GET['p']) ? (int)$_GET['p'] : 1;
    if ($pagina < 1) $pagina = 1;
    $limit = 15;
    $offset = ($pagina - 1) * $limit;

    $tiposConsulta   = $this->reporteModel->getTiposConsulta();
    $totalesPorTipo  = $this->reporteModel->getTotalesPorTipoConsultaApp($filtros);
    $totalRegistros  = $this->reporteModel->getTotalConsultasApp($filtros);
    $consultas       = $this->reporteModel->getConsultasAppPaginadas($filtros, $limit, $offset);
    $totalPaginas    = (int)ceil($totalRegistros / $limit) ?: 1;

    $this->render('reportes/app_socios', [
        'titulo'          => 'Movimientos de la App de Socios',
        'consultas'       => $consultas,
        'tiposConsulta'   => $tiposConsulta,
        'totalesPorTipo'  => $totalesPorTipo,
        'filtros'         => $filtros,
        'paginaActual'    => $pagina,
        'totalPaginas'    => $totalPaginas,
        'totalRegistros'  => $totalRegistros
    ]);
}
```

---

# PARTE 2: CAMBIOS EN EL FRONTEND

Esta parte cubre únicamente la capa de presentación visual: el menú lateral y la pantalla de reportes en `COSMOL-Reportes`, y la clarificación sobre la app móvil.

---

### 2.1 Menú Lateral de Navegación (`app/Views/layouts/partials/sidebar.php`)

Agregar el acceso directo **"App de Socios"** en la barra lateral, debajo de la sección **Reportes**:

```php
<!-- Módulo Reportes (Visible para Administrador y Supervisor) -->
<?php if ($rolActual !== 'Operador' && $hasPermission('reportes.ver')): ?>
    <li class="sidebar-section-title">Reportes</li>

    <!-- 1. Reporte de Consultas Chatbot (WhatsApp) -->
    <li class="nav-item">
        <a class="nav-link <?= $isActive('/reportes/visualizar') ?>" href="/reportes/visualizar" data-bs-toggle="tooltip" data-bs-placement="right" data-bs-title="Consultas Chatbot">
            <i class="bi bi-whatsapp"></i>
            <span style="color: #f8fafc;">Consultas Chatbot</span>
        </a>
    </li>

    <!-- 2. NUEVO: Reporte de Movimientos de la App de Socios -->
    <li class="nav-item">
        <a class="nav-link <?= $isActive('/reportes/app-socios') ?>" href="/reportes/app-socios" data-bs-toggle="tooltip" data-bs-placement="right" data-bs-title="App de Socios">
            <i class="bi bi-phone"></i>
            <span style="color: #f8fafc;">App de Socios</span>
        </a>
    </li>
<?php endif; ?>
```

---

### 2.2 Pantalla Visual del Reporte (`app/Views/reportes/app_socios.php`)

Crear la vista completa que renderiza las tarjetas métricas, los filtros y la tabla interactiva:

```html
<div class="container-fluid py-4">
    <!-- Encabezado -->
    <div class="d-flex justify-content-between align-items-center mb-4">
        <div>
            <h4 class="mb-1 fw-bold text-dark">
                <i class="bi bi-phone text-primary me-2"></i>Reporte de Movimientos — App de Socios
            </h4>
            <p class="text-muted small mb-0">Auditoría en tiempo real de consultas, descargas y accesos desde la aplicación móvil</p>
        </div>
        <span class="badge bg-primary px-3 py-2 fs-7">
            <i class="bi bi-check-circle me-1"></i> Canal: App Móvil (id_usuario = 3)
        </span>
    </div>

    <!-- Tarjetas KPI Resumen -->
    <div class="row g-3 mb-4">
        <div class="col-md-3">
            <div class="card border-0 shadow-sm p-3 border-start border-primary border-4 rounded-3">
                <span class="text-muted small fw-semibold">Accesos y Logins</span>
                <h3 class="fw-bold mb-0 text-primary mt-1"><?= $totalesPorTipo[1]['total'] ?? 0 ?></h3>
            </div>
        </div>
        <div class="col-md-3">
            <div class="card border-0 shadow-sm p-3 border-start border-info border-4 rounded-3">
                <span class="text-muted small fw-semibold">Consultas de Deuda</span>
                <h3 class="fw-bold mb-0 text-info mt-1"><?= $totalesPorTipo[2]['total'] ?? 0 ?></h3>
            </div>
        </div>
        <div class="col-md-3">
            <div class="card border-0 shadow-sm p-3 border-start border-warning border-4 rounded-3">
                <span class="text-muted small fw-semibold">Historial de Consumo</span>
                <h3 class="fw-bold mb-0 text-warning mt-1"><?= $totalesPorTipo[3]['total'] ?? 0 ?></h3>
            </div>
        </div>
        <div class="col-md-3">
            <div class="card border-0 shadow-sm p-3 border-start border-success border-4 rounded-3">
                <span class="text-muted small fw-semibold">Descargas PDF y Pagos</span>
                <h3 class="fw-bold mb-0 text-success mt-1">
                    <?= ($totalesPorTipo[9]['total'] ?? 0) + ($totalesPorTipo[10]['total'] ?? 0) ?>
                </h3>
            </div>
        </div>
    </div>

    <!-- Barra de Filtros -->
    <div class="card border-0 shadow-sm mb-4 rounded-3">
        <div class="card-body p-3">
            <form method="GET" action="/reportes/app-socios" class="row g-2 align-items-end">
                <div class="col-md-3">
                    <label class="form-label small fw-semibold text-muted">Fecha Desde</label>
                    <input type="date" name="fecha_inicio" class="form-control form-control-sm" value="<?= htmlspecialchars($filtros['fecha_inicio'] ?? '') ?>">
                </div>
                <div class="col-md-3">
                    <label class="form-label small fw-semibold text-muted">Fecha Hasta</label>
                    <input type="date" name="fecha_fin" class="form-control form-control-sm" value="<?= htmlspecialchars($filtros['fecha_fin'] ?? '') ?>">
                </div>
                <div class="col-md-3">
                    <label class="form-label small fw-semibold text-muted">Tipo de Movimiento</label>
                    <select name="id_tipo" class="form-select form-select-sm">
                        <option value="">-- Todos los Movimientos --</option>
                        <option value="1" <?= ($filtros['id_tipo'] == 1) ? 'selected' : '' ?>>Autenticación / Acceso</option>
                        <option value="2" <?= ($filtros['id_tipo'] == 2) ? 'selected' : '' ?>>Consulta de Deuda</option>
                        <option value="3" <?= ($filtros['id_tipo'] == 3) ? 'selected' : '' ?>>Historial de Consumos</option>
                        <option value="9" <?= ($filtros['id_tipo'] == 9) ? 'selected' : '' ?>>Descarga de PDF</option>
                        <option value="10" <?= ($filtros['id_tipo'] == 10) ? 'selected' : '' ?>>Intento de Pago</option>
                    </select>
                </div>
                <div class="col-md-3 d-flex gap-2">
                    <button type="submit" class="btn btn-primary btn-sm w-100">
                        <i class="bi bi-funnel me-1"></i>Filtrar
                    </button>
                    <a href="/reportes/app-socios" class="btn btn-outline-secondary btn-sm">
                        <i class="bi bi-x-circle"></i>
                    </a>
                </div>
            </form>
        </div>
    </div>

    <!-- Tabla de Resultados -->
    <div class="card border-0 shadow-sm rounded-3">
        <div class="table-responsive">
            <table class="table table-hover align-middle mb-0">
                <thead class="table-light">
                    <tr>
                        <th class="ps-3"># ID</th>
                        <th>Cód. Socio</th>
                        <th>Nombre Titular</th>
                        <th>Teléfono</th>
                        <th>Acción Realizada</th>
                        <th>Fecha y Hora</th>
                        <th class="text-center">Canal</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($consultas)): ?>
                        <tr>
                            <td colspan="7" class="text-center py-4 text-muted">
                                <i class="bi bi-inbox fs-3 d-block mb-2"></i>No se encontraron movimientos registrados para la App de Socios.
                            </td>
                        </tr>
                    <?php else: ?>
                        <?php foreach ($consultas as $item): ?>
                            <tr>
                                <td class="ps-3 fw-bold text-muted"><?= $item['id_consulta'] ?></td>
                                <td><span class="badge bg-light text-dark border"><?= $item['codigo_socio'] ?></span></td>
                                <td class="fw-semibold"><?= htmlspecialchars($item['nombres'] ?? 'No disponible') ?></td>
                                <td><?= htmlspecialchars($item['telefono'] ?? '-') ?></td>
                                <td>
                                    <span class="badge bg-primary-subtle text-primary border border-primary-subtle px-2 py-1">
                                        <?= htmlspecialchars($item['tipo'] ?? 'Consulta General') ?>
                                    </span>
                                </td>
                                <td class="small text-muted"><?= $item['fecha_consulta'] ?> <?= $item['hora_consulta'] ?></td>
                                <td class="text-center">
                                    <span class="badge bg-secondary px-2">APP_MOVIL</span>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>
</div>
```

---

### 2.3 Impacto en el Frontend Móvil (`COSMOL-app` / Flutter)

* **Cero cambios en la UI de Flutter:**
  * El socio en su teléfono no ve nada diferente ni se le pide interacción adicional.
  * Cuando el socio consulta su deuda, descarga una factura o inicia sesión, el backend de FastAPI es quien despacha el evento en segundo plano (`BackgroundTasks`) de manera 100% silenciosa y sin consumir recursos de su teléfono.

---

## 3. Resumen y Criterios de Aprobación

| Componente | Capa | Acción Requerida | Estado de Base de Datos |
| :--- | :--- | :--- | :--- |
| **API Receiver** | Backend PHP | Capturar `id_usuario: 3` en `POST /api/consultas` | **Sin cambios de columnas** |
| **Modelo Reporte** | Backend PHP | Agregar consultas filtrando por `id_usuario = 3` | **Sin cambios de columnas** |
| **Rutas** | Backend PHP | Registrar `/reportes/app-socios` | No aplica |
| **Sidebar** | Frontend Web | Agregar botón "App de Socios" con icono celular | No aplica |
| **Vista Web** | Frontend Web | Crear `app_socios.php` con KPIs y tabla paginada | No aplica |
| **Flutter App** | Frontend Móvil | **Ninguno** (transparente e invisible) | No aplica |
