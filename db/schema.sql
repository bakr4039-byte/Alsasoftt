-- ============================================================
-- حاضر (Hader) — مخطط قاعدة البيانات الجديد
-- المرحلة 1: يغطي تسجيل الدخول، بيانات المعلمين، وسجل الحضور
-- تقنية الإنتاج المستهدفة: PostgreSQL 15+
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto"; -- لإنشاء UUID وتشفير كلمات المرور لاحقًا

-- ---------- بيانات مرجعية ----------

CREATE TABLE schools (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL,                 -- كان اسم المدرسة يظهر داخل نص رسائل SMS ثابت (نظام حاضر القديم)
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE departments (                         -- يقابل DEPARTMENTS في TDATA.mde
    id              SERIAL PRIMARY KEY,
    school_id       UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    parent_id       INTEGER REFERENCES departments(id)
);

CREATE TABLE job_titles (                          -- يقابل JOBS
    id              SERIAL PRIMARY KEY,
    school_id       UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    title           TEXT NOT NULL
);

CREATE TABLE academic_terms (                      -- يستبدل تكرار term1/term2 كجداول منفصلة
    id              SERIAL PRIMARY KEY,
    school_id       UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    hijri_year      TEXT NOT NULL,                 -- مثال: 1447
    term_number     SMALLINT NOT NULL CHECK (term_number IN (1, 2, 3)),
    start_date      DATE,
    end_date        DATE,
    UNIQUE (school_id, hijri_year, term_number)
);

CREATE TABLE holidays (                            -- يقابل HOLIDAYS
    id              SERIAL PRIMARY KEY,
    school_id       UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    holiday_date    DATE NOT NULL
);

-- ---------- المعلمون والمستخدمون ----------

CREATE TABLE teachers (                            -- يقابل USERINFO
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id           UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    badge_number        TEXT,                      -- Badgenumber
    national_id         TEXT,                      -- SSN
    full_name           TEXT NOT NULL,
    gender              TEXT CHECK (gender IN ('male','female')),
    phone               TEXT,
    hired_at            DATE,
    department_id       INTEGER REFERENCES departments(id),
    job_title_id        INTEGER REFERENCES job_titles(id),
    photo_url           TEXT,                      -- بدل حقل OLE القديم، رابط ملف في تخزين سحابي
    is_active           BOOLEAN NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE auth_accounts (                       -- يستبدل User + UserLogIn (بلا نص صريح للباسورد)
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id          UUID UNIQUE REFERENCES teachers(id) ON DELETE CASCADE,
    username            TEXT UNIQUE NOT NULL,
    password_hash       TEXT NOT NULL,              -- bcrypt / argon2
    role                TEXT NOT NULL CHECK (role IN ('teacher','supervisor','admin')),
    is_active           BOOLEAN NOT NULL DEFAULT true,
    last_login_at       TIMESTAMPTZ
);

-- ---------- أجهزة البصمة ----------

CREATE TABLE biometric_devices (                   -- يقابل Machines
    id                  SERIAL PRIMARY KEY,
    school_id           UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    alias               TEXT NOT NULL,
    ip_address          TEXT,
    serial_number       TEXT,
    is_enabled          BOOLEAN NOT NULL DEFAULT true
);

-- ---------- الحضور ----------

CREATE TABLE attendance_events (                   -- يقابل CHECKINOUT — سجل خام لكل بصمة/تسجيل جوال
    id                  BIGSERIAL PRIMARY KEY,
    teacher_id          UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
    check_time          TIMESTAMPTZ NOT NULL,
    check_type          TEXT NOT NULL CHECK (check_type IN ('in','out')),
    source              TEXT NOT NULL CHECK (source IN ('device','mobile_gps','mobile_code','manual')),
    device_id           INTEGER REFERENCES biometric_devices(id),
    latitude            NUMERIC(9,6),               -- تُملأ فقط عند source = mobile_gps
    longitude           NUMERIC(9,6),
    is_manual_override  BOOLEAN NOT NULL DEFAULT false,
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_attendance_events_teacher_time ON attendance_events (teacher_id, check_time DESC);

CREATE TABLE attendance_status (                   -- يوحّد جداول absence/late/leave/escape term1+term2
    id                  BIGSERIAL PRIMARY KEY,
    teacher_id          UUID NOT NULL REFERENCES teachers(id) ON DELETE CASCADE,
    term_id             INTEGER NOT NULL REFERENCES academic_terms(id),
    status_date         DATE NOT NULL,
    status              TEXT NOT NULL CHECK (
        status IN ('present','absent','late','excused_leave','unexcused_leave','permission','violation','commendation')
    ),
    minutes_late        INTEGER,
    minutes_early_leave INTEGER,
    notes               TEXT,
    UNIQUE (teacher_id, status_date, status)
);
CREATE INDEX idx_attendance_status_teacher_date ON attendance_status (teacher_id, status_date DESC);

-- ---------- الإشعارات ----------

CREATE TABLE notifications_log (                   -- يوحّد SMSTABLE وجداول واتساب المؤقتة
    id                  BIGSERIAL PRIMARY KEY,
    teacher_id          UUID REFERENCES teachers(id) ON DELETE SET NULL,
    channel             TEXT NOT NULL CHECK (channel IN ('sms','whatsapp','push')),
    body                TEXT NOT NULL,
    status              TEXT NOT NULL CHECK (status IN ('queued','sent','failed')) DEFAULT 'queued',
    sent_at             TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
