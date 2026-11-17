-- TPFI Base de Datos - Sistema de Justicia
-- 02_vistas.sql
-- Correr despues de 01_creacion.sql.

BEGIN;

DROP VIEW IF EXISTS vw_involucrados_causa CASCADE;
DROP VIEW IF EXISTS vw_relaciones_familiares CASCADE;
DROP VIEW IF EXISTS vw_causas_estado CASCADE;
DROP VIEW IF EXISTS vw_condenas_detalle CASCADE;
DROP VIEW IF EXISTS vw_domicilio_principal CASCADE;
DROP VIEW IF EXISTS vw_resumen_cambios_condena CASCADE;

-- Personas que participan de cada causa, con su rol (consultas C y E)
CREATE VIEW vw_involucrados_causa AS
SELECT a.causa_id AS numeroInternoRegistro,
       p.dni, p.nombres, p.apellidos,
       'ACUSADO' AS rol,
       a.estadoActual
FROM Acusado a
JOIN Persona p ON p.dni = a.persona_dni
UNION ALL
SELECT c.numeroInternoRegistro, p.dni, p.nombres, p.apellidos,
       'JUEZ', NULL
FROM CausaJudicial c
JOIN Persona p ON p.dni = c.juez_dni
UNION ALL
SELECT c.numeroInternoRegistro, p.dni, p.nombres, p.apellidos,
       'SECRETARIO', NULL
FROM CausaJudicial c
JOIN Persona p ON p.dni = c.secretario_dni;

-- Relaciones de parentesco (consulta C)
CREATE VIEW vw_relaciones_familiares AS
SELECT r.id, r.persona_dni, r.familiar_dni, r.tipo
FROM RelacionFamiliar r;

-- Una fila por causa con su estado (consulta A)
CREATE VIEW vw_causas_estado AS
SELECT c.numeroInternoRegistro,
       c.fechaAlta,
       c.fechaResolucion,
       c.secretaria_id,
       s.nombre AS secretaria,
       f.nombre AS fiscalia,
       c.juez_dni,
       j.nombres || ' ' || j.apellidos AS juez,
       c.secretario_dni,
       se.nombres || ' ' || se.apellidos AS secretario,
       CASE WHEN c.fechaResolucion IS NULL THEN 'VIGENTE' ELSE 'CERRADA' END AS estado
FROM CausaJudicial c
JOIN Secretaria s ON s.id = c.secretaria_id
JOIN Fiscalia f ON f.id = c.fiscalia_id
JOIN Persona j ON j.dni = c.juez_dni
JOIN Persona se ON se.dni = c.secretario_dni;

-- Cada condena con persona, causa, fecha de fin, lugar y situacion (consultas B, D y F)
CREATE VIEW vw_condenas_detalle AS
SELECT co.id AS condena_id,
       co.acusado_id,
       p.dni, p.nombres, p.apellidos,
       a.causa_id AS numeroInternoRegistro,
       c.secretaria_id,
       co.fechaInicio,
       co.duracionMeses,
       (co.fechaInicio + co.duracionMeses * INTERVAL '1 month')::DATE AS fechaFin,
       co.fechaBajaLibertad,
       co.domicilio_id,
       co.unidadCarcelaria_id,
       COALESCE(u.nombre, d.direccion) AS lugar,
       CASE
           WHEN co.fechaBajaLibertad IS NOT NULL THEN 'DADA DE BAJA'
           WHEN co.fechaInicio > CURRENT_DATE THEN 'PENDIENTE'
           WHEN (co.fechaInicio + co.duracionMeses * INTERVAL '1 month')::DATE < CURRENT_DATE THEN 'VENCIDA'
           ELSE 'VIGENTE'
       END AS situacion
FROM Condena co
JOIN Acusado a ON a.id = co.acusado_id
JOIN Persona p ON p.dni = a.persona_dni
JOIN CausaJudicial c ON c.numeroInternoRegistro = a.causa_id
LEFT JOIN UnidadCarcelaria u ON u.id = co.unidadCarcelaria_id
LEFT JOIN Domicilio d ON d.id = co.domicilio_id;

-- Domicilio principal vigente de cada persona
CREATE VIEW vw_domicilio_principal AS
SELECT pd.persona_dni, pd.domicilio_id, d.direccion, pd.fechaDesde
FROM PropiedadDomicilio pd
JOIN Domicilio d ON d.id = pd.domicilio_id
WHERE pd.esPrincipal = TRUE
  AND pd.fechaHasta IS NULL;

-- Cantidad de cambios de cada tipo por condena (consultas B y F)
CREATE VIEW vw_resumen_cambios_condena AS
SELECT co.id AS condena_id,
       COUNT(cc.id) FILTER (WHERE cc.tipoCambio = 'EXTENSION_CONDENA') AS extensiones,
       COUNT(cc.id) FILTER (WHERE cc.tipoCambio = 'REDUCCION_CONDENA') AS reducciones,
       COUNT(cc.id) FILTER (WHERE cc.tipoCambio = 'CAMBIO_UNIDAD_CARCELARIA') AS traslados,
       COUNT(cc.id) FILTER (WHERE cc.tipoCambio = 'PRISION_DOMICILIARIA') AS pasos_domiciliaria,
       COUNT(cc.id) AS total_cambios
FROM Condena co
LEFT JOIN CambioCondena cc ON cc.condena_id = co.id
GROUP BY co.id;

ALTER VIEW vw_involucrados_causa OWNER TO propietario_sistema;
ALTER VIEW vw_relaciones_familiares OWNER TO propietario_sistema;
ALTER VIEW vw_causas_estado OWNER TO propietario_sistema;
ALTER VIEW vw_condenas_detalle OWNER TO propietario_sistema;
ALTER VIEW vw_domicilio_principal OWNER TO propietario_sistema;
ALTER VIEW vw_resumen_cambios_condena OWNER TO propietario_sistema;

COMMIT;
