import os
from datetime import timedelta
from dotenv import load_dotenv

load_dotenv()


class Config:
    SECRET_KEY = os.getenv("SECRET_KEY") or os.getenv("FLASK_SECRET_KEY") or "4e27855fb346296422042a48d994abe5d3dc8200ed0e708e895760b3e197c03f"

    # Base de datos MySQL
    # Valores por defecto = los del .env; si existe el .env, tiene prioridad.
    DB_HOST = os.getenv("DB_HOST", "100.114.34.119")
    DB_PORT = int(os.getenv("DB_PORT", "3306"))
    DB_USER = os.getenv("DB_USER", "enfermeria_app")
    DB_PASSWORD = os.getenv("DB_PASSWORD", "enfermeria161719")
    DB_NAME = os.getenv("DB_NAME", "enfermeria_escolar")
    FRONTEND_DIR = os.path.abspath(os.getenv("FRONTEND_DIR", "../Enfermeria IPHA"))

    # IA: Google Gemini
    GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")   # solo en .env (GitHub bloquea claves dentro del código)
    AI_MODEL = os.getenv("AI_MODEL") or "gemini-3.6-flash"

    # Cookies de sesión
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = "Lax"
    PERMANENT_SESSION_LIFETIME = timedelta(hours=8)