CREATE DATABASE IF NOT EXISTS enfermeria_escolar;

USE enfermeria_escolar;

CREATE TABLE IF NOT EXISTS estudiantes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    curso VARCHAR(30),
    grado VARCHAR(10),
    fecha_nacimiento DATE,
    telefono_contacto VARCHAR(20)
);


CREATE TABLE IF NOT EXISTS login_enfermeria (
rol VARCHAR(50) PRIMARY KEY,
contraseña VARCHAR(50)
);

SHOW TABLES;
alter table estudiantes drop column matricula

DELETE FROM estudiantes WHERE id >= 31;

CREATE USER 'Landers'@'100.88.144.11'
IDENTIFIED BY 'landers19';

GRANT SELECT, INSERT, UPDATE, DELETE
ON enfermeria_escolar.*
TO 'Landers'@'100.88.144.11';

alter table estudiantes add column despachado bit;

update estudiantes set despachado = 0 where id >= 0

SELECT user, host
FROM mysql.user
WHERE user = 'Landers';

SHOW GRANTS FOR 'Robinson'@'100.117.198.43';

CREATE USER 'Robinson'@'100.117.198.43'
IDENTIFIED BY 'robin17';

GRANT SELECT, INSERT, UPDATE, DELETE
ON enfermeria_escolar.*
TO 'Robinson'@'100.117.198.43';

SELECT user, host
FROM mysql.user
WHERE user = 'Robinson';

show tables;

ALTER TABLE estudiantes RENAME COLUMN seccion TO grado;

INSERT INTO estudiantes (nombre, apellido, curso, grado, fecha_nacimiento, telefono_contacto) 
VALUES ('Abniel Moises', 'Almonte Arias', 'Informatica', '6to', '2008-10-07', '809-594-4959');

INSERT INTO estudiantes (nombre, apellido, curso, grado, fecha_nacimiento, telefono_contacto) VALUES
-- Contabilidad
('Laisha Nicantri', 'Adames Susana', 'Contabilidad', '6to', '2008-03-15', '809-555-0101'),
('Genesis', 'Almonte Arias', 'Contabilidad', '6to', '2008-07-22', '809-555-0102'),
('Darlenis', 'Arias Ramirez', 'Contabilidad', '6to', '2008-01-10', '809-555-0103'),
('Jaely', 'Campusano Evans', 'Contabilidad', '6to', '2008-11-05', '809-555-0104'),
('Jhoarmi Victoria', 'Cuello Cuevas', 'Contabilidad', '6to', '2008-05-18', '809-555-0105'),

-- Informatica (Varones)
('Abniel Moises', 'Adames Susana', 'Informatica', '6to', '2008-04-10', '809-555-0127'),
('Robinson Jadiel', 'Hidalgo Correa', 'Informatica', '6to', '2008-08-20', '809-555-0128'),
('Enmanuel', 'Lorezo Delgado', 'Informatica', '6to', '2008-01-12', '809-555-0129'),
('Lander Enmanuel', 'Medrano Cuevas', 'Informatica', '6to', '2008-06-05', '809-555-0130'),

-- Mecanica
('Bismar', 'Cuello Martinez', 'Mecanica', '6to', '2008-09-30', '809-555-0106'),
('Iamdra Jhermayoni', 'De Los Santos Santana', 'Mecanica', '6to', '2008-02-14', '809-555-0107'),
('Enyeli', 'De Los Santos Valdez', 'Mecanica', '6to', '2008-08-12', '809-555-0108'),
('Mariely', 'De Mata Encarnacion', 'Mecanica', '6to', '2008-04-25', '809-555-0109'),
('Yolayny Ester', 'Diaz Hidalgo', 'Mecanica', '6to', '2008-12-01', '809-555-0110'),

-- Electricidad
('Deyanersi', 'Encarnacion Cuevas', 'Electricidad', '6to', '2008-06-17', '809-555-0111'),
('Brendelis Dancis', 'Fajardo Perez', 'Electricidad', '6to', '2008-10-08', '809-555-0112'),
('Mariermi', 'Feliz Moreno', 'Electricidad', '6to', '2008-01-29', '809-555-0113'),
('Nicole Isabel', 'Figueroa Mrtinez', 'Electricidad', '6to', '2008-03-03', '809-555-0114'),
('Cristar Alexa', 'Gomez De Leon', 'Electricidad', '6to', '2008-07-19', '809-555-0115'),

-- Mecatronica
('Keisi Freyeli', 'Herrera Vargas', 'Mecatronica', '6to', '2008-05-24', '809-555-0116'),
('Esmerlin', 'Medina Trinidad', 'Mecatronica', '6to', '2008-09-11', '809-555-0117'),
('Wilmari Yasmil', 'Pared German', 'Mecatronica', '6to', '2008-11-28', '809-555-0118'),
('Alejandra', 'Peña Valdez', 'Mecatronica', '6to', '2008-02-07', '809-555-0119'),
('Lorianan', 'Peñalo Chaves', 'Mecatronica', '6to', '2008-08-15', '809-555-0120'),

-- Refrigeracion
('Yadelis', 'Perez Perez', 'Refrigeracion', '6to', '2008-04-02', '809-555-0121'),
('Yismeiry', 'Rodriguez Mercedez', 'Refrigeracion', '6to', '2008-10-21', '809-555-0122'),
('Washley Janel', 'Rosario Peña', 'Refrigeracion', '6to', '2008-06-09', '809-555-0123'),
('Ashley Juliette', 'Tejada Capellan', 'Refrigeracion', '6to', '2008-12-14', '809-555-0124'),
('Emma Pedrina', 'Valdez Diaz', 'Refrigeracion', '6to', '2008-01-31', '809-555-0125'),
('Olianny', 'Ventura Montero', 'Refrigeracion', '6to', '2008-07-04', '809-555-0126');

update estudiantes set fecha_nacimiento = '2009-11-20' where id = 8

select * from estudiantes