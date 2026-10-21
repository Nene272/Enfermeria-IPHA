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

-- Crea los roles sin contraseñas. El inicio de sesión debe rechazarlos
-- hasta que el backend configure un hash válido para cada uno.
INSERT INTO login_enfermeria (rol) VALUES
    ('enfermeria'),
    ('orientacion'),
    ('administracion');


-- Datos principales del estudiante.
-- grado y curso se guardan aquí; no se duplican en otras tablas.
CREATE TABLE estudiantes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    curso ENUM(
        'Mecatronica',
        'Informatica',
        'Electricidad',
        'Refrigeracion',
        'Contabilidad',
        'Mecanica'
    ) NOT NULL,
    grado ENUM('4to', '5to', '6to') NOT NULL,
    fecha_nacimiento DATE NULL,
    telefono_contacto VARCHAR(20) NULL,
    nombre_tutor VARCHAR(150) NULL,
    estado ENUM('activo', 'graduado', 'archivado') NOT NULL DEFAULT 'activo',
    fecha_archivado DATE NULL,
    creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_estudiantes_grado_curso (grado, curso),
    INDEX idx_estudiantes_estado (estado)
) ENGINE=InnoDB;


-- Información de salud actual y prioridad visual.
-- La prioridad es un indicador de atención, no un diagnóstico.
CREATE TABLE datos_salud_estudiante (
    id_estudiante INT NOT NULL PRIMARY KEY,
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
    cantidad_solicitada VARCHAR(60) NULL,
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
    entidad VARCHAR(80) NOT NULL,
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
    e.nombre,
    e.apellido,
    e.grado,
    e.curso,
    e.estado,
    COUNT(v.id) AS cantidad_visitas,
    MAX(v.fecha_visita) AS ultima_visita
FROM estudiantes AS e
LEFT JOIN visitas AS v
    ON v.id_estudiante = e.id
GROUP BY e.id;


-- Verificar las tablas creadas.
SHOW TABLES;

