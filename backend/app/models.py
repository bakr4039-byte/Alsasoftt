"""
نماذج SQLAlchemy — تعكس db/schema.sql (نسخة مبسّطة تعمل على SQLite للتجربة المحلية).
"""
import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean, Column, Date, DateTime, ForeignKey, Integer, Numeric,
    String, Text, UniqueConstraint,
)
from sqlalchemy.orm import relationship

from .database import Base


def new_uuid():
    return str(uuid.uuid4())


class School(Base):
    __tablename__ = "schools"
    id = Column(String, primary_key=True, default=new_uuid)
    name = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)


class Department(Base):
    __tablename__ = "departments"
    id = Column(Integer, primary_key=True, autoincrement=True)
    school_id = Column(String, ForeignKey("schools.id"), nullable=False)
    name = Column(Text, nullable=False)
    parent_id = Column(Integer, ForeignKey("departments.id"), nullable=True)


class JobTitle(Base):
    __tablename__ = "job_titles"
    id = Column(Integer, primary_key=True, autoincrement=True)
    school_id = Column(String, ForeignKey("schools.id"), nullable=False)
    title = Column(Text, nullable=False)


class AcademicTerm(Base):
    __tablename__ = "academic_terms"
    id = Column(Integer, primary_key=True, autoincrement=True)
    school_id = Column(String, ForeignKey("schools.id"), nullable=False)
    hijri_year = Column(Text, nullable=False)
    term_number = Column(Integer, nullable=False)
    start_date = Column(Date, nullable=True)
    end_date = Column(Date, nullable=True)
    __table_args__ = (UniqueConstraint("school_id", "hijri_year", "term_number"),)


class Holiday(Base):
    __tablename__ = "holidays"
    id = Column(Integer, primary_key=True, autoincrement=True)
    school_id = Column(String, ForeignKey("schools.id"), nullable=False)
    name = Column(Text, nullable=False)
    holiday_date = Column(Date, nullable=False)


class Teacher(Base):
    __tablename__ = "teachers"
    id = Column(String, primary_key=True, default=new_uuid)
    school_id = Column(String, ForeignKey("schools.id"), nullable=False)
    badge_number = Column(Text, nullable=True)
    national_id = Column(Text, nullable=True)
    full_name = Column(Text, nullable=False)
    gender = Column(Text, nullable=True)
    phone = Column(Text, nullable=True)
    hired_at = Column(Date, nullable=True)
    department_id = Column(Integer, ForeignKey("departments.id"), nullable=True)
    job_title_id = Column(Integer, ForeignKey("job_titles.id"), nullable=True)
    photo_url = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    auth_account = relationship("AuthAccount", back_populates="teacher", uselist=False)
    department = relationship("Department")
    job_title = relationship("JobTitle")


class AuthAccount(Base):
    __tablename__ = "auth_accounts"
    id = Column(String, primary_key=True, default=new_uuid)
    teacher_id = Column(String, ForeignKey("teachers.id"), unique=True)
    username = Column(String, unique=True, nullable=False)
    password_hash = Column(Text, nullable=False)
    role = Column(String, nullable=False)  # teacher | supervisor | admin
    is_active = Column(Boolean, default=True)
    last_login_at = Column(DateTime, nullable=True)

    teacher = relationship("Teacher", back_populates="auth_account")


class BiometricDevice(Base):
    __tablename__ = "biometric_devices"
    id = Column(Integer, primary_key=True, autoincrement=True)
    school_id = Column(String, ForeignKey("schools.id"), nullable=False)
    alias = Column(Text, nullable=False)
    ip_address = Column(Text, nullable=True)
    serial_number = Column(Text, nullable=True)
    is_enabled = Column(Boolean, default=True)


class AttendanceEvent(Base):
    __tablename__ = "attendance_events"
    id = Column(Integer, primary_key=True, autoincrement=True)
    teacher_id = Column(String, ForeignKey("teachers.id"), nullable=False)
    check_time = Column(DateTime, nullable=False)
    check_type = Column(String, nullable=False)  # in | out
    source = Column(String, nullable=False)  # device | mobile_gps | mobile_code | manual
    device_id = Column(Integer, ForeignKey("biometric_devices.id"), nullable=True)
    latitude = Column(Numeric(9, 6), nullable=True)
    longitude = Column(Numeric(9, 6), nullable=True)
    is_manual_override = Column(Boolean, default=False)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class AttendanceStatus(Base):
    __tablename__ = "attendance_status"
    id = Column(Integer, primary_key=True, autoincrement=True)
    teacher_id = Column(String, ForeignKey("teachers.id"), nullable=False)
    term_id = Column(Integer, ForeignKey("academic_terms.id"), nullable=False)
    status_date = Column(Date, nullable=False)
    status = Column(String, nullable=False)
    minutes_late = Column(Integer, nullable=True)
    minutes_early_leave = Column(Integer, nullable=True)
    notes = Column(Text, nullable=True)
    __table_args__ = (UniqueConstraint("teacher_id", "status_date", "status"),)


class NotificationLog(Base):
    __tablename__ = "notifications_log"
    id = Column(Integer, primary_key=True, autoincrement=True)
    teacher_id = Column(String, ForeignKey("teachers.id"), nullable=True)
    channel = Column(String, nullable=False)  # sms | whatsapp | push
    body = Column(Text, nullable=False)
    status = Column(String, default="queued")
    sent_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
