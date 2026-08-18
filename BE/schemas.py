from pydantic import BaseModel
from typing import Optional
from datetime import date


class FamilyBase(BaseModel):
    name: str
    description: Optional[str] = None
    origin_location: Optional[str] = None


class FamilyCreate(FamilyBase):
    pass


class FamilyRead(FamilyBase):
    id: int
    join_code: Optional[str] = None
    owner_id: Optional[int] = None
    user_role: Optional[str] = "member"
    member_count: Optional[int] = 0

    class Config:
        from_attributes = True

class FamilyUpdateRequest(BaseModel):
    """Schema chỉnh sửa thông tin gia phả (Dành cho Admin/Owner)"""
    name: Optional[str] = None
    description: Optional[str] = None
    origin_location: Optional[str] = None
    join_code: Optional[str] = None


class FamilyJoinRequest(BaseModel):
    """Schema gửi yêu cầu tham gia gia phả bằng mã code"""
    join_code: str
    branch_type: Optional[str] = "Họ nội"  # "Họ nội" hoặc "Họ ngoại"


class PersonBase(BaseModel):
    cccd: Optional[str] = None
    first_name: str
    last_name: Optional[str] = None
    gender: str
    date_of_birth: Optional[date] = None
    date_of_death: Optional[date] = None
    place_of_birth: Optional[str] = None
    phone_number: Optional[str] = None
    permanent_address: Optional[str] = None
    avatar_url: Optional[str] = None
    biography: Optional[str] = None
    occupation: Optional[str] = None
    generation: Optional[int] = None
    place_of_death: Optional[str] = None
    father_id: Optional[int] = None
    mother_id: Optional[int] = None
    family_id: Optional[int] = None


class PersonCreate(PersonBase):
    pass


class PersonUpdate(PersonBase):
    pass


class PersonRead(PersonBase):
    id: int
    role: Optional[str] = "member"

    class Config:
        from_attributes = True


class RelationshipBase(BaseModel):
    person1_id: int
    person2_id: int
    type: str


class RelationshipCreate(RelationshipBase):
    pass


class RelationshipRead(RelationshipBase):
    id: int

    class Config:
        from_attributes = True


class MemberFlutterRead(BaseModel):
    id: str
    fullName: str
    gender: str
    status: str
    dateOfBirth: Optional[str] = None
    placeOfBirth: Optional[str] = None
    fatherId: Optional[str] = None
    fatherName: Optional[str] = None
    motherId: Optional[str] = None
    motherName: Optional[str] = None
    phoneNumber: Optional[str] = None
    email: Optional[str] = None
    currentAddress: Optional[str] = None
    dateOfDeath: Optional[str] = None
    placeOfDeath: Optional[str] = None
    occupation: Optional[str] = None
    notes: Optional[str] = None
    avatarUrl: Optional[str] = None
    generation: Optional[int] = None
    identityCard: Optional[str] = None


class MemberFlutterCreate(BaseModel):
    fullName: str
    gender: str
    status: Optional[str] = "Còn sống"
    dateOfBirth: Optional[str] = None
    placeOfBirth: Optional[str] = None
    fatherId: Optional[str] = None
    motherId: Optional[str] = None
    phoneNumber: Optional[str] = None
    email: Optional[str] = None
    currentAddress: Optional[str] = None
    dateOfDeath: Optional[str] = None
    placeOfDeath: Optional[str] = None
    occupation: Optional[str] = None
    notes: Optional[str] = None
    avatarUrl: Optional[str] = None
    generation: Optional[int] = None
    identityCard: Optional[str] = None
    familyId: Optional[int] = None


class UserLoginRequest(BaseModel):
    """Schema nhận thông tin đăng nhập"""
    username: str
    password: str


class UserRegisterRequest(BaseModel):
    """Schema nhận thông tin đăng ký tài khoản mới"""
    username: str
    password: str
    first_name: str
    last_name: Optional[str] = None
    gender: Optional[str] = None
    date_of_birth: Optional[str] = None
    place_of_birth: Optional[str] = None
    email: EmailStr
    cccd: Optional[str] = None
    avatar_url: Optional[str] = None
    role: Optional[str] = "member"


class UserRead(BaseModel):
    """Schema trả về thông tin người dùng an toàn (không lộ mật khẩu)"""
    id: int
    username: str
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    gender: Optional[str] = None
    date_of_birth: Optional[date] = None
    place_of_birth: Optional[str] = None
    email: str
    cccd: Optional[str] = None
    avatar_url: Optional[str] = None
    role: str

    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    """Schema phản hồi khi đăng nhập thành công"""
    access_token: str
    token_type: str = "bearer"
    user: Optional[UserRead] = None

