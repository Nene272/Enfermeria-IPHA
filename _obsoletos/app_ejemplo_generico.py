from flask import Flask, jsonify, request
from flask_cors import CORS
import mysql.connector

app = Flask(__name__)
CORS(app)  # permite que el frontend llame a la API

def get_db():
    return mysql.connector.connect(
        host="localhost",
        user="tu_usuario",
        password="tu_password",
        database="tu_base_de_datos"
    )

@app.route("/api/usuarios", methods=["GET"])
def listar_usuarios():
    db = get_db()
    cursor = db.cursor(dictionary=True)
    cursor.execute("SELECT id, nombre, email FROM usuarios")
    datos = cursor.fetchall()
    cursor.close()
    db.close()
    return jsonify(datos)

@app.route("/api/usuarios", methods=["POST"])
def crear_usuario():
    data = request.get_json()
    db = get_db()
    cursor = db.cursor()
    cursor.execute(
        "INSERT INTO usuarios (nombre, email) VALUES (%s, %s)",
        (data["nombre"], data["email"])
    )
    db.commit()
    cursor.close()
    db.close()
    return jsonify({"mensaje": "Usuario creado"}), 201

if __name__ == "__main__":
    app.run(debug=True)