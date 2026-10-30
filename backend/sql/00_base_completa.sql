-- =====================================================================
-- BASE COMPLETA - Enfermería IPHA (un solo script, todo incluido)
--   * Tablas con las columnas que usa la aplicación (ya no hace falta migracion.sql)
--   * Orientadoras, roles con contraseña (hash) y usuario MySQL de la app
-- Ejecutar en una base NUEVA:   mysql -u root -p < backend/sql/00_base_completa.sql
-- (En MySQL Workbench: abrir el archivo y pulsar el rayo.)
-- Si ya existe una base con tablas, descomenta la línea de DROP de abajo (BORRA todos sus datos).
-- =====================================================================
-- DROP DATABASE IF EXISTS enfermeria_escolar;

CREATE DATABASE IF NOT EXISTS enfermeria_escolar
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE enfermeria_escolar;


-- Una credencial compartida por rol.
-- El backend debe guardar aquí el hash, nunca la contraseña en texto plano.
CREATE TABLE login_enfermeria (
    rol ENUM('enfermeria', 'orientacion', 'administracion') NOT NULL,
    contrasena_hash VARCHAR(255) NULL,
    actualizado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (rol)
) ENGINE=InnoDB;

-- Roles con la contraseña ya cifrada (hash).
-- Enfermería: Demo-Enfermeria-26 | Orientación: Demo-Orientacion-26 | Administración: Demo-Admin-26
INSERT INTO login_enfermeria (rol, contrasena_hash) VALUES
    ('enfermeria', 'pbkdf2:sha256:600000$cvwA15QMJIOt6wul$77ef6b8bcf282690352761679be5c60f13521b8a06113b1de46ad281fdff1c06'),
    ('orientacion', 'pbkdf2:sha256:600000$Ql5jQbMKcq2loFNd$6b5a818a708eed616a2ce01682ea3aacacbefd36512747ce83930f6fb9ec0bbe'),
    ('administracion', 'pbkdf2:sha256:600000$nXTDjrJzabxtoeOp$1c90af23f09dce89425377ee069d9a2a1e1aaba01c3b5dc3a33e133e5d411596');


-- Datos principales del estudiante.
-- grado y curso se guardan aquí; no se duplican en otras tablas.
CREATE TABLE estudiantes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    matricula VARCHAR(30) NOT NULL,
    nombre_completo VARCHAR(200) NOT NULL,
    edad TINYINT UNSIGNED NULL,
    estado_registro ENUM('Al día', 'Revisar', 'Pendiente') NOT NULL DEFAULT 'Pendiente',
    motivo_archivo VARCHAR(80) NULL,
    curso ENUM(
        'Mecatronica',
        'Informatica',
        'Electricidad',
        'Refrigeracion',
        'Contabilidad',
        'Mecanica'
    ) NULL,
    grado ENUM('4to', '5to', '6to') NOT NULL,
    fecha_nacimiento DATE NULL,
    telefono_contacto VARCHAR(30) NULL,
    nombre_tutor VARCHAR(150) NULL,
    estado ENUM('activo', 'graduado', 'archivado') NOT NULL DEFAULT 'activo',
    fecha_archivado DATE NULL,
    creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_estudiantes_matricula (matricula),
    INDEX idx_estudiantes_grado_curso (grado, curso),
    INDEX idx_estudiantes_estado (estado)
) ENGINE=InnoDB;


-- Información de salud actual y prioridad visual.
-- La prioridad es un indicador de atención, no un diagnóstico.
CREATE TABLE datos_salud_estudiante (
    id_estudiante INT NOT NULL PRIMARY KEY,
    grupo_sanguineo VARCHAR(12) NULL,
    alergias TEXT NULL,
    medicamentos_relevantes TEXT NULL,
    condiciones_relevantes TEXT NULL,
    detalle_necesidad TEXT NULL,
    prioridad ENUM('Leve', 'Media', 'Grave') NULL,
    observaciones TEXT NULL,
    actualizado_por_rol ENUM(
        'enfermeria',
        'orientacion',
        'administracion'
    ) NULL,
    actualizado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_salud_estudiante
        FOREIGN KEY (id_estudiante) REFERENCES estudiantes(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB;


-- Notas y cambios consultables desde el historial del estudiante.
CREATE TABLE historial_estudiantil (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_estudiante INT NOT NULL,
    tipo ENUM('nota', 'cambio_datos', 'cambio_prioridad') NOT NULL,
    campo_afectado VARCHAR(80) NULL,
    valor_anterior TEXT NULL,
    valor_nuevo TEXT NULL,
    descripcion TEXT NOT NULL,
    registrado_por_rol ENUM(
        'enfermeria',
        'orientacion',
        'administracion'
    ) NOT NULL,
    registrado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_historial_estudiante_fecha (id_estudiante, registrado_en),
    CONSTRAINT fk_historial_estudiante
        FOREIGN KEY (id_estudiante) REFERENCES estudiantes(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB;


-- Cada visita tiene su propio estado de despacho.
-- No se guarda "despachado" en estudiantes porque puede cambiar entre visitas.
CREATE TABLE visitas (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_estudiante INT NOT NULL,
    fecha_visita DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    motivo TEXT NOT NULL,
    atencion_realizada TEXT NULL,
    observaciones TEXT NULL,
    despachado BOOLEAN NOT NULL DEFAULT FALSE,
    registrada_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    registrada_por_rol ENUM(
        'enfermeria',
        'orientacion',
        'administracion'
    ) NOT NULL,
    INDEX idx_visitas_estudiante_fecha (id_estudiante, fecha_visita),
    INDEX idx_visitas_fecha (fecha_visita),
    CONSTRAINT fk_visita_estudiante
        FOREIGN KEY (id_estudiante) REFERENCES estudiantes(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB;


-- Orientadoras disponibles como destinatarias de las solicitudes.
CREATE TABLE orientadoras (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE KEY uq_orientadora_nombre (nombre)
) ENGINE=InnoDB;

INSERT INTO orientadoras (nombre) VALUES
    ('Mabel Maldonado'),
    ('Daniela Asencio'),
    ('Esmeralda Vicente');


-- Solicitudes de medicamentos: intencionalmente no tiene id_estudiante.
CREATE TABLE solicitudes_medicamentos (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_orientadora INT NOT NULL,
    medicamento VARCHAR(150) NOT NULL,
    presentacion VARCHAR(100) NULL,
    cantidad_solicitada INT UNSIGNED NULL,
    cantidad_entregada INT UNSIGNED NOT NULL DEFAULT 0,
    detalle_solicitud TEXT NULL,
    estado ENUM(
        'pendiente',
        'recibida',
        'gestionada',
        'no_disponible'
    ) NOT NULL DEFAULT 'pendiente',
    solicitada_por_rol ENUM(
        'enfermeria',
        'orientacion',
        'administracion'
    ) NOT NULL,
    solicitada_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    respondida_por_rol ENUM(
        'enfermeria',
        'orientacion',
        'administracion'
    ) NULL,
    respuesta TEXT NULL,
    respondida_en DATETIME NULL,
    INDEX idx_solicitudes_estado_fecha (estado, solicitada_en),
    CONSTRAINT fk_solicitud_orientadora
        FOREIGN KEY (id_orientadora) REFERENCES orientadoras(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB;


-- Proceso de cierre escolar. La aplicación debe pedir confirmación
-- administrativa antes de aplicar promociones o archivar graduados.
CREATE TABLE cierres_escolares (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    anio_escolar VARCHAR(9) NOT NULL,
    estado ENUM(
        'preparado',
        'confirmado',
        'ejecutado',
        'cancelado'
    ) NOT NULL DEFAULT 'preparado',
    creado_por_rol ENUM(
        'enfermeria',
        'orientacion',
        'administracion'
    ) NOT NULL,
    confirmado_por_rol ENUM(
        'enfermeria',
        'orientacion',
        'administracion'
    ) NULL,
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    confirmado_en DATETIME NULL,
    ejecutado_en DATETIME NULL,
    INDEX idx_cierres_anio_estado (anio_escolar, estado)
) ENGINE=InnoDB;


-- Resultado de cada estudiante dentro de un cierre escolar.
CREATE TABLE historial_promociones (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_cierre BIGINT NOT NULL,
    id_estudiante INT NOT NULL,
    grado_anterior ENUM('4to', '5to', '6to') NOT NULL,
    grado_nuevo ENUM('4to', '5to', '6to') NULL,
    accion ENUM(
        'promovido',
        'graduado_archivado',
        'sin_cambio'
    ) NOT NULL,
    procesado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_cierre_estudiante (id_cierre, id_estudiante),
    CONSTRAINT fk_promocion_cierre
        FOREIGN KEY (id_cierre) REFERENCES cierres_escolares(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_promocion_estudiante
        FOREIGN KEY (id_estudiante) REFERENCES estudiantes(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB;


-- Registro general de acciones. No se deben guardar contraseñas
-- ni detalles médicos dentro del resumen de auditoría.
CREATE TABLE registros_auditoria (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    rol_actor ENUM(
        'enfermeria',
        'orientacion',
        'administracion'
    ) NOT NULL,
    accion VARCHAR(80) NOT NULL,
    entidad VARCHAR(80) NOT NULL DEFAULT 'general',
    id_entidad BIGINT NULL,
    resumen VARCHAR(255) NULL,
    registrado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_auditoria_fecha (registrado_en),
    INDEX idx_auditoria_rol_fecha (rol_actor, registrado_en)
) ENGINE=InnoDB;


-- Vista para consultar cuántas visitas tiene cada estudiante.
CREATE OR REPLACE VIEW vista_visitas_por_estudiante AS
SELECT
    e.id AS id_estudiante,
    e.matricula,
    e.nombre_completo,
    e.grado,
    e.curso,
    e.estado,
    COUNT(v.id) AS cantidad_visitas,
    MAX(v.fecha_visita) AS ultima_visita
FROM estudiantes AS e
LEFT JOIN visitas AS v
    ON v.id_estudiante = e.id
GROUP BY e.id;

-- Usuario que usa la aplicación (NO uses root). La clave debe coincidir con DB_PASSWORD del .env.
-- '%' permite conectarse desde otra computadora de la red; 'localhost' desde la misma.
CREATE USER IF NOT EXISTS 'enfermeria_app'@'%' IDENTIFIED BY 'enfermeria161719';
CREATE USER IF NOT EXISTS 'enfermeria_app'@'localhost' IDENTIFIED BY 'enfermeria161719';
GRANT SELECT, INSERT, UPDATE ON enfermeria_escolar.* TO 'enfermeria_app'@'%';
GRANT SELECT, INSERT, UPDATE ON enfermeria_escolar.* TO 'enfermeria_app'@'localhost';
FLUSH PRIVILEGES;

SHOW TABLES;
