import os
from datetime import datetime, date
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from fastapi.responses import JSONResponse
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr
from itsdangerous import URLSafeTimedSerializer, BadSignature, SignatureExpired
from passlib.context import CryptContext

from db.mysql_connection import get_db
from models import User

# =====================
# ⚙️ Cấu hình Authentication
# =====================
SECRET_KEY = os.getenv("SECRET_KEY", "family_tree_secret_key_2026_super_safe")
SESSION_EXPIRE_SECONDS = int(os.getenv("SESSION_EXPIRE_SECONDS", "604800"))  # 7 ngày = 604800s

serializer = URLSafeTimedSerializer(SECRET_KEY)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security_bearer = HTTPBearer(auto_error=False)

router = APIRouter(prefix="/api/auth", tags=["Authentication"])


# =====================
# 📘 Pydantic Schemas
# =====================
class LoginRequest(BaseModel):
    username: str
    password: str


class RegisterRequest(BaseModel):
    username: str
    password: str
    first_name: str
    last_name: Optional[str] = None
    gender: Optional[str] = None
    date_of_birth: Optional[str] = None
    place_of_birth: Optional[str] = None
    email: str
    phone_number: Optional[str] = None
    cccd: Optional[str] = None
    avatar_url: Optional[str] = None
    role: Optional[str] = "member"


class ProfileUpdateRequest(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    gender: Optional[str] = None
    date_of_birth: Optional[str] = None
    place_of_birth: Optional[str] = None
    email: Optional[str] = None
    phone_number: Optional[str] = None
    cccd: Optional[str] = None
    avatar_url: Optional[str] = None


# =====================
# 🛠️ Helper Functions
# =====================
def hash_password(password: str) -> str:
    try:
        return pwd_context.hash(password)
    except Exception:
        # Fallback SHA256 nếu hệ thống thiếu thư viện bcrypt backend
        import hashlib
        return hashlib.sha256(password.encode("utf-8")).hexdigest()


def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        if hashed_password.startswith("$2b$") or hashed_password.startswith("$2a$"):
            return pwd_context.verify(plain_password, hashed_password)
        import hashlib
        return hashlib.sha256(plain_password.encode("utf-8")).hexdigest() == hashed_password or pwd_context.verify(plain_password, hashed_password)
    except Exception:
        import hashlib
        return hashlib.sha256(plain_password.encode("utf-8")).hexdigest() == hashed_password


def parse_date(date_str: Optional[str]) -> Optional[date]:
    if not date_str or not str(date_str).strip():
        return None
    for fmt in ("%d/%m/%Y", "%Y-%m-%d", "%d-%m-%Y"):
        try:
            return datetime.strptime(str(date_str).strip(), fmt).date()
        except ValueError:
            pass
    return None


def format_date(d: Optional[date]) -> Optional[str]:
    if not d:
        return None
    try:
        return d.strftime("%d/%m/%Y")
    except Exception:
        return str(d)


def _gender_to_vn(gender: Optional[str]) -> Optional[str]:
    if not gender:
        return None
    mapping = {"male": "Nam", "female": "Nữ", "other": "Khác"}
    return mapping.get(gender, gender)


def _gender_to_db(gender: Optional[str]) -> Optional[str]:
    if not gender:
        return None
    mapping = {"Nam": "male", "Nữ": "female", "Khác": "other"}
    return mapping.get(gender, gender if gender in ["male", "female", "other"] else "male")


def user_to_dict(user: User) -> dict:
    return {
        "id": user.id,
        "username": user.username,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "gender": _gender_to_vn(user.gender),
        "date_of_birth": format_date(user.date_of_birth),
        "place_of_birth": user.place_of_birth,
        "email": user.email,
        "phone_number": getattr(user, 'phone_number', '') or '',
        "cccd": user.cccd,
        "avatar_url": user.avatar_url,
        "role": user.role,
        "created_at": user.created_at.strftime("%d/%m/%Y %H:%M:%S") if user.created_at else None,
    }


# =====================
# 🔐 Dependency: Lấy thông tin User hiện tại
# =====================
def get_current_user(
    request: Request,
    token_auth: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer),
    db: Session = Depends(get_db),
) -> User:
    token = None
    # 1. Ưu tiên Authorization: Bearer <token>
    if token_auth and token_auth.credentials:
        token = token_auth.credentials
    # 2. Sau đó kiểm tra cookie session
    if not token:
        token = request.cookies.get("user_session")

    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Chưa đăng nhập hoặc thiếu Token")

    try:
        payload = serializer.loads(token, max_age=SESSION_EXPIRE_SECONDS)
        user_id = payload.get("user_id")
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Tài khoản không tồn tại")
        return user
    except SignatureExpired:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Phiên đăng nhập đã hết hạn")
    except (BadSignature, Exception):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token không hợp lệ")


# =====================
# 🔑 API Đăng ký (Register)
# =====================
@router.post("/register")
def register(data: RegisterRequest, db: Session = Depends(get_db)):
    try:
        # 1. Kiểm tra username đã tồn tại chưa
        existing_username = db.query(User).filter(User.username == data.username.strip()).first()
        if existing_username:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Tên đăng nhập này đã được sử dụng. Vui lòng chọn tên đăng nhập khác.",
            )
        # 2. Kiểm tra email đã tồn tại chưa
        existing_email = db.query(User).filter(User.email == data.email.strip()).first()
        if existing_email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Địa chỉ email này đã được đăng ký cho một tài khoản khác.",
            )
        # 3. Kiểm tra số CCCD/CMND đã tồn tại chưa (nếu có nhập)
        if data.cccd and data.cccd.strip():
            cccd_clean = data.cccd.strip()
            existing_cccd = db.query(User).filter(User.cccd == cccd_clean).first()
            if existing_cccd:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Số CCCD/CMND '{cccd_clean}' đã được đăng ký cho tài khoản '{existing_cccd.username}'. Vui lòng kiểm tra lại hoặc đăng nhập bằng tài khoản này.",
                )
        # 4. Tạo User mới (ép quyền 'member' mặc định)        new_user = User(
            username=data.username.strip(),
            password_hash=hash_password(data.password),
            first_name=data.first_name.strip(),
            last_name=data.last_name.strip() if data.last_name else None,
            gender=_gender_to_db(data.gender),
            date_of_birth=parse_date(data.date_of_birth),
            place_of_birth=data.place_of_birth.strip() if data.place_of_birth else None,
            email=data.email.strip(),
            phone_number=data.phone_number.strip() if getattr(data, 'phone_number', None) else None,
            cccd=data.cccd.strip() if data.cccd else None,
            avatar_url=data.avatar_url,
            role="member",  # Luôn mặc định là member
            created_at=datetime.now(),
        

        db.add(new_user)
        db.commit()
        db.refresh(new_user)

        # 4. Tạo token phiên làm việc
        token = serializer.dumps({"user_id": new_user.id, "role": new_user.role})

        response_data = {
            "success": True,
            "message": "Đăng ký tài khoản thành công",
            "access_token": token,
            "token_type": "bearer",
            "user": user_to_dict(new_user),
        }

        response = JSONResponse(content=response_data, status_code=status.HTTP_201_CREATED)
        response.set_cookie(
            key="user_session",
            value=token,
            httponly=True,
            max_age=SESSION_EXPIRE_SECONDS,
            samesite="lax",
            secure=False,
            path="/",
        )
        return response
    except HTTPException:
            raise
    except Exception as e:
            db.rollback()
            err_msg = str(e)
            if "Duplicate entry" in err_msg or "1062" in err_msg:
                if "cccd" in err_msg.lower():
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Số CCCD/CMND này đã được đăng ký cho một tài khoản khác.",
                    )
                elif "username" in err_msg.lower():
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Tên đăng nhập này đã được sử dụng.",
                    )
                elif "email" in err_msg.lower():
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Địa chỉ email này đã được sử dụng.",
                    )
            import traceback
            traceback.print_exc()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Đã xảy ra lỗi trong quá trình đăng ký. Vui lòng kiểm tra lại thông tin.",
            )

# =====================
# 🔑 API Đăng nhập (Login)
# =====================
@router.post("/login")
def login(data: LoginRequest, db: Session = Depends(get_db)):
    # Tìm kiếm theo username hoặc email
    user = (
        db.query(User)
        .filter((User.username == data.username.strip()) | (User.email == data.username.strip()))
        .first()
    )

    if not user or not verify_password(data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Tên đăng nhập hoặc mật khẩu không chính xác",
        )

    # Tạo token
    token = serializer.dumps({"user_id": user.id, "role": user.role})

    response_data = {
        "success": True,
        "message": "Đăng nhập thành công",
        "access_token": token,
        "token_type": "bearer",
        "user": user_to_dict(user),
    }

    response = JSONResponse(content=response_data)
    response.set_cookie(
        key="user_session",
        value=token,
        httponly=True,
        max_age=SESSION_EXPIRE_SECONDS,
        samesite="lax",
        secure=False,
        path="/",
    )
    return response


# =====================
# 👤 API Thông tin cá nhân (Me)
# =====================
@router.get("/me")
def get_me(current_user: User = Depends(get_current_user)):
    return {
        "success": True,
        "user": user_to_dict(current_user),
    }


# =====================
# 👤 API Cập nhật thông tin cá nhân
# =====================
@router.put("/profile")
def update_profile(
    data: ProfileUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if data.first_name is not None:
        current_user.first_name = data.first_name.strip()
    if data.last_name is not None:
        current_user.last_name = data.last_name.strip()
    if data.gender is not None:
        current_user.gender = data.gender
    if data.date_of_birth is not None:
        current_user.date_of_birth = parse_date(data.date_of_birth)
    if data.place_of_birth is not None:
        current_user.place_of_birth = data.place_of_birth
    if data.email is not None:
        # Kiểm tra trùng email với user khác
        existing = db.query(User).filter(User.email == data.email.strip(), User.id != current_user.id).first()
        if existing:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email này đã được tài khoản khác sử dụng")
        current_user.email = data.email.strip()
    if data.cccd is not None and data.cccd.strip():
        current_user.cccd = data.cccd.strip()
        cccd_clean = data.cccd.strip()
        existing_cccd = db.query(User).filter(User.cccd == cccd_clean, User.id != current_user.id).first()
        if existing_cccd:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Số CCCD/CMND '{cccd_clean}' đã được tài khoản khác sử dụng.",
            )
        current_user.cccd = cccd_clean
    if data.avatar_url is not None:
        current_user.avatar_url = data.avatar_url

    db.commit()
    db.refresh(current_user)

    return {
        "success": True,
        "message": "Cập nhật thông tin thành công",
        "user": user_to_dict(current_user),
    }


# =====================
# 🚪 API Đăng xuất (Logout)
# =====================
@router.post("/logout")
def logout():
    response = JSONResponse(content={"success": True, "message": "Đã đăng xuất thành công"})
    response.delete_cookie(key="user_session", path="/")
    return response
