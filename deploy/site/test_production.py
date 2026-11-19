"""Isolated production authentication and persistence checks; no committed DB use."""
import importlib.util
from contextlib import closing
import os
from pathlib import Path
import sqlite3
import tempfile
import unittest
from unittest.mock import patch

from werkzeug.security import generate_password_hash


class ProductionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory()
        cls.database = Path(cls.directory.name) / 'synthetic.sqlite3'
        cls.passwords = {str(i): f'inert-individual-test-password-{i}' for i in range(1, 5)}
        environment = {'APP_ENV': 'production', 'SECRET_KEY': 'inert-production-test-key-1234567890',
                       'DATABASE': str(cls.database)}
        environment.update({f'STAFF_PASSWORD_HASH_{i}': generate_password_hash(password, method='pbkdf2:sha256:1000')
                            for i, password in cls.passwords.items()})
        with patch.dict(os.environ, environment, clear=True):
            spec = importlib.util.spec_from_file_location('isolated_hospital', Path(__file__).with_name('app.py'))
            cls.module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(cls.module)
        cls.app = cls.module.app
        cls.app.config['TESTING'] = True
        assert not cls.database.exists(), 'Production import must never create a database.'
        result = cls.app.test_cli_runner().invoke(args=['init-demo-db', '--confirm-synthetic'])
        assert result.exit_code == 0, result.output

    @classmethod
    def tearDownClass(cls):
        cls.directory.cleanup()

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
        before = self.database.read_bytes()
        response = self.client.get('/health/')
        self.assertEqual(response.json, {'status': 'ok'})
        self.assertNotIn('Set-Cookie', response.headers)
        self.assertEqual(before, self.database.read_bytes())

    def test_missing_database_is_not_silently_created(self):
        missing = Path(self.directory.name) / 'absent.sqlite3'
        with patch.object(self.module, 'DB', str(missing)):
            self.assertEqual(self.client.get('/health/').status_code, 503)
        self.assertFalse(missing.exists())

    def test_initializer_refuses_existing_database(self):
        before = self.database.read_bytes()
        result = self.app.test_cli_runner().invoke(args=['init-demo-db', '--confirm-synthetic'])
        self.assertNotEqual(result.exit_code, 0)
        self.assertEqual(before, self.database.read_bytes())

    def test_seed_is_isolated_and_public_report_works(self):
        with closing(sqlite3.connect(self.database)) as connection:
            self.assertEqual(connection.execute('SELECT COUNT(*) FROM patient').fetchone()[0], 400)
        self.assertEqual(self.client.get('/').status_code, 200)


if __name__ == '__main__':
    unittest.main()
