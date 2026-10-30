import pymysql
import pymysql.cursors
from flask import current_app, g


def _connect(c):
    return pymysql.connect(
        host=c["DB_HOST"], port=c["DB_PORT"], user=c["DB_USER"],
        password=c["DB_PASSWORD"], database=c["DB_NAME"],
        charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
        autocommit=False,
        connect_timeout=5,   # si el servidor MySQL no responde, falla rápido en vez de colgar la página
        read_timeout=15, write_timeout=15,
    )


def get_db():
    if "db" not in g:
        g.db = _connect(current_app.config)
    return g.db


def close_db(_exc=None):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def query(sql, args=None, one=False):
    with get_db().cursor() as cur:
        cur.execute(sql, args or ())
        rows = cur.fetchall()
    if one:
        return rows[0] if rows else None
    return rows


def execute(sql, args=None):
    with get_db().cursor() as cur:
        cur.execute(sql, args or ())
        return cur.lastrowid


def commit():
    get_db().commit()


def rollback():
    get_db().rollback()


# Columnas que api.py necesita. Si falta alguna, la base no tiene aplicado migracion.sql.
REQUIRED_COLUMNS = {
    "login_enfermeria": ["rol", "contrasena_hash"],
    "estudiantes": ["id", "matricula", "nombre_completo", "curso", "grado", "edad", "estado_registro", "nombre_tutor",
                    "telefono_contacto", "estado", "fecha_archivado", "motivo_archivo"],
    "datos_salud_estudiante": ["id_estudiante", "grupo_sanguineo", "alergias", "prioridad", "observaciones", "actualizado_por_rol"],
    "historial_estudiantil": ["id", "id_estudiante", "tipo", "campo_afectado", "valor_anterior", "valor_nuevo", "descripcion",
                              "registrado_por_rol", "registrado_en"],
    "visitas": ["id", "id_estudiante", "fecha_visita", "motivo", "despachado", "registrada_en", "registrada_por_rol"],
    "orientadoras": ["id", "nombre", "activa"],
    "solicitudes_medicamentos": ["id", "id_orientadora", "medicamento", "presentacion", "cantidad_solicitada", "cantidad_entregada",
                                 "detalle_solicitud", "estado", "solicitada_por_rol", "solicitada_en", "respuesta",
                                 "respondida_por_rol", "respondida_en"],
    "cierres_escolares": ["id", "anio_escolar", "estado", "creado_por_rol", "confirmado_por_rol", "confirmado_en", "ejecutado_en"],
    "historial_promociones": ["id_cierre", "id_estudiante", "grado_anterior", "grado_nuevo", "accion"],
    "registros_auditoria": ["id", "rol_actor", "accion", "entidad", "id_entidad", "resumen", "registrado_en"],
}


def check_schema(config):
    """Prueba la conexión y compara el esquema con lo que api.py usa. Devuelve (ok, lista_de_problemas).

    Solo lee (SELECT sobre information_schema); no modifica nada de la base.
    """
    try:
        conn = _connect(config)
    except pymysql.MySQLError as error:
        return False, [f"No se pudo conectar a MySQL en {config['DB_HOST']}:{config['DB_PORT']} ({error})"]
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT table_name AS t, column_name AS c FROM information_schema.columns WHERE table_schema = %s",
                        (config["DB_NAME"],))
            present = {}
            for row in cur.fetchall():
                present.setdefault(row["t"].lower(), set()).add(row["c"].lower())
    finally:
        conn.close()
    problems = []
    for table, columns in REQUIRED_COLUMNS.items():
        if table not in present:
            problems.append(f"Falta la tabla {table}")
            continue
        missing = [col for col in columns if col not in present[table]]
        if missing:
            problems.append(f"Tabla {table}: faltan las columnas {', '.join(missing)}")
    if problems:
        problems.append("Solución: ejecutar migracion.sql (base creada con el dbo.sql original) y revisar LEEME.txt.")
    return not problems, problems
