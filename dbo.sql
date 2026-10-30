CREATE DATABASE IF NOT EXISTS enfermeria_escolar
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE enfermeria_escolar;
show tables

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

select * from login_enfermeria
-- Verificar las tablas creadas.
SHOW TABLES;

INSERT INTO estudiantes (nombre, apellido, curso, grado, fecha_nacimiento, telefono_contacto, nombre_tutor, estado) VALUES
    ('Carlos', 'Pérez', 'Informatica', '4to', '2009-05-12', '809-555-0192', 'María Pérez', 'activo'),
    ('Ana', 'Gómez', 'Mecatronica', '5to', '2008-08-23', '809-555-8833', 'Juan Gómez', 'activo'),
    ('José', 'Martínez', 'Electricidad', '6to', '2007-02-15', '809-555-4421', 'Carmen Rosa', 'activo'),
    ('Laura', 'Rodríguez', 'Contabilidad', '4to', '2009-11-04', '809-555-9988', 'Pedro Rodríguez', 'activo'),
    ('Miguel', 'Díaz', 'Refrigeracion', '5to', '2008-01-30', '809-555-3322', 'Lucía Díaz', 'activo');
    
INSERT INTO datos_salud_estudiante (id_estudiante, alergias, medicamentos_relevantes, condiciones_relevantes, detalle_necesidad, prioridad, observaciones, actualizado_por_rol) VALUES
    (1, 'Penicilina', 'Ninguno', 'Asma leve', 'Uso de inhalador en caso de crisis', 'Media', 'Trajo autorización médica firmada.', 'enfermeria'),
    (2, 'Ninguna', 'Antihistamínicos', 'Rinitis alérgica', 'Estornudos frecuentes con polvo', 'Leve', 'Controlar exposición a áreas con polvo.', 'orientacion'),
    (3, 'Mariscos', 'EpiPen (si aplica)', 'Alergia severa', 'Precaución con alimentos externos', 'Grave', 'Padres informados sobre protocolos de emergencia.', 'enfermeria'),
    (4, 'Ninguna', 'Ninguno', 'Ninguna', 'Ninguna', 'Leve', 'Estudiante sin historial complejo.', 'administracion'),
    (5, 'Polen', 'Gotas oftálmicas', 'Conjuntivitis alérgica estacional', 'Uso de lentes de sol al aire libre', 'Media', 'Revisión periódica.', 'enfermeria');
    
    INSERT INTO historial_estudiantil (id_estudiante, tipo, campo_afectado, valor_anterior, valor_nuevo, descripcion, registrado_por_rol) VALUES
    (1, 'cambio_prioridad', 'prioridad', 'Leve', 'Media', 'Se actualizó tras presentar crisis de asma leve en el taller.', 'enfermeria'),
    (3, 'nota', NULL, NULL, NULL, 'Se recordó al estudiante la prohibición de consumir alimentos con mariscos en la cafetería.', 'orientacion');
    
    INSERT INTO visitas (id_estudiante, fecha_visita, motivo, atencion_realizada, observaciones, despachado, registrada_por_rol) VALUES
    (1, '2026-05-10 09:30:00', 'Dolor de cabeza leve y mareo', 'Se tomó la presión arterial (normal), reposo de 15 minutos.', 'Se le dio agua y mejoró notablemente.', TRUE, 'enfermeria'),
    (2, '2026-05-11 10:15:00', 'Ataque de estornudos por polvo en el taller', 'Aplicación de gotas y lavado nasal.', 'Sin mayores complicaciones, regresó a clases.', TRUE, 'enfermeria'),
    (3, '2026-05-12 11:00:00', 'Corte leve en un dedo manipulando herramientas', 'Limpieza con solución salina, aplicación de antiséptico y curita.', 'Curación exitosa.', TRUE, 'enfermeria'),
    (4, '2026-05-12 14:20:00', 'Dolor estomacal', 'Reposo y infarto de manzanilla.', 'Fue retirada por su tutor más tarde.', FALSE, 'enfermeria');
    
    INSERT INTO solicitudes_medicamentos (id_orientadora, medicamento, cantidad_solicitada, detalle_solicitud, estado, solicitada_por_rol, respondida_por_rol, respuesta, respondida_en) VALUES
    (1, 'Paracetamol 500mg', '2 cajas', 'Necesario para botiquín de orientación ante dolores comunes de estudiantes.', 'gestionada', 'orientacion', 'enfermeria', 'Entregado en la oficina de enfermería.', '2026-05-01 10:00:00'),
    (2, 'Ibuprofeno 400mg', '1 caja', 'Solicitado para emergencias de dolor menstrual en alumnas.', 'pendiente', 'orientacion', NULL, NULL, NULL);
    
    INSERT INTO cierres_escolares (anio_escolar, estado, creado_por_rol, confirmado_por_rol, confirmado_en) VALUES
    ('2025-2026', 'confirmado', 'administracion', 'administracion', '2026-06-25 08:00:00');
    
    INSERT INTO historial_promociones (id_cierre, id_estudiante, grado_anterior, grado_nuevo, accion) VALUES
    (1, 1, '4to', '5to', 'promovido'),
    (1, 2, '5to', '6to', 'promovido'),
    (1, 3, '6to', NULL, 'graduado_archivado');
    
    INSERT INTO registros_auditoria (rol_actor, accion, entidad, id_entidad, resumen) VALUES
    ('enfermeria', 'CREAR', 'estudiantes', 1, 'Registro inicial del estudiante Carlos Pérez.'),
    ('orientacion', 'CREAR', 'solicitudes_medicamentos', 1, 'Solicitud de Paracetamol para botiquín auxiliar.'),
    ('administracion', 'CONFIRMAR', 'cierres_escolares', 1, 'Confirmación del proceso de cierre escolar período 2025-2026.');

USE enfermeria_escolar;

DROP VIEW IF EXISTS vista_visitas_por_estudiante;

-- Estudiantes: matrícula, nombre completo, edad, estado del registro...
ALTER TABLE estudiantes
    ADD COLUMN matricula VARCHAR(30) NULL AFTER id,
    ADD COLUMN nombre_completo VARCHAR(200) NULL AFTER matricula,
    ADD COLUMN edad TINYINT UNSIGNED NULL,
    ADD COLUMN estado_registro ENUM('Al día', 'Revisar', 'Pendiente') NOT NULL DEFAULT 'Pendiente',
    ADD COLUMN motivo_archivo VARCHAR(80) NULL,
    MODIFY curso ENUM('Mecatronica','Informatica','Electricidad','Refrigeracion','Contabilidad','Mecanica') NULL,
    MODIFY telefono_contacto VARCHAR(30) NULL;

UPDATE estudiantes SET nombre_completo = TRIM(CONCAT(nombre, ' ', apellido));
UPDATE estudiantes SET matricula = CONCAT('SIN-MAT-', id) WHERE matricula IS NULL;  -- solo si ya había filas
ALTER TABLE datos_salud_estudiante ADD COLUMN grupo_sanguineo VARCHAR(12) NULL AFTER id_estudiante;

-- Visitas: momento en que se registró (la pantalla lo muestra aparte de la fecha de la visita)
ALTER TABLE visitas ADD COLUMN registrada_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER despachado;

-- Solicitudes de medicamentos: presentación y cantidades numéricas (solicitada / entregada)
ALTER TABLE solicitudes_medicamentos
    ADD COLUMN presentacion VARCHAR(100) NULL AFTER medicamento,
    MODIFY cantidad_solicitada INT UNSIGNED NULL,
    ADD COLUMN cantidad_entregada INT UNSIGNED NOT NULL DEFAULT 0 AFTER cantidad_solicitada;

-- Auditoría
ALTER TABLE registros_auditoria MODIFY entidad VARCHAR(80) NOT NULL DEFAULT 'general';
ALTER TABLE datos_salud_estudiante ADD COLUMN grupo_sanguineo VARCHAR(12) NULL AFTER id_estudiante;

-- Visitas: momento en que se registró (la pantalla lo muestra aparte de la fecha de la visita)
ALTER TABLE visitas ADD COLUMN registrada_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER despachado;

-- Solicitudes de medicamentos: presentación y cantidades numéricas (solicitada / entregada)
ALTER TABLE solicitudes_medicamentos
    ADD COLUMN presentacion VARCHAR(100) NULL AFTER medicamento,
    MODIFY cantidad_solicitada INT UNSIGNED NULL,
    ADD COLUMN cantidad_entregada INT UNSIGNED NOT NULL DEFAULT 0 AFTER cantidad_solicitada;

-- Auditoría
ALTER TABLE registros_auditoria MODIFY entidad VARCHAR(80) NOT NULL DEFAULT 'general';

select * from estudiantes