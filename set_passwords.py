"""Guarda el HASH de la contraseña de cada rol. Ejecutar una vez:  python set_passwords.py
(funciona desde la carpeta backend/ o desde la raíz del proyecto)."""
import getpass
import os
import sys

# config.py y el .env están en la carpeta del proyecto (un nivel arriba de backend/).
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
from dotenv import load_dotenv
load_dotenv(os.path.join(ROOT, ".env"))

import pymysql
from werkzeug.security import generate_password_hash

from config import Config

conn = pymysql.connect(host=Config.DB_HOST, port=Config.DB_PORT, user=Config.DB_USER,
                       password=Config.DB_PASSWORD, database=Config.DB_NAME, connect_timeout=5)
with conn.cursor() as cur:
    for rol in ("enfermeria", "orientacion", "administracion"):
        pw = getpass.getpass(f"Contraseña para {rol} (mín. 8 caracteres): ")
        if len(pw) < 8:
            raise SystemExit("Muy corta.")
        cur.execute("UPDATE login_enfermeria SET contrasena_hash=%s WHERE rol=%s",
                    (generate_password_hash(pw), rol))
conn.commit()
print("Listo.")
