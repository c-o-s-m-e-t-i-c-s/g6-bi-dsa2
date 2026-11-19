"""Explicit one-time schema/fictional seed operations, independent of Flask auth."""
import argparse
from contextlib import closing
from pathlib import Path

from mysql_store import Database, SCHEMA, PROJECTIONS, verify_schema
from seed_data import seed


def create_baseline(connection):
    if connection.execute('SELECT DATABASE()').fetchone()[0] != SCHEMA:
        raise RuntimeError('Unexpected selected schema.')
    count = connection.execute('SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=%s', (SCHEMA,)).fetchone()[0]
    if count:
        raise RuntimeError('Schema is not empty; refusing baseline application or automatic retry.')
    path = Path(__file__).with_name('migrations') / '0001_initial_schema.sql'
    sql = '\n'.join(line for line in path.read_text().splitlines() if not line.lstrip().startswith('--'))
    statements = [statement.strip() for statement in sql.split(';') if statement.strip()]
    if len(statements) != len(PROJECTIONS) or any(not statement.startswith('CREATE TABLE ') for statement in statements):
        raise RuntimeError('Baseline accepts only the reviewed CREATE TABLE statements.')
    for statement in statements:
        connection.execute(statement)
    verify_schema(connection)


def seed_database(connection):
    verify_schema(connection)
    locked = connection.execute('SELECT GET_LOCK(%s, 10)', ('kc-hospital-synthetic-bootstrap',)).fetchone()[0]
    if locked != 1:
        raise RuntimeError('Another bootstrap holds the seed lock.')
    try:
        if any(connection.execute(f'SELECT 1 FROM {table} LIMIT 1').fetchone() for table in PROJECTIONS):
            raise RuntimeError('Seed refuses existing records; tables must be completely empty.')
        counters = connection.execute('SELECT AUTO_INCREMENT FROM information_schema.tables '
            'WHERE table_schema=%s AND AUTO_INCREMENT IS NOT NULL', (SCHEMA,)).fetchall()
        if any(row[0] != 1 for row in counters):
            raise RuntimeError('Seed requires a fresh baseline with unused IDs; inspect failed attempts privately.')
        seed(connection)
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.execute('SELECT RELEASE_LOCK(%s)', ('kc-hospital-synthetic-bootstrap',))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['schema', 'seed', 'verify'])
    parser.add_argument('--confirm-schema', choices=[SCHEMA], required=True)
    parser.add_argument('--confirm-synthetic', action='store_true')
    arguments = parser.parse_args()
    if arguments.operation == 'seed' and not arguments.confirm_synthetic:
        parser.error('Seeding requires --confirm-synthetic.')
    with closing(Database('BOOTSTRAP_DB_')) as connection:
        if arguments.operation == 'schema':
            create_baseline(connection)
        elif arguments.operation == 'seed':
            seed_database(connection)
        else:
            verify_schema(connection)
    print(f'{arguments.operation} completed for the confirmed KC Hospital MySQL schema.')


if __name__ == '__main__':
    main()
