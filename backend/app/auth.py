"""تسجيل الدخول وإصدار/التحقق من JWT."""
import os
from datetime import datetime, timedelta

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session

from . import models
from .database import get_db

# في الإنتاج: يجب ضبط SECRET_KEY كمتغيّر بيئة سري حقيقي — لا يوضع بالنص داخل الكود
SECRET_KEY = os.getenv("HADER_SECRET_KEY", "dev-only-secret-change-me")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 12

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


def hash_password(raw: str) -> str:
    return pwd_context.hash(raw)


def verify_password(raw: str, hashed: str) -> bool:
    return pwd_context.verify(raw, hashed)


def create_access_token(subject: str, role: str) -> str:
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {"sub": subject, "role": role, "exp": expire}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def get_current_account(
    token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)
) -> models.AuthAccount:
    credentials_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="بيانات الدخول غير صالحة أو انتهت صلاحيتها",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        account_id = payload.get("sub")
        if account_id is None:
            raise credentials_error
    except JWTError:
        raise credentials_error

    account = db.query(models.AuthAccount).filter(models.AuthAccount.id == account_id).first()
    if account is None or not account.is_active:
        raise credentials_error
    return account


def require_role(*roles: str):
    def checker(account: models.AuthAccount = Depends(get_current_account)):
        if account.role not in roles:
            raise HTTPException(status_code=403, detail="لا تملك صلاحية الوصول لهذا المسار")
        return account
    return checker
