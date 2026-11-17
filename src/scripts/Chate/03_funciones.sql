-- TPFI Base de Datos - Sistema de Justicia
-- 03_funciones.sql
-- Correr despues de 02_vistas.sql.

BEGIN;

-- Funciones auxiliares

CREATE OR REPLACE FUNCTION fn_edad(p_dni INTEGER)
RETURNS INTEGER
LANGUAGE sql
SECURITY INVOKER
AS $$
    SELECT EXTRACT(YEAR FROM AGE(CURRENT_DATE, p.fechaNacimiento))::INTEGER
    FROM Persona p
    WHERE p.dni = p_dni;
$$;

CREATE OR REPLACE FUNCTION fn_fecha_fin_condena(p_condena_id INTEGER)
RETURNS DATE
LANGUAGE sql
SECURITY INVOKER
AS $$
    SELECT (c.fechaInicio + c.duracionMeses * INTERVAL '1 month')::DATE
    FROM Condena c
    WHERE c.id = p_condena_id;
$$;

CREATE OR REPLACE FUNCTION fn_domicilio_principal(p_dni INTEGER)
RETURNS INTEGER
LANGUAGE sql
SECURITY INVOKER
AS $$
    SELECT dp.domicilio_id
    FROM vw_domicilio_principal dp
    WHERE dp.persona_dni = p_dni;
$$;

-- Consultas A a F (solo leen vistas)

-- Consulta A: causas de una secretaria en los ultimos 6 meses, por estado
CREATE OR REPLACE FUNCTION fn_causas_secretaria(p_secretaria_id INTEGER)
RETURNS TABLE (
    numeroInternoRegistro INTEGER,
    fechaAlta DATE,
    fechaResolucion DATE,
    fiscalia VARCHAR,
    juez TEXT,
    secretario TEXT,
    estado TEXT,
    cantidadEnEstado BIGINT
)
LANGUAGE sql
SECURITY INVOKER
AS $$
    SELECT c.numeroInternoRegistro, c.fechaAlta, c.fechaResolucion,
           c.fiscalia, c.juez, c.secretario, c.estado,
           COUNT(*) OVER (PARTITION BY c.estado)
    FROM vw_causas_estado c
    WHERE c.secretaria_id = p_secretaria_id
      AND c.fechaAlta >= CURRENT_DATE - INTERVAL '6 months'
    ORDER BY CASE c.estado WHEN 'VIGENTE' THEN 0 ELSE 1 END, c.fechaAlta;
$$;

-- Consulta B: condenados con al menos 5 extensiones o reducciones, de una secretaria
CREATE OR REPLACE FUNCTION fn_condenados_con_cambios(p_secretaria_id INTEGER, p_minimo INTEGER DEFAULT 5)
RETURNS TABLE (
    dni INTEGER,
    nombres VARCHAR,
    apellidos VARCHAR,
    numeroInternoRegistro INTEGER,
    extensiones BIGINT,
    reducciones BIGINT,
    totalCambios BIGINT
)
LANGUAGE sql
SECURITY INVOKER
AS $$
    SELECT d.dni, d.nombres, d.apellidos, d.numeroInternoRegistro,
           r.extensiones, r.reducciones,
           r.extensiones + r.reducciones
    FROM vw_condenas_detalle d
    JOIN vw_resumen_cambios_condena r ON r.condena_id = d.condena_id
    WHERE d.secretaria_id = p_secretaria_id
      AND r.extensiones + r.reducciones >= p_minimo
    ORDER BY r.extensiones + r.reducciones DESC;
$$;

-- Consulta C: causas con familiares directos involucrados
CREATE OR REPLACE FUNCTION fn_causas_con_familiares()
RETURNS TABLE (
    numeroInternoRegistro INTEGER,
    dni1 INTEGER,
    persona1 TEXT,
    rol1 TEXT,
    dni2 INTEGER,
    persona2 TEXT,
    rol2 TEXT,
    parentesco TEXT
)
LANGUAGE sql
SECURITY INVOKER
AS $$
    SELECT i1.numeroInternoRegistro,
           i1.dni, i1.nombres || ' ' || i1.apellidos, i1.rol,
           i2.dni, i2.nombres || ' ' || i2.apellidos, i2.rol,
           CASE WHEN r.familiar_dni = i1.dni
                THEN i1.nombres || ' ' || i1.apellidos || ' es ' || r.tipo || ' de ' || i2.nombres || ' ' || i2.apellidos
                ELSE i2.nombres || ' ' || i2.apellidos || ' es ' || r.tipo || ' de ' || i1.nombres || ' ' || i1.apellidos
           END
    FROM vw_involucrados_causa i1
    JOIN vw_involucrados_causa i2
      ON i2.numeroInternoRegistro = i1.numeroInternoRegistro
     AND i2.dni > i1.dni
    JOIN vw_relaciones_familiares r
      ON (r.persona_dni = i1.dni AND r.familiar_dni = i2.dni)
      OR (r.persona_dni = i2.dni AND r.familiar_dni = i1.dni)
    ORDER BY i1.numeroInternoRegistro;
$$;

-- Consulta D: cantidad de personas en prision domiciliaria a hoy
CREATE OR REPLACE FUNCTION fn_cantidad_prision_domiciliaria()
RETURNS INTEGER
LANGUAGE sql
SECURITY INVOKER
AS $$
    SELECT COUNT(DISTINCT d.dni)::INTEGER
    FROM vw_condenas_detalle d
    WHERE d.domicilio_id IS NOT NULL
      AND d.situacion = 'VIGENTE';
$$;

-- Consulta E: personas que fueron condenadas en una causa y sobreseidas en otra
CREATE OR REPLACE FUNCTION fn_condenados_y_sobreseidos()
RETURNS TABLE (
    dni INTEGER,
    nombres VARCHAR,
    apellidos VARCHAR,
    causasCondenado TEXT,
    causasSobreseido TEXT
)
LANGUAGE sql
SECURITY INVOKER
AS $$
    SELECT i.dni, i.nombres, i.apellidos,
           STRING_AGG(i.numeroInternoRegistro::TEXT, ', ') FILTER (WHERE i.estadoActual = 'CONDENADO'),
           STRING_AGG(i.numeroInternoRegistro::TEXT, ', ') FILTER (WHERE i.estadoActual = 'SOBRESEIDO')
    FROM vw_involucrados_causa i
    WHERE i.rol = 'ACUSADO'
    GROUP BY i.dni, i.nombres, i.apellidos
    HAVING BOOL_OR(i.estadoActual = 'CONDENADO')
       AND BOOL_OR(i.estadoActual = 'SOBRESEIDO');
$$;

-- Consulta F: condenas vencidas con mas de 3 traslados de unidad carcelaria
CREATE OR REPLACE FUNCTION fn_condenas_vencidas_con_traslados(p_minimo INTEGER DEFAULT 3)
RETURNS TABLE (
    condena_id INTEGER,
    dni INTEGER,
    nombres VARCHAR,
    apellidos VARCHAR,
    numeroInternoRegistro INTEGER,
    fechaInicio DATE,
    fechaFin DATE,
    traslados BIGINT
)
LANGUAGE sql
SECURITY INVOKER
AS $$
    SELECT d.condena_id, d.dni, d.nombres, d.apellidos, d.numeroInternoRegistro,
           d.fechaInicio, d.fechaFin, r.traslados
    FROM vw_condenas_detalle d
    JOIN vw_resumen_cambios_condena r ON r.condena_id = d.condena_id
    WHERE d.fechaFin < CURRENT_DATE
      AND r.traslados > p_minimo
    ORDER BY r.traslados DESC;
$$;

ALTER FUNCTION fn_edad(INTEGER) OWNER TO propietario_sistema;
ALTER FUNCTION fn_fecha_fin_condena(INTEGER) OWNER TO propietario_sistema;
ALTER FUNCTION fn_domicilio_principal(INTEGER) OWNER TO propietario_sistema;
ALTER FUNCTION fn_causas_secretaria(INTEGER) OWNER TO propietario_sistema;
ALTER FUNCTION fn_condenados_con_cambios(INTEGER, INTEGER) OWNER TO propietario_sistema;
ALTER FUNCTION fn_causas_con_familiares() OWNER TO propietario_sistema;
ALTER FUNCTION fn_cantidad_prision_domiciliaria() OWNER TO propietario_sistema;
ALTER FUNCTION fn_condenados_y_sobreseidos() OWNER TO propietario_sistema;
ALTER FUNCTION fn_condenas_vencidas_con_traslados(INTEGER) OWNER TO propietario_sistema;

COMMIT;
