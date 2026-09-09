"""
واجهة برمجية (API) — المرحلة 1 من مشروع حاضر للجوال.
تشغيل محلي: uvicorn app.main:app --reload
"""
import os
from datetime import date, datetime, timedelta

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import func
from sqlalchemy.orm import Session

from . import auth, models, schemas
from .database import Base, SessionLocal, engine, get_db
from .seed import seed_demo_data

Base.metadata.create_all(bind=engine)

app = FastAPI(title="حاضر API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # للتطوير فقط — يُقيّد بدومين التطبيق عند الإنتاج
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def _auto_seed_if_empty():
    """عند أول إقلاع على قاعدة فاضية (مثلاً بعد ربط قاعدة بيانات سحابية جديدة)،
    تُعبَّأ بيانات تجريبية تلقائيًا حتى يقدر المستخدم يجرب التطبيق فورًا بدون خطوات يدوية إضافية.
    هذا خاص بنسخة العرض/التجربة فقط — عطّله بمتغير البيئة DISABLE_AUTO_SEED=1 عند الحاجة."""
    if os.getenv("DISABLE_AUTO_SEED") == "1":
        return
    db = SessionLocal()
    try:
        if db.query(models.School).first() is None:
            seed_demo_data(db, wipe_existing=False)
    finally:
        db.close()


@app.get("/")
def root():
    return {"service": "حاضر API", "status": "up", "docs": "/docs"}


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/auth/login", response_model=schemas.TokenResponse)
def login(payload: schemas.LoginRequest, db: Session = Depends(get_db)):
    account = db.query(models.AuthAccount).filter(
        models.AuthAccount.username == payload.username
    ).first()
    if not account or not auth.verify_password(payload.password, account.password_hash):
        raise HTTPException(status_code=401, detail="اسم المستخدم أو كلمة المرور غير صحيحة")
    account.last_login_at = datetime.utcnow()
    db.commit()
    token = auth.create_access_token(subject=account.id, role=account.role)
    return schemas.TokenResponse(access_token=token)


@app.get("/me", response_model=schemas.TeacherProfile)
def get_me(account: models.AuthAccount = Depends(auth.get_current_account), db: Session = Depends(get_db)):
    teacher = db.query(models.Teacher).filter(models.Teacher.id == account.teacher_id).first()
    if not teacher:
        raise HTTPException(status_code=404, detail="لم يتم العثور على بيانات المعلم")
    return schemas.TeacherProfile(
        id=teacher.id,
        full_name=teacher.full_name,
        badge_number=teacher.badge_number,
        department=teacher.department.name if teacher.department else None,
        job_title=teacher.job_title.title if teacher.job_title else None,
        phone=teacher.phone,
        photo_url=teacher.photo_url,
        role=account.role,
    )


@app.get("/me/attendance/events", response_model=list[schemas.AttendanceEventOut])
def my_attendance_events(
    days: int = 30,
    account: models.AuthAccount = Depends(auth.get_current_account),
    db: Session = Depends(get_db),
):
    since = datetime.utcnow() - timedelta(days=days)
    rows = (
        db.query(models.AttendanceEvent)
        .filter(models.AttendanceEvent.teacher_id == account.teacher_id)
        .filter(models.AttendanceEvent.check_time >= since)
        .order_by(models.AttendanceEvent.check_time.desc())
        .all()
    )
    return rows


@app.get("/me/attendance/status", response_model=list[schemas.AttendanceStatusOut])
def my_attendance_status(
    days: int = 30,
    account: models.AuthAccount = Depends(auth.get_current_account),
    db: Session = Depends(get_db),
):
    since = date.today() - timedelta(days=days)
    rows = (
        db.query(models.AttendanceStatus)
        .filter(models.AttendanceStatus.teacher_id == account.teacher_id)
        .filter(models.AttendanceStatus.status_date >= since)
        .order_by(models.AttendanceStatus.status_date.desc())
        .all()
    )
    return rows


@app.post("/attendance/checkin", response_model=schemas.AttendanceEventOut)
def check_in(
    payload: schemas.CheckInRequest,
    account: models.AuthAccount = Depends(auth.require_role("teacher", "supervisor", "admin")),
    db: Session = Depends(get_db),
):
    event = models.AttendanceEvent(
        teacher_id=account.teacher_id,
        check_time=datetime.utcnow(),
        check_type=payload.check_type,
        source=payload.source,
        latitude=payload.latitude,
        longitude=payload.longitude,
    )
    db.add(event)
    db.commit()
    db.refresh(event)
    return event


@app.get("/admin/teachers", response_model=list[schemas.TeacherSummaryOut])
def list_teachers(
    account: models.AuthAccount = Depends(auth.require_role("supervisor", "admin")),
    db: Session = Depends(get_db),
):
    teachers = db.query(models.Teacher).filter(models.Teacher.school_id == _school_id(db, account)).all()
    today = date.today()
    results = []
    for t in teachers:
        status_row = (
            db.query(models.AttendanceStatus)
            .filter(models.AttendanceStatus.teacher_id == t.id, models.AttendanceStatus.status_date == today)
            .first()
        )
        results.append(
            schemas.TeacherSummaryOut(
                id=t.id,
                full_name=t.full_name,
                department=t.department.name if t.department else None,
                today_status=status_row.status if status_row else None,
            )
        )
    return results


@app.get("/admin/summary", response_model=schemas.AdminSummaryOut)
def admin_summary(
    account: models.AuthAccount = Depends(auth.require_role("supervisor", "admin")),
    db: Session = Depends(get_db),
):
    """إحصائيات اليوم — مقابل بطاقات اللوحة الرئيسية بالنظام المكتبي (حاضر/غائب/تأخر/إجازة)."""
    school_id = _school_id(db, account)
    teachers = db.query(models.Teacher).filter(models.Teacher.school_id == school_id, models.Teacher.is_active == True).all()  # noqa: E712
    today = date.today()
    counts = {"present": 0, "absent": 0, "late": 0, "on_leave": 0, "not_marked": 0}
    leave_statuses = {"excused_leave", "unexcused_leave", "permission"}
    for t in teachers:
        status_row = (
            db.query(models.AttendanceStatus)
            .filter(models.AttendanceStatus.teacher_id == t.id, models.AttendanceStatus.status_date == today)
            .first()
        )
        if status_row is None:
            counts["not_marked"] += 1
        elif status_row.status == "present":
            counts["present"] += 1
        elif status_row.status == "late":
            counts["late"] += 1
        elif status_row.status in leave_statuses:
            counts["on_leave"] += 1
        elif status_row.status == "absent":
            counts["absent"] += 1
    return schemas.AdminSummaryOut(total=len(teachers), **counts)


@app.get("/admin/teachers/{teacher_id}/status", response_model=list[schemas.AttendanceStatusOut])
def teacher_status_history(
    teacher_id: str,
    days: int = 30,
    account: models.AuthAccount = Depends(auth.require_role("supervisor", "admin")),
    db: Session = Depends(get_db),
):
    """سجل حضور معلم محدد — مقابل شاشة (جدول الدوام حضوري) عند فتح ملف معلم من لوحة الإدارة."""
    teacher = db.query(models.Teacher).filter(
        models.Teacher.id == teacher_id, models.Teacher.school_id == _school_id(db, account)
    ).first()
    if not teacher:
        raise HTTPException(status_code=404, detail="لم يتم العثور على المعلم")
    since = date.today() - timedelta(days=days)
    rows = (
        db.query(models.AttendanceStatus)
        .filter(models.AttendanceStatus.teacher_id == teacher_id, models.AttendanceStatus.status_date >= since)
        .order_by(models.AttendanceStatus.status_date.desc())
        .all()
    )
    return rows


@app.post("/admin/teachers/{teacher_id}/mark", response_model=schemas.AttendanceStatusOut)
def mark_attendance(
    teacher_id: str,
    payload: schemas.MarkAttendanceRequest,
    account: models.AuthAccount = Depends(auth.require_role("supervisor", "admin")),
    db: Session = Depends(get_db),
):
    """تسجيل سريع لحالة معلم اليوم (حاضر/غائب/تأخر/استئذان...) — مقابل أزرار التسجيل السريع
    بالشاشة الرئيسية بالنظام المكتبي. يستبدل أي حالة سابقة لنفس اليوم بنفس القيد."""
    teacher = db.query(models.Teacher).filter(
        models.Teacher.id == teacher_id, models.Teacher.school_id == _school_id(db, account)
    ).first()
    if not teacher:
        raise HTTPException(status_code=404, detail="لم يتم العثور على المعلم")

    term = (
        db.query(models.AcademicTerm)
        .filter(models.AcademicTerm.school_id == teacher.school_id)
        .order_by(models.AcademicTerm.start_date.desc())
        .first()
    )
    if not term:
        raise HTTPException(status_code=400, detail="لا يوجد فصل دراسي مُعرَّف لهذه المدرسة بعد")

    today = date.today()
    db.query(models.AttendanceStatus).filter(
        models.AttendanceStatus.teacher_id == teacher_id, models.AttendanceStatus.status_date == today
    ).delete()
    row = models.AttendanceStatus(
        teacher_id=teacher_id,
        term_id=term.id,
        status_date=today,
        status=payload.status,
        minutes_late=payload.minutes_late,
        notes=payload.notes,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def _school_id(db: Session, account: models.AuthAccount) -> str:
    teacher = db.query(models.Teacher).filter(models.Teacher.id == account.teacher_id).first()
    return teacher.school_id if teacher else None
