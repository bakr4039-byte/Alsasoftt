"""مخططات Pydantic لطلبات واستجابات الـ API."""
from datetime import date, datetime
from typing import Literal, Optional

from pydantic import BaseModel


class LoginRequest(BaseModel):
    username: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class TeacherProfile(BaseModel):
    id: str
    full_name: str
    badge_number: Optional[str] = None
    department: Optional[str] = None
    job_title: Optional[str] = None
    phone: Optional[str] = None
    photo_url: Optional[str] = None
    role: str

    class Config:
        from_attributes = True


class AttendanceEventOut(BaseModel):
    id: int
    check_time: datetime
    check_type: str
    source: str

    class Config:
        from_attributes = True


class AttendanceStatusOut(BaseModel):
    status_date: date
    status: str
    minutes_late: Optional[int] = None
    minutes_early_leave: Optional[int] = None

    class Config:
        from_attributes = True


class CheckInRequest(BaseModel):
    check_type: Literal["in", "out"]
    source: Literal["mobile_gps", "mobile_code"] = "mobile_gps"
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class TeacherSummaryOut(BaseModel):
    id: str
    full_name: str
    department: Optional[str] = None
    today_status: Optional[str] = None

    class Config:
        from_attributes = True


class AdminSummaryOut(BaseModel):
    total: int
    present: int
    absent: int
    late: int
    on_leave: int
    not_marked: int


class MarkAttendanceRequest(BaseModel):
    status: Literal[
        "present", "absent", "late", "excused_leave",
        "unexcused_leave", "permission", "violation", "commendation",
    ]
    minutes_late: Optional[int] = None
    notes: Optional[str] = None
