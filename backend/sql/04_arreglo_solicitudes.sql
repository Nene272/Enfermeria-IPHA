-- Termina la migración: solo la tabla solicitudes_medicamentos (y lo que venía después).
-- Ejecutar UNA vez con root, sobre la base que ya tienen.
USE enfermeria_escolar;

-- 1) La cantidad pasaba de texto ('2 cajas') a número: se deja solo el número ('2').
UPDATE solicitudes_medicamentos
SET cantidad_solicitada = NULLIF(REGEXP_REPLACE(cantidad_solicitada, '[^0-9]', ''), '')
WHERE id > 0;

-- 2) Columnas que faltaban.
ALTER TABLE solicitudes_medicamentos
    ADD COLUMN presentacion VARCHAR(100) NULL AFTER medicamento,
    MODIFY cantidad_solicitada INT UNSIGNED NULL,
    ADD COLUMN cantidad_entregada INT UNSIGNED NOT NULL DEFAULT 0 AFTER cantidad_solicitada;

-- 3) Lo que quedaba al final de migracion.sql.
ALTER TABLE registros_auditoria MODIFY entidad VARCHAR(80) NOT NULL DEFAULT 'general';

CREATE OR REPLACE VIEW vista_visitas_por_estudiante AS
SELECT e.id AS id_estudiante, e.matricula, e.nombre_completo, e.grado, e.curso, e.estado,
       COUNT(v.id) AS cantidad_visitas, MAX(v.fecha_visita) AS ultima_visita
FROM estudiantes AS e LEFT JOIN visitas AS v ON v.id_estudiante = e.id
GROUP BY e.id;

SELECT 'Listo' AS resultado;
