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

--  TRIGGERS


--TRIGGER 1
CREATE OR REPLACE FUNCTION fn_validar_aforo_venta()
RETURNS TRIGGER AS $$
DECLARE
    v_cupo_disp INT;
BEGIN
    SELECT cupo_disponible INTO v_cupo_disp
    FROM tipos_boleta
    WHERE id_tipo = NEW.id_tipo
    FOR UPDATE;

    IF v_cupo_disp < NEW.cantidad THEN
        RAISE EXCEPTION
            'No hay cupo suficiente. Disponibles: %, solicitados: %',
            v_cupo_disp, NEW.cantidad;
    END IF;

    UPDATE tipos_boleta
    SET cupo_disponible = cupo_disponible - NEW.cantidad
    WHERE id_tipo = NEW.id_tipo;

    -- Genera código QR único
    NEW.codigo_qr := 'TML-' || UPPER(SUBSTRING(MD5(RANDOM()::TEXT), 1, 12));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_aforo_venta
BEFORE INSERT ON ventas
FOR EACH ROW EXECUTE FUNCTION fn_validar_aforo_venta();


-- TRIGGER 2
CREATE OR REPLACE FUNCTION fn_auditoria_presentaciones()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.estado IS DISTINCT FROM NEW.estado THEN
        INSERT INTO auditoria_presentaciones(id_presentacion, campo_modificado, valor_anterior, valor_nuevo)
        VALUES (NEW.id_presentacion, 'estado', OLD.estado, NEW.estado);
    END IF;

    IF OLD.fecha_inicio IS DISTINCT FROM NEW.fecha_inicio THEN
        INSERT INTO auditoria_presentaciones(id_presentacion, campo_modificado, valor_anterior, valor_nuevo)
        VALUES (NEW.id_presentacion, 'fecha_inicio', OLD.fecha_inicio::TEXT, NEW.fecha_inicio::TEXT);
    END IF;

    IF OLD.fecha_fin IS DISTINCT FROM NEW.fecha_fin THEN
        INSERT INTO auditoria_presentaciones(id_presentacion, campo_modificado, valor_anterior, valor_nuevo)
        VALUES (NEW.id_presentacion, 'fecha_fin', OLD.fecha_fin::TEXT, NEW.fecha_fin::TEXT);
    END IF;

    IF OLD.id_escenario IS DISTINCT FROM NEW.id_escenario THEN
        INSERT INTO auditoria_presentaciones(id_presentacion, campo_modificado, valor_anterior, valor_nuevo)
        VALUES (NEW.id_presentacion, 'id_escenario', OLD.id_escenario::TEXT, NEW.id_escenario::TEXT);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auditoria_presentaciones
AFTER UPDATE ON presentaciones
FOR EACH ROW EXECUTE FUNCTION fn_auditoria_presentaciones();


-- 6. DATOS DE PRUEBA
-- ESCENARIOS (5)
INSERT INTO escenarios (nombre, capacidad_max, tipo_escenario, zona_especial, descripcion, equipamiento) VALUES
('Mainstage Freedom',    20000, 'Principal',     'Zona VIP Premium',     'Escenario principal con pantallas LED 360°',          'Sistema d&b audiotechnik, pantallas ROE Visual 800m²'),
('Stage Of Unity',        5000, 'Secundario',    'Zona Arte Interactivo', 'Escenario techno con instalaciones de arte inmersivo', 'Funktion-One, luces laser 100kW'),
('Elixir Stage',          3000, 'Carpa',         'Zona Gastronomía VIP',  'Carpa de house y melodic techno',                     'Martin Audio, CO2 cannons'),
('Planaxis Stage',        2000, 'Al aire libre', 'Zona Glamping',         'Escenario para artistas emergentes latinoamericanos',  'JBL Line Array, pantalla 200m²'),
('The Library Stage',     1000, 'Indoor',        'Zona Cultural',         'Sala íntima para sets experimentales y B2B',          'Void Acoustics, iluminación arquitectónica');

--ARTISTAS (12)
INSERT INTO artistas (nombre, nombre_artistico, nacionalidad, genero_musical, subgenero, descripcion, redes_sociales) VALUES
('Martin Garrix',         'Martin Garrix',   'Neerlandesa', 'Electrónica', 'Progressive House / Big Room', 'DJ #1 del mundo según DJ Mag 2016–2019',        '@martingarrix'),
('Charlotte de Witte',    'Charlotte de Witte','Belga',     'Electrónica', 'Techno',                        'Referente del techno oscuro europeo',            '@charlottedewitte'),
('David Guetta',          'David Guetta',    'Francesa',    'Electrónica', 'House / EDM',                   'Productor ganador de 2 Grammy Awards',           '@davidguetta'),
('Fisher',                'Fisher',          'Australiana', 'Electrónica', 'Tech House',                    'Conocido por su energético tech house',          '@fisher'),
('Amelie Lens',           'Amelie Lens',     'Belga',       'Electrónica', 'Techno',                        'Cofundadora del sello LENSKE',                   '@amelielens'),
('Bicep',                 'Bicep',           'Irlandesa',   'Electrónica', 'Melodic Techno / House',         'Dúo conocido por "Glue" y "Glue70"',            '@feelbicep'),
('Adam Beyer',            'Adam Beyer',      'Sueca',       'Electrónica', 'Techno',                        'Fundador del sello Drumcode Records',            '@adambeyer'),
('Nina Kraviz',           'Nina Kraviz',     'Rusa',        'Electrónica', 'Techno / Acid',                 'Fundadora del sello трип (Trip)',                '@ninakraviz'),
('Solomun',               'Solomun',         'Bosnio-alemana','Electrónica','Melodic House & Techno',       'Reconocido por sus sets de +8 horas',            '@djsolomun'),
('Peggy Gou',             'Peggy Gou',       'Surcoreana',  'Electrónica', 'House / Disco',                 'DJ y diseñadora de moda, fundadora de Gudu',     '@peggygou_'),
('Carl Cox',              'Carl Cox',        'Británica',   'Electrónica', 'Techno / Tech House',           'Leyenda viva de la escena electrónica',          '@carlcox'),
('Reinier Zonneveld',     'Reinier Zonneveld','Neerlandesa','Electrónica', 'Techno / Industrial',           'Conocido por sus sets en piano en vivo',         '@reinierzonneveld');

-- CONTRATOS (12, uno por artista)
INSERT INTO contratos (id_artista, fecha_firma, monto_base, moneda, porcentaje_royalties, clausulas, estado) VALUES
(1,  '2025-01-15', 450000000, 'COP', 5.00, 'Rider técnico 40 ítems, 2 vuelos business, hotel 5 estrellas', 'Activo'),
(2,  '2025-01-20', 280000000, 'COP', 3.50, 'Set mínimo 2h, rider técnico Funktion-One',                    'Activo'),
(3,  '2025-02-01', 520000000, 'COP', 6.00, 'Invitado de honor, derechos de imagen incluidos',              'Activo'),
(4,  '2025-02-10', 220000000, 'COP', 3.00, 'Set mínimo 90 min, restricción de grabación privada',          'Activo'),
(5,  '2025-02-14', 240000000, 'COP', 3.50, 'Requiere sistema Funktion-One, set mínimo 2h',                 'Activo'),
(6,  '2025-02-20', 310000000, 'COP', 4.00, 'Dúo, 2 boletos adicionales, hotel suite doble',               'Activo'),
(7,  '2025-03-01', 380000000, 'COP', 4.50, 'Sello Drumcode, set mínimo 2.5h',                              'Activo'),
(8,  '2025-03-05', 290000000, 'COP', 4.00, 'Set b2b opcional con Adam Beyer',                              'Activo'),
(9,  '2025-03-10', 420000000, 'COP', 5.00, 'Exclusividad Colombia 6 meses, set mínimo 4h',                 'Activo'),
(10, '2025-03-15', 300000000, 'COP', 4.00, 'Rider especial: luces neón y espejos',                         'Activo'),
(11, '2025-03-20', 600000000, 'COP', 7.00, 'Headliner cierre, exclusividad Sudamérica 3 meses',            'Activo'),
(12, '2025-03-25', 200000000, 'COP', 2.50, 'Piano en vivo incluido, set mínimo 2h',                        'Activo');

-- TIPOS DE BOLETA (6)
INSERT INTO tipos_boleta (nombre, precio, cupo_maximo, cupo_disponible, descripcion, beneficios, fecha_inicio_venta, fecha_fin_venta) VALUES
('Full Festival General',     850000, 10000, 10000, 'Acceso 7 días todos los escenarios',              'Acceso general, app oficial',                          '2025-04-01', '2025-07-25'),
('Full Festival VIP',        2200000,  3000,  3000, 'Acceso 7 días con privilegios VIP',               'Zona VIP, baños privados, lounge exclusivo, bar open', '2025-04-01', '2025-07-25'),
('Full Festival Premium',    4500000,   500,   500, 'Experiencia premium total',                        'Todo VIP + acceso backstage + meet & greet artistas',  '2025-04-01', '2025-07-25'),
('Día Único General',         180000,  8000,  8000, 'Acceso 1 día a elección',                         'Acceso general día seleccionado',                      '2025-05-01', '2025-07-25'),
('Día Único VIP',             420000,  2000,  2000, 'Acceso 1 día con zona VIP',                       'Zona VIP + baños privados',                            '2025-05-01', '2025-07-25'),
('Glamping Package',         3800000,   200,   200, 'Festival completo + glamping 7 noches',            'Carpa premium, desayuno, ducha privada, zona exclusiva','2025-04-01', '2025-07-01');

-- PRESENTACIONES (35)
INSERT INTO presentaciones (id_artista, id_escenario, fecha_inicio, fecha_fin, estado, aforo_actual, notas) VALUES
-- Día 1: 26 julio
(3,  1, '2025-07-26 20:00', '2025-07-26 22:00', 'Programada', 0, 'Apertura oficial del festival'),
(10, 2, '2025-07-26 21:00', '2025-07-26 23:00', 'Programada', 0, 'Apertura Stage of Unity'),
(12, 3, '2025-07-26 22:00', '2025-07-27 00:00', 'Programada', 0, 'Set con piano en vivo'),
(4,  4, '2025-07-26 20:00', '2025-07-26 22:00', 'Programada', 0, 'Set emergentes Latinoamérica'),
(6,  5, '2025-07-26 22:00', '2025-07-27 00:30', 'Programada', 0, 'Set B2B sorpresa'),
-- Día 2: 27 julio
(1,  1, '2025-07-27 21:00', '2025-07-27 23:30', 'Programada', 0, 'Headliner día 2'),
(2,  2, '2025-07-27 23:00', '2025-07-28 02:00', 'Programada', 0, 'Set techno 3 horas'),
(5,  3, '2025-07-27 20:00', '2025-07-27 22:30', 'Programada', 0, 'Primer set Colombia'),
(9,  5, '2025-07-27 22:00', '2025-07-28 02:00', 'Programada', 0, 'Set maratón 4h'),
(8,  2, '2025-07-27 20:00', '2025-07-27 22:00', 'Programada', 0, 'Set acid techno'),
-- Día 3: 28 julio
(7,  2, '2025-07-28 22:00', '2025-07-29 00:30', 'Programada', 0, 'Drumcode showcase'),
(3,  1, '2025-07-28 21:00', '2025-07-28 23:00', 'Programada', 0, 'Segunda presentación'),
(11, 1, '2025-07-28 23:30', '2025-07-29 02:00', 'Programada', 0, 'Carl Cox cierre día 3'),
(4,  3, '2025-07-28 20:00', '2025-07-28 22:00', 'Programada', 0, 'Set tech house'),
(6,  5, '2025-07-28 21:00', '2025-07-28 23:00', 'Programada', 0, 'Bicep íntimo'),
-- Día 4: 29 julio
(10, 1, '2025-07-29 21:00', '2025-07-29 23:00', 'Programada', 0, 'Peggy Gou mainstage'),
(2,  1, '2025-07-29 23:00', '2025-07-30 02:00', 'Programada', 0, 'Charlotte de Witte mainstage'),
(1,  3, '2025-07-29 20:00', '2025-07-29 22:00', 'Programada', 0, 'Martin Garrix set íntimo'),
(5,  2, '2025-07-29 22:00', '2025-07-30 00:30', 'Programada', 0, 'Set Amelie Lens techno'),
(12, 4, '2025-07-29 20:00', '2025-07-29 22:00', 'Programada', 0, 'Set piano emergentes'),
-- Día 5: 30 julio
(8,  2, '2025-07-30 22:00', '2025-07-31 01:00', 'Programada', 0, 'Nina Kraviz b2b Adam Beyer'),
(7,  2, '2025-07-30 20:00', '2025-07-30 22:00', 'Programada', 0, 'Adam Beyer abre noche'),
(9,  1, '2025-07-30 21:00', '2025-07-31 01:00', 'Programada', 0, 'Solomun 4h mainstage'),
(4,  5, '2025-07-30 22:00', '2025-07-31 00:00', 'Programada', 0, 'Fisher íntimo Library'),
(6,  3, '2025-07-30 20:00', '2025-07-30 22:30', 'Programada', 0, 'Bicep set Elixir'),
-- Día 6: 31 julio
(11, 1, '2025-07-31 20:00', '2025-07-31 23:00', 'Programada', 0, 'Carl Cox penúltima noche'),
(3,  1, '2025-07-31 18:00', '2025-07-31 20:00', 'Programada', 0, 'David Guetta sunset set'),
(1,  3, '2025-07-31 21:00', '2025-07-31 23:00', 'Programada', 0, 'Martin Garrix Elixir'),
(5,  2, '2025-07-31 23:00', '2025-08-01 02:00', 'Programada', 0, 'Amelie Lens cierre night'),
(10, 4, '2025-07-31 19:00', '2025-07-31 21:00', 'Programada', 0, 'Peggy Gou sunset'),
-- Día 7: 1 agosto – CIERRE
(11, 1, '2025-08-01 21:00', '2025-08-02 00:00', 'Programada', 0, 'CLOSING CEREMONY - Carl Cox'),
(2,  2, '2025-08-01 22:00', '2025-08-02 02:00', 'Programada', 0, 'Charlotte de Witte cierre techno'),
(7,  2, '2025-08-01 20:00', '2025-08-01 22:00', 'Programada', 0, 'Adam Beyer pre-cierre'),
(9,  5, '2025-08-01 20:00', '2025-08-01 23:00', 'Programada', 0, 'Solomun Library closing'),
(12, 4, '2025-08-01 19:00', '2025-08-01 21:00', 'Programada', 0, 'Reinier Zonneveld piano finale');

-- ASISTENTES (35)
INSERT INTO asistentes (nombres, apellidos, documento_id, tipo_documento, correo, telefono, ciudad_origen, fecha_nacimiento) VALUES
('Santiago',   'Ramírez Torres',   '1020345678', 'CC', 'sramirez@gmail.com',       '3101234567', 'Bogotá',        '1998-03-12'),
('Valentina',  'Gómez Herrera',    '1023456789', 'CC', 'vgomez@hotmail.com',       '3119876543', 'Medellín',      '2000-07-22'),
('Andrés',     'López Martínez',   '1045678901', 'CC', 'alopez@yahoo.com',         '3201234568', 'Cali',          '1995-11-08'),
('Camila',     'Torres Jiménez',   '1067890123', 'CC', 'ctorres@gmail.com',        '3151234569', 'Barranquilla',  '2002-04-15'),
('Sebastián',  'Vargas Rincón',    '1089012345', 'CC', 'svargas@outlook.com',      '3001234570', 'Bogotá',        '1997-09-30'),
('Isabella',   'Castro Morales',   '1012345679', 'CC', 'icastro@gmail.com',        '3181234571', 'Bucaramanga',   '2001-12-05'),
('Felipe',     'Moreno Sandoval',  '1034567890', 'CC', 'fmoreno@gmail.com',        '3101234572', 'Cartagena',     '1999-06-18'),
('Daniela',    'Ruiz Pedraza',     '1056789012', 'CC', 'druiz@hotmail.com',        '3121234573', 'Pereira',       '2003-02-28'),
('Julián',     'Hernández Cruz',   '1078901234', 'CC', 'jhernandez@gmail.com',     '3211234574', 'Bogotá',        '1994-08-14'),
('Sofía',      'Díaz Ospina',      '1001234567', 'CC', 'sdiaz@gmail.com',          '3141234575', 'Manizales',     '2000-10-01'),
('Tomás',      'Salcedo Pineda',   '1013456780', 'CC', 'tsalcedo@gmail.com',       '3161234576', 'Ibagué',        '1996-05-20'),
('Laura',      'Medina Parra',     '1035678901', 'CC', 'lmedina@yahoo.com',        '3131234577', 'Bogotá',        '2001-01-11'),
('Miguel',     'González Arias',   '1057890123', 'CC', 'mgonzalez@gmail.com',      '3221234578', 'Cúcuta',        '1993-07-07'),
('Paula',      'Restrepo León',    '1079012345', 'CC', 'prestrepo@outlook.com',    '3101234579', 'Medellín',      '2002-09-25'),
('Nicolás',    'Cárdenas Muñoz',   '1002345678', 'CC', 'ncardenas@gmail.com',      '3151234580', 'Bogotá',        '1997-03-17'),
('Alejandra',  'Mejía Gutiérrez',  '1024567890', 'CC', 'amejia@gmail.com',         '3191234581', 'Cali',          '2000-06-30'),
('David',      'Rojas Bermúdez',   '1046789012', 'CC', 'drojas@gmail.com',         '3001234582', 'Bogotá',        '1998-11-22'),
('Mariana',    'Acosta Lozano',    '1068901234', 'CC', 'macosta@hotmail.com',      '3111234583', 'Armenia',       '2001-04-08'),
('Samuel',     'Patiño Cortés',    '1090123456', 'CC', 'spatino@gmail.com',        '3201234584', 'Bogotá',        '1995-08-03'),
('Valeria',    'Suárez Montoya',   '1012345680', 'CC', 'vsuarez@gmail.com',        '3171234585', 'Barranquilla',  '2003-12-19'),
('Juan Pablo', 'Niño Velandia',    '1034567891', 'CC', 'jpnino@gmail.com',         '3121234586', 'Villavicencio', '1999-02-14'),
('Natalia',    'Bernal Quintero',  '1056789013', 'CC', 'nbernal@outlook.com',      '3231234587', 'Bogotá',        '2001-07-09'),
('Esteban',    'Ortega Ramos',     '1078901235', 'CC', 'eortega@gmail.com',        '3141234588', 'Santa Marta',   '1996-10-26'),
('Carolina',   'Vega Ríos',        '1001234568', 'CC', 'cvega@gmail.com',          '3161234589', 'Bogotá',        '2000-03-04'),
('Diego',      'Duarte Escobar',   '1013456781', 'CC', 'dduarte@yahoo.com',        '3101234590', 'Pasto',         '1997-05-13'),
('Ana Lucía',  'Arango Zapata',    '1035678902', 'CC', 'alarango@gmail.com',       '3181234591', 'Medellín',      '2002-08-21'),
('Ricardo',    'Camacho Silva',    '1057890124', 'CC', 'rcamacho@gmail.com',       '3221234592', 'Bogotá',        '1994-01-30'),
('Luisa',      'Trujillo Campos',  '1079012346', 'CC', 'ltrujillo@hotmail.com',    '3111234593', 'Cali',          '2001-11-15'),
('Mateo',      'Estrada Vergara',  '1002345679', 'CC', 'mestrada@gmail.com',       '3201234594', 'Bogotá',        '1998-06-07'),
('Gabriela',   'Hurtado Gallego',  '1024567891', 'CC', 'ghurtado@gmail.com',       '3151234595', 'Bucaramanga',   '2000-09-18'),
('Simón',      'Betancourt Ossa',  '1046789013', 'CC', 'sbetancourt@gmail.com',    '3191234596', 'Bogotá',        '1996-04-02'),
('Daniela',    'Ceballos Montes',  '1068901235', 'CC', 'dceballos@yahoo.com',      '3001234597', 'Pereira',       '2003-07-27'),
('Alejandro',  'Zapata Loaiza',    '1090123457', 'CC', 'azapata@gmail.com',        '3171234598', 'Bogotá',        '1995-12-10'),
('María José', 'Mosquera Agudelo', '1012345681', 'CC', 'mmosquera@outlook.com',    '3121234599', 'Cartagena',     '2001-02-23'),
('Tomás',      'Villegas Echeverri','1034567892','CC', 'tvillegas@gmail.com',       '3231234600', 'Medellín',      '1999-10-05');

-- STAFF (15 registros)
INSERT INTO staff (nombres, apellidos, documento_id, cargo, area, id_escenario, telefono, correo, turno) VALUES
('Carlos',     'Mendoza',   '79123456', 'Jefe de Seguridad',       'Seguridad',         1, '3001110001', 'cmendoza@tml.co',   'Completo'),
('Andrea',     'Santos',    '52234567', 'Coordinadora de Logística','Logística',         NULL,'3001110002','asantos@tml.co',   'Completo'),
('Pedro',      'Cano',      '80345678', 'Técnico de Sonido',       'Técnico',           1, '3001110003', 'pcano@tml.co',      'Noche'),
('Gloria',     'Ríos',      '43456789', 'Paramédico',              'Médico',            NULL,'3001110004','grios@tml.co',     'Completo'),
('Hernán',     'Suárez',    '79567890', 'Técnico de Iluminación',  'Técnico',           2, '3001110005', 'hsuarez@tml.co',   'Noche'),
('Mónica',     'Álvarez',   '52678901', 'Atención al Cliente',     'Atención al público',NULL,'3001110006','malvarez@tml.co', 'Tarde'),
('Rodrigo',    'Pinzón',    '80789012', 'Supervisor Escenario',    'Producción',        3, '3001110007', 'rpinzon@tml.co',   'Completo'),
('Natalia',    'Corredor',  '43890123', 'Community Manager',       'Comunicaciones',    NULL,'3001110008','ncorredor@tml.co', 'Completo'),
('Javier',     'Molina',    '79901234', 'Guardia de Seguridad',    'Seguridad',         2, '3001110009', 'jmolina@tml.co',   'Noche'),
('Patricia',   'Guerrero',  '52012345', 'Administradora',          'Administrativo',    NULL,'3001110010','pguerrero@tml.co', 'Completo'),
('Luis',       'Castellanos','80123456','Técnico de Video',        'Técnico',           1, '3001110011', 'lcastellanos@tml.co','Noche'),
('Sandra',     'Portilla',  '43234567', 'Asistente Médico',        'Médico',            NULL,'3001110012','sportilla@tml.co', 'Mañana'),
('Fabio',      'Nieto',     '79345678', 'Coordinador Artístico',   'Producción',        NULL,'3001110013','fnieto@tml.co',    'Completo'),
('Claudia',    'Bermeo',    '52456789', 'Asesora de Prensa',       'Comunicaciones',    NULL,'3001110014','cbermeo@tml.co',   'Completo'),
('Ernesto',    'Valbuena',  '80567890', 'Supervisor Glamping',     'Logística',         4, '3001110015', 'evalbuena@tml.co', 'Completo');

--  VENTAS (35) 
INSERT INTO ventas (id_asistente, id_tipo, id_presentacion, cantidad, precio_unitario, total, canal_venta, estado_pago) VALUES
(1,  1,  1, 1,  850000,  850000,  'Online',                'Pagado'),
(2,  2,  6, 2, 2200000, 4400000,  'Online',                'Pagado'),
(3,  1,  2, 1,  850000,  850000,  'App móvil',             'Pagado'),
(4,  4,  4, 2,  180000,  360000,  'Online',                'Pagado'),
(5,  3,  6, 1, 4500000, 4500000,  'Online',                'Pagado'),
(6,  1,  1, 1,  850000,  850000,  'Presencial',            'Pagado'),
(7,  6,  9, 1, 3800000, 3800000,  'Online',                'Pagado'),
(8,  4,  4, 1,  180000,  180000,  'App móvil',             'Pagado'),
(9,  2,  7, 1, 2200000, 2200000,  'Online',                'Pagado'),
(10, 1,  6, 2,  850000, 1700000,  'Revendedor autorizado', 'Pagado'),
(11, 5,  5, 1,  420000,  420000,  'Online',                'Pagado'),
(12, 1, 11, 1,  850000,  850000,  'App móvil',             'Pagado'),
(13, 3, 13, 1, 4500000, 4500000,  'Online',                'Pagado'),
(14, 4,  4, 3,  180000,  540000,  'Online',                'Pagado'),
(15, 2, 17, 1, 2200000, 2200000,  'Presencial',            'Pagado'),
(16, 1, 16, 1,  850000,  850000,  'Online',                'Pagado'),
(17, 6,  9, 2, 3800000, 7600000,  'Online',                'Pagado'),
(18, 4, 20, 1,  180000,  180000,  'App móvil',             'Pagado'),
(19, 1,  1, 1,  850000,  850000,  'Online',                'Pagado'),
(20, 5, 19, 2,  420000,  840000,  'Revendedor autorizado', 'Pagado'),
(21, 2, 21, 1, 2200000, 2200000,  'Online',                'Pagado'),
(22, 1, 23, 1,  850000,  850000,  'App móvil',             'Pagado'),
(23, 4, 25, 2,  180000,  360000,  'Online',                'Pagado'),
(24, 3, 26, 1, 4500000, 4500000,  'Online',                'Pagado'),
(25, 1, 27, 1,  850000,  850000,  'Presencial',            'Pagado'),
(26, 5, 30, 1,  420000,  420000,  'Online',                'Pagado'),
(27, 2, 31, 1, 2200000, 2200000,  'Online',                'Pagado'),
(28, 6,  9, 1, 3800000, 3800000,  'App móvil',             'Pagado'),
(29, 4, 32, 1,  180000,  180000,  'Online',                'Pagado'),
(30, 1, 31, 2,  850000, 1700000,  'Revendedor autorizado', 'Pagado'),
(31, 2, 33, 1, 2200000, 2200000,  'Online',                'Pagado'),
(32, 4, 35, 2,  180000,  360000,  'Online',                'Pagado'),
(33, 1, 34, 1,  850000,  850000,  'App móvil',             'Pagado'),
(34, 3, 13, 1, 4500000, 4500000,  'Online',                'Pagado'),
(35, 5, 30, 1,  420000,  420000,  'Online',                'Pagado');
