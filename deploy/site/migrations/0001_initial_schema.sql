-- One-time additive MySQL 8 baseline for 2026_3dsa_6_kchospital only.
-- Selected schema and emptiness are asserted by bootstrap_mysql.py.
-- No database creation, schema switching, data import or destructive statements.
CREATE TABLE department (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE staff (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(255) NOT NULL,
  role ENUM('Staff','Admin') NOT NULL,
  department_id INT UNSIGNED NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  FOREIGN KEY (department_id) REFERENCES department(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE patient (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(32) UNIQUE,
  full_name VARCHAR(255) NOT NULL,
  birthdate DATE NOT NULL,
  sex VARCHAR(20),
  contact VARCHAR(32) NOT NULL,
  insurance VARCHAR(80),
  created_by INT UNSIGNED,
  archived BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_patient_identity (full_name,birthdate),
  FOREIGN KEY (created_by) REFERENCES staff(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE visit (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  patient_id INT UNSIGNED NOT NULL,
  department_id INT UNSIGNED NOT NULL,
  visit_date DATE NOT NULL,
  wait_min INT,
  stay_hours DECIMAL(8,1),
  diagnosis VARCHAR(100),
  readmitted BOOLEAN NOT NULL DEFAULT FALSE,
  FOREIGN KEY (patient_id) REFERENCES patient(id),
  FOREIGN KEY (department_id) REFERENCES department(id),
  INDEX idx_visit_date_department (visit_date,department_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE appointment (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  patient_id INT UNSIGNED NOT NULL,
  staff_id INT UNSIGNED,
  appt_date DATE NOT NULL,
  type ENUM('Treatment','Diagnosis'),
  status ENUM('Completed','Scheduled','Cancelled','No-show'),
  FOREIGN KEY (patient_id) REFERENCES patient(id),
  FOREIGN KEY (staff_id) REFERENCES staff(id),
  INDEX idx_appointment_date (appt_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE treatment (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  visit_id INT UNSIGNED NOT NULL,
  name VARCHAR(100) NOT NULL,
  status ENUM('Completed','Partially Completed','On Hold','Failed'),
  FOREIGN KEY (visit_id) REFERENCES visit(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE invoice (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  patient_id INT UNSIGNED NOT NULL,
  visit_id INT UNSIGNED,
  amount DECIMAL(12,2) NOT NULL CHECK(amount>=0),
  paid DECIMAL(12,2) NOT NULL DEFAULT 0,
  issued DATE NOT NULL,
  FOREIGN KEY (patient_id) REFERENCES patient(id),
  FOREIGN KEY (visit_id) REFERENCES visit(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE vendor_bill (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  vendor VARCHAR(255) NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  paid DECIMAL(12,2) NOT NULL DEFAULT 0,
  issued DATE NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE supply (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  category VARCHAR(100),
  stock INT NOT NULL,
  reorder_level INT NOT NULL,
  unit_cost DECIMAL(12,2)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE audit_log (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  staff_id INT UNSIGNED,
  action VARCHAR(100),
  detail VARCHAR(500),
  at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (staff_id) REFERENCES staff(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
