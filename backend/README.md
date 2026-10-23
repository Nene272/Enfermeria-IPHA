# Backend Enfermería IPHA (Flask + MySQL + IA)

## 1. Descargar / instalar (en TU laptop)
1. Python 3.11+  → https://www.python.org/downloads/  (marca "Add Python to PATH")
2. VS Code (opcional) → https://code.visualstudio.com/
3. Git (opcional) → https://git-scm.com/
4. Cliente MySQL para probar: MySQL Workbench o DBeaver (opcional)
5. API key de Anthropic → https://console.anthropic.com/  (Settings > API Keys; requiere crédito)

## 2. Estructura de carpetas
    Proyecto/
      backend/            <- esta carpeta
      Enfermeria IPHA/    <- frontend de tu compañero (descomprimido)

## 3. Entorno Python
    cd backend
    python -m venv venv
    venv\Scripts\activate          (Windows)   |   source venv/bin/activate   (Mac/Linux)
    pip install -r requirements.txt
    copy .env.example .env         (Mac/Linux: cp)   y edítalo

Genera el SECRET_KEY:  python -c "import secrets;print(secrets.token_hex(32))"

## 4. Base de datos
Opción A (recomendada para desarrollar): cada quien instala MySQL 8 local y corre los scripts:
    1) el .sql original   2) sql/02_ajustes.sql   (cambia la clave del usuario enfermeria_app)
    DB_HOST=127.0.0.1 en tu .env

Opción B (todos usan la BD de la laptop de tu compañero). Él debe:
  - Ejecutar los dos scripts.
  - Averiguar su IP local (Windows: `ipconfig`, busca IPv4, ej. 192.168.1.25).
  - En my.ini (Windows: C:\ProgramData\MySQL\MySQL Server 8.0\my.ini) poner `bind-address = 0.0.0.0` y reiniciar el servicio MySQL.
  - Abrir el puerto 3306 en el Firewall de Windows (solo red privada).
  - Estar en la MISMA red WiFi que tú.
  Tú pones en .env:  DB_HOST=192.168.1.25  (su IP). Prueba: `mysql -h 192.168.1.25 -u enfermeria_app -p`
  Limitación: si su laptop se apaga o cambia de red, no tendrás BD. Para entregar el proyecto, usen un solo servidor.

## 5. Contraseñas de los 3 roles
    python set_passwords.py        (guarda los HASH en login_enfermeria)

## 6. Frontend
Copia api.js, login.js, ia.js y los cambios descritos en frontend_patch/GUIA_APP_JS.md a la carpeta "Enfermeria IPHA".
Quita de login.html el bloque "Credenciales ficticias de prueba".

## 7. Correr
    python app.py
Abre http://127.0.0.1:5000  (desde otro dispositivo: http://TU_IP:5000)

## 8. Probar la API sin frontend (opcional)
    curl -c c.txt -H "Content-Type: application/json" -d "{\"role\":\"nurse\",\"password\":\"TU_CLAVE\"}" http://127.0.0.1:5000/api/login
    curl -b c.txt http://127.0.0.1:5000/api/students

## Endpoints
POST /api/login · POST /api/logout · GET /api/me
GET/POST /api/students · PUT /api/students/<id> · POST /api/students/<id>/archive · POST /api/students/<id>/notes
GET/POST /api/visits · PATCH /api/visits/<id>/dispatch
GET/POST /api/medication-requests · POST /api/medication-requests/<id>/respond · GET /api/orientadoras
GET /api/audit · GET /api/year-end/preview · POST /api/year-end/execute
POST /api/ai/chat · POST /api/ai/report-summary

## Antes de usar datos reales
Usar HTTPS (cookie Secure), debug=False con gunicorn/waitress, no exponer MySQL a Internet, y permiso de la institución.
