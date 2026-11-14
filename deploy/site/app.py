import os, re, sqlite3, random, secrets
from datetime import date, datetime, timedelta
from functools import wraps
from flask import Flask, g, render_template, request, redirect, url_for, session, flash, abort

app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", "dev-change-me")
app.config.update(SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE="Lax")
DB = os.environ.get("DATABASE", os.path.join(os.path.dirname(__file__), "kacchan.db"))

def db():
    if "db" not in g:
        g.db = sqlite3.connect(DB); g.db.row_factory = sqlite3.Row
        g.db.execute("PRAGMA foreign_keys=ON")
    return g.db
@app.teardown_appcontext
def close(_):
    d = g.pop("db", None)
    if d: d.close()

def init_db():
    c = sqlite3.connect(DB)
    c.executescript(open(os.path.join(os.path.dirname(__file__), "schema.sql")).read())
    if c.execute("SELECT COUNT(*) FROM patient").fetchone()[0] == 0:
        seed(c)
    c.commit(); c.close()

def seed(c):  # fictional sample data only
    r = random.Random(7)
    depts = ["Cardiology","Respiratory","Neurology","Gastroenterology","Dermatology","Orthopedics","Emergency","Pediatrics"]
    for d in depts: c.execute("INSERT INTO department(name) VALUES(?)", (d,))
    for n, role, d in [("Ana Reyes","Admin",1),("Ben Cruz","Staff",2),("Carla Dizon","Staff",3),("Dan Lopez","Admin",7)]:
        c.execute("INSERT INTO staff(full_name,role,department_id) VALUES(?,?,?)", (n, role, d))
    first = ["Mia","Leo","Ivy","Noel","Tess","Raf","Joy","Kai","Lena","Omar","Pia","Sam"]; last = ["Santos","Garcia","Tan","Lim","Bautista","Aquino","Ramos","Flores","Mendoza","Navarro"]
    dx = ["Renal","Psych","Addict","Oral","Allgy","Trauma","Urinary","Cardiac","Resp","Derm","Ortho","Neuro"]
    dxw = [600,550,470,455,425,372,340,250,225,140,120,110]
    tx = ["Cardio","Respir","Neuro","Gastro","Derma","Ortho","Onco","Renal"]
    for i in range(400):
        by = r.choice([2015,2008,1995,1985,1975,1960,1950,1990,2000])
        nm = f"{r.choice(first)} {r.choice('ABCDEFGHJKLMNPRST')}. {r.choice(last)} {i}"
        c.execute("INSERT INTO patient(code,full_name,birthdate,sex,contact,insurance,created_by) VALUES(?,?,?,?,?,?,1)",
          (f"PT-{i+1:06d}", nm, f"{by-r.randint(0,9)}-{r.randint(1,12):02d}-{r.randint(1,28):02d}", r.choice(["Male","Male","Female","Female","Female"]),
           "09"+"".join(r.choice("0123456789") for _ in range(9)), r.choice(["PhilHealth","Maxicare","Intellicare","None"])))
    for i in range(1500):
        d = date(2026,1,1)+timedelta(days=r.randint(0,300)); pid = r.randint(1,400)
        c.execute("INSERT INTO visit(patient_id,department_id,visit_date,wait_min,stay_hours,diagnosis,readmitted) VALUES(?,?,?,?,?,?,?)",
          (pid, r.randint(1,8), d.isoformat(), r.randint(3,25), round(r.uniform(.5,72),1), r.choices(dx,dxw)[0], int(r.random()<.067)))
        vid = c.execute("SELECT last_insert_rowid()").fetchone()[0]
        if r.random()<.7: c.execute("INSERT INTO treatment(visit_id,name,status) VALUES(?,?,?)", (vid, r.choices(tx,[9,8,6,5,4,3,2,1])[0], r.choices(["Completed","Partially Completed","On Hold","Failed"],[5,3,2,1])[0]))
        amt = round(r.uniform(500,25000),2)
        c.execute("INSERT INTO invoice(patient_id,visit_id,amount,paid,issued) VALUES(?,?,?,?,?)", (pid, vid, amt, amt if r.random()<.75 else round(amt*r.random(),2), d.isoformat()))
        c.execute("INSERT INTO appointment(patient_id,staff_id,appt_date,type,status) VALUES(?,?,?,?,?)", (pid, r.randint(1,4), d.isoformat(), r.choice(["Treatment","Diagnosis","Diagnosis"]),
          r.choices(["Completed","Scheduled","Cancelled","No-show"],[80,8,6,6])[0]))
    for v in ["MedSupply Co.","PharmaOne","SteriCare","BioEquip"]:
        for m in range(1,10):
            a = round(r.uniform(20000,90000),2); c.execute("INSERT INTO vendor_bill(vendor,amount,paid,issued) VALUES(?,?,?,?)", (v,a,a if r.random()<.7 else 0,f"2026-{m:02d}-15"))
    for n,cat in [("Gloves (box)","Consumables"),("Syringes 5ml","Consumables"),("IV Sets","Consumables"),("Paracetamol 500mg","Pharmacy"),("Amoxicillin 500mg","Pharmacy"),("Surgical Masks","PPE"),("Gauze Rolls","Consumables"),("Oxygen Tanks","Equipment"),("Saline 1L","Pharmacy"),("Wheelchairs","Equipment")]:
        lv = r.randint(30,120); c.execute("INSERT INTO supply(name,category,stock,reorder_level,unit_cost) VALUES(?,?,?,?,?)", (n,cat,r.randint(5,400),lv,round(r.uniform(10,900),2)))

def audit(action, detail=""):
    db().execute("INSERT INTO audit_log(staff_id,action,detail) VALUES(?,?,?)", (session.get("uid"), action, detail)); db().commit()

def login_required(admin=False):
    def deco(f):
        @wraps(f)
        def w(*a, **k):
            if "uid" not in session:
                flash("Please log in with your staff credentials first.", "err"); return redirect(url_for("login", next=request.path))
            if admin and session.get("role") != "Admin": abort(403)
            return f(*a, **k)
        return w
    return deco

@app.before_request
def csrf():
    session.setdefault("csrf", secrets.token_hex(16))
    if request.method == "POST" and request.form.get("csrf") != session["csrf"]: abort(400)
@app.context_processor
def ctx(): return dict(csrf=session.get("csrf"), user=session.get("name"), role=session.get("role"))
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
    if len(name) < 3 or not re.fullmatch(r"[A-Za-zÀ-ÿ.\-' ]+", name): errs["full_name"] = "Enter a valid full name."
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
                cur = db().execute("INSERT INTO patient(full_name,birthdate,contact,insurance,created_by) VALUES(?,?,?,?,?)",
                    (name, bd.isoformat(), ct, form.get("insurance", "").strip()[:80] or "None", session["uid"]))
                db().execute("UPDATE patient SET code=? WHERE id=?", (f"PT-{cur.lastrowid:06d}", cur.lastrowid)); db().commit()
                audit("patient_created", f"PT-{cur.lastrowid:06d}")
                flash(f"Record saved. Patient ID: PT-{cur.lastrowid:06d}", "ok"); return redirect(request.form.get("back") or url_for("add_patient"))
            except sqlite3.IntegrityError:
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
    w, p = ["strftime('%Y',v.visit_date)=?"], [year]
    if month != "All" and month.isdigit(): w.append("strftime('%m',v.visit_date)=?"); p.append(f"{int(month):02d}")
    if dept != "All" and dept.isdigit(): w.append("v.department_id=?"); p.append(int(dept))
    W = " AND ".join(w); q = lambda s, *x: db().execute(s, p + list(x)).fetchall(); s1 = lambda s: (db().execute(s, p).fetchone()[0] or 0)
    d = dict(view=view, year=year, month=month, dept=dept, depts=db().execute("SELECT * FROM department").fetchall())
    d.update(visits=s1(f"SELECT COUNT(*) FROM visit v WHERE {W}"), wait=round(s1(f"SELECT AVG(wait_min) FROM visit v WHERE {W}")),
      los=round(s1(f"SELECT AVG(stay_hours) FROM visit v WHERE {W}"), 1), readm=round(100*s1(f"SELECT AVG(readmitted) FROM visit v WHERE {W}"), 1),
      noshow=round(100*one("SELECT AVG(status IN('Cancelled','No-show')) FROM appointment WHERE strftime('%Y',appt_date)=?", year), 1),
      comp=round(100*s1(f"SELECT AVG(t.status='Completed') FROM treatment t JOIN visit v ON v.id=t.visit_id WHERE {W}")),
      ar=s1(f"SELECT SUM(i.amount-i.paid) FROM invoice i JOIN visit v ON v.id=i.visit_id WHERE {W}"), ap=one("SELECT SUM(amount-paid) FROM vendor_bill"))
    d["sex"] = {r[0]: r[1] for r in q(f"SELECT p.sex,COUNT(*) FROM visit v JOIN patient p ON p.id=v.patient_id WHERE {W} GROUP BY 1")}
    d["dx"] = [tuple(r) for r in q(f"SELECT diagnosis,COUNT(*) c FROM visit v WHERE {W} GROUP BY 1 ORDER BY c DESC")]
    d["trend"] = [tuple(r) for r in q(f"SELECT strftime('%m',visit_date),COUNT(*) FROM visit v WHERE {W} GROUP BY 1 ORDER BY 1")]
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
        d["monthly"] = [(r[0], round(r[1])) for r in q(f"SELECT strftime('%m',v.visit_date),SUM(i.amount) FROM invoice i JOIN visit v ON v.id=i.visit_id WHERE {W} GROUP BY 1 ORDER BY 1")]
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

@app.route("/login", methods=["GET", "POST"])
def login():
    f = request.form if request.method == "POST" else {}
    if request.method == "POST":
        row = db().execute("SELECT * FROM staff WHERE id=? AND department_id=? AND role=? AND lower(full_name)=lower(?) AND active=1",
            (f.get("staff_id", "").strip() or 0, f.get("department_id", "").strip() or 0, f.get("role", "").strip().title(), " ".join(f.get("full_name", "").split()))).fetchone() \
            if f.get("staff_id", "").strip().isdigit() and f.get("department_id", "").strip().isdigit() else None
        if row:
            session.clear(); session.update(uid=row["id"], name=row["full_name"], role=row["role"], csrf=secrets.token_hex(16)); audit("login")
            nxt = request.args.get("next", ""); return redirect(nxt if nxt.startswith("/") and not nxt.startswith("//") else url_for("dashboard"))
        flash("Those details do not match an active staff account.", "err")
    return render_template("login.html", form=f, page="login")

@app.route("/logout", methods=["POST"])
def logout(): session.clear(); flash("You have been logged out.", "ok"); return redirect(url_for("home"))

init_db()
if __name__ == "__main__": app.run(debug=os.environ.get("FLASK_DEBUG") == "1")
