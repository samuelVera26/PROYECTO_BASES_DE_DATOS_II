--  Bases de Datos 2 – Primer Entregable
-- 1. CREACIÓN DE TABLAS 


--ARTISTAS
CREATE TABLE artistas (
    id_artista      SERIAL PRIMARY KEY,
    nombre          VARCHAR(120) NOT NULL,
    nombre_artistico VARCHAR(120),
    nacionalidad    VARCHAR(80)  NOT NULL,
    genero_musical  VARCHAR(80)  NOT NULL DEFAULT 'Electrónica',
    subgenero       VARCHAR(80),
    descripcion     TEXT,
    redes_sociales  VARCHAR(200),
    fecha_registro  DATE         NOT NULL DEFAULT CURRENT_DATE,
    activo          BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_artista_nombre CHECK (LENGTH(TRIM(nombre)) > 0)
);

--CONTRATOS
CREATE TABLE contratos (
    id_contrato     SERIAL PRIMARY KEY,
    id_artista      INT          NOT NULL REFERENCES artistas(id_artista) ON DELETE RESTRICT,
    fecha_firma     DATE         NOT NULL,
    monto_base      NUMERIC(14,2) NOT NULL,
    moneda          CHAR(3)      NOT NULL DEFAULT 'COP',
    porcentaje_royalties NUMERIC(5,2) DEFAULT 0.00,
    clausulas       TEXT,
    estado          VARCHAR(20)  NOT NULL DEFAULT 'Activo'
                    CHECK (estado IN ('Activo','Cancelado','Finalizado','En revisión')),
    fecha_creacion  TIMESTAMP    NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_monto_positivo CHECK (monto_base > 0)
);

--  ESCENARIOS
CREATE TABLE escenarios (
    id_escenario    SERIAL PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL UNIQUE,
    capacidad_max   INT          NOT NULL,
    tipo_escenario  VARCHAR(60)  NOT NULL
                    CHECK (tipo_escenario IN ('Principal','Secundario','Carpa','Al aire libre','Indoor')),
    zona_especial   VARCHAR(100),
    descripcion     TEXT,
    equipamiento    TEXT,
    CONSTRAINT chk_capacidad CHECK (capacidad_max > 0)
);

-- PRESENTACIONES
CREATE TABLE presentaciones (
    id_presentacion SERIAL PRIMARY KEY,
    id_artista      INT          NOT NULL REFERENCES artistas(id_artista)   ON DELETE RESTRICT,
    id_escenario    INT          NOT NULL REFERENCES escenarios(id_escenario) ON DELETE RESTRICT,
    fecha_inicio    TIMESTAMP    NOT NULL,
    fecha_fin       TIMESTAMP    NOT NULL,
    estado          VARCHAR(20)  NOT NULL DEFAULT 'Programada'
                    CHECK (estado IN ('Programada','En curso','Finalizada','Cancelada','Pospuesta')),
    aforo_actual    INT          NOT NULL DEFAULT 0,
    notas           TEXT,
    CONSTRAINT chk_fechas_presentacion CHECK (fecha_fin > fecha_inicio),
    CONSTRAINT chk_aforo_positivo      CHECK (aforo_actual >= 0)
);

-- TIPOS DE BOLETA
CREATE TABLE tipos_boleta (
    id_tipo         SERIAL PRIMARY KEY,
    nombre          VARCHAR(80)  NOT NULL UNIQUE,
    precio          NUMERIC(12,2) NOT NULL,
    cupo_maximo     INT          NOT NULL,
    cupo_disponible INT          NOT NULL,
    descripcion     TEXT,
    beneficios      TEXT,
    fecha_inicio_venta DATE,
    fecha_fin_venta    DATE,
    CONSTRAINT chk_precio_boleta    CHECK (precio >= 0),
    CONSTRAINT chk_cupos            CHECK (cupo_maximo > 0 AND cupo_disponible >= 0 AND cupo_disponible <= cupo_maximo)
);

-- ASISTENTES
CREATE TABLE asistentes (
    id_asistente    SERIAL PRIMARY KEY,
    nombres         VARCHAR(100) NOT NULL,
    apellidos       VARCHAR(100) NOT NULL,
    documento_id    VARCHAR(30)  NOT NULL UNIQUE,
    tipo_documento  VARCHAR(20)  NOT NULL DEFAULT 'CC'
                    CHECK (tipo_documento IN ('CC','CE','Pasaporte','TI')),
    correo          VARCHAR(150) NOT NULL UNIQUE,
    telefono        VARCHAR(20),
    ciudad_origen   VARCHAR(80),
    fecha_nacimiento DATE,
    fecha_registro  TIMESTAMP    NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_correo_formato CHECK (correo LIKE '%@%.%')
);

-- VENTAS
CREATE TABLE ventas (
    id_venta        SERIAL PRIMARY KEY,
    id_asistente    INT          NOT NULL REFERENCES asistentes(id_asistente)      ON DELETE RESTRICT,
    id_tipo         INT          NOT NULL REFERENCES tipos_boleta(id_tipo)         ON DELETE RESTRICT,
    id_presentacion INT          NOT NULL REFERENCES presentaciones(id_presentacion) ON DELETE RESTRICT,
    cantidad        INT          NOT NULL DEFAULT 1,
    precio_unitario NUMERIC(12,2) NOT NULL,
    total           NUMERIC(14,2) NOT NULL,
    fecha_venta     TIMESTAMP    NOT NULL DEFAULT NOW(),
    canal_venta     VARCHAR(40)  NOT NULL DEFAULT 'Online'
                    CHECK (canal_venta IN ('Online','Presencial','App móvil','Revendedor autorizado')),
    estado_pago     VARCHAR(20)  NOT NULL DEFAULT 'Pagado'
                    CHECK (estado_pago IN ('Pagado','Pendiente','Reembolsado','Fallido')),
    codigo_qr       VARCHAR(80)  UNIQUE,
    CONSTRAINT chk_cantidad_venta CHECK (cantidad > 0),
    CONSTRAINT chk_total_venta    CHECK (total > 0)
);

-- STAFF
CREATE TABLE staff (
    id_staff        SERIAL PRIMARY KEY,
    nombres         VARCHAR(100) NOT NULL,
    apellidos       VARCHAR(100) NOT NULL,
    documento_id    VARCHAR(30)  NOT NULL UNIQUE,
    cargo           VARCHAR(80)  NOT NULL,
    area            VARCHAR(80)  NOT NULL
                    CHECK (area IN ('Seguridad','Producción','Atención al público','Logística',
                                    'Técnico','Médico','Comunicaciones','Administrativo')),
    id_escenario    INT          REFERENCES escenarios(id_escenario),
    telefono        VARCHAR(20),
    correo          VARCHAR(150),
    turno           VARCHAR(20)  NOT NULL DEFAULT 'Completo'
                    CHECK (turno IN ('Mañana','Tarde','Noche','Completo')),
    activo          BOOLEAN      NOT NULL DEFAULT TRUE
);


-- TABLA DE AUDITORÍA

CREATE TABLE auditoria_presentaciones (
    id_auditoria    SERIAL PRIMARY KEY,
    id_presentacion INT          NOT NULL,
    campo_modificado VARCHAR(50) NOT NULL,
    valor_anterior  TEXT,
    valor_nuevo     TEXT,
    usuario_db      VARCHAR(100) NOT NULL DEFAULT CURRENT_USER,
    fecha_cambio    TIMESTAMP    NOT NULL DEFAULT NOW()
);

--  ÍNDICES BÁSICOS

CREATE INDEX idx_artistas_nombre        ON artistas(nombre_artistico);
CREATE INDEX idx_contratos_artista      ON contratos(id_artista);
CREATE INDEX idx_contratos_estado       ON contratos(estado);
CREATE INDEX idx_presentaciones_artista ON presentaciones(id_artista);
CREATE INDEX idx_presentaciones_escen   ON presentaciones(id_escenario);
CREATE INDEX idx_presentaciones_fecha   ON presentaciones(fecha_inicio);
CREATE INDEX idx_ventas_asistente       ON ventas(id_asistente);
CREATE INDEX idx_ventas_tipo            ON ventas(id_tipo);
CREATE INDEX idx_ventas_presentacion    ON ventas(id_presentacion);
CREATE INDEX idx_ventas_fecha           ON ventas(fecha_venta);
CREATE INDEX idx_ventas_estado          ON ventas(estado_pago);
CREATE INDEX idx_asistentes_doc         ON asistentes(documento_id);
CREATE INDEX idx_staff_escenario        ON staff(id_escenario);
CREATE INDEX idx_staff_area             ON staff(area);
