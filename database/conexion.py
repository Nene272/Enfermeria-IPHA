import mysql.connector

def obtener_conexion():
    conexion = mysql.connector.connect(
        host="169.254.83.107",
        port=3306,
        user="enfermeria_app",
        password="enfermeria161719",
        database="enfermeria_escolar"
    )

    return conexion