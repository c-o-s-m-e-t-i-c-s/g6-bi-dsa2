"""Explicitly fictional deterministic demonstration data; never real hospital records."""
import random
from datetime import date, timedelta


def seed(c):  # fictional sample data only
    r = random.Random(7)
    depts = ["Cardiology","Respiratory","Neurology","Gastroenterology","Dermatology","Orthopedics","Emergency","Pediatrics"]
    for d in depts: c.execute("INSERT INTO department(name) VALUES(%s)", (d,))
    for n, role, d in [("Ana Reyes","Admin",1),("Ben Cruz","Staff",2),("Carla Dizon","Staff",3),("Dan Lopez","Admin",7)]:
        c.execute("INSERT INTO staff(full_name,role,department_id) VALUES(%s,%s,%s)", (n, role, d))
    first = ["Mia","Leo","Ivy","Noel","Tess","Raf","Joy","Kai","Lena","Omar","Pia","Sam"]; last = ["Santos","Garcia","Tan","Lim","Bautista","Aquino","Ramos","Flores","Mendoza","Navarro"]
    dx = ["Renal","Psych","Addict","Oral","Allgy","Trauma","Urinary","Cardiac","Resp","Derm","Ortho","Neuro"]
    dxw = [600,550,470,455,425,372,340,250,225,140,120,110]
    tx = ["Cardio","Respir","Neuro","Gastro","Derma","Ortho","Onco","Renal"]
    for i in range(400):
        by = r.choice([2015,2008,1995,1985,1975,1960,1950,1990,2000])
        nm = f"{r.choice(first)} {r.choice('ABCDEFGHJKLMNPRST')}. {r.choice(last)} {i}"
        c.execute("INSERT INTO patient(code,full_name,birthdate,sex,contact,insurance,created_by) VALUES(%s,%s,%s,%s,%s,%s,1)",
          (f"PT-{i+1:06d}", nm, f"{by-r.randint(0,9)}-{r.randint(1,12):02d}-{r.randint(1,28):02d}", r.choice(["Male","Male","Female","Female","Female"]),
           "09"+"".join(r.choice("0123456789") for _ in range(9)), r.choice(["PhilHealth","Maxicare","Intellicare","None"])))
    for i in range(1500):
        d = date(2026,1,1)+timedelta(days=r.randint(0,300)); pid = r.randint(1,400)
        c.execute("INSERT INTO visit(patient_id,department_id,visit_date,wait_min,stay_hours,diagnosis,readmitted) VALUES(%s,%s,%s,%s,%s,%s,%s)",
          (pid, r.randint(1,8), d.isoformat(), r.randint(3,25), round(r.uniform(.5,72),1), r.choices(dx,dxw)[0], int(r.random()<.067)))
        vid = c.execute("SELECT LAST_INSERT_ID()").fetchone()[0]
        if r.random()<.7: c.execute("INSERT INTO treatment(visit_id,name,status) VALUES(%s,%s,%s)", (vid, r.choices(tx,[9,8,6,5,4,3,2,1])[0], r.choices(["Completed","Partially Completed","On Hold","Failed"],[5,3,2,1])[0]))
        amt = round(r.uniform(500,25000),2)
        c.execute("INSERT INTO invoice(patient_id,visit_id,amount,paid,issued) VALUES(%s,%s,%s,%s,%s)", (pid, vid, amt, amt if r.random()<.75 else round(amt*r.random(),2), d.isoformat()))
        c.execute("INSERT INTO appointment(patient_id,staff_id,appt_date,type,status) VALUES(%s,%s,%s,%s,%s)", (pid, r.randint(1,4), d.isoformat(), r.choice(["Treatment","Diagnosis","Diagnosis"]),
          r.choices(["Completed","Scheduled","Cancelled","No-show"],[80,8,6,6])[0]))
    for v in ["MedSupply Co.","PharmaOne","SteriCare","BioEquip"]:
        for m in range(1,10):
            a = round(r.uniform(20000,90000),2); c.execute("INSERT INTO vendor_bill(vendor,amount,paid,issued) VALUES(%s,%s,%s,%s)", (v,a,a if r.random()<.7 else 0,f"2026-{m:02d}-15"))
    for n,cat in [("Gloves (box)","Consumables"),("Syringes 5ml","Consumables"),("IV Sets","Consumables"),("Paracetamol 500mg","Pharmacy"),("Amoxicillin 500mg","Pharmacy"),("Surgical Masks","PPE"),("Gauze Rolls","Consumables"),("Oxygen Tanks","Equipment"),("Saline 1L","Pharmacy"),("Wheelchairs","Equipment")]:
        lv = r.randint(30,120); c.execute("INSERT INTO supply(name,category,stock,reorder_level,unit_cost) VALUES(%s,%s,%s,%s,%s)", (n,cat,r.randint(5,400),lv,round(r.uniform(10,900),2)))
