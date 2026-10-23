"""Servidor de la Enfermería IPHA.

Hace tres cosas:
  1. Sirve las páginas (HTML/JS/CSS) del proyecto.
  2. Registra la API con MySQL (api.py): login, estudiantes, visitas, solicitudes, auditoría.
  3. Ofrece la ruta de IA (/api/ia).

Ejecutar:  python servidor.py   y abrir  http://localhost:5000
"""
import os
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# El .env debe cargarse ANTES de importar config.py (que lee las variables al importarse).
from dotenv import load_dotenv
load_dotenv(os.path.join(BASE_DIR, ".env"))

from flask import Flask, abort, jsonify, redirect, request, send_from_directory

# backend/ contiene config.py y db.py; se agrega al path para que api.py pueda hacer "from db import get_db".
sys.path.insert(0, os.path.join(BASE_DIR, "backend"))
from config import Config   # noqa: E402
import db                   # noqa: E402
import api                  # noqa: E402

# Solo se sirven estos tipos de archivo: así nunca se expone .env, el código Python ni los .sql.
ALLOWED_EXT = {".html", ".js", ".css", ".png", ".jpg", ".jpeg", ".svg", ".ico", ".webp"}

app = Flask(__name__, static_folder=None)
app.config.from_object(Config)                  # SECRET_KEY, datos de MySQL, cookies de sesión
app.config["MAX_CONTENT_LENGTH"] = 100_000      # las peticiones de esta app son pequeñas
app.teardown_appcontext(db.close_db)            # cierra la conexión MySQL al terminar cada petición
app.register_blueprint(api.bp)                  # <-- esto es lo que faltaba: activa /api/login, /api/datos, etc.


# ------------------------------------------------------------------ IA

SYSTEM_RESUMEN = (
    "Eres un asistente de apoyo administrativo para la enfermería de un colegio. "
    "Resume en español, en máximo 6 líneas, el historial de visitas que se te da: frecuencia, "
    "motivos que se repiten y si hay algo que el personal de enfermería podría revisar. "
    "NO diagnostiques, NO recomiendes tratamientos ni medicamentos y NO tomes decisiones clínicas. "
    "Termina siempre con: 'Resumen informativo; la decisión corresponde al personal de enfermería.'"
)

SYSTEM_SOLICITUD = (
    "Redactas mensajes breves y formales en español, de la enfermería de un colegio hacia el equipo de "
    "orientación, para solicitar medicamentos o insumos. Máximo 6 líneas, tono cordial y claro. "
    "Usa solo los datos que se te dan; no inventes cantidades, nombres ni fechas. "
    "No incluyas información de estudiantes y no des consejos médicos."
)


def clip(value, limit):
    return str(value or "").strip()[:limit]


def build_prompt(data):
    """Valida lo que manda el navegador y arma el prompt. Lanza ValueError si algo no cuadra."""
    mode = data.get("mode")
    if mode == "resumen":
        visits = data.get("visits")
        if not isinstance(visits, list) or not visits:
            raise ValueError("No hay visitas para resumir.")
        lines = [
            f'- {clip(v.get("date"), 10)}: {clip(v.get("reason"), 300)} '
            f'(despachado: {"sí" if v.get("dispatched") else "no"})'
            for v in visits[:30] if isinstance(v, dict)
        ]
        user = (f'Estudiante de {clip(data.get("grade"), 30)}, edad: {clip(data.get("age"), 3) or "no registrada"}.\n'
                "Visitas (de la más reciente a la más antigua):\n" + "\n".join(lines))
        return SYSTEM_RESUMEN, user
    if mode == "solicitud":
        medication = clip(data.get("medication"), 100)
        if not medication:
            raise ValueError("Falta el medicamento.")
        user = (f"Medicamento: {medication}\nCantidad: {clip(data.get('quantity'), 60) or 'no indicada'}\n"
                f"Contexto: {clip(data.get('context'), 300) or 'ninguno'}")
        return SYSTEM_SOLICITUD, user
    raise ValueError("Tarea no reconocida.")


def ask_model(system, user):
    """Única función que habla con el proveedor de IA (si usan otro, solo cambian esta)."""
    import anthropic

    client = anthropic.Anthropic()  # lee ANTHROPIC_API_KEY del entorno
    message = client.messages.create(
        model=os.getenv("AI_MODEL", "claude-sonnet-5-5"),
        max_tokens=600,
        system=system,
        messages=[{"role": "user", "content": user}],
    )
    return "".join(block.text for block in message.content if block.type == "text")


@app.get("/api/ia/estado")
@api.require()          # solo con sesión iniciada
def ia_estado():
    return jsonify(key=bool(os.getenv("ANTHROPIC_API_KEY")))


@app.post("/api/ia")
@api.require("nurse", "admin")   # el historial de visitas solo lo consultan Enfermería y Administración
def ia():
    if not request.is_json:
        return jsonify(error="Se esperaba JSON."), 415
    if not os.getenv("ANTHROPIC_API_KEY"):
        return jsonify(error="Falta ANTHROPIC_API_KEY en el archivo .env del servidor."), 503
    try:
        system, user = build_prompt(request.get_json(silent=True) or {})
    except ValueError as error:
        return jsonify(error=str(error)), 400
    try:
        return jsonify(text=ask_model(system, user))
    except Exception:
        app.logger.exception("Error llamando a la IA")
        return jsonify(error="La IA no respondió. Revisa la clave y la conexión a internet."), 502


# ------------------------------------------------------------------ páginas

def real_name(name):
    """Busca el archivo sin importar mayúsculas (Index.html / index.html)."""
    if "/" in name or "\\" in name:
        return None
    return next((f for f in os.listdir(BASE_DIR) if f.lower() == name.lower()), None)


@app.get("/")
def root():
    return redirect("/login.html")


@app.get("/<path:filename>")
def files(filename):
    real = real_name(filename)
    if not real or os.path.splitext(real)[1].lower() not in ALLOWED_EXT:
        abort(404)
    return send_from_directory(BASE_DIR, real)


if __name__ == "__main__":
    print("Abre http://localhost:5000 en el navegador")
    app.run(host="127.0.0.1", port=5000)  # solo accesible desde esta misma computadora
