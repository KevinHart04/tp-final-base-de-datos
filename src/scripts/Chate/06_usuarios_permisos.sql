-- TPFI Base de Datos - Sistema de Justicia
-- 06_usuarios_permisos.sql
-- Correr despues de 05_procedimientos.sql, con el superusuario postgres.
-- Las contraseñas son de ejemplo: cambiarlas antes de usar la base en serio.

BEGIN;

-- Roles
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_secretaria') THEN
        CREATE ROLE rol_secretaria NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_juzgado') THEN
        CREATE ROLE rol_juzgado NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_consulta') THEN
        CREATE ROLE rol_consulta NOLOGIN;
    END IF;
END $$;

-- Usuarios
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin_bd') THEN
        CREATE ROLE admin_bd LOGIN SUPERUSER PASSWORD 'admin123';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'secretario') THEN
        CREATE ROLE secretario LOGIN PASSWORD 'secretario123';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'juez') THEN
        CREATE ROLE juez LOGIN PASSWORD 'juez123';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'invitado') THEN
        CREATE ROLE invitado LOGIN PASSWORD 'invitado123';
    END IF;
END $$;

GRANT rol_secretaria TO secretario;
GRANT rol_juzgado TO juez;
GRANT rol_consulta TO invitado;

-- Nadie crea objetos en el esquema ni ejecuta funciones salvo que se le otorgue
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO rol_secretaria, rol_juzgado, rol_consulta;

-- rol_secretaria: carga personas, familiares, domicilios y causas, e imputa acusados
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_secretaria;
GRANT INSERT, UPDATE ON Persona, RelacionFamiliar, Domicilio TO rol_secretaria;
GRANT INSERT ON PropiedadDomicilio, CausaJudicial, Acusado TO rol_secretaria;

-- rol_juzgado: cambia estados, registra cambios de condena y da de baja condenas
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_juzgado;
GRANT UPDATE (estadoActual) ON Acusado TO rol_juzgado;
GRANT UPDATE (fechaBajaLibertad) ON Condena TO rol_juzgado;
GRANT INSERT ON CambioCondena TO rol_juzgado;

-- rol_consulta: solo vistas
GRANT SELECT ON vw_involucrados_causa, vw_relaciones_familiares, vw_causas_estado,
                vw_condenas_detalle, vw_domicilio_principal, vw_resumen_cambios_condena
    TO rol_consulta;

-- Funciones de consulta (A a F): todos los roles
GRANT EXECUTE ON FUNCTION
    fn_causas_secretaria(INTEGER),
    fn_condenados_con_cambios(INTEGER, INTEGER),
    fn_causas_con_familiares(),
    fn_cantidad_prision_domiciliaria(),
    fn_condenados_y_sobreseidos(),
    fn_condenas_vencidas_con_traslados(INTEGER)
    TO rol_secretaria, rol_juzgado, rol_consulta;

-- Funciones auxiliares: no para rol_consulta
GRANT EXECUTE ON FUNCTION
    fn_edad(INTEGER),
    fn_fecha_fin_condena(INTEGER),
    fn_domicilio_principal(INTEGER)
    TO rol_secretaria, rol_juzgado;

-- Procedimientos: solo rol_juzgado
GRANT EXECUTE ON FUNCTION
    sp_dictar_condena(INTEGER, DATE, INTEGER, INTEGER, BOOLEAN),
    sp_resolver_causa(INTEGER, DATE),
    sp_trasladar_condenados(INTEGER, INTEGER, VARCHAR),
    sp_liberar_condenas_cumplidas()
    TO rol_juzgado;

COMMIT;
