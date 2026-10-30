import pymysql
import pymysql.cursors
from flask import current_app, g


def get_db():
    if "db" not in g:
        c = current_app.config
        g.db = pymysql.connect(
            host=c["DB_HOST"], port=c["DB_PORT"], user=c["DB_USER"],
            password=c["DB_PASSWORD"], database=c["DB_NAME"],
            charset="utf8mb4", cursorclass=pymysql.cursors.DictCursor,
            autocommit=False,
        )
    return g.db


def close_db(_exc=None):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def query(sql, args=None, one=False):
    with get_db().cursor() as cur:
        cur.execute(sql, args or ())
        rows = cur.fetchall()
    if one:
        return rows[0] if rows else None
    return rows


def execute(sql, args=None):
    with get_db().cursor() as cur:
        cur.execute(sql, args or ())
        return cur.lastrowid


def commit():
    get_db().commit()


def rollback():
    get_db().rollback()
