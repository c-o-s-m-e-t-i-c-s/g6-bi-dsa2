"""Small MySQL adapter retaining indexed and named access for existing templates."""
import os
from datetime import date, datetime
from decimal import Decimal

import pymysql

SCHEMA = '2026_3dsa_6_kchospital'
PROJECTIONS = {
    'department': 'id,name',
    'staff': 'id,full_name,role,department_id,active',
    'patient': 'id,code,full_name,birthdate,sex,contact,insurance,created_by,archived,created_at',
    'visit': 'id,patient_id,department_id,visit_date,wait_min,stay_hours,diagnosis,readmitted',
    'appointment': 'id,patient_id,staff_id,appt_date,type,status',
    'treatment': 'id,visit_id,name,status',
    'invoice': 'id,patient_id,visit_id,amount,paid,issued',
    'vendor_bill': 'id,vendor,amount,paid,issued',
    'supply': 'id,name,category,stock,reorder_level,unit_cost',
    'audit_log': 'id,staff_id,action,detail,at',
}


def connection_options(prefix='DB_'):
    name = os.getenv(prefix + 'NAME', SCHEMA)
    if name != SCHEMA:
        raise RuntimeError('KC Hospital must use its exact project schema.')
    host = os.environ[prefix + 'HOST']
    options = dict(host=host, port=int(os.getenv(prefix + 'PORT', '3306')),
                   database=name, user=os.environ[prefix + 'USER'],
                   password=os.environ[prefix + 'PASSWORD'], charset='utf8mb4',
                   connect_timeout=8, read_timeout=30, write_timeout=20,
                   autocommit=False, local_infile=False)
    ca = os.getenv(prefix + 'SSL_CA')
    if ca:
        options.update(ssl_ca=ca, ssl_verify_cert=True, ssl_verify_identity=True)
    elif os.getenv('APP_ENV') == 'production' and host not in ('127.0.0.1', 'localhost', '::1'):
        raise RuntimeError('Production remote MySQL requires a trusted DB_SSL_CA.')
    return options


class Row:
    def __init__(self, columns, values):
        self.columns = columns
        # Preserve the original presentation model: ISO dates and numeric charts.
        self.values = tuple(value.isoformat() if isinstance(value, (date, datetime))
                            else float(value) if isinstance(value, Decimal) else value
                            for value in values)

    def __getitem__(self, key):
        return self.values[self.columns.index(key) if isinstance(key, str) else key]

    def __iter__(self):
        return iter(self.values)


class Result:
    def __init__(self, rows, lastrowid):
        self.rows, self.lastrowid = rows, lastrowid

    def fetchone(self):
        return self.rows[0] if self.rows else None

    def fetchall(self):
        return self.rows

    def __iter__(self):
        return iter(self.rows)


class Database:
    def __init__(self, prefix='DB_'):
        self.connection = pymysql.connect(**connection_options(prefix))

    def execute(self, sql, parameters=()):
        with self.connection.cursor() as cursor:
            cursor.execute(sql, parameters)
            columns = [field[0] for field in cursor.description] if cursor.description else []
            rows = [Row(columns, row) for row in cursor.fetchall()] if columns else []
            return Result(rows, cursor.lastrowid)

    def commit(self):
        self.connection.commit()

    def rollback(self):
        self.connection.rollback()

    def close(self):
        self.connection.close()


def verify_schema(connection):
    if connection.execute('SELECT DATABASE()').fetchone()[0] != SCHEMA:
        raise RuntimeError('Unexpected selected MySQL schema.')
    for table, columns in PROJECTIONS.items():
        connection.execute(f'SELECT {columns} FROM {table} WHERE 1=0')
