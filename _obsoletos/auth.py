import time
from functools import wraps

from flask import Blueprint, jsonify, request, session
from werkzeug.security import check_password_hash

from db import commit, execute, query

bp = Blueprint("auth", __name__, url_prefix="/api")

# El frontend usa nurse/guidance/admin; la base de datos usa español.
FRONT_TO_DB = {"nurse": "enfermeria", "guidance": "orientacion", "admin": "administracion"}
DB_TO_FRONT = {v: k for k, v in FRONT_TO_DB.items()}
LABEL = {"enfermeria": "Enfermería", "orientacion": "Orientación", "administracion": "Administración"}

_attempts = {}  # ip -> [timestamps]  (freno simple contra fuerza bruta)


def audit(accion, entidad, id_entidad=None, resumen=None):
    """Registra una acción. NUNCA pongas contraseñas ni datos médicos en 'resumen'."""
    execute(
        "INSERT INTO registros_auditoria (rol_actor, accion, entidad, id_entidad, resumen) "
        "VALUES (%s,%s,%s,%s,%s)",
        (session["rol"], accion[:80], entidad[:80], id_entidad, (resumen or "")[:255]),
    )


def current_role():
    return session.get("rol")


def login_required(fn):
    @wraps(fn)
    def wrapper(*a, **kw):
        if not current_role():
            return jsonify(error="No autenticado"), 401
        return fn(*a, **kw)
    return wrapper


def roles_required(*allowed):
    """Uso: @roles_required('enfermeria','administracion')"""
    def deco(fn):
        @wraps(fn)
        def wrapper(*a, **kw):
            if not current_role():
                return jsonify(error="No autenticado"), 401
            if current_role() not in allowed:
                return jsonify(error="No tienes permiso para esto"), 403
            return fn(*a, **kw)
        return wrapper
    return deco


@bp.post("/login")
def login():
    ip = request.remote_addr or "?"
    now = time.time()
    recent = [t for t in _attempts.get(ip, []) if now - t < 300]
    if len(recent) >= 8:
        return jsonify(error="Demasiados intentos. Espera 5 minutos."), 429

    data = request.get_json(silent=True) or {}
    rol = FRONT_TO_DB.get(data.get("role"))
    password = data.get("password") or ""
    row = query("SELECT contrasena_hash FROM login_enfermeria WHERE rol=%s", (rol,), one=True) if rol else None

    if not row or not row["contrasena_hash"] or not check_password_hash(row["contrasena_hash"], password):
        recent.append(now)
        _attempts[ip] = recent
        return jsonify(error="Rol o contraseña incorrectos."), 401

    _attempts.pop(ip, None)
    session.clear()
    session.permanent = True
    session["rol"] = rol
    audit("Inicio de sesión", "sesion")
    commit()
    return jsonify(role=DB_TO_FRONT[rol], label=LABEL[rol])


@bp.post("/logout")
def logout():
    session.clear()
    return jsonify(ok=True)


@bp.get("/me")
def me():
    rol = current_role()
    if not rol:
        return jsonify(error="No autenticado"), 401
    return jsonify(role=DB_TO_FRONT[rol], label=LABEL[rol])
