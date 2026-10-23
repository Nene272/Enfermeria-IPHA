-- Ejecutar DESPUÉS del script original (el que ya tienen).
USE enfermeria_escolar;

-- El frontend maneja grupo sanguíneo, presentación y cantidad entregada; la BD original no.
ALTER TABLE datos_salud_estudiante ADD COLUMN grupo_sanguineo VARCHAR(5) NULL AFTER id_estudiante;
ALTER TABLE solicitudes_medicamentos
    ADD COLUMN presentacion VARCHAR(80) NULL AFTER medicamento,
    ADD COLUMN cantidad_entregada INT NOT NULL DEFAULT 0 AFTER cantidad_solicitada;

-- Usuario de la aplicación (NO uses root en el backend).
-- Cambia la clave. '%' permite conexión desde otro dispositivo de la red.
CREATE USER IF NOT EXISTS 'enfermeria_app'@'%' IDENTIFIED BY 'CAMBIA_ESTA_CLAVE';
GRANT SELECT, INSERT, UPDATE ON enfermeria_escolar.* TO 'enfermeria_app'@'%';
FLUSH PRIVILEGES;
