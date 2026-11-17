-- TPFI Base de Datos - Sistema de Justicia
-- 07_poblado.sql
-- Correr despues de 06_usuarios_permisos.sql, con admin_bd y sobre las tablas recien creadas.
-- Los triggers quedan activos: el poblado tambien prueba las reglas de negocio.
--
-- Referencias usadas en todo el script (n = numero de persona, c = numero de causa):
--   Persona n      -> DNI 30000000 + n   (1-20 jueces, 21-40 secretarios, 41-300 civiles)
--   Causa c        -> numeroInternoRegistro 1000 + c (c = 1..120)
--   Acusado k      -> id k (k = 1..200)

BEGIN;

-- ---------------------------------------------------------------
-- Catalogos
-- ---------------------------------------------------------------
INSERT INTO Nacionalidad (id, nombre) VALUES
(1, 'Argentina'), (2, 'Uruguaya'), (3, 'Paraguaya'), (4, 'Brasileña'), (5, 'Chilena'),
(6, 'Boliviana'), (7, 'Peruana'), (8, 'Colombiana'), (9, 'Venezolana'), (10, 'Ecuatoriana'),
(11, 'Mexicana'), (12, 'Española'), (13, 'Italiana'), (14, 'Estadounidense'), (15, 'China');

INSERT INTO Profesion (id, nombre) VALUES
(1, 'Abogado'), (2, 'Comerciante'), (3, 'Docente'), (4, 'Albañil'), (5, 'Electricista'),
(6, 'Médico'), (7, 'Enfermero'), (8, 'Contador'), (9, 'Mecánico'), (10, 'Chofer'),
(11, 'Programador'), (12, 'Carpintero'), (13, 'Plomero'), (14, 'Empleado administrativo'), (15, 'Agricultor'),
(16, 'Cocinero'), (17, 'Vendedor'), (18, 'Policía'), (19, 'Arquitecto'), (20, 'Estudiante');

INSERT INTO Secretaria (id, nombre)
SELECT s, 'Secretaría Penal N° ' || s
FROM generate_series(1, 15) s;

INSERT INTO Fiscalia (id, nombre)
SELECT f, 'Fiscalía de Instrucción N° ' || f
FROM generate_series(1, 15) f;

-- ---------------------------------------------------------------
-- Domicilios: 1-15 sedes de unidades carcelarias, 16-200 viviendas
-- ---------------------------------------------------------------
INSERT INTO Domicilio (id, direccion)
SELECT d, 'Ruta Provincial ' || (10 + d) || ' Km ' || (d * 7)
FROM generate_series(1, 15) d;

INSERT INTO Domicilio (id, direccion)
SELECT d,
       (ARRAY['San Martín', 'Belgrano', 'Rivadavia', '25 de Mayo', 'Mitre', 'Urquiza',
              'Sarmiento', 'Moreno', 'Alem', 'España', 'Galarza', 'Rocamora'])[1 + d % 12]
       || ' ' || (100 + d * 13)
FROM generate_series(16, 200) d;

INSERT INTO UnidadCarcelaria (id, nombre, domicilio_id)
SELECT u, 'Unidad Penal N° ' || u, u
FROM generate_series(1, 15) u;

-- ---------------------------------------------------------------
-- Personas
-- ---------------------------------------------------------------
INSERT INTO Persona (dni, nombres, apellidos, fechaNacimiento, estadoCivil, nivelEducacion, nacionalidad_id, profesion_id)
SELECT 30000000 + n,
       (ARRAY['Juan', 'María', 'Carlos', 'Ana', 'Luis', 'Laura', 'Jorge', 'Sofía', 'Pedro', 'Lucía',
              'Diego', 'Paula', 'Martín', 'Valeria', 'Pablo', 'Carolina', 'Andrés', 'Gabriela', 'Hugo', 'Romina'])[1 + n % 20],
       (ARRAY['González', 'Rodríguez', 'Gómez', 'Fernández', 'López', 'Díaz', 'Martínez', 'Pérez', 'García',
              'Sánchez', 'Romero', 'Sosa', 'Álvarez', 'Torres', 'Ruiz', 'Ramírez', 'Flores', 'Benítez', 'Acosta',
              'Medina', 'Herrera', 'Suárez', 'Aguirre', 'Giménez', 'Gutiérrez'])[1 + (n * 7) % 25],
       CASE
           WHEN n <= 20 THEN DATE '1955-03-01' + n * 200
           WHEN n <= 40 THEN DATE '1965-01-01' + (n - 20) * 180
           ELSE DATE '1955-01-01' + (n - 41) * 45
       END,
       (ARRAY['SOLTERO', 'CASADO', 'DIVORCIADO', 'VIUDO', 'CONVIVIENTE'])[1 + n % 5],
       CASE
           WHEN n <= 40 THEN 'UNIVERSITARIO'
           ELSE (ARRAY['SIN_INSTRUCCION', 'PRIMARIO', 'SECUNDARIO', 'TERCIARIO', 'UNIVERSITARIO'])[1 + n % 5]
       END,
       CASE WHEN n <= 40 OR n % 4 <> 0 THEN 1 ELSE 1 + n % 15 END,
       CASE
           WHEN n <= 40 THEN 1
           WHEN n % 6 = 0 THEN NULL
           ELSE 1 + n % 20
       END
FROM generate_series(1, 300) n;

-- ---------------------------------------------------------------
-- Relaciones familiares
-- ---------------------------------------------------------------
-- Casos para la consulta C (familiares en la misma causa)
INSERT INTO RelacionFamiliar (tipo, persona_dni, familiar_dni) VALUES
('PADRE',   30000210, 30000090),  -- padre e hijo acusados en la causa 1050
('HERMANO', 30000091, 30000211),  -- dos hermanos acusados en la causa 1051
('HIJO',    30000092, 30000212),  -- padre e hijo acusados en la causa 1052
('HERMANO', 30000093, 30000013);  -- el juez de la causa 1053 es hermano del acusado

-- Resto: entre personas que no participan de ninguna causa (231 a 300)
INSERT INTO RelacionFamiliar (tipo, persona_dni, familiar_dni)
SELECT (ARRAY['HERMANO', 'PADRE', 'MADRE', 'HIJO'])[1 + i % 4],
       30000231 + i % 70,
       30000231 + (i % 70 + 1 + 3 * (i / 70)) % 70
FROM generate_series(0, 145) i;

-- ---------------------------------------------------------------
-- Propiedad de domicilios
-- ---------------------------------------------------------------
-- Personas 41 a 225: duenas de las viviendas 16 a 200 (domicilio principal)
INSERT INTO PropiedadDomicilio (persona_dni, domicilio_id, fechaDesde, esPrincipal)
SELECT 30000000 + n, n - 25, DATE '2010-01-01' + n, TRUE
FROM generate_series(41, 225) n;

-- Personas 226 a 300 compran las viviendas 16 a 90:
-- trg_propiedad_rotacion cierra el periodo del dueno anterior
INSERT INTO PropiedadDomicilio (persona_dni, domicilio_id, fechaDesde, esPrincipal)
SELECT 30000000 + n, n - 210, DATE '2022-03-01' + (n - 226) * 3, TRUE
FROM generate_series(226, 300) n;

-- ---------------------------------------------------------------
-- Causas judiciales
-- ---------------------------------------------------------------
-- Las causas 1101 a 1113 son de la secretaria 1 (consulta A):
--   1101-1110 con alta en los ultimos 6 meses, 1111-1113 con alta de hace mas de 7 meses
INSERT INTO CausaJudicial (numeroInternoRegistro, fechaAlta, secretaria_id, fiscalia_id, juez_dni, secretario_dni)
SELECT 1000 + c,
       CASE
           WHEN c BETWEEN 101 AND 110 THEN CURRENT_DATE - (c - 100) * 15
           WHEN c BETWEEN 111 AND 113 THEN (CURRENT_DATE - INTERVAL '7 months')::DATE - (c - 110) * 20
           ELSE DATE '2016-01-01' + c * 20
       END,
       CASE WHEN c BETWEEN 101 AND 113 THEN 1 ELSE 2 + (c - 1) % 14 END,
       1 + (c - 1) % 15,
       30000000 + 1 + (c - 1) % 20,
       30000000 + 21 + (c - 1) % 20
FROM generate_series(1, 120) c;

-- ---------------------------------------------------------------
-- Acusados
-- ---------------------------------------------------------------
-- 1 a 120: primer acusado de cada causa (personas 41 a 160)
-- 121 a 190: segundo acusado de las causas 1001 a 1070 (personas 161 a 230)
-- 191 a 200: segundo acusado de las causas 1071 a 1080 (personas 41 a 50, que ya estan en otra causa)
INSERT INTO Acusado (id, persona_dni, causa_id)
SELECT k,
       30000000 + CASE WHEN k <= 190 THEN 40 + k ELSE 40 + (k - 190) END,
       1000 + CASE WHEN k <= 120 THEN k ELSE k - 120 END
FROM generate_series(1, 200) k;

-- Cambios de estado (los valida trg_acusado_estado)
UPDATE Acusado SET estadoActual = 'PROCESADO'
WHERE id <= 120
   OR (id BETWEEN 121 AND 190 AND id % 3 <> 2)
   OR id >= 191;

-- Sobreseidos. Los acusados 191 a 193 son las personas 41 a 43,
-- que ademas quedan condenadas en las causas 1001 a 1003 (consulta E)
UPDATE Acusado SET estadoActual = 'SOBRESEIDO'
WHERE (id BETWEEN 121 AND 190 AND id % 3 = 1)
   OR id BETWEEN 191 AND 193;

-- ---------------------------------------------------------------
-- Condenas: se dictan con sp_dictar_condena (acusados 1 a 120)
-- ---------------------------------------------------------------
-- Causas 1076 a 1087: prision domiciliaria (consulta D)
--   1076-1083 vigentes, 1084-1085 se dan de baja, 1086 vencida sin baja, 1087 empieza en el futuro
DO $$
DECLARE
    c INTEGER;
    v_alta DATE;
    v_inicio DATE;
    v_duracion INTEGER;
BEGIN
    FOR c IN 1..120 LOOP
        SELECT fechaAlta INTO v_alta FROM CausaJudicial WHERE numeroInternoRegistro = 1000 + c;

        v_inicio := v_alta + 30;
        v_duracion := CASE c % 4 WHEN 0 THEN 24 WHEN 1 THEN 60 WHEN 2 THEN 120 ELSE 240 END;

        IF c BETWEEN 101 AND 113 THEN
            v_inicio := v_alta + 5;
            v_duracion := 60;
        ELSIF c BETWEEN 20 AND 24 THEN
            v_duracion := 24;
        ELSIF c = 25 OR c BETWEEN 76 AND 83 THEN
            v_duracion := 240;
        ELSIF c = 30 THEN
            v_duracion := 120;
        ELSIF c BETWEEN 84 AND 86 THEN
            v_duracion := 12;
        ELSIF c = 87 THEN
            v_inicio := CURRENT_DATE + 30;
            v_duracion := 24;
        END IF;

        PERFORM sp_dictar_condena(
            c,
            v_inicio,
            v_duracion,
            1 + (c - 1) % 15,
            c BETWEEN 76 AND 87
        );
    END LOOP;
END $$;

-- ---------------------------------------------------------------
-- Cambios de condena (los aplica trg_cambio_aplicar)
-- ---------------------------------------------------------------
DO $$
DECLARE
    v_condena RECORD;
    v_destino INTEGER;
    v_fecha DATE;
    i INTEGER;
    v_faltan INTEGER;
    v_ronda INTEGER;
BEGIN
    -- Consulta B: extensiones y reducciones
    --   secretaria 1: 1101 (5), 1102 (6), 1103 (7), 1104 (4) y 1105 (4)
    --   otra secretaria: 1030 (6)
    FOR v_condena IN
        SELECT co.id, co.fechaInicio, x.ext, x.red
        FROM (VALUES (101, 3, 2), (102, 4, 2), (103, 4, 3),
                     (104, 2, 2), (105, 3, 1), (30, 4, 2)) AS x(c, ext, red)
        JOIN Condena co ON co.acusado_id = x.c
    LOOP
        FOR i IN 1..v_condena.ext LOOP
            INSERT INTO CambioCondena (fechaCambio, tipoCambio, razon, condena_id, mesesVariacion)
            VALUES (LEAST(v_condena.fechaInicio + i * 5, CURRENT_DATE), 'EXTENSION_CONDENA',
                    'Nuevo delito cometido durante la condena', v_condena.id, 2);
        END LOOP;
        FOR i IN 1..v_condena.red LOOP
            INSERT INTO CambioCondena (fechaCambio, tipoCambio, razon, condena_id, mesesVariacion)
            VALUES (LEAST(v_condena.fechaInicio + (v_condena.ext + i) * 5, CURRENT_DATE), 'REDUCCION_CONDENA',
                    'Buena conducta', v_condena.id, 1);
        END LOOP;
    END LOOP;

    -- Consulta F: traslados
    --   vencidas: 1020 (4), 1021 (4), 1022 (5), 1023 (3), 1024 (3); vigente: 1025 (5)
    FOR v_condena IN
        SELECT co.id, co.fechaInicio, x.cant
        FROM (VALUES (20, 4), (21, 4), (22, 5), (23, 3), (24, 3), (25, 5)) AS x(c, cant)
        JOIN Condena co ON co.acusado_id = x.c
    LOOP
        FOR i IN 1..v_condena.cant LOOP
            SELECT 1 + unidadCarcelaria_id % 15 INTO v_destino FROM Condena WHERE id = v_condena.id;
            INSERT INTO CambioCondena (fechaCambio, tipoCambio, razon, condena_id, unidadCarcelaria_id)
            VALUES (v_condena.fechaInicio + i * 60, 'CAMBIO_UNIDAD_CARCELARIA',
                    'Traslado por sobrepoblación', v_condena.id, v_destino);
        END LOOP;
    END LOOP;

    -- Resto de las condenas: una extension, un traslado y, si hace falta, una reduccion,
    -- hasta llegar a 250 cambios en total
    v_ronda := 1;
    WHILE (SELECT COUNT(*) FROM CambioCondena) < 250 AND v_ronda <= 3 LOOP
        FOR v_condena IN
            SELECT co.id, co.fechaInicio
            FROM Condena co
            WHERE co.acusado_id NOT IN (20, 21, 22, 23, 24, 25, 30, 101, 102, 103, 104, 105)
              AND co.acusado_id NOT BETWEEN 76 AND 87
            ORDER BY co.id
        LOOP
            EXIT WHEN (SELECT COUNT(*) FROM CambioCondena) >= 250;
            v_fecha := LEAST(v_condena.fechaInicio + v_ronda * 40, CURRENT_DATE);

            IF v_ronda = 1 THEN
                INSERT INTO CambioCondena (fechaCambio, tipoCambio, razon, condena_id, mesesVariacion)
                VALUES (v_fecha, 'EXTENSION_CONDENA', 'Incumplimiento de normas del penal', v_condena.id, 1);
            ELSIF v_ronda = 2 THEN
                SELECT 1 + unidadCarcelaria_id % 15 INTO v_destino FROM Condena WHERE id = v_condena.id;
                INSERT INTO CambioCondena (fechaCambio, tipoCambio, razon, condena_id, unidadCarcelaria_id)
                VALUES (v_fecha, 'CAMBIO_UNIDAD_CARCELARIA', 'Acercamiento familiar', v_condena.id, v_destino);
            ELSE
                INSERT INTO CambioCondena (fechaCambio, tipoCambio, razon, condena_id, mesesVariacion)
                VALUES (v_fecha, 'REDUCCION_CONDENA', 'Estudios completados en el penal', v_condena.id, 1);
            END IF;
        END LOOP;
        v_ronda := v_ronda + 1;
    END LOOP;
END $$;

-- ---------------------------------------------------------------
-- Bajas de condenas cumplidas
-- ---------------------------------------------------------------
-- Domiciliarias 1084 y 1085, la vencida 1020 y la mitad de las demas vencidas.
-- Quedan sin baja la domiciliaria 1086 y otras vencidas, para probar sp_liberar_condenas_cumplidas.
UPDATE Condena co
SET fechaBajaLibertad = (co.fechaInicio + co.duracionMeses * INTERVAL '1 month')::DATE + 10
WHERE (co.fechaInicio + co.duracionMeses * INTERVAL '1 month')::DATE < CURRENT_DATE - 30
  AND (co.acusado_id IN (20, 84, 85)
       OR (co.acusado_id % 2 = 0
           AND co.acusado_id NOT IN (21, 22, 23, 24, 86)
           AND co.acusado_id NOT BETWEEN 76 AND 87));

-- ---------------------------------------------------------------
-- Causas resueltas (con sp_resolver_causa)
-- ---------------------------------------------------------------
-- 1107 a 1110: cerradas de la secretaria 1 (consulta A); 1081 a 1100 y 1114 a 1120: causas viejas
DO $$
DECLARE
    c INTEGER;
BEGIN
    FOR c IN 107..110 LOOP
        PERFORM sp_resolver_causa(1000 + c, CURRENT_DATE - 2);
    END LOOP;

    FOR c IN SELECT generate_series(81, 100) UNION SELECT generate_series(114, 120) LOOP
        PERFORM sp_resolver_causa(1000 + c, (SELECT fechaAlta + 400 FROM CausaJudicial
                                             WHERE numeroInternoRegistro = 1000 + c));
    END LOOP;
END $$;

-- Los ids se cargaron a mano en algunas tablas: se ajustan las secuencias
SELECT setval(pg_get_serial_sequence('nacionalidad', 'id'), (SELECT MAX(id) FROM Nacionalidad));
SELECT setval(pg_get_serial_sequence('profesion', 'id'), (SELECT MAX(id) FROM Profesion));
SELECT setval(pg_get_serial_sequence('secretaria', 'id'), (SELECT MAX(id) FROM Secretaria));
SELECT setval(pg_get_serial_sequence('fiscalia', 'id'), (SELECT MAX(id) FROM Fiscalia));
SELECT setval(pg_get_serial_sequence('domicilio', 'id'), (SELECT MAX(id) FROM Domicilio));
SELECT setval(pg_get_serial_sequence('unidadcarcelaria', 'id'), (SELECT MAX(id) FROM UnidadCarcelaria));
SELECT setval(pg_get_serial_sequence('acusado', 'id'), (SELECT MAX(id) FROM Acusado));

COMMIT;

-- Verificacion: cantidad de filas por tabla
SELECT 'Nacionalidad' AS tabla, COUNT(*) AS filas FROM Nacionalidad
UNION ALL SELECT 'Profesion', COUNT(*) FROM Profesion
UNION ALL SELECT 'Secretaria', COUNT(*) FROM Secretaria
UNION ALL SELECT 'Fiscalia', COUNT(*) FROM Fiscalia
UNION ALL SELECT 'Domicilio', COUNT(*) FROM Domicilio
UNION ALL SELECT 'UnidadCarcelaria', COUNT(*) FROM UnidadCarcelaria
UNION ALL SELECT 'Persona', COUNT(*) FROM Persona
UNION ALL SELECT 'RelacionFamiliar', COUNT(*) FROM RelacionFamiliar
UNION ALL SELECT 'PropiedadDomicilio', COUNT(*) FROM PropiedadDomicilio
UNION ALL SELECT 'CausaJudicial', COUNT(*) FROM CausaJudicial
UNION ALL SELECT 'Acusado', COUNT(*) FROM Acusado
UNION ALL SELECT 'Condena', COUNT(*) FROM Condena
UNION ALL SELECT 'CambioCondena', COUNT(*) FROM CambioCondena;
