import mysql.connector

def obtener_conexion():
    conexion = mysql.connector.connect(
        host="localhost",
        port=3306,
        user="enfermeria_app",
        password="enfermeria161719",
        database="enfermeria_escolar"
    )

    return conexion