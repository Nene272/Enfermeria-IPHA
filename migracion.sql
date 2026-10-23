-- Adapta una base YA creada con el dbo.sql original al diseño actual de la pantalla.
-- Ejecutar UNA sola vez:  mysql -u root -p enfermeria_escolar < migracion.sql
-- (Si la base es nueva, no hace falta: el dbo.sql de este repositorio ya incluye todo.)
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

ALTER TABLE estudiantes
    MODIFY matricula VARCHAR(30) NOT NULL,
    MODIFY nombre_completo VARCHAR(200) NOT NULL,
    ADD UNIQUE KEY uq_estudiantes_matricula (matricula),
    DROP COLUMN nombre,
    DROP COLUMN apellido;

-- Salud: grupo sanguíneo
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

CREATE OR REPLACE VIEW vista_visitas_por_estudiante AS
SELECT e.id AS id_estudiante, e.matricula, e.nombre_completo, e.grado, e.curso, e.estado,
       COUNT(v.id) AS cantidad_visitas, MAX(v.fecha_visita) AS ultima_visita
FROM estudiantes AS e LEFT JOIN visitas AS v ON v.id_estudiante = e.id
GROUP BY e.id;
