-- Roles de la aplicación con contraseña de prueba (se guardan cifradas).
--   Enfermería:     Demo-Enfermeria-26
--   Orientación:    Demo-Orientacion-26
--   Administración: Demo-Admin-26
-- Ejecutar sobre la base que ya tienes (enfermeria_escolar). Sirve aunque los roles ya existan.
USE enfermeria_escolar;

INSERT INTO login_enfermeria (rol, contrasena_hash) VALUES
    ('enfermeria', 'pbkdf2:sha256:600000$cvwA15QMJIOt6wul$77ef6b8bcf282690352761679be5c60f13521b8a06113b1de46ad281fdff1c06'),
    ('orientacion', 'pbkdf2:sha256:600000$Ql5jQbMKcq2loFNd$6b5a818a708eed616a2ce01682ea3aacacbefd36512747ce83930f6fb9ec0bbe'),
    ('administracion', 'pbkdf2:sha256:600000$nXTDjrJzabxtoeOp$1c90af23f09dce89425377ee069d9a2a1e1aaba01c3b5dc3a33e133e5d411596')
ON DUPLICATE KEY UPDATE contrasena_hash = VALUES(contrasena_hash);

SELECT rol, LEFT(contrasena_hash, 20) AS hash_inicio FROM login_enfermeria;
