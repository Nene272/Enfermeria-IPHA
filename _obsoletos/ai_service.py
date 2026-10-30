import re
import time

from anthropic import Anthropic
from flask import Blueprint, current_app, jsonify, request, session

from api import ENF, ADM, GRADO_UI, CURSO_UI
from auth import audit, roles_required
from db import commit, query

bp = Blueprint("ai", __name__, url_prefix="/api/ai")

SYSTEM_CHAT = """Eres un asistente de apoyo para la enfermería de un colegio técnico (IPHA).
Reglas estrictas:
- Das orientación GENERAL y educativa (primeros auxilios básicos, cuándo derivar a un médico o llamar a emergencias,
  cómo redactar notas o mensajes, cómo organizar el trabajo de la enfermería).
- NO diagnosticas, NO recetas ni indicas dosis de medicamentos, NO reemplazas el juicio de la enfermera ni de un médico.
- Si la situación suena grave (dificultad para respirar, pérdida de conocimiento, sangrado fuerte, reacción alérgica
  severa, dolor en el pecho, golpe fuerte en la cabeza), indica de inmediato llamar a emergencias y avisar a la familia.
- No pidas ni uses nombres, teléfonos ni datos personales de estudiantes. Si el usuario los incluye, pídele que los quite.
- Responde en español, claro y breve."""

SYSTEM_REPORT = """Resume estadísticas de visitas a la enfermería de un colegio. Recibirás solo cifras agregadas
(sin nombres). Escribe en español un resumen de máximo 120 palabras: tendencias, grupos con más visitas y una
recomendación práctica. No inventes datos que no estén en las cifras."""

_last_call = {}


def _scrub(text):
    """Quita correos y números largos (teléfonos/cédulas) antes de enviar a la IA."""
    text = re.sub(r"[\w.+-]+@[\w-]+\.[\w.-]+", "[correo]", text)
    return re.sub(r"\+?\d[\d\s().-]{6,}\d", "[número]", text)


def _client():
    key = current_app.config["ANTHROPIC_API_KEY"]
    if not key:
        raise RuntimeError("Falta ANTHROPIC_API_KEY en .env")
    return Anthropic(api_key=key)


def _ask(system, messages):
    resp = _client().messages.create(model=current_app.config["AI_MODEL"], max_tokens=600,
                                     system=system, messages=messages)
    return "".join(b.text for b in resp.content if b.type == "text")


def _throttle():
    """Máximo 1 consulta cada 2 segundos por sesión (evita gastar crédito)."""
    key = session.get("rol")
    now = time.time()
    if now - _last_call.get(key, 0) < 2:
        return True
    _last_call[key] = now
    return False


@bp.post("/chat")
@roles_required(ENF, ADM)
def chat():
    if _throttle():
        return jsonify(error="Espera un momento antes de enviar otra consulta."), 429
    history = (request.get_json(silent=True) or {}).get("messages", [])[-10:]
    clean = []
    for m in history:
        if m.get("role") in ("user", "assistant") and isinstance(m.get("content"), str):
            clean.append({"role": m["role"], "content": _scrub(m["content"])[:2000]})
    if not clean or clean[-1]["role"] != "user":
        return jsonify(error="Mensaje vacío"), 400
    try:
        answer = _ask(SYSTEM_CHAT, clean)
    except Exception as e:  # clave mala, sin crédito, sin internet...
        current_app.logger.exception("Error IA")
        return jsonify(error="No se pudo contactar a la IA."), 502
    audit("Consulta a la IA", "ia", None, "Chat de orientación (sin datos de estudiantes)")
    commit()
    return jsonify(answer=answer)


@bp.post("/report-summary")
@roles_required(ADM)
def report_summary():
    if _throttle():
        return jsonify(error="Espera un momento antes de enviar otra consulta."), 429
    month = (request.get_json(silent=True) or {}).get("month", "")
    if not re.fullmatch(r"\d{4}-\d{2}", month):
        return jsonify(error="Mes inválido (AAAA-MM)"), 400
    rows = query("""SELECT e.grado, e.curso, COUNT(*) visitas, SUM(v.despachado) despachadas
                    FROM visitas v JOIN estudiantes e ON e.id=v.id_estudiante
                    WHERE DATE_FORMAT(v.fecha_visita,'%%Y-%%m')=%s GROUP BY e.grado, e.curso""", (month,))
    if not rows:
        return jsonify(answer="No hay visitas registradas en ese mes.")
    stats = "\n".join(f"{GRADO_UI[r['grado']]} - {CURSO_UI[r['curso']]}: {r['visitas']} visitas, "
                      f"{int(r['despachadas'] or 0)} despachadas" for r in rows)
    try:
        answer = _ask(SYSTEM_REPORT, [{"role": "user", "content": f"Mes {month}:\n{stats}"}])
    except Exception:
        current_app.logger.exception("Error IA")
        return jsonify(error="No se pudo contactar a la IA."), 502
    audit("Resumen IA de reportes", "ia", None, month)
    commit()
    return jsonify(answer=answer)
