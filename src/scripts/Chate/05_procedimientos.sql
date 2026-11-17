-- TPFI Base de Datos - Sistema de Justicia
-- 05_procedimientos.sql
-- Correr despues de 04_triggers.sql.
-- Se crean como funciones porque devuelven un valor (id o cantidad de filas).

BEGIN;

-- Dicta la condena de un acusado PROCESADO: lo pasa a CONDENADO y registra la condena.
-- Devuelve el id de la condena.
CREATE OR REPLACE FUNCTION sp_dictar_condena(
    p_acusado_id INTEGER,
    p_fecha_inicio DATE,
    p_duracion_meses INTEGER,
    p_unidad_id INTEGER,
    p_domiciliaria BOOLEAN DEFAULT FALSE
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_dni INTEGER;
    v_estado estado_acusado;
    v_domicilio INTEGER;
    v_condena_id INTEGER;
BEGIN
    IF p_acusado_id IS NULL OR p_fecha_inicio IS NULL OR p_duracion_meses IS NULL THEN
        RAISE EXCEPTION 'El acusado, la fecha de inicio y la duración son obligatorios';
    END IF;

    SELECT persona_dni, estadoActual INTO v_dni, v_estado
    FROM Acusado
    WHERE id = p_acusado_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El acusado % no existe', p_acusado_id;
    END IF;

    IF v_estado <> 'PROCESADO' THEN
        RAISE EXCEPTION 'Solo se puede condenar a un acusado PROCESADO (estado actual: %)', v_estado;
    END IF;

    IF COALESCE(p_domiciliaria, FALSE) THEN
        v_domicilio := fn_domicilio_principal(v_dni);
        IF v_domicilio IS NULL THEN
            RAISE EXCEPTION 'El acusado no tiene domicilio principal vigente';
        END IF;
        p_unidad_id := NULL;
    ELSIF p_unidad_id IS NULL THEN
        RAISE EXCEPTION 'Debe indicarse la unidad carcelaria';
    END IF;

    UPDATE Acusado SET estadoActual = 'CONDENADO' WHERE id = p_acusado_id;

    INSERT INTO Condena (fechaInicio, duracionMeses, acusado_id, domicilio_id, unidadCarcelaria_id)
    VALUES (p_fecha_inicio, p_duracion_meses, p_acusado_id, v_domicilio, p_unidad_id)
    RETURNING id INTO v_condena_id;

    RETURN v_condena_id;
END;
$$;

-- Cierra una causa si no le quedan acusados INDAGADO o PROCESADO.
CREATE OR REPLACE FUNCTION sp_resolver_causa(p_causa INTEGER, p_fecha DATE)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_causa RECORD;
    v_pendientes TEXT;
BEGIN
    IF p_causa IS NULL OR p_fecha IS NULL THEN
        RAISE EXCEPTION 'La causa y la fecha son obligatorias';
    END IF;

    SELECT * INTO v_causa
    FROM CausaJudicial
    WHERE numeroInternoRegistro = p_causa;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La causa % no existe', p_causa;
    END IF;

    IF v_causa.fechaResolucion IS NOT NULL THEN
        RAISE EXCEPTION 'La causa % ya fue resuelta', p_causa;
    END IF;

    IF p_fecha < v_causa.fechaAlta THEN
        RAISE EXCEPTION 'La fecha de resolución no puede ser anterior al alta de la causa (%)', v_causa.fechaAlta;
    END IF;

    SELECT STRING_AGG(persona_dni::TEXT, ', ') INTO v_pendientes
    FROM Acusado
    WHERE causa_id = p_causa
      AND estadoActual IN ('INDAGADO', 'PROCESADO');

    IF v_pendientes IS NOT NULL THEN
        RAISE EXCEPTION 'La causa tiene acusados pendientes (DNI: %)', v_pendientes;
    END IF;

    UPDATE CausaJudicial
    SET fechaResolucion = p_fecha
    WHERE numeroInternoRegistro = p_causa;
END;
$$;

-- Traslada todas las condenas en curso de una unidad a otra.
-- Registra un CambioCondena por cada una (trg_cambio_aplicar actualiza la condena).
CREATE OR REPLACE FUNCTION sp_trasladar_condenados(
    p_unidad_origen INTEGER,
    p_unidad_destino INTEGER,
    p_razon VARCHAR
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_cantidad INTEGER;
BEGIN
    IF p_unidad_origen = p_unidad_destino THEN
        RAISE EXCEPTION 'La unidad de origen y la de destino deben ser distintas';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM UnidadCarcelaria WHERE id = p_unidad_destino) THEN
        RAISE EXCEPTION 'La unidad de destino % no existe', p_unidad_destino;
    END IF;

    INSERT INTO CambioCondena (tipoCambio, razon, condena_id, unidadCarcelaria_id)
    SELECT 'CAMBIO_UNIDAD_CARCELARIA', p_razon, c.id, p_unidad_destino
    FROM Condena c
    WHERE c.unidadCarcelaria_id = p_unidad_origen
      AND c.fechaBajaLibertad IS NULL;

    GET DIAGNOSTICS v_cantidad = ROW_COUNT;
    RETURN v_cantidad;
END;
$$;

-- Da de baja todas las condenas cumplidas a hoy que siguen sin baja.
CREATE OR REPLACE FUNCTION sp_liberar_condenas_cumplidas()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_cantidad INTEGER;
BEGIN
    UPDATE Condena
    SET fechaBajaLibertad = CURRENT_DATE
    WHERE fechaBajaLibertad IS NULL
      AND fechaInicio + duracionMeses * INTERVAL '1 month' < CURRENT_DATE;

    GET DIAGNOSTICS v_cantidad = ROW_COUNT;
    RETURN v_cantidad;
END;
$$;

ALTER FUNCTION sp_dictar_condena(INTEGER, DATE, INTEGER, INTEGER, BOOLEAN) OWNER TO propietario_sistema;
ALTER FUNCTION sp_resolver_causa(INTEGER, DATE) OWNER TO propietario_sistema;
ALTER FUNCTION sp_trasladar_condenados(INTEGER, INTEGER, VARCHAR) OWNER TO propietario_sistema;
ALTER FUNCTION sp_liberar_condenas_cumplidas() OWNER TO propietario_sistema;

COMMIT;
