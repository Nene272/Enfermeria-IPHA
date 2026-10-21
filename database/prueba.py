from database.conexion import obtener_conexion

try:
    conexion = obtener_conexion()
    print("¡Conexión exitosa con MySQL!")

    cursor = conexion.cursor()
    cursor.execute("SELECT * FROM estudiantes")

    for estudiante in cursor.fetchall():
        print(estudiante)

    cursor.close()
    conexion.close()

except Exception as error:
    print("Error:", error)