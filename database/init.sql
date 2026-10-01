-- ============================================================================
-- COSMOL R.L. - Plataforma de Socios (App Móvil y Web)
-- Script de Inicialización Automática de Base de Datos PostgreSQL
-- Montado en: /docker-entrypoint-initdb.d/init.sql
-- ============================================================================

-- 1. Extensiones requeridas para generación de UUIDs v4
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. Tabla de Auditoría OTP (Códigos de verificación WhatsApp / SMS)
CREATE TABLE IF NOT EXISTS otps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    telefono VARCHAR(20) NOT NULL,
    canal VARCHAR(20) NOT NULL,
    proposito VARCHAR(30) NOT NULL,
    fue_verificado BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_otps_id ON otps (id);
CREATE INDEX IF NOT EXISTS ix_otps_telefono ON otps (telefono);

-- 3. Tabla de Usuarios Digitales (Cuentas ligadas a número de celular verificado)
CREATE TABLE IF NOT EXISTS usuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    telefono VARCHAR(20) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    esta_activo BOOLEAN NOT NULL DEFAULT TRUE,
    intentos_fallidos INTEGER NOT NULL DEFAULT 0,
    bloqueado_hasta TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_usuarios_id ON usuarios (id);
CREATE INDEX IF NOT EXISTS ix_usuarios_telefono ON usuarios (telefono);

-- 4. Tabla de Suministros (Arquitectura Multicuenta: Códigos de socio vinculados)
CREATE TABLE IF NOT EXISTS suministros (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    cod_socio VARCHAR(20) NOT NULL,
    alias VARCHAR(50) NOT NULL DEFAULT 'Mi Suministro',
    rol VARCHAR(20) NOT NULL DEFAULT 'TITULAR',
    es_suministro_principal BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_usuario_cod_socio UNIQUE (usuario_id, cod_socio)
);

CREATE INDEX IF NOT EXISTS ix_suministros_id ON suministros (id);
CREATE INDEX IF NOT EXISTS ix_suministros_usuario_id ON suministros (usuario_id);
CREATE INDEX IF NOT EXISTS ix_suministros_cod_socio ON suministros (cod_socio);

-- 5. Tabla de Dispositivos (Sesión única estilo WhatsApp y tokens push FCM)
CREATE TABLE IF NOT EXISTS dispositivos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    device_id VARCHAR(100) NOT NULL,
    modelo_dispositivo VARCHAR(100) NULL,
    fcm_token TEXT NULL,
    ultimo_acceso TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_dispositivos_id ON dispositivos (id);
CREATE INDEX IF NOT EXISTS ix_dispositivos_usuario_id ON dispositivos (usuario_id);
CREATE INDEX IF NOT EXISTS ix_dispositivos_device_id ON dispositivos (device_id);

-- 6. Tabla de Documentos Fiscales y Avisos (Metadatos de Facturas, Avisos de Cobranza y Corte)
CREATE TABLE IF NOT EXISTS documentos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cod_socio VARCHAR(20) NOT NULL,
    tipo_documento VARCHAR(30) NOT NULL,
    nro_factura VARCHAR(50) NULL,
    nro_facip VARCHAR(50) NULL,
    cod_autorizacion VARCHAR(100) NULL,
    periodo VARCHAR(20) NOT NULL,
    anio INTEGER NOT NULL,
    mes INTEGER NOT NULL,
    monto_bs NUMERIC(10, 2) NOT NULL,
    s3_key VARCHAR(255) NOT NULL,
    fecha_emision DATE NOT NULL,
    fecha_vencimiento DATE NULL,
    estado_pago VARCHAR(20) NOT NULL,
    suministro_id UUID NULL REFERENCES suministros(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_socio_tipo_periodo UNIQUE (cod_socio, tipo_documento, periodo)
);

CREATE INDEX IF NOT EXISTS ix_documentos_id ON documentos (id);
CREATE INDEX IF NOT EXISTS ix_documentos_cod_socio ON documentos (cod_socio);
CREATE INDEX IF NOT EXISTS ix_documentos_tipo_documento ON documentos (tipo_documento);
CREATE INDEX IF NOT EXISTS ix_documentos_nro_factura ON documentos (nro_factura);
CREATE INDEX IF NOT EXISTS ix_documentos_suministro_id ON documentos (suministro_id);

-- 7. Tabla de Auditoría de Redirección a Pasarelas de Pago
CREATE TABLE IF NOT EXISTS auditoria_pagos_redireccion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    cod_socio VARCHAR(20) NOT NULL,
    canal_id VARCHAR(30) NOT NULL,
    monto_deuda_bs NUMERIC(10, 2) NOT NULL,
    ip_origen VARCHAR(50) NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_auditoria_pagos_redireccion_id ON auditoria_pagos_redireccion (id);
CREATE INDEX IF NOT EXISTS ix_auditoria_pagos_redireccion_usuario_id ON auditoria_pagos_redireccion (usuario_id);
CREATE INDEX IF NOT EXISTS ix_auditoria_pagos_redireccion_cod_socio ON auditoria_pagos_redireccion (cod_socio);
CREATE INDEX IF NOT EXISTS ix_auditoria_pagos_redireccion_canal_id ON auditoria_pagos_redireccion (canal_id);

-- 8. Tabla de Control de Versiones de Alembic (Mantiene sincronizado el ORM)
CREATE TABLE IF NOT EXISTS alembic_version (
    version_num VARCHAR(32) NOT NULL PRIMARY KEY
);

INSERT INTO alembic_version (version_num) 
VALUES ('204a5f9f8fef')
ON CONFLICT (version_num) DO NOTHING;
