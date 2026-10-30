
import time
from datetime import date, datetime
from functools import wraps

import pymysql
from flask import Blueprint, current_app, jsonify, request, session
from werkzeug.exceptions import HTTPException
from werkzeug.security import check_password_hash

from db import get_db

bp = Blueprint("api", __name__, url_prefix="/api")

# ---------------------------------------------------------------- traducciones pantalla <-> base de datos
ROLE_DB = {"nurse": "enfermeria", "guidance": "orientacion", "admin": "administracion"}
ROLE_FE = {v: k for k, v in ROLE_DB.items()}
ROLE_LABEL = {"enfermeria": "Enfermería", "orientacion": "Orientación", "administracion": "Administración"}

GRADE_DB = {"4.º Secundaria": "4to", "5.º Secundaria": "5to", "6.º Secundaria": "6to"}
GRADE_FE = {v: k for k, v in GRADE_DB.items()}
GRADE_ORDER = ["4to", "5to", "6to"]

MENTION_DB = {"Mecatrónica": "Mecatronica", "Informática": "Informatica", "Electricidad": "Electricidad",
              "Refrigeración": "Refrigeracion", "Contabilidad": "Contabilidad", "Mecánica": "Mecanica"}
MENTION_FE = {v: k for k, v in MENTION_DB.items()}

REG_STATUS = ("Al día", "Revisar", "Pendiente")
PRIORITIES = ("Leve", "Media", "Grave")
MSG_STATUS_DB = {"Pendiente": "pendiente", "Atendida": "gestionada", "No disponible": "no_disponible"}
MSG_STATUS_FE = {"pendiente": "Pendiente", "recibida": "Pendiente", "gestionada": "Atendida", "no_disponible": "No disponible"}

# Acciones que el navegador puede registrar por su cuenta (las demás las registra el servidor al guardar).
CLIENT_AUDIT_ACTIONS = {"Consultó mensajes", "Consultó visitas", "Usó la IA"}

FIELD_LABELS = {"nombre": "Nombre", "grado": "Curso", "curso": "Mención técnica", "edad": "Edad",
                "estado_registro": "Estado del registro", "prioridad": "Prioridad de atención",
                "nombre_tutor": "Tutor responsable", "telefono_contacto": "Teléfono del tutor",
                "grupo_sanguineo": "Grupo sanguíneo", "alergias": "Alergias conocidas", "observaciones": "Observaciones"}


class ApiError(Exception):
    def __init__(self, message, status=400):
        super().__init__(message)
        self.message, self.status = message, status


@bp.app_errorhandler(ApiError)
def _api_error(error):
    return jsonify(error=error.message), error.status


@bp.app_errorhandler(pymysql.err.OperationalError)
def _db_down(error):
    current_app.logger.error("MySQL no disponible: %s", error)
    return jsonify(error="No hay conexión con la base de datos. Avisa a quien administra el servidor."), 503


@bp.app_errorhandler(Exception)
def _unexpected(error):
    if isinstance(error, HTTPException):
        return error
    current_app.logger.exception("Error inesperado en la API")
    return jsonify(error="Error del servidor. Intenta de nuevo."), 500


@bp.before_request
def _only_json_writes():
    # Con cookie SameSite=Lax + exigir JSON, otra página no puede disparar escrituras en nombre del usuario (CSRF).
    if request.method in ("POST", "PUT", "DELETE") and not request.is_json:
        raise ApiError("Se esperaba JSON.", 415)


# ---------------------------------------------------------------- sesión y permisos
def current_role():
    return session.get("rol")


def require(*roles_fe):
    """Exige sesión iniciada y, si se indican, uno de esos roles (nurse / guidance / admin)."""
    allowed = {ROLE_DB[r] for r in roles_fe}

    def decorator(view):
        @wraps(view)
        def wrapper(*args, **kwargs):
            rol = current_role()
            if rol not in ROLE_LABEL:
                raise ApiError("Inicia sesión para continuar.", 401)
            if allowed and rol not in allowed:
                raise ApiError("Tu rol no tiene permiso para esta acción.", 403)
            return view(*args, **kwargs)
        return wrapper
    return decorator


_failed = {}          # ip -> [momentos de intentos fallidos]  (en memoria; basta con un solo proceso)
MAX_FAILS, WINDOW = 5, 300


def _too_many(ip):
    now = time.time()
    _failed[ip] = [t for t in _failed.get(ip, []) if now - t < WINDOW]
    return len(_failed[ip]) >= MAX_FAILS


@bp.post("/login")
def login():
    data = request.get_json(silent=True) or {}
    rol, password, ip = ROLE_DB.get(data.get("role")), str(data.get("password") or ""), request.remote_addr
    if _too_many(ip):
        raise ApiError("Demasiados intentos. Espera unos minutos e inténtalo de nuevo.", 429)
    stored = None
    if rol:
        with get_db().cursor() as cur:
            cur.execute("SELECT contrasena_hash FROM login_enfermeria WHERE rol = %s", (rol,))
            row = cur.fetchone()
            stored = row["contrasena_hash"] if row else None
    # Se compara el HASH, nunca la contraseña guardada. Sin hash configurado => se rechaza siempre.
    ok = bool(stored) and check_password_hash(stored, password)
    if not ok:
        _failed.setdefault(ip, []).append(time.time())
        raise ApiError("Rol o contraseña incorrectos.", 401)
    session.clear()
    session["rol"] = rol
    session.permanent = True
    audit(get_db(), rol, "Inició sesión", "sesion")
    get_db().commit()
    return jsonify(role=ROLE_FE[rol])


@bp.post("/logout")
def logout():
    session.clear()
    return jsonify(ok=True)


@bp.get("/sesion")
@require()
def sesion():
    return jsonify(role=ROLE_FE[current_role()])


# ---------------------------------------------------------------- utilidades
def clip(value, limit):
    return str(value if value is not None else "").strip()[:limit]


def audit(db, rol, accion, entidad="general", id_entidad=None, resumen=""):
    """Registra quién hizo qué. El resumen NO debe llevar contraseñas ni detalles médicos."""
    with db.cursor() as cur:
        cur.execute("INSERT INTO registros_auditoria (rol_actor, accion, entidad, id_entidad, resumen) VALUES (%s,%s,%s,%s,%s)",
                    (rol, clip(accion, 80), clip(entidad, 80), id_entidad, clip(resumen, 255) or None))


def fmt_dt(value):
    return value.strftime("%d/%m/%Y, %H:%M:%S") if value else ""


def fmt_d(value):
    return value.strftime("%d/%m/%Y") if value else ""


def none_if_empty(value):
    return value if value not in ("", None) else None


def clean_student(data):
    """Valida lo que manda la pantalla y lo traduce a columnas de la base."""
    name = clip(data.get("name"), 200)
    if not name:
        raise ApiError("Falta el nombre del estudiante.")
    grado = GRADE_DB.get(data.get("grade"))
    if not grado:
        raise ApiError("Curso no válido (solo 4.º, 5.º y 6.º de Secundaria).")
    mention = clip(data.get("mention"), 40)
    if mention and mention not in MENTION_DB:
        raise ApiError("Mención técnica no válida.")
    age_raw = data.get("age")
    try:
        age = int(age_raw) if age_raw not in (None, "", 0, "0") else None
    except (TypeError, ValueError):
        raise ApiError("Edad no válida.")
    if age is not None and not 1 <= age <= 99:
        raise ApiError("Edad no válida.")
    status = clip(data.get("status"), 20) or "Pendiente"
    priority = clip(data.get("priority"), 10)
    if status not in REG_STATUS or (priority and priority not in PRIORITIES):
        raise ApiError("Estado o prioridad no válidos.")
    return {
        "nombre": name, "grado": grado, "curso": MENTION_DB.get(mention), "edad": age,
        "estado_registro": status, "nombre_tutor": none_if_empty(clip(data.get("guardian"), 150)),
        "telefono_contacto": none_if_empty(clip(data.get("phone"), 30)),
        "grupo_sanguineo": none_if_empty(clip(data.get("blood"), 12)),
        "alergias": none_if_empty(clip(data.get("allergies"), 1000)), "prioridad": none_if_empty(priority),
        "observaciones": none_if_empty(clip(data.get("notes"), 2000)),
    }


STUDENT_SELECT = """
    SELECT e.id AS pk, e.matricula, e.nombre, e.grado, e.curso, e.edad, e.estado_registro,
           e.nombre_tutor, e.telefono_contacto, e.estado, e.fecha_archivado, e.motivo_archivo,
           s.grupo_sanguineo, s.alergias, s.prioridad, s.observaciones
    FROM estudiantes e LEFT JOIN datos_salud_estudiante s ON s.id_estudiante = e.id
"""


def student_out(row, notes, full):
    base = {"id": row["matricula"], "name": row["nombre"], "grade": GRADE_FE.get(row["grado"], ""),
            "mention": MENTION_FE.get(row["curso"], ""), "age": row["edad"], "status": row["estado_registro"],
            "priority": row["prioridad"] or ""}
    if not full:        # Orientación no ve datos de contacto ni de salud
        return base
    base.update(guardian=row["nombre_tutor"] or "", phone=row["telefono_contacto"] or "", blood=row["grupo_sanguineo"] or "",
                allergies=row["alergias"] or "", notes=row["observaciones"] or "",
                infoHistory=[{"id": n["id"], "createdAt": n["registrado_en"].isoformat(), "createdBy": ROLE_LABEL[n["registrado_por_rol"]],
                              "text": n["descripcion"]} for n in notes])
    return base


def get_active_student(cur, matricula, lock=False):
    cur.execute(STUDENT_SELECT + " WHERE e.matricula = %s AND e.estado = 'activo'" + (" FOR UPDATE" if lock else ""), (matricula,))
    row = cur.fetchone()
    if not row:
        raise ApiError("Estudiante no encontrado.", 404)
    return row


def school_year(today=None):
    today = today or date.today()
    start = today.year if today.month >= 8 else today.year - 1
    return f"{start}-{start + 1}"


# ---------------------------------------------------------------- lectura: todo lo que la pantalla necesita al abrir
@bp.get("/datos")
@require()
def datos():
    rol = current_role()
    full = rol in ("enfermeria", "administracion")
    db = get_db()
    with db.cursor() as cur:
        cur.execute(STUDENT_SELECT + " WHERE e.estado = 'activo' ORDER BY e.id")
        rows = cur.fetchall()
        notes = {}
        if full:
            cur.execute("""SELECT h.id, h.id_estudiante, h.descripcion, h.registrado_por_rol, h.registrado_en FROM historial_estudiantil h
                           JOIN estudiantes e ON e.id = h.id_estudiante WHERE e.estado = 'activo' AND h.tipo = 'nota'
                           ORDER BY h.registrado_en, h.id""")
            for n in cur.fetchall():
                notes.setdefault(n["id_estudiante"], []).append(n)
        students = [student_out(r, notes.get(r["pk"], []), full) for r in rows]

        cur.execute("""SELECT v.id, e.matricula, v.fecha_visita, v.motivo, v.despachado, v.registrada_en, v.registrada_por_rol
                       FROM visitas v JOIN estudiantes e ON e.id = v.id_estudiante WHERE e.estado = 'activo'
                       ORDER BY v.fecha_visita DESC, v.id DESC""")
        visits = {}
        for v in cur.fetchall():
            visits.setdefault(v["matricula"], []).append({
                "id": v["id"], "date": v["fecha_visita"].strftime("%Y-%m-%d"), "time": v["fecha_visita"].strftime("%H:%M"),
                "reason": v["motivo"] if full else "", "dispatched": bool(v["despachado"]),
                "recordedAt": v["registrada_en"].isoformat(), "recordedBy": ROLE_LABEL[v["registrada_por_rol"]] if full else ""})

        cur.execute("""SELECT m.*, o.nombre AS orientadora FROM solicitudes_medicamentos m
                       JOIN orientadoras o ON o.id = m.id_orientadora ORDER BY m.solicitada_en DESC, m.id DESC""")
        messages = [{
            "id": m["id"], "from": ROLE_LABEL[m["solicitada_por_rol"]], "to": m["orientadora"], "type": "Solicitud de medicamento",
            "medication": m["medicamento"], "presentation": m["presentacion"] or "No especificada",
            "quantityRequested": m["cantidad_solicitada"] or 0, "quantityDelivered": m["cantidad_entregada"] or 0,
            "body": m["detalle_solicitud"] or "", "status": MSG_STATUS_FE[m["estado"]], "date": fmt_d(m["solicitada_en"]),
            "responseNote": m["respuesta"] or "", "responseBy": ROLE_LABEL.get(m["respondida_por_rol"], ""),
            "respondedAt": fmt_dt(m["respondida_en"])} for m in cur.fetchall()]

        audit_rows, archive = [], []
        if rol == "administracion":
            cur.execute("SELECT * FROM registros_auditoria ORDER BY id DESC LIMIT 150")
            audit_rows = [{"date": fmt_dt(a["registrado_en"]), "role": ROLE_LABEL[a["rol_actor"]], "action": a["accion"],
                           "detail": a["resumen"] or ""} for a in cur.fetchall()]
            cur.execute("SELECT * FROM estudiantes WHERE estado IN ('archivado','graduado') ORDER BY fecha_archivado DESC, id DESC")
            archive = [{"name": a["nombre"], "grade": GRADE_FE.get(a["grado"], ""), "mention": MENTION_FE.get(a["curso"], ""),
                        "archivedAt": fmt_d(a["fecha_archivado"]), "archiveStatus": a["motivo_archivo"] or ""} for a in cur.fetchall()]
    return jsonify(role=ROLE_FE[rol], students=students, visits=visits, messages=messages, audit=audit_rows, archive=archive)


# ---------------------------------------------------------------- estudiantes
def _insert_health(cur, pk, c, rol):
    cur.execute("""INSERT INTO datos_salud_estudiante (id_estudiante, grupo_sanguineo, alergias, prioridad, observaciones, actualizado_por_rol)
                   VALUES (%s,%s,%s,%s,%s,%s)
                   ON DUPLICATE KEY UPDATE grupo_sanguineo=VALUES(grupo_sanguineo), alergias=VALUES(alergias), prioridad=VALUES(prioridad),
                   observaciones=VALUES(observaciones), actualizado_por_rol=VALUES(actualizado_por_rol)""",
                (pk, c["grupo_sanguineo"], c["alergias"], c["prioridad"], c["observaciones"], rol))


@bp.post("/estudiantes")
@require("nurse", "admin")
def crear_estudiante():
    data, rol, db = request.get_json(silent=True) or {}, current_role(), get_db()
    matricula = clip(data.get("id"), 30)
    if not matricula:
        raise ApiError("Falta la matrícula.")
    c = clean_student(data)
    try:
        with db.cursor() as cur:
            cur.execute("""INSERT INTO estudiantes (matricula, nombre, curso, grado, edad, nombre_tutor, telefono_contacto, estado_registro)
                           VALUES (%s,%s,%s,%s,%s,%s,%s,%s)""",
                        (matricula, c["nombre"], c["curso"], c["grado"], c["edad"], c["nombre_tutor"], c["telefono_contacto"], c["estado_registro"]))
            pk = cur.lastrowid
            _insert_health(cur, pk, c, rol)
        audit(db, rol, "Agregó estudiante al directorio", "estudiante", pk, f'{c["nombre"]} · {matricula}')
        db.commit()
    except pymysql.err.IntegrityError as error:
        db.rollback()
        if error.args and error.args[0] == 1062:
            raise ApiError("Esa matrícula ya está registrada (puede estar en el archivo).", 409)
        raise
    return jsonify(id=matricula), 201


@bp.put("/estudiantes/<path:matricula>")
@require("nurse", "admin")
def actualizar_estudiante(matricula):
    data, rol, db = request.get_json(silent=True) or {}, current_role(), get_db()
    c = clean_student(data)
    notes = [clip(n, 500) for n in (data.get("newNotes") or [])[:20] if clip(n, 500)]
    with db.cursor() as cur:
        old = get_active_student(cur, matricula, lock=True)
        changed = [col for col in FIELD_LABELS if none_if_empty(old[col]) != c[col]]
        if changed:
            cur.execute("""UPDATE estudiantes SET nombre=%s, curso=%s, grado=%s, edad=%s, nombre_tutor=%s,
                           telefono_contacto=%s, estado_registro=%s WHERE id=%s""",
                        (c["nombre"], c["curso"], c["grado"], c["edad"], c["nombre_tutor"], c["telefono_contacto"], c["estado_registro"], old["pk"]))
            _insert_health(cur, old["pk"], c, rol)
            for col in changed:
                cur.execute("""INSERT INTO historial_estudiantil (id_estudiante, tipo, campo_afectado, valor_anterior, valor_nuevo, descripcion, registrado_por_rol)
                               VALUES (%s,%s,%s,%s,%s,%s,%s)""",
                            (old["pk"], "cambio_prioridad" if col == "prioridad" else "cambio_datos", col,
                             None if old[col] is None else str(old[col]), None if c[col] is None else str(c[col]),
                             f"Se actualizó: {FIELD_LABELS[col]}", rol))
        for text in notes:
            cur.execute("INSERT INTO historial_estudiantil (id_estudiante, tipo, descripcion, registrado_por_rol) VALUES (%s,'nota',%s,%s)",
                        (old["pk"], text, rol))
    if changed or notes:
        labels = [FIELD_LABELS[col] for col in changed] + (["notas añadidas"] if notes else [])
        audit(db, rol, "Actualizó estudiante", "estudiante", old["pk"], f'{c["nombre"]} · {", ".join(labels)}')
    db.commit()
    return jsonify(ok=True)


@bp.post("/estudiantes/<path:matricula>/archivar")
@require("nurse", "admin")
def archivar_estudiante(matricula):
    rol, db = current_role(), get_db()
    with db.cursor() as cur:
        row = get_active_student(cur, matricula, lock=True)
        cur.execute("UPDATE estudiantes SET estado='archivado', fecha_archivado=CURDATE(), motivo_archivo='Archivo manual' WHERE id=%s", (row["pk"],))
    audit(db, rol, "Archivó estudiante", "estudiante", row["pk"], row["nombre"])
    db.commit()
    return jsonify(ok=True)


# ---------------------------------------------------------------- visitas
@bp.post("/visitas")
@require("nurse")
def crear_visita():
    data, rol, db = request.get_json(silent=True) or {}, current_role(), get_db()
    try:
        when = datetime.strptime(f'{clip(data.get("date"), 10)} {clip(data.get("time"), 5) or "00:00"}', "%Y-%m-%d %H:%M")
    except ValueError:
        raise ApiError("Fecha u hora no válidas.")
    reason = clip(data.get("reason"), 2000)
    if not reason:
        raise ApiError("Falta el motivo de la visita.")
    dispatched = bool(data.get("dispatched"))
    with db.cursor() as cur:
        student = get_active_student(cur, clip(data.get("student"), 30))
        cur.execute("INSERT INTO visitas (id_estudiante, fecha_visita, motivo, despachado, registrada_por_rol) VALUES (%s,%s,%s,%s,%s)",
                    (student["pk"], when, reason, dispatched, rol))
        visit_id = cur.lastrowid
    audit(db, rol, "Registró visita", "visita", visit_id, f'{student["nombre"]} · Despachado: {"Sí" if dispatched else "No"}')
    db.commit()
    return jsonify(id=visit_id), 201


# ---------------------------------------------------------------- solicitudes de medicamentos
def _positive_int(value, message):
    try:
        number = int(value)
    except (TypeError, ValueError):
        raise ApiError(message)
    if number < 1 or number > 100000:
        raise ApiError(message)
    return number


@bp.post("/solicitudes")
@require("nurse")
def crear_solicitud():
    data, rol, db = request.get_json(silent=True) or {}, current_role(), get_db()
    medication = clip(data.get("medication"), 150)
    if not medication:
        raise ApiError("Falta el medicamento.")
    quantity = _positive_int(data.get("quantityRequested"), "Indica una cantidad mayor que cero.")
    with db.cursor() as cur:
        cur.execute("SELECT id FROM orientadoras WHERE nombre = %s AND activa = TRUE", (clip(data.get("to"), 150),))
        target = cur.fetchone()
        if not target:
            raise ApiError("Destinatario no válido.")
        cur.execute("""INSERT INTO solicitudes_medicamentos (id_orientadora, medicamento, presentacion, cantidad_solicitada, detalle_solicitud, solicitada_por_rol)
                       VALUES (%s,%s,%s,%s,%s,%s)""",
                    (target["id"], medication, none_if_empty(clip(data.get("presentation"), 100)), quantity,
                     none_if_empty(clip(data.get("body"), 1000)), rol))
        request_id = cur.lastrowid
    audit(db, rol, "Envió solicitud de medicamento", "solicitud", request_id, f'{medication} → {clip(data.get("to"), 80)}')
    db.commit()
    return jsonify(id=request_id), 201


@bp.put("/solicitudes/<int:request_id>")
@require("guidance")
def responder_solicitud(request_id):
    data, rol, db = request.get_json(silent=True) or {}, current_role(), get_db()
    status = data.get("status")
    if status not in ("Atendida", "No disponible"):
        raise ApiError("Resultado no válido.")
    delivered = _positive_int(data.get("quantityDelivered"), "Indica una cantidad entregada mayor que cero.") if status == "Atendida" else 0
    with db.cursor() as cur:
        cur.execute("SELECT id, medicamento, estado FROM solicitudes_medicamentos WHERE id = %s FOR UPDATE", (request_id,))
        row = cur.fetchone()
        if not row:
            raise ApiError("Solicitud no encontrada.", 404)
        if row["estado"] not in ("pendiente", "recibida"):
            raise ApiError("Esta solicitud ya fue respondida.", 409)
        cur.execute("""UPDATE solicitudes_medicamentos SET estado=%s, cantidad_entregada=%s, respuesta=%s,
                       respondida_por_rol=%s, respondida_en=NOW() WHERE id=%s""",
                    (MSG_STATUS_DB[status], delivered, none_if_empty(clip(data.get("responseNote"), 180)), rol, request_id))
    audit(db, rol, "Respondió solicitud de medicamento", "solicitud", request_id, f'{row["medicamento"]} · {status}')
    db.commit()
    return jsonify(ok=True)


# ---------------------------------------------------------------- cierre escolar
@bp.post("/cierre")
@require("admin")
def cierre_escolar():
    data, rol, db = request.get_json(silent=True) or {}, current_role(), get_db()
    graduate_from = GRADE_DB.get(data.get("graduateGrade"))
    if not graduate_from:
        raise ApiError("Elige el curso que se gradúa.")
    cut = GRADE_ORDER.index(graduate_from)
    promoted = archived = 0
    with db.cursor() as cur:
        cur.execute("""INSERT INTO cierres_escolares (anio_escolar, estado, creado_por_rol, confirmado_por_rol, confirmado_en, ejecutado_en)
                       VALUES (%s,'ejecutado',%s,%s,NOW(),NOW())""", (school_year(), rol, rol))
        closing_id = cur.lastrowid
        cur.execute("SELECT id, grado FROM estudiantes WHERE estado = 'activo' FOR UPDATE")
        for student in cur.fetchall():
            index = GRADE_ORDER.index(student["grado"])
            if index >= cut:
                cur.execute("UPDATE estudiantes SET estado='graduado', fecha_archivado=CURDATE(), motivo_archivo='Pendiente de revisión de retención' WHERE id=%s", (student["id"],))
                cur.execute("INSERT INTO historial_promociones (id_cierre, id_estudiante, grado_anterior, grado_nuevo, accion) VALUES (%s,%s,%s,NULL,'graduado_archivado')",
                            (closing_id, student["id"], student["grado"]))
                archived += 1
            else:
                new_grade = GRADE_ORDER[index + 1]
                cur.execute("UPDATE estudiantes SET grado=%s WHERE id=%s", (new_grade, student["id"]))
                cur.execute("INSERT INTO historial_promociones (id_cierre, id_estudiante, grado_anterior, grado_nuevo, accion) VALUES (%s,%s,%s,%s,'promovido')",
                            (closing_id, student["id"], student["grado"], new_grade))
                promoted += 1
    audit(db, rol, "Ejecutó cierre escolar", "cierre", closing_id, f"Promovidos: {promoted}; archivados: {archived}")
    db.commit()
    return jsonify(promoted=promoted, archived=archived)


# ---------------------------------------------------------------- auditoría que sí puede mandar el navegador
@bp.post("/auditoria")
@require()
def auditoria_cliente():
    data = request.get_json(silent=True) or {}
    action = clip(data.get("action"), 80)
    if action not in CLIENT_AUDIT_ACTIONS:
        raise ApiError("Acción no permitida.", 400)
    db = get_db()
    audit(db, current_role(), action, "consulta", None, clip(data.get("detail"), 120))
    db.commit()
    return jsonify(ok=True)