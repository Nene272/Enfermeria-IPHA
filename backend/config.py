import os
from datetime import timedelta
from dotenv import load_dotenv

load_dotenv()


class Config:
    SECRET_KEY = os.getenv("SECRET_KEY") or os.getenv("FLASK_SECRET_KEY")
    if not SECRET_KEY:
        raise RuntimeError(
            "Falta SECRET_KEY en el archivo .env. Genera una con:  "
            'python -c "import secrets; print(secrets.token_hex(32))"'
        )
    DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
    DB_PORT = int(os.getenv("DB_PORT", "3306"))
    DB_USER = os.getenv("DB_USER", "root")
    DB_PASSWORD = os.getenv("DB_PASSWORD", "")
    DB_NAME = os.getenv("DB_NAME", "enfermeria_escolar")
    FRONTEND_DIR = os.path.abspath(os.getenv("FRONTEND_DIR", "../Enfermeria IPHA"))
    ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
    AI_MODEL = os.getenv("AI_MODEL", "claude-sonnet-5-5")

    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = "Lax"
    PERMANENT_SESSION_LIFETIME = timedelta(hours=8)
