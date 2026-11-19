import os, re, secrets, hashlib
import pymysql
from mysql_store import Database, SCHEMA, connection_options, verify_schema
from pathlib import Path
from contextlib import closing
import click
from werkzeug.middleware.proxy_fix import ProxyFix
from werkzeug.security import check_password_hash
from datetime import date, datetime, timedelta
from functools import wraps
from flask import Flask, g, render_template, request, redirect, url_for, session, flash, abort

app = Flask(__name__, root_path=str(Path(__file__).resolve().parent))
PRODUCTION = os.environ.get('APP_ENV') == 'production'
app.secret_key = os.environ.get("SECRET_KEY", "dev-change-me")
app.config.update(SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE="Lax",
                  SESSION_COOKIE_SECURE=PRODUCTION, PERMANENT_SESSION_LIFETIME=timedelta(hours=8))
STAFF_PASSWORD_HASHES = {str(i): os.environ.get(f'STAFF_PASSWORD_HASH_{i}', '') for i in range(1, 5)}
if PRODUCTION:
    if len(app.secret_key) < 32:
        raise RuntimeError('Production SECRET_KEY must contain at least 32 characters.')
    connection_options()  # Validate schema, private credentials and TLS without connecting.
    if any(not value.startswith(('scrypt:', 'pbkdf2:')) or value.count('$') != 2
           for value in STAFF_PASSWORD_HASHES.values()):
        raise RuntimeError('Configure individual Werkzeug STAFF_PASSWORD_HASH_1 through _4 values.')
    # One trusted loopback Nginx proxy; it must overwrite X-Forwarded-Proto.
    app.wsgi_app = ProxyFix(app.wsgi_app, x_proto=1)


def db():
    if "db" not in g:
        g.db = Database()
    return g.db


@app.teardown_appcontext
def close(_):
    connection = g.pop("db", None)
    if connection:
        connection.close()


@app.cli.command('seed-demo-data')
@click.option('--confirm-schema', required=True, type=click.Choice([SCHEMA]))
@click.option('--confirm-synthetic', is_flag=True, required=True)
def seed_demo_data(confirm_schema, confirm_synthetic):
    """Populate an initialized but completely empty project schema, once."""
    if not confirm_synthetic:
        raise click.ClickException('Explicit synthetic confirmation is required.')
    from bootstrap_mysql import seed_database
    with closing(Database('BOOTSTRAP_DB_')) as connection:
        seed_database(connection)
    click.echo('Seeded explicitly synthetic demo data in the confirmed project MySQL schema.')


def audit(action, detail=""):
    db().execute("INSERT INTO audit_log(staff_id,action,detail) VALUES(%s,%s,%s)", (session.get("uid"), action, detail)); db().commit()

def login_required(admin=False):
    def deco(f):
        @wraps(f)
        def w(*a, **k):
            expected = STAFF_PASSWORD_HASHES.get(str(session.get('uid')), '')
            authenticated = not PRODUCTION or (expected and secrets.compare_digest(
                session.get('auth_version', ''), hashlib.sha256(expected.encode()).hexdigest()))
            if "uid" not in session or not authenticated:
                flash("Please log in with your staff credentials first.", "err"); return redirect(url_for("login", next=request.path))
            if admin and session.get("role") != "Admin": abort(403)
            return f(*a, **k)
        return w
    return deco

@app.before_request
def csrf():
    if request.endpoint == 'health':
        return
    session.setdefault("csrf", secrets.token_hex(16))
    if request.method == "POST" and request.form.get("csrf") != session["csrf"]: abort(400)
@app.context_processor
def ctx(): return dict(csrf=session.get("csrf"), user=session.get("name"), role=session.get("role"), production=PRODUCTION)
@app.errorhandler(403)
def e403(e): return render_template("msg.html", title="Admin access only", text="Your role does not have access to this page."), 403
@app.errorhandler(404)
def e404(e): return render_template("msg.html", title="Page not found", text="That page does not exist."), 404

def one(sql, *a): return db().execute(sql, a).fetchone()[0] or 0
def money(v): return f"${v:,.2f}"
app.jinja_env.filters["money"] = money

def kpis():
    return dict(visits=one("SELECT COUNT(*) FROM visit"), wait=round(one("SELECT AVG(wait_min) FROM visit")),
      noshow=round(100*one("SELECT AVG(status IN('Cancelled','No-show')) FROM appointment"),1),
      ar=one("SELECT SUM(amount-paid) FROM invoice"), ap=one("SELECT SUM(amount-paid) FROM vendor_bill"))

@app.route("/")
def home():
    k = kpis()
    dx = [(r[0], r[1]) for r in db().execute("SELECT diagnosis,COUNT(*) c FROM visit GROUP BY 1 ORDER BY c DESC")]
    fin = [(r[0], round(r[1])) for r in db().execute("SELECT substr(issued,6,2),SUM(amount) FROM invoice GROUP BY 1 ORDER BY 1")]
    ap = [(r[0], r[1]) for r in db().execute("SELECT status,COUNT(*) FROM appointment GROUP BY 1 ORDER BY 2 DESC")]
    inv = [(r[0][:7], r[1]) for r in db().execute("SELECT name,stock FROM supply ORDER BY stock DESC")]
    return render_template("home.html", k=k, tabs=[("Overview", dx), ("Finance", fin), ("Appointments", ap), ("Inventory", inv)], page="home")

def parse_patient(f):
    errs = {}; name = " ".join(f.get("full_name", "").split())
    if not 3 <= len(name) <= 255 or not re.fullmatch(r"[A-Za-zÀ-ÿ.\-' ]+", name): errs["full_name"] = "Enter a valid full name (3–255 characters)."
    try:
        bd = datetime.strptime(f.get("birthdate", "").strip(), "%m/%d/%Y").date()
        if bd > date.today() or bd.year < 1900: raise ValueError
    except ValueError: bd = None; errs["birthdate"] = "Use MM/DD/YYYY (a past date)."
    ct = re.sub(r"[\s\-]", "", f.get("contact", ""))
    if not re.fullmatch(r"09\d{9}", ct): errs["contact"] = "Use format 09XX XXX XXXX."
    return errs, name, bd, ct

@app.route("/add-patient", methods=["GET", "POST"])
@login_required()
def add_patient():
    form = request.form if request.method == "POST" else {}; errs = {}
    if request.method == "POST":
        errs, name, bd, ct = parse_patient(form)
        if not errs:
            try:
                cur = db().execute("INSERT INTO patient(full_name,birthdate,contact,insurance,created_by) VALUES(%s,%s,%s,%s,%s)",
                    (name, bd.isoformat(), ct, form.get("insurance", "").strip()[:80] or "None", session["uid"]))
                db().execute("UPDATE patient SET code=%s WHERE id=%s", (f"PT-{cur.lastrowid:06d}", cur.lastrowid)); db().commit()
                audit("patient_created", f"PT-{cur.lastrowid:06d}")
                flash(f"Record saved. Patient ID: PT-{cur.lastrowid:06d}", "ok"); return redirect(request.form.get("back") or url_for("add_patient"))
            except pymysql.IntegrityError:
                db().rollback()
                errs["full_name"] = "A patient with this name and birthdate already exists."
        flash("Please fix the highlighted fields.", "err")
    return render_template("add_patient.html", form=form, errs=errs, page="add")

@app.route("/dashboard")
@login_required()
def dashboard():
    view = request.args.get("view", "overview")
    if view not in ("overview", "finance", "operations", "inventory", "treatment"): abort(404)
    if view in ("finance", "inventory") and session["role"] != "Admin": abort(403)
    year = request.args.get("year", "2026"); month = request.args.get("month", "All"); dept = request.args.get("dept", "All")
    w, p = ["LEFT(v.visit_date,4)=%s"], [year]
    if month != "All" and month.isdigit(): w.append("SUBSTRING(v.visit_date,6,2)=%s"); p.append(f"{int(month):02d}")
    if dept != "All" and dept.isdigit(): w.append("v.department_id=%s"); p.append(int(dept))
    W = " AND ".join(w); q = lambda s, *x: db().execute(s, p + list(x)).fetchall(); s1 = lambda s: (db().execute(s, p).fetchone()[0] or 0)
    d = dict(view=view, year=year, month=month, dept=dept, depts=db().execute("SELECT * FROM department").fetchall())
    d.update(visits=s1(f"SELECT COUNT(*) FROM visit v WHERE {W}"), wait=round(s1(f"SELECT AVG(wait_min) FROM visit v WHERE {W}")),
      los=round(s1(f"SELECT AVG(stay_hours) FROM visit v WHERE {W}"), 1), readm=round(100*s1(f"SELECT AVG(readmitted) FROM visit v WHERE {W}"), 1),
      noshow=round(100*one("SELECT AVG(status IN('Cancelled','No-show')) FROM appointment WHERE LEFT(appt_date,4)=%s", year), 1),
      comp=round(100*s1(f"SELECT AVG(t.status='Completed') FROM treatment t JOIN visit v ON v.id=t.visit_id WHERE {W}")),
      ar=s1(f"SELECT SUM(i.amount-i.paid) FROM invoice i JOIN visit v ON v.id=i.visit_id WHERE {W}"), ap=one("SELECT SUM(amount-paid) FROM vendor_bill"))
    d["sex"] = {r[0]: r[1] for r in q(f"SELECT p.sex,COUNT(*) FROM visit v JOIN patient p ON p.id=v.patient_id WHERE {W} GROUP BY 1")}
    d["dx"] = [tuple(r) for r in q(f"SELECT diagnosis,COUNT(*) c FROM visit v WHERE {W} GROUP BY 1 ORDER BY c DESC")]
    d["trend"] = [tuple(r) for r in q(f"SELECT SUBSTRING(visit_date,6,2),COUNT(*) FROM visit v WHERE {W} GROUP BY 1 ORDER BY 1")]
    d["appt"] = {r[0]: r[1] for r in db().execute("SELECT type,COUNT(*) FROM appointment GROUP BY 1")}
    tr = {}
    for n, s, c in q(f"SELECT t.name,t.status,COUNT(*) FROM treatment t JOIN visit v ON v.id=t.visit_id WHERE {W} GROUP BY 1,2"): tr.setdefault(n, {})[s] = c
    order = ["Completed", "Partially Completed", "On Hold", "Failed"]
    d["treat"] = sorted([(n, [m.get(s, 0) for s in order]) for n, m in tr.items()], key=lambda x: -sum(x[1]))
    ages = [0, 0, 0, 0, 0]
    for (bd,) in q(f"SELECT p.birthdate FROM visit v JOIN patient p ON p.id=v.patient_id WHERE {W}"):
        a = int(year) - int(bd[:4]); ages[0 if a < 13 else 1 if a < 18 else 2 if a < 40 else 3 if a < 60 else 4] += 1
    d["ages"] = list(zip(["Child 0-12", "Teen 13-17", "Adult 18-39", "Age 40-59", "Senior 60+"], ages))
    if view == "finance":
        d["monthly"] = [(r[0], round(r[1])) for r in q(f"SELECT SUBSTRING(v.visit_date,6,2),SUM(i.amount) FROM invoice i JOIN visit v ON v.id=i.visit_id WHERE {W} GROUP BY 1 ORDER BY 1")]
        d["vendors"] = db().execute("SELECT vendor,SUM(amount) a,SUM(amount-paid) o FROM vendor_bill GROUP BY 1").fetchall()
    if view == "inventory": d["supplies"] = db().execute("SELECT * FROM supply ORDER BY stock*1.0/reorder_level").fetchall()
    if view == "operations":
        d["byDept"] = [tuple(r) for r in q(f"SELECT d.name,COUNT(*) FROM visit v JOIN department d ON d.id=v.department_id WHERE {W} GROUP BY 1 ORDER BY 2 DESC")]
        d["astat"] = [tuple(r) for r in db().execute("SELECT status,COUNT(*) FROM appointment GROUP BY 1 ORDER BY 2 DESC")]
    return render_template("dashboard.html", d=d, page="dash")

@app.route("/about")
def about(): return render_template("about.html", page="about")
@app.route("/contact")
def contact(): return render_template("contact.html", page="contact")


@app.get('/health/')
def health():
    """Read-only database readiness without returning records or counts."""
    try:
        with closing(Database()) as connection:
            connection.execute('START TRANSACTION READ ONLY')
            verify_schema(connection)
        return {'status': 'ok'}
    except (pymysql.Error, RuntimeError):
        return {'status': 'database_unavailable'}, 503

@app.route("/login", methods=["GET", "POST"])
def login():
    f = request.form if request.method == "POST" else {}
    if request.method == "POST":
        row = db().execute("SELECT * FROM staff WHERE id=%s AND department_id=%s AND role=%s AND lower(full_name)=lower(%s) AND active=1",
            (f.get("staff_id", "").strip() or 0, f.get("department_id", "").strip() or 0, f.get("role", "").strip().title(), " ".join(f.get("full_name", "").split()))).fetchone() \
            if f.get("staff_id", "").strip().isdigit() and f.get("department_id", "").strip().isdigit() else None
        password_hash = STAFF_PASSWORD_HASHES.get(str(row['id']), '') if row else ''
        verified = not PRODUCTION or (password_hash and check_password_hash(password_hash, f.get('password', '')))
        if row and verified:
            session.clear(); session.update(uid=row["id"], name=row["full_name"], role=row["role"], csrf=secrets.token_hex(16))
            if PRODUCTION:
                session['auth_version'] = hashlib.sha256(password_hash.encode()).hexdigest()
                session.permanent = True
            audit("login")
            nxt = request.args.get("next", ""); return redirect(nxt if nxt.startswith("/") and not nxt.startswith("//") else url_for("dashboard"))
        flash("Those details do not match an active staff account.", "err")
    return render_template("login.html", form=f, page="login")

@app.route("/logout", methods=["POST"])
def logout(): session.clear(); flash("You have been logged out.", "ok"); return redirect(url_for("home"))

if __name__ == "__main__": app.run(debug=os.environ.get("FLASK_DEBUG") == "1")
