"""
طبقة الاتصال بقاعدة البيانات.
للتطوير المحلي: SQLite (ملف hader.db) افتراضيًا.
للعمل عبر الإنترنت: اضبط متغير البيئة DATABASE_URL برابط قاعدة PostgreSQL سحابية
(مثل رابط Neon) — بنية الجداول متوافقة تلقائيًا (SQLAlchemy تنشئها بنفسها).
"""
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./hader.db")

# بعض المزودين (مثل Neon) يعطون الرابط بصيغة postgres:// القديمة — SQLAlchemy/psycopg2 تحتاج postgresql://
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}
engine = create_engine(DATABASE_URL, connect_args=connect_args, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
