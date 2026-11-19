# Kacchan Care Hospital
Flask + SQLite. `pip install -r requirements.txt && python app.py` → http://127.0.0.1:5000
Set `SECRET_KEY` in the environment for any non-local use.
Demo logins (Full name / Role / Staff ID / Department ID): Ana Reyes / Admin / 1 / 1 · Ben Cruz / Staff / 2 / 2

## Production on the shared EC2 host

This is a **synthetic demonstration**: the deterministic `seed()` generates
fictional records. The application keeps its existing native SQLite engine;
it does not use MySQL/RDS or another project's database.

Install the complete pinned `requirements.txt` with Linux CPython 3.14.4.
Production service environment (stored privately outside releases):

- `APP_ENV=production`, `FLASK_DEBUG=0`.
- `SECRET_KEY`: a persistent, independently generated secret of at least 32 characters.
- `DATABASE`: absolute external writable SQLite path, such as
  `/var/lib/kc-hospital/kacchan.sqlite3`, owned by this app's dedicated service user.
- `STAFF_PASSWORD_HASH_1`, `STAFF_PASSWORD_HASH_2`, `STAFF_PASSWORD_HASH_3`,
  `STAFF_PASSWORD_HASH_4`: separate Werkzeug `generate_password_hash()` values
  for independently generated private passwords. Use the default scrypt method.
  Keep clear passwords in private credential storage for the authorized users;
  do not put passwords or hashes in Git, artifacts, workflow output, or public pages.

Existing synthetic staff identities are Ana Reyes / Admin / 1 / 1, Ben Cruz /
Staff / 2 / 2, Carla Dizon / Staff / 3 / 3, and Dan Lopez / Admin / 4 / 7.
Production requires both matching identity details and that person's password.
Password fields never repopulate on failure. Changing a person's configured hash
invalidates their previous sessions; keep `SECRET_KEY` stable between releases.
Protected staff/admin routes and patient creation require an authenticated session
and existing role checks. Public home/about/contact remain demonstration pages.

After creating the dedicated private parent directory and loading the production
environment, initialize **once** from `deploy/site`:

```sh
python3 -m flask --app app init-demo-db --confirm-synthetic
```

The initializer exclusively creates a new file (mode 0600 on Linux), refuses any
existing file, and uses the existing explicitly fictional seed. Production imports
never initialize, migrate or seed a database. Failed initialization leaves its file
for private inspection rather than automatically overwriting it. Protect database
and SQLite journal files through directory ownership and a restrictive service umask.

Start from repository root (port is a proposal; first verify availability):

```sh
python3 -m gunicorn --chdir deploy/site app:app --bind 127.0.0.1:8135 --workers 2 --threads 2 --timeout 60 --access-logfile - --error-logfile -
```

Nginx terminates HTTPS, proxies only to the loopback listener, and overwrites
`X-Forwarded-Proto` with its own `$scheme`. Production trusts exactly one proxy for
that header and uses Secure, HttpOnly, SameSite=Lax session cookies with an eight-hour
session lifetime. Redirect public HTTP to HTTPS; consider a proxy login rate limit.
Static files remain under `deploy/site/static/` and can be served by Flask or Nginx.

`GET /health/` opens the external DB in read-only mode, checks SQLite integrity and
required columns, and returns only `{"status":"ok"}` or a generic 503. It does not
create a missing database, expose records or set a session cookie.

Artifacts must contain only app source, templates, static assets, schema and locked
runtime dependencies. **Exclude `deploy/site/kacchan.db`, all SQLite files/journals,
private environments, and test outputs**; `.gitattributes` excludes the committed DB
from Git export archives, and any custom tar/zip packager must also exclude it.
Retain the same external `DATABASE` for application updates and rollbacks. Back up
SQLite using its online backup API or `sqlite3 .backup`, preserving private storage;
copying a live SQLite file without its journals is not a consistent backup method.

Run isolated tests from repository root:

```sh
python3 -m unittest discover -s deploy/site -p test_production.py
```

Tests create only temporary synthetic SQLite data and inert password hashes. A
matching Linux Gunicorn startup, private host permission check, public HTTPS check
and authorized staff login remain required production validation.
