CREATE TABLE IF NOT EXISTS department(id INTEGER PRIMARY KEY, name TEXT UNIQUE NOT NULL);
CREATE TABLE IF NOT EXISTS staff(id INTEGER PRIMARY KEY, full_name TEXT NOT NULL, role TEXT NOT NULL CHECK(role IN('Staff','Admin')),
  department_id INTEGER NOT NULL REFERENCES department(id), active INTEGER DEFAULT 1);
CREATE TABLE IF NOT EXISTS patient(id INTEGER PRIMARY KEY, code TEXT UNIQUE, full_name TEXT NOT NULL, birthdate TEXT NOT NULL, sex TEXT,
  contact TEXT NOT NULL, insurance TEXT, created_by INTEGER REFERENCES staff(id), archived INTEGER DEFAULT 0,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP, UNIQUE(full_name,birthdate));
CREATE TABLE IF NOT EXISTS visit(id INTEGER PRIMARY KEY, patient_id INTEGER NOT NULL REFERENCES patient(id), department_id INTEGER NOT NULL REFERENCES department(id),
  visit_date TEXT NOT NULL, wait_min INTEGER, stay_hours REAL, diagnosis TEXT, readmitted INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS appointment(id INTEGER PRIMARY KEY, patient_id INTEGER NOT NULL REFERENCES patient(id), staff_id INTEGER REFERENCES staff(id),
  appt_date TEXT NOT NULL, type TEXT CHECK(type IN('Treatment','Diagnosis')), status TEXT CHECK(status IN('Completed','Scheduled','Cancelled','No-show')));
CREATE TABLE IF NOT EXISTS treatment(id INTEGER PRIMARY KEY, visit_id INTEGER NOT NULL REFERENCES visit(id), name TEXT NOT NULL,
  status TEXT CHECK(status IN('Completed','Partially Completed','On Hold','Failed')));
CREATE TABLE IF NOT EXISTS invoice(id INTEGER PRIMARY KEY, patient_id INTEGER NOT NULL REFERENCES patient(id), visit_id INTEGER REFERENCES visit(id),
  amount REAL NOT NULL CHECK(amount>=0), paid REAL NOT NULL DEFAULT 0, issued TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS vendor_bill(id INTEGER PRIMARY KEY, vendor TEXT NOT NULL, amount REAL NOT NULL, paid REAL NOT NULL DEFAULT 0, issued TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS supply(id INTEGER PRIMARY KEY, name TEXT NOT NULL, category TEXT, stock INTEGER NOT NULL, reorder_level INTEGER NOT NULL, unit_cost REAL);
CREATE TABLE IF NOT EXISTS audit_log(id INTEGER PRIMARY KEY, staff_id INTEGER, action TEXT, detail TEXT, at TEXT DEFAULT CURRENT_TIMESTAMP);
