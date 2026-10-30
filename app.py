"""Compatibilidad: el servidor real es servidor.py (MySQL + IA + páginas).

Este archivo antes era un ejemplo suelto (tabla "usuarios" que no existe y contraseña escrita en el código).
Ahora solo arranca servidor.py, así `python app.py` y `python servidor.py` hacen lo mismo.
"""
import runpy
import os

if __name__ == "__main__":
    runpy.run_path(os.path.join(os.path.dirname(os.path.abspath(__file__)), "servidor.py"), run_name="__main__")
