"""Focused checks without MySQL credentials or network activity."""
import importlib.util
import os
from datetime import date
from decimal import Decimal
from pathlib import Path
import unittest
from unittest.mock import MagicMock, patch

import pymysql
from mysql_store import Database, Row, SCHEMA, connection_options
from bootstrap_mysql import create_baseline, seed_database


class MySQLUnitTests(unittest.TestCase):
    def test_rows_preserve_named_indexed_iterable_and_chart_access(self):
        row = Row(['id', 'issued', 'amount'], (3, date(2026, 1, 2), Decimal('12.50')))
        self.assertEqual(row['id'], 3)
        self.assertEqual(row[1], '2026-01-02')
        self.assertEqual(tuple(row), (3, '2026-01-02', 12.5))

    def test_remote_production_requires_verified_tls(self):
        environment = {'APP_ENV': 'production', 'DB_HOST': 'rds.example.invalid',
                       'DB_USER': 'inert', 'DB_PASSWORD': 'inert'}
        with patch.dict(os.environ, environment, clear=True):
            with self.assertRaises(RuntimeError):
                connection_options()
            with patch.dict(os.environ, {'DB_SSL_CA': '/private/trusted-ca.pem'}):
                options = connection_options()
                self.assertTrue(options['ssl_verify_cert'])
                self.assertTrue(options['ssl_verify_identity'])
                self.assertFalse(options['local_infile'])

    def test_other_project_schema_is_rejected(self):
        with patch.dict(os.environ, {'DB_NAME': 'another_project'}, clear=True):
            with self.assertRaises(RuntimeError):
                connection_options()

    def test_baseline_refuses_existing_objects(self):
        connection = MagicMock()
        connection.execute.return_value.fetchone.side_effect = [(SCHEMA,), (1,)]
        with self.assertRaises(RuntimeError):
            create_baseline(connection)
        self.assertTrue(all(call.args[0].startswith('SELECT ') for call in connection.execute.call_args_list))

    @patch('bootstrap_mysql.verify_schema')
    def test_seed_refuses_existing_records_and_rolls_back(self, verify):
        connection = MagicMock()
        connection.execute.return_value.fetchone.side_effect = [(1,), (1,)]
        with self.assertRaises(RuntimeError):
            seed_database(connection)
        connection.rollback.assert_called_once()
        connection.commit.assert_not_called()

    def test_app_import_never_connects_or_initializes(self):
        environment = {'APP_ENV': 'production', 'SECRET_KEY': 'inert-long-test-session-secret-1234567890',
                       'DB_HOST': '127.0.0.1', 'DB_USER': 'inert', 'DB_PASSWORD': 'inert'}
        environment.update({f'STAFF_PASSWORD_HASH_{i}': 'pbkdf2:sha256:1000$inert$inert' for i in range(1, 5)})
        with patch.dict(os.environ, environment, clear=True), patch('mysql_store.pymysql.connect') as connect:
            spec = importlib.util.spec_from_file_location('inert_hospital', Path(__file__).with_name('app.py'))
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            connect.assert_not_called()
            with patch.object(module, 'Database', side_effect=pymysql.OperationalError('private')):
                response = module.app.test_client().get('/health/')
                self.assertEqual(response.status_code, 503)
                self.assertEqual(response.json, {'status': 'database_unavailable'})


if __name__ == '__main__':
    unittest.main()
