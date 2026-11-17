-- TPFI Base de Datos - Sistema de Justicia
-- 04_triggers.sql
-- Correr despues de 03_funciones.sql.

BEGIN;

-- 4.1 trg_persona_fecha: la fecha de nacimiento no puede ser futura
CREATE OR REPLACE FUNCTION fn_validar_fecha_nacimiento()
RETURNS TRIGGER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NEW.fechaNacimiento > CURRENT_DATE THEN
        RAISE EXCEPTION 'La fecha de nacimiento no puede ser futura';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_persona_fecha ON Persona;
CREATE TRIGGER trg_persona_fecha
    BEFORE INSERT OR UPDATE ON Persona
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_fecha_nacimiento();


-- 4.2 trg_propiedad_principal: un solo domicilio principal vigente por persona
CREATE OR REPLACE FUNCTION fn_validar_propiedad_principal()
RETURNS TRIGGER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- las filas que se estan cerrando no se controlan (las cierra trg_propiedad_rotacion)
    IF NEW.esPrincipal AND NEW.fechaHasta IS NULL THEN
        IF EXISTS (SELECT 1
                   FROM PropiedadDomicilio
                   WHERE persona_dni = NEW.persona_dni
                     AND esPrincipal = TRUE
                     AND fechaHasta IS NULL
                     AND id <> NEW.id) THEN
            RAISE EXCEPTION 'La persona ya tiene un domicilio principal vigente';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_propiedad_principal ON PropiedadDomicilio;
CREATE TRIGGER trg_propiedad_principal
    BEFORE INSERT OR UPDATE ON PropiedadDomicilio
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_propiedad_principal();


-- 4.3 trg_propiedad_rotacion: al cargar un nuevo dueno se cierra el periodo del anterior
CREATE OR REPLACE FUNCTION fn_validar_propiedad_rotacion()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    propietario_anterior RECORD;
BEGIN
    IF NEW.fechaHasta IS NOT NULL THEN
        RETURN NEW; -- se esta cargando un periodo ya cerrado (historial)
    END IF;

    SELECT * INTO propietario_anterior
    FROM PropiedadDomicilio
    WHERE domicilio_id = NEW.domicilio_id
      AND fechaHasta IS NULL;

    IF FOUND THEN
        IF propietario_anterior.persona_dni = NEW.persona_dni THEN
            RAISE EXCEPTION 'La persona ya es dueña vigente del domicilio';
        END IF;

        IF NEW.fechaDesde < propietario_anterior.fechaDesde THEN
            RAISE EXCEPTION 'La fecha de inicio no puede ser anterior al período del dueño actual';
        END IF;

        UPDATE PropiedadDomicilio
        SET fechaHasta = NEW.fechaDesde
        WHERE id = propietario_anterior.id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_propiedad_rotacion ON PropiedadDomicilio;
CREATE TRIGGER trg_propiedad_rotacion
    BEFORE INSERT ON PropiedadDomicilio
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_propiedad_rotacion();


-- 4.4 trg_acusado_estado: INDAGADO -> PROCESADO -> CONDENADO o SOBRESEIDO
CREATE OR REPLACE FUNCTION fn_validar_acusado_estado()
RETURNS TRIGGER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF OLD.estadoActual = NEW.estadoActual THEN
        RETURN NEW;
    END IF;

    IF NOT ((OLD.estadoActual = 'INDAGADO' AND NEW.estadoActual = 'PROCESADO')
         OR (OLD.estadoActual = 'PROCESADO' AND NEW.estadoActual IN ('CONDENADO', 'SOBRESEIDO'))) THEN
        RAISE EXCEPTION 'Transición de estado no permitida: % a %', OLD.estadoActual, NEW.estadoActual;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_acusado_estado ON Acusado;
CREATE TRIGGER trg_acusado_estado
    BEFORE UPDATE ON Acusado
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_acusado_estado();


-- 4.5 trg_condena_domiciliaria: un solo lugar de cumplimiento; si es domiciliaria, el domicilio principal
CREATE OR REPLACE FUNCTION fn_validar_condena_domiciliaria()
RETURNS TRIGGER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_domicilio_principal INTEGER;
BEGIN
    IF (NEW.domicilio_id IS NULL) = (NEW.unidadCarcelaria_id IS NULL) THEN
        RAISE EXCEPTION 'La condena debe tener un único lugar de cumplimiento: domicilio o unidad carcelaria';
    END IF;

    IF NEW.domicilio_id IS NOT NULL THEN
        SELECT dp.domicilio_id INTO v_domicilio_principal
        FROM vw_domicilio_principal dp
        JOIN Acusado a ON a.persona_dni = dp.persona_dni
        WHERE a.id = NEW.acusado_id;

        IF v_domicilio_principal IS NULL THEN
            RAISE EXCEPTION 'El acusado no tiene domicilio principal vigente';
        END IF;

        IF v_domicilio_principal <> NEW.domicilio_id THEN
            RAISE EXCEPTION 'Para prisión domiciliaria debe usarse el domicilio principal vigente del acusado';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_condena_domiciliaria ON Condena;
CREATE TRIGGER trg_condena_domiciliaria
    BEFORE INSERT ON Condena
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_condena_domiciliaria();


-- 4.6 trg_condena_solo_condenado: acusado CONDENADO y fechaInicio >= fechaAlta de la causa
CREATE OR REPLACE FUNCTION fn_validar_condena_solo_condenado()
RETURNS TRIGGER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_estado_acusado estado_acusado;
    v_fecha_alta_causa DATE;
BEGIN
    SELECT a.estadoActual, c.fechaAlta
    INTO v_estado_acusado, v_fecha_alta_causa
    FROM Acusado a
    JOIN CausaJudicial c ON c.numeroInternoRegistro = a.causa_id
    WHERE a.id = NEW.acusado_id;

    IF v_estado_acusado IS DISTINCT FROM 'CONDENADO' THEN
        RAISE EXCEPTION 'Solo se puede registrar la condena de un acusado CONDENADO (estado actual: %)', v_estado_acusado;
    END IF;

    IF NEW.fechaInicio < v_fecha_alta_causa THEN
        RAISE EXCEPTION 'La fecha de inicio de la condena no puede ser anterior al alta de la causa (%)', v_fecha_alta_causa;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_condena_solo_condenado ON Condena;
CREATE TRIGGER trg_condena_solo_condenado
    BEFORE INSERT ON Condena
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_condena_solo_condenado();


-- 4.7 trg_condena_no_delete: las condenas no se borran, se dan de baja con fechaBajaLibertad
CREATE OR REPLACE FUNCTION fn_validar_condena_no_delete()
RETURNS TRIGGER
SET search_path = public, pg_temp
AS $$
BEGIN
    RAISE EXCEPTION 'Las condenas no se borran: use fechaBajaLibertad para darla de baja';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_condena_no_delete ON Condena;
CREATE TRIGGER trg_condena_no_delete
    BEFORE DELETE ON Condena
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_condena_no_delete();


-- 4.8 trg_condena_update: duracion, unidad y domicilio solo cambian desde trg_cambio_aplicar
CREATE OR REPLACE FUNCTION fn_validar_condena_update()
RETURNS TRIGGER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- pg_trigger_depth() = 1: UPDATE directo; > 1: UPDATE hecho por otro trigger
    IF pg_trigger_depth() = 1
       AND (NEW.duracionMeses <> OLD.duracionMeses
            OR NEW.unidadCarcelaria_id IS DISTINCT FROM OLD.unidadCarcelaria_id
            OR NEW.domicilio_id IS DISTINCT FROM OLD.domicilio_id) THEN
        RAISE EXCEPTION 'Los cambios de condena deben registrarse en CambioCondena';
    END IF;

    IF OLD.fechaBajaLibertad IS NOT NULL
       AND NEW.fechaBajaLibertad IS DISTINCT FROM OLD.fechaBajaLibertad THEN
        RAISE EXCEPTION 'La condena ya fue dada de baja';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_condena_update ON Condena;
CREATE TRIGGER trg_condena_update
    BEFORE UPDATE ON Condena
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_condena_update();


-- 4.9 trg_cambio_validacion: valida el cambio contra los datos de la condena
CREATE OR REPLACE FUNCTION fn_validar_cambio_condena()
RETURNS TRIGGER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_condena RECORD;
BEGIN
    IF NEW.fechaCambio IS NULL THEN
        NEW.fechaCambio := CURRENT_DATE;
    END IF;

    SELECT co.*, a.persona_dni INTO v_condena
    FROM Condena co
    JOIN Acusado a ON a.id = co.acusado_id
    WHERE co.id = NEW.condena_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La condena % no existe', NEW.condena_id;
    END IF;

    IF v_condena.fechaBajaLibertad IS NOT NULL THEN
        RAISE EXCEPTION 'La condena ya fue dada de baja';
    END IF;

    IF NEW.tipoCambio = 'REDUCCION_CONDENA'
       AND v_condena.duracionMeses - NEW.mesesVariacion <= 0 THEN
        RAISE EXCEPTION 'La reducción supera la duración de la condena';
    END IF;

    IF NEW.tipoCambio = 'CAMBIO_UNIDAD_CARCELARIA'
       AND NEW.unidadCarcelaria_id = v_condena.unidadCarcelaria_id THEN
        RAISE EXCEPTION 'La condena ya se cumple en esa unidad';
    END IF;

    IF NEW.tipoCambio = 'PRISION_DOMICILIARIA'
       AND NOT EXISTS (SELECT 1 FROM vw_domicilio_principal
                       WHERE persona_dni = v_condena.persona_dni) THEN
        RAISE EXCEPTION 'El acusado no tiene domicilio principal vigente';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_cambio_validacion ON CambioCondena;
CREATE TRIGGER trg_cambio_validacion
    BEFORE INSERT ON CambioCondena
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_cambio_condena();


-- 4.10 trg_cambio_aplicar: aplica a la Condena el cambio registrado
CREATE OR REPLACE FUNCTION fn_aplicar_cambio_condena()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NEW.tipoCambio = 'EXTENSION_CONDENA' THEN
        UPDATE Condena
        SET duracionMeses = duracionMeses + NEW.mesesVariacion
        WHERE id = NEW.condena_id;

    ELSIF NEW.tipoCambio = 'REDUCCION_CONDENA' THEN
        UPDATE Condena
        SET duracionMeses = duracionMeses - NEW.mesesVariacion
        WHERE id = NEW.condena_id;

    ELSIF NEW.tipoCambio = 'CAMBIO_UNIDAD_CARCELARIA' THEN
        UPDATE Condena
        SET unidadCarcelaria_id = NEW.unidadCarcelaria_id,
            domicilio_id = NULL
        WHERE id = NEW.condena_id;

    ELSIF NEW.tipoCambio = 'PRISION_DOMICILIARIA' THEN
        UPDATE Condena co
        SET domicilio_id = dp.domicilio_id,
            unidadCarcelaria_id = NULL
        FROM Acusado a
        JOIN vw_domicilio_principal dp ON dp.persona_dni = a.persona_dni
        WHERE co.id = NEW.condena_id
          AND a.id = co.acusado_id;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_cambio_aplicar ON CambioCondena;
CREATE TRIGGER trg_cambio_aplicar
    AFTER INSERT ON CambioCondena
    FOR EACH ROW
    EXECUTE FUNCTION fn_aplicar_cambio_condena();


ALTER FUNCTION fn_validar_fecha_nacimiento() OWNER TO propietario_sistema;
ALTER FUNCTION fn_validar_propiedad_principal() OWNER TO propietario_sistema;
ALTER FUNCTION fn_validar_propiedad_rotacion() OWNER TO propietario_sistema;
ALTER FUNCTION fn_validar_acusado_estado() OWNER TO propietario_sistema;
ALTER FUNCTION fn_validar_condena_domiciliaria() OWNER TO propietario_sistema;
ALTER FUNCTION fn_validar_condena_solo_condenado() OWNER TO propietario_sistema;
ALTER FUNCTION fn_validar_condena_no_delete() OWNER TO propietario_sistema;
ALTER FUNCTION fn_validar_condena_update() OWNER TO propietario_sistema;
ALTER FUNCTION fn_validar_cambio_condena() OWNER TO propietario_sistema;
ALTER FUNCTION fn_aplicar_cambio_condena() OWNER TO propietario_sistema;

COMMIT;
