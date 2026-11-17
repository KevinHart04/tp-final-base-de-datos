-- TPFI Base de Datos - Sistema de Justicia
-- 08_testing.sql
-- Correr despues de 07_poblado.sql, con admin_bd.
-- Cada caso corre en su propia transaccion y termina en ROLLBACK, asi no cambia los datos.
-- El resultado sale como NOTICE: "OK" si se cumplio lo esperado, "FALLA" si no.
-- (En DBeaver se ve en la pestaña Output; activarla con el boton "Show server output".)

-- =====================================================================
-- Restricciones
-- =====================================================================

-- T01: PK Persona, DNI repetido
BEGIN;
DO $$ BEGIN
    INSERT INTO Persona VALUES (30000001, 'Repetido', 'Repetido', '1990-01-01', 'SOLTERO', 'PRIMARIO', 1, NULL);
    RAISE NOTICE 'T01 FALLA: se insertó un DNI repetido';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'T01 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T02: FK Acusado, causa inexistente
BEGIN;
DO $$ BEGIN
    INSERT INTO Acusado (persona_dni, causa_id) VALUES (30000231, 9999);
    RAISE NOTICE 'T02 FALLA: se insertó un acusado con causa inexistente';
EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE 'T02 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T03: UNIQUE Acusado, misma persona dos veces en la misma causa
BEGIN;
DO $$ BEGIN
    INSERT INTO Acusado (persona_dni, causa_id) VALUES (30000041, 1001);
    RAISE NOTICE 'T03 FALLA: se imputó dos veces a la misma persona';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'T03 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T04: CHECK Condena, duracionMeses = 0
BEGIN;
DO $$ BEGIN
    INSERT INTO Condena (fechaInicio, duracionMeses, acusado_id, unidadCarcelaria_id)
    VALUES (CURRENT_DATE, 0, 196, 1);
    RAISE NOTICE 'T04 FALLA: se insertó una condena de 0 meses';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T04 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T05: Condena con unidad carcelaria y domicilio a la vez
BEGIN;
DO $$ BEGIN
    UPDATE Acusado SET estadoActual = 'CONDENADO' WHERE id = 196;
    INSERT INTO Condena (fechaInicio, duracionMeses, acusado_id, unidadCarcelaria_id, domicilio_id)
    VALUES (CURRENT_DATE, 12, 196, 1, 30);
    RAISE NOTICE 'T05 FALLA: se insertó una condena con dos lugares';
EXCEPTION WHEN check_violation OR raise_exception THEN RAISE NOTICE 'T05 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T08: CHECK RelacionFamiliar, persona relacionada consigo misma
BEGIN;
DO $$ BEGIN
    INSERT INTO RelacionFamiliar (tipo, persona_dni, familiar_dni) VALUES ('HERMANO', 30000050, 30000050);
    RAISE NOTICE 'T08 FALLA: se relacionó a una persona consigo misma';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T08 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T19: CHECK Condena, baja antes del fin de la condena
BEGIN;
DO $$ BEGIN
    UPDATE Condena SET fechaBajaLibertad = CURRENT_DATE WHERE id = 3;
    RAISE NOTICE 'T19 FALLA: se dio de baja una condena vigente';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T19 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T20: razon vacia
BEGIN;
DO $$ BEGIN
    INSERT INTO CambioCondena (tipoCambio, razon, condena_id, mesesVariacion)
    VALUES ('EXTENSION_CONDENA', '   ', 3, 2);
    RAISE NOTICE 'T20 FALLA: se insertó un cambio sin razón';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T20 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T36: CAMBIO_UNIDAD_CARCELARIA con mesesVariacion
BEGIN;
DO $$ BEGIN
    INSERT INTO CambioCondena (tipoCambio, razon, condena_id, mesesVariacion, unidadCarcelaria_id)
    VALUES ('CAMBIO_UNIDAD_CARCELARIA', 'Traslado', 3, 3, 9);
    RAISE NOTICE 'T36 FALLA: se insertó un traslado con meses';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T36 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T37: EXTENSION_CONDENA sin mesesVariacion
BEGIN;
DO $$ BEGIN
    INSERT INTO CambioCondena (tipoCambio, razon, condena_id) VALUES ('EXTENSION_CONDENA', 'Extensión', 3);
    RAISE NOTICE 'T37 FALLA: se insertó una extensión sin meses';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T37 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T38: CAMBIO_UNIDAD_CARCELARIA sin unidad de destino
BEGIN;
DO $$ BEGIN
    INSERT INTO CambioCondena (tipoCambio, razon, condena_id) VALUES ('CAMBIO_UNIDAD_CARCELARIA', 'Traslado', 3);
    RAISE NOTICE 'T38 FALLA: se insertó un traslado sin destino';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T38 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T39: fechaResolucion anterior a fechaAlta
BEGIN;
DO $$ BEGIN
    UPDATE CausaJudicial SET fechaResolucion = '2000-01-01' WHERE numeroInternoRegistro = 1001;
    RAISE NOTICE 'T39 FALLA: se cargó una resolución anterior al alta';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'T39 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- =====================================================================
-- Triggers
-- =====================================================================

-- T06: fecha de nacimiento futura
BEGIN;
DO $$ BEGIN
    INSERT INTO Persona VALUES (40000001, 'Test', 'Futuro', CURRENT_DATE + 1, 'SOLTERO', 'PRIMARIO', 1, NULL);
    RAISE NOTICE 'T06 FALLA: se insertó una fecha de nacimiento futura';
EXCEPTION WHEN raise_exception THEN RAISE NOTICE 'T06 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T07: fecha de nacimiento valida
BEGIN;
DO $$ BEGIN
    INSERT INTO Persona VALUES (40000002, 'Test', 'Valido', '1990-05-10', 'SOLTERO', 'PRIMARIO', 1, NULL);
    RAISE NOTICE 'T07 OK: se insertó la persona';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'T07 FALLA: %', SQLERRM;
END $$;
ROLLBACK;

-- T09: segundo domicilio principal vigente
BEGIN;
DO $$
DECLARE v_dom INTEGER;
BEGIN
    INSERT INTO Domicilio (direccion) VALUES ('Calle de prueba 1') RETURNING id INTO v_dom;
    INSERT INTO PropiedadDomicilio (persona_dni, domicilio_id, fechaDesde, esPrincipal)
    VALUES (30000116, v_dom, CURRENT_DATE, TRUE);
    RAISE NOTICE 'T09 FALLA: la persona quedó con dos domicilios principales';
EXCEPTION WHEN raise_exception THEN RAISE NOTICE 'T09 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T10: nuevo dueno de un domicilio con dueno vigente (domicilio 100, dueña la persona 125)
BEGIN;
DO $$
DECLARE v_cierre DATE; v_vigentes INTEGER;
BEGIN
    INSERT INTO PropiedadDomicilio (persona_dni, domicilio_id, fechaDesde, esPrincipal)
    VALUES (30000240, 100, CURRENT_DATE, FALSE);
    SELECT fechaHasta INTO v_cierre FROM PropiedadDomicilio WHERE domicilio_id = 100 AND persona_dni = 30000125;
    SELECT COUNT(*) INTO v_vigentes FROM PropiedadDomicilio WHERE domicilio_id = 100 AND fechaHasta IS NULL;
    IF v_cierre = CURRENT_DATE AND v_vigentes = 1 THEN
        RAISE NOTICE 'T10 OK: se cerró el período anterior y hay un solo dueño vigente';
    ELSE
        RAISE NOTICE 'T10 FALLA: cierre %, dueños vigentes %', v_cierre, v_vigentes;
    END IF;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'T10 FALLA: %', SQLERRM;
END $$;
ROLLBACK;

-- T11: nuevo dueno con fecha anterior a la del dueno vigente
BEGIN;
DO $$ BEGIN
    INSERT INTO PropiedadDomicilio (persona_dni, domicilio_id, fechaDesde) VALUES (30000240, 100, '2000-01-01');
    RAISE NOTICE 'T11 FALLA: se aceptó un dueño con fecha anterior';
EXCEPTION WHEN raise_exception THEN RAISE NOTICE 'T11 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T12: INDAGADO -> PROCESADO -> CONDENADO (acusado 122)
BEGIN;
DO $$ BEGIN
    UPDATE Acusado SET estadoActual = 'PROCESADO' WHERE id = 122;
    UPDATE Acusado SET estadoActual = 'CONDENADO' WHERE id = 122;
    RAISE NOTICE 'T12 OK: se guardaron los dos cambios de estado';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'T12 FALLA: %', SQLERRM;
END $$;
ROLLBACK;

-- T13: INDAGADO -> CONDENADO (acusado 125)
BEGIN;
DO $$ BEGIN
    UPDATE Acusado SET estadoActual = 'CONDENADO' WHERE id = 125;
    RAISE NOTICE 'T13 FALLA: se permitió INDAGADO a CONDENADO';
EXCEPTION WHEN raise_exception THEN RAISE NOTICE 'T13 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T14: SOBRESEIDO -> PROCESADO (acusado 121)
BEGIN;
DO $$ BEGIN
    UPDATE Acusado SET estadoActual = 'PROCESADO' WHERE id = 121;
    RAISE NOTICE 'T14 FALLA: se permitió SOBRESEIDO a PROCESADO';
EXCEPTION WHEN raise_exception THEN RAISE NOTICE 'T14 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T15: condena directa para un acusado PROCESADO (acusado 123)
BEGIN;
DO $$ BEGIN
    INSERT INTO Condena (fechaInicio, duracionMeses, acusado_id, unidadCarcelaria_id)
    VALUES (CURRENT_DATE, 12, 123, 1);
    RAISE NOTICE 'T15 FALLA: se insertó la condena de un acusado PROCESADO';
EXCEPTION WHEN raise_exception THEN RAISE NOTICE 'T15 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T16: prision domiciliaria en un domicilio que no es el principal
BEGIN;
DO $$ BEGIN
    UPDATE Acusado SET estadoActual = 'CONDENADO' WHERE id = 123;
    INSERT INTO Condena (fechaInicio, duracionMeses, acusado_id, domicilio_id)
    VALUES (CURRENT_DATE, 12, 123, 30);
    RAISE NOTICE 'T16 FALLA: se aceptó un domicilio que no es el principal';
EXCEPTION WHEN raise_exception THEN RAISE NOTICE 'T16 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T17: DELETE de una condena
BEGIN;
DO $$ BEGIN
    DELETE FROM Condena WHERE id = 1;
    RAISE NOTICE 'T17 FALLA: se borró una condena';
EXCEPTION WHEN raise_exception THEN RAISE NOTICE 'T17 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T18: UPDATE directo de duracionMeses
BEGIN;
DO $$ BEGIN
    UPDATE Condena SET duracionMeses = 999 WHERE id = 3;
    RAISE NOTICE 'T18 FALLA: se cambió la duración sin CambioCondena';
EXCEPTION WHEN raise_exception THEN RAISE NOTICE 'T18 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T21: EXTENSION_CONDENA de 6 meses
BEGIN;
DO $$
DECLARE v_antes INTEGER; v_despues INTEGER;
BEGIN
    SELECT duracionMeses INTO v_antes FROM Condena WHERE id = 3;
    INSERT INTO CambioCondena (tipoCambio, razon, condena_id, mesesVariacion)
    VALUES ('EXTENSION_CONDENA', 'Prueba T21', 3, 6);
    SELECT duracionMeses INTO v_despues FROM Condena WHERE id = 3;
    IF v_despues = v_antes + 6 THEN
        RAISE NOTICE 'T21 OK: la duración pasó de % a %', v_antes, v_despues;
    ELSE
        RAISE NOTICE 'T21 FALLA: la duración pasó de % a %', v_antes, v_despues;
    END IF;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'T21 FALLA: %', SQLERRM;
END $$;
ROLLBACK;

-- T22: REDUCCION_CONDENA mayor que la duracion
BEGIN;
DO $$ BEGIN
    INSERT INTO CambioCondena (tipoCambio, razon, condena_id, mesesVariacion)
    VALUES ('REDUCCION_CONDENA', 'Prueba T22', 3, 999);
    RAISE NOTICE 'T22 FALLA: se aceptó la reducción';
EXCEPTION WHEN raise_exception THEN RAISE NOTICE 'T22 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T23: CAMBIO_UNIDAD_CARCELARIA
BEGIN;
DO $$
DECLARE v_destino INTEGER; v_condena RECORD;
BEGIN
    SELECT 1 + unidadCarcelaria_id % 15 INTO v_destino FROM Condena WHERE id = 3;
    INSERT INTO CambioCondena (tipoCambio, razon, condena_id, unidadCarcelaria_id)
    VALUES ('CAMBIO_UNIDAD_CARCELARIA', 'Prueba T23', 3, v_destino);
    SELECT * INTO v_condena FROM Condena WHERE id = 3;
    IF v_condena.unidadCarcelaria_id = v_destino AND v_condena.domicilio_id IS NULL THEN
        RAISE NOTICE 'T23 OK: la condena pasó a la unidad %', v_destino;
    ELSE
        RAISE NOTICE 'T23 FALLA: unidad %, domicilio %', v_condena.unidadCarcelaria_id, v_condena.domicilio_id;
    END IF;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'T23 FALLA: %', SQLERRM;
END $$;
ROLLBACK;

-- T24: paso a PRISION_DOMICILIARIA (condena 103, persona 143, domicilio principal 118)
BEGIN;
DO $$
DECLARE v_condena RECORD;
BEGIN
    INSERT INTO CambioCondena (tipoCambio, razon, condena_id) VALUES ('PRISION_DOMICILIARIA', 'Prueba T24', 103);
    SELECT * INTO v_condena FROM Condena WHERE id = 103;
    IF v_condena.domicilio_id = fn_domicilio_principal(30000143) AND v_condena.unidadCarcelaria_id IS NULL THEN
        RAISE NOTICE 'T24 OK: la condena pasó al domicilio %', v_condena.domicilio_id;
    ELSE
        RAISE NOTICE 'T24 FALLA: unidad %, domicilio %', v_condena.unidadCarcelaria_id, v_condena.domicilio_id;
    END IF;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'T24 FALLA: %', SQLERRM;
END $$;
ROLLBACK;

-- =====================================================================
-- Funciones y procedimientos
-- =====================================================================

-- T25: fn_edad con alguien que cumple anos hoy y alguien que cumple manana
BEGIN;
DO $$
DECLARE v_hoy INTEGER; v_manana INTEGER;
BEGIN
    INSERT INTO Persona VALUES (40000003, 'Cumple', 'Hoy', (CURRENT_DATE - INTERVAL '30 years')::DATE, 'SOLTERO', 'PRIMARIO', 1, NULL);
    INSERT INTO Persona VALUES (40000004, 'Cumple', 'Manana', (CURRENT_DATE + 1 - INTERVAL '30 years')::DATE, 'SOLTERO', 'PRIMARIO', 1, NULL);
    v_hoy := fn_edad(40000003);
    v_manana := fn_edad(40000004);
    IF v_hoy = 30 AND v_manana = 29 THEN
        RAISE NOTICE 'T25 OK: hoy % años, mañana % años', v_hoy, v_manana;
    ELSE
        RAISE NOTICE 'T25 FALLA: hoy %, mañana %', v_hoy, v_manana;
    END IF;
END $$;
ROLLBACK;

-- T26: sp_resolver_causa con un acusado PROCESADO (causa 1063)
BEGIN;
DO $$ BEGIN
    PERFORM sp_resolver_causa(1063, CURRENT_DATE);
    RAISE NOTICE 'T26 FALLA: se resolvió la causa';
EXCEPTION WHEN raise_exception THEN RAISE NOTICE 'T26 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T40: sp_dictar_condena domiciliaria (acusado 123, persona 163)
BEGIN;
DO $$
DECLARE v_id INTEGER; v_condena RECORD; v_estado TEXT;
BEGIN
    v_id := sp_dictar_condena(123, CURRENT_DATE, 24, NULL, TRUE);
    SELECT * INTO v_condena FROM Condena WHERE id = v_id;
    SELECT estadoActual INTO v_estado FROM Acusado WHERE id = 123;
    IF v_estado = 'CONDENADO' AND v_condena.domicilio_id = fn_domicilio_principal(30000163) THEN
        RAISE NOTICE 'T40 OK: condena % en el domicilio %', v_id, v_condena.domicilio_id;
    ELSE
        RAISE NOTICE 'T40 FALLA: estado %, domicilio %', v_estado, v_condena.domicilio_id;
    END IF;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'T40 FALLA: %', SQLERRM;
END $$;
ROLLBACK;

-- T41: sp_dictar_condena a un acusado INDAGADO (acusado 122)
BEGIN;
DO $$ BEGIN
    PERFORM sp_dictar_condena(122, CURRENT_DATE, 24, 1, FALSE);
    RAISE NOTICE 'T41 FALLA: se condenó a un acusado INDAGADO';
EXCEPTION WHEN raise_exception THEN RAISE NOTICE 'T41 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T42: sp_trasladar_condenados de la unidad 1 a la 2
BEGIN;
DO $$
DECLARE v_esperado INTEGER; v_devuelto INTEGER; v_quedan INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_esperado FROM Condena WHERE unidadCarcelaria_id = 1 AND fechaBajaLibertad IS NULL;
    v_devuelto := sp_trasladar_condenados(1, 2, 'Refacción de la unidad 1');
    SELECT COUNT(*) INTO v_quedan FROM Condena WHERE unidadCarcelaria_id = 1 AND fechaBajaLibertad IS NULL;
    IF v_devuelto = v_esperado AND v_quedan = 0 THEN
        RAISE NOTICE 'T42 OK: se trasladaron % condenas', v_devuelto;
    ELSE
        RAISE NOTICE 'T42 FALLA: esperadas %, devueltas %, quedan %', v_esperado, v_devuelto, v_quedan;
    END IF;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'T42 FALLA: %', SQLERRM;
END $$;
ROLLBACK;

-- T43: sp_liberar_condenas_cumplidas
BEGIN;
DO $$
DECLARE v_esperado INTEGER; v_devuelto INTEGER; v_quedan INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_esperado FROM vw_condenas_detalle WHERE situacion = 'VENCIDA';
    v_devuelto := sp_liberar_condenas_cumplidas();
    SELECT COUNT(*) INTO v_quedan FROM vw_condenas_detalle WHERE situacion = 'VENCIDA';
    IF v_devuelto = v_esperado AND v_quedan = 0 THEN
        RAISE NOTICE 'T43 OK: se dieron de baja % condenas', v_devuelto;
    ELSE
        RAISE NOTICE 'T43 FALLA: esperadas %, devueltas %, quedan %', v_esperado, v_devuelto, v_quedan;
    END IF;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'T43 FALLA: %', SQLERRM;
END $$;
ROLLBACK;

-- =====================================================================
-- Consultas
-- =====================================================================

-- T27: consulta A, secretaria 1 -> 10 causas: 6 vigentes y 4 cerradas
DO $$
DECLARE v_vig INTEGER; v_cer INTEGER;
BEGIN
    SELECT COUNT(*) FILTER (WHERE estado = 'VIGENTE'), COUNT(*) FILTER (WHERE estado = 'CERRADA')
    INTO v_vig, v_cer FROM fn_causas_secretaria(1);
    IF v_vig = 6 AND v_cer = 4 THEN RAISE NOTICE 'T27 OK: 6 vigentes y 4 cerradas';
    ELSE RAISE NOTICE 'T27 FALLA: % vigentes y % cerradas', v_vig, v_cer; END IF;
END $$;

-- T28: consulta B, secretaria 1 -> causas 1101, 1102 y 1103
DO $$
DECLARE v_causas TEXT;
BEGIN
    SELECT STRING_AGG(numeroInternoRegistro::TEXT, ',' ORDER BY numeroInternoRegistro) INTO v_causas
    FROM fn_condenados_con_cambios(1);
    IF v_causas = '1101,1102,1103' THEN RAISE NOTICE 'T28 OK: %', v_causas;
    ELSE RAISE NOTICE 'T28 FALLA: %', v_causas; END IF;
END $$;

-- T29: consulta C -> causas 1050 a 1053
DO $$
DECLARE v_causas TEXT;
BEGIN
    SELECT STRING_AGG(numeroInternoRegistro::TEXT, ',' ORDER BY numeroInternoRegistro) INTO v_causas
    FROM fn_causas_con_familiares();
    IF v_causas = '1050,1051,1052,1053' THEN RAISE NOTICE 'T29 OK: %', v_causas;
    ELSE RAISE NOTICE 'T29 FALLA: %', v_causas; END IF;
END $$;

-- T30: consulta D -> 8
DO $$ BEGIN
    IF fn_cantidad_prision_domiciliaria() = 8 THEN RAISE NOTICE 'T30 OK: 8 personas en prisión domiciliaria';
    ELSE RAISE NOTICE 'T30 FALLA: %', fn_cantidad_prision_domiciliaria(); END IF;
END $$;

-- T31: consulta E -> personas 41, 42 y 43
DO $$
DECLARE v_dnis TEXT;
BEGIN
    SELECT STRING_AGG(dni::TEXT, ',' ORDER BY dni) INTO v_dnis FROM fn_condenados_y_sobreseidos();
    IF v_dnis = '30000041,30000042,30000043' THEN RAISE NOTICE 'T31 OK: %', v_dnis;
    ELSE RAISE NOTICE 'T31 FALLA: %', v_dnis; END IF;
END $$;

-- T32: consulta F -> causas 1020, 1021 y 1022
DO $$
DECLARE v_causas TEXT;
BEGIN
    SELECT STRING_AGG(numeroInternoRegistro::TEXT, ',' ORDER BY numeroInternoRegistro) INTO v_causas
    FROM fn_condenas_vencidas_con_traslados();
    IF v_causas = '1020,1021,1022' THEN RAISE NOTICE 'T32 OK: %', v_causas;
    ELSE RAISE NOTICE 'T32 FALLA: %', v_causas; END IF;
END $$;

-- =====================================================================
-- Permisos (cada caso se ejecuta con el usuario indicado)
-- =====================================================================

-- T33: invitado lee la tabla Persona
BEGIN;
SET LOCAL ROLE invitado;
DO $$ BEGIN
    PERFORM * FROM Persona;
    RAISE NOTICE 'T33 FALLA: invitado pudo leer Persona';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'T33 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T34: juez inserta una condena directo (rechazado) y con sp_dictar_condena (acusado 196)
BEGIN;
SET LOCAL ROLE juez;
DO $$
DECLARE v_id INTEGER;
BEGIN
    BEGIN
        INSERT INTO Condena (fechaInicio, duracionMeses, acusado_id, unidadCarcelaria_id)
        VALUES (CURRENT_DATE, 12, 196, 1);
        RAISE NOTICE 'T34 FALLA: juez insertó directo en Condena';
    EXCEPTION WHEN insufficient_privilege THEN
        v_id := sp_dictar_condena(196, CURRENT_DATE, 12, 1, FALSE);
        RAISE NOTICE 'T34 OK: INSERT directo rechazado, sp_dictar_condena registró la condena %', v_id;
    END;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'T34 FALLA: %', SQLERRM;
END $$;
ROLLBACK;

-- T35: secretario cambia el estado de un acusado
BEGIN;
SET LOCAL ROLE secretario;
DO $$ BEGIN
    UPDATE Acusado SET estadoActual = 'PROCESADO' WHERE id = 122;
    RAISE NOTICE 'T35 FALLA: secretario cambió un estado';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'T35 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T44: juez registra una extension de 3 meses (condena 3)
BEGIN;
SET LOCAL ROLE juez;
DO $$
DECLARE v_antes INTEGER; v_despues INTEGER;
BEGIN
    SELECT duracionMeses INTO v_antes FROM Condena WHERE id = 3;
    INSERT INTO CambioCondena (tipoCambio, razon, condena_id, mesesVariacion)
    VALUES ('EXTENSION_CONDENA', 'Prueba T44', 3, 3);
    SELECT duracionMeses INTO v_despues FROM Condena WHERE id = 3;
    IF v_despues = v_antes + 3 THEN RAISE NOTICE 'T44 OK: la duración pasó de % a % sin error de permisos', v_antes, v_despues;
    ELSE RAISE NOTICE 'T44 FALLA: % a %', v_antes, v_despues; END IF;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'T44 FALLA: %', SQLERRM;
END $$;
ROLLBACK;

-- T45: secretario registra un nuevo dueno (domicilio 101, dueña la persona 126)
BEGIN;
SET LOCAL ROLE secretario;
DO $$
DECLARE v_cierre DATE;
BEGIN
    INSERT INTO PropiedadDomicilio (persona_dni, domicilio_id, fechaDesde) VALUES (30000241, 101, CURRENT_DATE);
    SELECT fechaHasta INTO v_cierre FROM PropiedadDomicilio WHERE domicilio_id = 101 AND persona_dni = 30000126;
    IF v_cierre = CURRENT_DATE THEN RAISE NOTICE 'T45 OK: se cerró el período anterior sin error de permisos';
    ELSE RAISE NOTICE 'T45 FALLA: cierre %', v_cierre; END IF;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'T45 FALLA: %', SQLERRM;
END $$;
ROLLBACK;

-- T46: invitado ejecuta la consulta E
BEGIN;
SET LOCAL ROLE invitado;
DO $$
DECLARE v_cant INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_cant FROM fn_condenados_y_sobreseidos();
    RAISE NOTICE 'T46 OK: invitado ejecutó la consulta E (% filas)', v_cant;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'T46 FALLA: %', SQLERRM;
END $$;
ROLLBACK;

-- T47: secretario ejecuta sp_dictar_condena
BEGIN;
SET LOCAL ROLE secretario;
DO $$ BEGIN
    PERFORM sp_dictar_condena(196, CURRENT_DATE, 12, 1, FALSE);
    RAISE NOTICE 'T47 FALLA: secretario dictó una condena';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'T47 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T48: invitado ejecuta fn_edad
BEGIN;
SET LOCAL ROLE invitado;
DO $$ BEGIN
    PERFORM fn_edad(30000001);
    RAISE NOTICE 'T48 FALLA: invitado ejecutó fn_edad';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'T48 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- T49: juez crea una vista temporal falsa vw_domicilio_principal y pasa una condena a domiciliaria
BEGIN;
SET LOCAL ROLE juez;
CREATE TEMP VIEW vw_domicilio_principal AS
SELECT 30000143 AS persona_dni, 1 AS domicilio_id, 'Falso'::VARCHAR AS direccion, CURRENT_DATE AS fechaDesde;
DO $$
DECLARE v_dom INTEGER; v_real INTEGER;
BEGIN
    INSERT INTO CambioCondena (tipoCambio, razon, condena_id) VALUES ('PRISION_DOMICILIARIA', 'Prueba T49', 103);
    SELECT domicilio_id INTO v_dom FROM Condena WHERE id = 103;
    SELECT domicilio_id INTO v_real FROM public.vw_domicilio_principal WHERE persona_dni = 30000143;
    IF v_dom = v_real THEN RAISE NOTICE 'T49 OK: se usó la vista real (domicilio %)', v_dom;
    ELSE RAISE NOTICE 'T49 FALLA: domicilio %, el real es %', v_dom, v_real; END IF;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'T49 FALLA: %', SQLERRM;
END $$;
ROLLBACK;

-- =====================================================================
-- Pruebas de triggers por operacion (las que no cubren los casos anteriores)
-- =====================================================================

-- O01: UPDATE de Persona con fecha futura (trg_persona_fecha)
BEGIN;
DO $$ BEGIN
    UPDATE Persona SET fechaNacimiento = CURRENT_DATE + 10 WHERE dni = 30000050;
    RAISE NOTICE 'O01 FALLA: se guardó una fecha futura';
EXCEPTION WHEN raise_exception THEN RAISE NOTICE 'O01 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- O02: UPDATE de otro atributo de Persona
BEGIN;
DO $$ BEGIN
    UPDATE Persona SET estadoCivil = 'CASADO' WHERE dni = 30000050;
    RAISE NOTICE 'O02 OK: se guardó el cambio';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'O02 FALLA: %', SQLERRM;
END $$;
ROLLBACK;

-- O03: marcar como principal otro domicilio vigente (trg_propiedad_principal)
BEGIN;
DO $$
DECLARE v_dom INTEGER;
BEGIN
    INSERT INTO Domicilio (direccion) VALUES ('Calle de prueba 2') RETURNING id INTO v_dom;
    INSERT INTO PropiedadDomicilio (persona_dni, domicilio_id, fechaDesde, esPrincipal)
    VALUES (30000116, v_dom, CURRENT_DATE, FALSE);
    UPDATE PropiedadDomicilio SET esPrincipal = TRUE WHERE domicilio_id = v_dom;
    RAISE NOTICE 'O03 FALLA: quedaron dos principales';
EXCEPTION WHEN raise_exception THEN RAISE NOTICE 'O03 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- O04: cerrar un periodo de propiedad
BEGIN;
DO $$ BEGIN
    UPDATE PropiedadDomicilio SET fechaHasta = CURRENT_DATE WHERE domicilio_id = 100 AND fechaHasta IS NULL;
    RAISE NOTICE 'O04 OK: se cerró el período';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'O04 FALLA: %', SQLERRM;
END $$;
ROLLBACK;

-- O05: borrar un acusado con condena (lo rechaza la FK)
BEGIN;
DO $$ BEGIN
    DELETE FROM Acusado WHERE id = 1;
    RAISE NOTICE 'O05 FALLA: se borró un acusado con condena';
EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE 'O05 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- O06: segunda baja de una condena (trg_condena_update)
BEGIN;
DO $$
DECLARE v_id INTEGER;
BEGIN
    SELECT id INTO v_id FROM Condena WHERE fechaBajaLibertad IS NOT NULL LIMIT 1;
    UPDATE Condena SET fechaBajaLibertad = fechaBajaLibertad + 1 WHERE id = v_id;
    RAISE NOTICE 'O06 FALLA: se cambió la baja';
EXCEPTION WHEN raise_exception THEN RAISE NOTICE 'O06 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- O07: cambio sobre una condena dada de baja (trg_cambio_validacion)
BEGIN;
DO $$
DECLARE v_id INTEGER;
BEGIN
    SELECT id INTO v_id FROM Condena WHERE fechaBajaLibertad IS NOT NULL LIMIT 1;
    INSERT INTO CambioCondena (tipoCambio, razon, condena_id, mesesVariacion)
    VALUES ('EXTENSION_CONDENA', 'Prueba O07', v_id, 1);
    RAISE NOTICE 'O07 FALLA: se aceptó el cambio';
EXCEPTION WHEN raise_exception THEN RAISE NOTICE 'O07 OK: %', SQLERRM;
END $$;
ROLLBACK;

-- O08: juez modifica o borra el historial de CambioCondena
BEGIN;
SET LOCAL ROLE juez;
DO $$ BEGIN
    UPDATE CambioCondena SET razon = 'Otra' WHERE id = 1;
    RAISE NOTICE 'O08 FALLA: juez modificó el historial';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'O08 OK: %', SQLERRM;
END $$;
ROLLBACK;

BEGIN;
SET LOCAL ROLE juez;
DO $$ BEGIN
    DELETE FROM CambioCondena WHERE id = 1;
    RAISE NOTICE 'O09 FALLA: juez borró el historial';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'O09 OK: %', SQLERRM;
END $$;
ROLLBACK;
