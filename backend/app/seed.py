"""
تعبئة بيانات تجريبية (وهمية بالكامل، لا تمثل بيانات حقيقية) لتجربة النموذج الأولي.
تشغيل يدوي محلي: python -m app.seed
تُستدعى أيضًا تلقائيًا عند إقلاع الخادم (main.py) إذا كانت القاعدة فاضية —
هذا مخصص لنسخة العرض/التجربة فقط، وليس سلوك النسخة النهائية (التي تبدأ فاضية بدون بيانات تجريبية).
"""
from datetime import date, datetime, timedelta

from . import auth, models
from .database import Base, SessionLocal, engine


def seed_demo_data(db, wipe_existing: bool = True):
    """يعبّئ بيانات تجريبية وهمية. wipe_existing=True يمسح أي بيانات سابقة أولاً (للتشغيل المحلي المتكرر)."""
    if wipe_existing:
        for model in [
            models.NotificationLog, models.AttendanceStatus, models.AttendanceEvent,
            models.AuthAccount, models.Teacher, models.BiometricDevice,
            models.Holiday, models.AcademicTerm, models.JobTitle, models.Department, models.School,
        ]:
            db.query(model).delete()
        db.commit()

    school = models.School(name="ثانوية تجريبية (بيانات وهمية للعرض فقط)")
    db.add(school)
    db.commit()

    dept_math = models.Department(school_id=school.id, name="قسم الرياضيات")
    dept_admin = models.Department(school_id=school.id, name="الإدارة المدرسية")
    db.add_all([dept_math, dept_admin])
    db.commit()

    job_teacher = models.JobTitle(school_id=school.id, title="معلم")
    job_supervisor = models.JobTitle(school_id=school.id, title="مشرف")
    db.add_all([job_teacher, job_supervisor])
    db.commit()

    term = models.AcademicTerm(school_id=school.id, hijri_year="1447", term_number=1,
                                start_date=date(2025, 8, 24), end_date=date(2025, 12, 18))
    db.add(term)
    db.commit()

    device = models.BiometricDevice(school_id=school.id, alias="جهاز البوابة الرئيسية", ip_address="192.168.1.50")
    db.add(device)
    db.commit()

    # معلمون تجريبيون (أسماء وهمية)
    teachers_data = [
        dict(full_name="عبدالله الحربي", gender="male", dept=dept_math, job=job_teacher,
             username="a.harbi", password="Teacher@123", role="teacher"),
        dict(full_name="سارة القحطاني", gender="female", dept=dept_math, job=job_teacher,
             username="s.qahtani", password="Teacher@123", role="teacher"),
        dict(full_name="محمد العتيبي", gender="male", dept=dept_admin, job=job_supervisor,
             username="m.otaibi", password="Supervisor@123", role="supervisor"),
    ]

    created_teachers = []
    for i, t in enumerate(teachers_data, start=1):
        teacher = models.Teacher(
            school_id=school.id,
            badge_number=f"T-00{i}",
            full_name=t["full_name"],
            gender=t["gender"],
            phone=f"05{i}0000000",
            hired_at=date(2020, 9, 1),
            department_id=t["dept"].id,
            job_title_id=t["job"].id,
        )
        db.add(teacher)
        db.commit()
        account = models.AuthAccount(
            teacher_id=teacher.id,
            username=t["username"],
            password_hash=auth.hash_password(t["password"]),
            role=t["role"],
        )
        db.add(account)
        db.commit()
        created_teachers.append((teacher, t))

    # سجل حضور تجريبي لآخر 10 أيام للمعلم الأول
    main_teacher = created_teachers[0][0]
    for d in range(10):
        day = date.today() - timedelta(days=d)
        if day.weekday() in (4, 5):  # الجمعة والسبت
            continue
        check_in_time = datetime.combine(day, datetime.min.time()) + timedelta(hours=6, minutes=45 + (d % 5))
        check_out_time = check_in_time + timedelta(hours=7)
        db.add(models.AttendanceEvent(
            teacher_id=main_teacher.id, check_time=check_in_time, check_type="in", source="device", device_id=device.id,
        ))
        db.add(models.AttendanceEvent(
            teacher_id=main_teacher.id, check_time=check_out_time, check_type="out", source="device", device_id=device.id,
        ))
        status = "late" if (d % 5) >= 3 else "present"
        db.add(models.AttendanceStatus(
            teacher_id=main_teacher.id, term_id=term.id, status_date=day, status=status,
            minutes_late=(45 + (d % 5)) if status == "late" else None,
        ))
    db.commit()

    print("تمت تعبئة بيانات تجريبية بنجاح.")
    print("حسابات الدخول التجريبية:")
    for teacher, t in created_teachers:
        print(f"  - {t['username']} / {t['password']}  ({t['role']} — {teacher.full_name})")


if __name__ == "__main__":
    Base.metadata.create_all(bind=engine)
    _db = SessionLocal()
    try:
        seed_demo_data(_db, wipe_existing=True)
    finally:
        _db.close()
