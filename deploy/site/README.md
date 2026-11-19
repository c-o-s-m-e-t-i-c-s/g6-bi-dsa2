# Kacchan Care Hospital production runtime

Flask + MySQL 8 on the existing shared RDS server. The exact project schema is
`2026_3dsa_6_kchospital`; other projects and schemas are outside scope. The old
committed SQLite file is excluded from artifacts and is never opened by this app.
Application import never connects, initializes, migrates or seeds a database.

## Runtime and private configuration

Install the fully pinned `deploy/site/requirements.txt` with Linux CPython 3.14.4.
Store private configuration outside release directories:

- `APP_ENV=production`, `FLASK_DEBUG=0`.
- `SECRET_KEY`: persistent independently generated secret, at least 32 characters.
- `DB_HOST`: the actual RDS DNS endpoint; `DB_PORT=3306`.
- `DB_NAME=2026_3dsa_6_kchospital`, `DB_USER`, `DB_PASSWORD`.
- `DB_SSL_CA`: private trusted RDS CA bundle path. Remote production connections
  require this; PyMySQL verifies the certificate chain and endpoint hostname.
- `STAFF_PASSWORD_HASH_1` through `STAFF_PASSWORD_HASH_4`: individual Werkzeug
  `generate_password_hash()` values for four independently generated passwords.
  Use its default scrypt method; keep clear passwords in private credential storage.

`DATABASE` and SQLite paths are no longer used. Runtime account grants are SELECT
on `department`, `staff`, `patient`, `visit`, `appointment`, `treatment`, `invoice`,
`vendor_bill`, `supply`, and `audit_log`; INSERT on `patient` and `audit_log`;
UPDATE of only `patient.code`. Grant no DDL, DELETE, grant management, or cross-schema
permissions. Use fully qualified table names when provisioning grants. Database
names contain underscores: verify MySQL `partial_revokes`, escaped wildcard
behavior, actual grants and active roles before using schema-level grants.

Existing synthetic identities: Ana Reyes / Admin / 1 / 1, Ben Cruz / Staff / 2 / 2,
Carla Dizon / Staff / 3 / 3, Dan Lopez / Admin / 4 / 7 (name / role / ID / department).
Production login also requires that individual's private password. Changing a
configured hash invalidates that person's old sessions. Role restrictions and
CSRF protections cover staff/admin pages and patient creation. Public pages show
only the existing demonstration reports. These records are explicitly fictional.

Start from repository root after verifying the proposed port is unused:

```sh
python3 -m gunicorn --chdir deploy/site app:app --bind 127.0.0.1:8135 --workers 2 --threads 2 --timeout 60 --access-logfile - --error-logfile -
```

Nginx terminates HTTPS and overwrites `X-Forwarded-Proto` using its own `$scheme`.
The app trusts exactly that one proxy for the scheme. Keep Gunicorn loopback-only.
Cookies are Secure, HttpOnly, SameSite=Lax with an eight-hour session lifetime.
Redirect public HTTP to HTTPS; configure a proxy login rate limit if appropriate.
Static assets remain in `deploy/site/static/`. DB timeouts: connect 8 seconds,
read 30 seconds and write 20 seconds. Each request closes its MySQL connection.

`GET /health/` starts a read-only transaction, checks `DATABASE()` against the exact
schema and SELECT access to all required table columns using zero-row projections.
It returns only `{"status":"ok"}` or a generic 503 and sets no session cookie.
It needs the baseline but no synthetic records; login needs the seeded staff rows.

## Explicit one-time RDS baseline and optional synthetic seed

`migrations/0001_initial_schema.sql` contains ten additive MySQL 8 InnoDB CREATE TABLE
statements. The paired `.verify.sql` contains read-only column checks. Neither
creates/selects/drops a database or inserts records. Review their exact digests
independently before application. Save a verified private backup of this exact
schema before DDL. `bootstrap_mysql.py` requires the existing schema to be completely
empty, refuses a rerun and verifies columns afterwards. MySQL DDL may partially
apply on failure: stop and reconcile privately; do not automatically retry/reset.

Use a separate temporary bootstrap identity, restricted to this schema. It requires
CREATE and REFERENCES for this baseline, SELECT for preflight/verification and
INSERT on the ten tables for seeding. Runtime credentials cannot execute bootstrap.
Never store an administrator credential in the application environment.

From `deploy/site`, load only private `BOOTSTRAP_DB_HOST`, `BOOTSTRAP_DB_PORT`,
`BOOTSTRAP_DB_NAME=2026_3dsa_6_kchospital`, `BOOTSTRAP_DB_USER`,
`BOOTSTRAP_DB_PASSWORD`, `BOOTSTRAP_DB_SSL_CA`, and `APP_ENV=production`:

```sh
python3 bootstrap_mysql.py schema --confirm-schema 2026_3dsa_6_kchospital
python3 bootstrap_mysql.py verify --confirm-schema 2026_3dsa_6_kchospital
# Optional, explicitly requested fictional demonstration population:
python3 bootstrap_mysql.py seed --confirm-schema 2026_3dsa_6_kchospital --confirm-synthetic
```

This standalone script imports no Flask application and requires no staff hashes
or session secret. `seed_data.py` contains the preexisting deterministic fictional
seed: 400 patients, 1,500 visits, four staff and related demonstration records.
The guarded seed takes a named MySQL lock, refuses any existing records or reused
ID counters, and commits all records together or rolls back. Failed attempts may
advance auto-increment counters; stop for private reconciliation rather than reset.
Do not seed on ordinary deployment or overwrite business records. Remove bootstrap
credentials after this one-time operation; retain only schema-restricted runtime
credentials on the service. Future reviewed additive migrations need their own
approved digests, backup and durable pending/applied history before automation.

Preserve RDS data and the persistent session key across application rollbacks.
Package only app source, templates, static assets, baseline files and locked runtime
dependencies. Exclude committed databases, private environments, caches and reports.
`.gitattributes` excludes the old DB from Git exports; custom packaging must also
exclude all DB files. Application releases do not run source research importers.

## Focused checks and isolated MySQL CI

No external services or credentials are required for the focused tests:

```sh
python3 -m unittest discover -s deploy/site -p 'test_*.py'
```

The nine integration tests skip unless `MYSQL_INTEGRATION_TEST=1`. For CI create a
fresh disposable MySQL 8 service, with an **empty** `2026_3dsa_6_kchospital` schema.
Provide inert DB and bootstrap credentials using `DB_*` and `BOOTSTRAP_DB_*` above,
with host `127.0.0.1`; TLS is required for remote production endpoints, and the
loopback isolated CI service may omit CA. Set `MYSQL_INTEGRATION_TEST=1` and run the
same command. The suite creates the baseline, seeds only fictional data, tests
staff passwords/roles/CSRF, checks all dashboard views, checks refused bootstrap
retries and writes one synthetic patient. It must never point at production or a
persistent schema. Schema creation for the disposable service is CI setup only.
Tests generate their own inert staff hashes and session key; no production secret
is passed to tests. A fresh service is required for each rerun.

After CI passes, verify matching Linux Gunicorn startup, verified RDS TLS and actual
grants, host environment, public HTTPS and authorized staff login separately.
