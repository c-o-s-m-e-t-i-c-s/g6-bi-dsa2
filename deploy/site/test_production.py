"""Isolated production authentication and persistence checks; no committed DB use."""
import importlib.util
from contextlib import closing
import os
from pathlib import Path
import pymysql
from mysql_store import Database
from bootstrap_mysql import create_baseline, seed_database
import unittest
from unittest.mock import patch

from werkzeug.security import generate_password_hash


@unittest.skipUnless(os.getenv('MYSQL_INTEGRATION_TEST') == '1', 'Requires an isolated empty MySQL 8 project schema.')
class ProductionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.passwords = {str(i): f'inert-individual-test-password-{i}' for i in range(1, 5)}
        environment = {'APP_ENV': 'production', 'SECRET_KEY': 'inert-production-test-key-1234567890',
                       **{key: value for key, value in os.environ.items() if key.startswith(('DB_', 'BOOTSTRAP_DB_'))}}
        environment.update({f'STAFF_PASSWORD_HASH_{i}': generate_password_hash(password, method='pbkdf2:sha256:1000')
                            for i, password in cls.passwords.items()})
        with patch.dict(os.environ, environment, clear=True):
            spec = importlib.util.spec_from_file_location('isolated_hospital', Path(__file__).with_name('app.py'))
            cls.module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(cls.module)
        cls.app = cls.module.app
        cls.app.config['TESTING'] = True
        with closing(Database('BOOTSTRAP_DB_')) as connection:
            create_baseline(connection)
            seed_database(connection)

    def setUp(self):
        self.client = self.app.test_client()

    def login(self, identifier='1', password=None):
        self.client.get('/login', base_url='https://localhost')
        with self.client.session_transaction() as state:
            csrf = state['csrf']
        values = {'1': ('Ana Reyes', 'Admin', '1'), '2': ('Ben Cruz', 'Staff', '2'),
                  '3': ('Carla Dizon', 'Staff', '3'), '4': ('Dan Lopez', 'Admin', '7')}
        name, role, department = values[identifier]
        return self.client.post('/login', base_url='https://localhost', data={
            'csrf': csrf, 'staff_id': identifier, 'full_name': name,
            'role': role, 'department_id': department, 'password': password or ''})

    def test_documented_identity_without_password_cannot_access(self):
        self.assertEqual(self.login().status_code, 200)
        self.assertEqual(self.client.get('/dashboard').status_code, 302)
        self.assertEqual(self.client.get('/add-patient').status_code, 302)

    def test_individual_passwords_and_role_permissions(self):
        self.assertEqual(self.login('2', self.passwords['1']).status_code, 200)
        self.assertEqual(self.login('2', self.passwords['2']).status_code, 302)
        self.assertEqual(self.client.get('/dashboard', base_url='https://localhost').status_code, 200)
        self.assertEqual(self.client.get('/dashboard?view=finance', base_url='https://localhost').status_code, 403)
        self.assertEqual(self.client.get('/dashboard?view=inventory', base_url='https://localhost').status_code, 403)

    def test_admin_cookie_and_csrf(self):
        response = self.login('1', self.passwords['1'])
        self.assertEqual(response.status_code, 302)
        self.assertIn('Secure', response.headers['Set-Cookie'])
        self.assertIn('HttpOnly', response.headers['Set-Cookie'])
        self.assertEqual(self.client.get('/dashboard?view=finance', base_url='https://localhost').status_code, 200)
        self.assertEqual(self.client.post('/add-patient', base_url='https://localhost', data={}).status_code, 400)

    def test_legacy_identity_session_cannot_bypass_password(self):
        with self.client.session_transaction() as state:
            state.update(uid=1, role='Admin', name='Ana Reyes')
        self.assertEqual(self.client.get('/dashboard').status_code, 302)

    def test_health_is_read_only_and_does_not_return_records(self):
        response = self.client.get('/health/')
        self.assertEqual(response.json, {'status': 'ok'})
        self.assertNotIn('Set-Cookie', response.headers)

    def test_missing_database_does_not_initialize(self):
        with patch.object(self.module, 'Database', side_effect=pymysql.OperationalError('private endpoint')):
            response = self.client.get('/health/')
            self.assertEqual(response.status_code, 503)
            self.assertNotIn(b'private', response.data)

    def test_initializer_refuses_existing_database(self):
        with closing(Database('BOOTSTRAP_DB_')) as connection:
            with self.assertRaises(RuntimeError):
                create_baseline(connection)
            with self.assertRaises(RuntimeError):
                seed_database(connection)

    def test_seed_is_isolated_and_public_report_works(self):
        with closing(Database('BOOTSTRAP_DB_')) as connection:
            self.assertGreaterEqual(connection.execute('SELECT COUNT(*) FROM patient').fetchone()[0], 400)
        self.assertEqual(self.client.get('/').status_code, 200)
        self.login('1', self.passwords['1'])
        for view in ('overview', 'finance', 'operations', 'inventory', 'treatment'):
            self.assertEqual(self.client.get('/dashboard?view='+view, base_url='https://localhost').status_code, 200)

    def test_authorized_patient_create_persists(self):
        self.login('2', self.passwords['2'])
        with self.client.session_transaction() as state:
            csrf = state['csrf']
        response = self.client.post('/add-patient', base_url='https://localhost', data={
            'csrf': csrf, 'full_name': 'Synthetic Integration Patient',
            'birthdate': '01/02/1990', 'contact': '09123456789', 'insurance': 'None'})
        self.assertEqual(response.status_code, 302)
        with closing(Database('BOOTSTRAP_DB_')) as connection:
            row = connection.execute('SELECT code FROM patient WHERE full_name=%s', ('Synthetic Integration Patient',)).fetchone()
            self.assertIsNotNone(row)
            self.assertTrue(row[0].startswith('PT-'))


if __name__ == '__main__':
    unittest.main()
