from pydantic import BaseModel, EmailStr
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


class MemberBase(BaseModel):
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


class MemberCreate(MemberBase):
    pass


class MemberUpdate(MemberBase):
    pass


class MemberRead(MemberBase):
    id: int
    role: Optional[str] = "member"
    user_id: Optional[int] = None

    class Config:
        from_attributes = True

class MemberRoleUpdateRequest(BaseModel):
    """Schema cập nhật vai trò thành viên (Phân quyền / Hủy quyền Editor)"""
    role: str  # "admin", "editor", "member"


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
    """Schema chuyển đổi dữ liệu thành viên thân thiện với Flutter Mobile"""
    id: str
    userId: Optional[int] = None
    fullName: str
    gender: str
    status: str
    role: Optional[str] = "member"
    familyId: Optional[int] = None
    dateOfBirth: Optional[str] = None
    placeOfBirth: Optional[str] = None
    fatherId: Optional[str] = None
    fatherName: Optional[str] = None
    motherId: Optional[str] = None
    motherName: Optional[str] = None
    phoneNumber: Optional[str] = None
    email: Optional[str] = None
    currentAddress: Optional[str] = None
    permanentAddress: Optional[str] = None
    dateOfDeath: Optional[str] = None
    placeOfDeath: Optional[str] = None
    occupation: Optional[str] = None
    notes: Optional[str] = None
    avatarUrl: Optional[str] = None
    generation: Optional[int] = None
    identityCard: Optional[str] = None
    createdAt: Optional[str] = None


class MemberFlutterCreate(BaseModel):
    """Schema nhận yêu cầu thêm / sửa thành viên từ Flutter Mobile"""
    fullName: str
    gender: str
    role: Optional[str] = "member"
    status: Optional[str] = "Còn sống"
    familyId: Optional[int] = None
    dateOfBirth: Optional[str] = None
    placeOfBirth: Optional[str] = None
    fatherId: Optional[str] = None
    motherId: Optional[str] = None
    phoneNumber: Optional[str] = None
    email: Optional[str] = None
    currentAddress: Optional[str] = None
    permanentAddress: Optional[str] = None
    dateOfDeath: Optional[str] = None
    placeOfDeath: Optional[str] = None
    occupation: Optional[str] = None
    notes: Optional[str] = None
    avatarUrl: Optional[str] = None
    generation: Optional[int] = None
    identityCard: Optional[str] = None


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

# event
class LunarDateSchema(BaseModel):
    """Schema ngày âm lịch"""
    day: int
    month: int
    year: int


class EventBase(BaseModel):
    """Thuộc tính cơ bản của một sự kiện"""
    title: str
    family_id: Optional[int] = None
    member_id: Optional[int] = None
    event_type: Optional[str] = "custom"
    solar_date: Optional[date] = None
    lunar_day: Optional[int] = None
    lunar_month: Optional[int] = None
    lunar_year: Optional[int] = None
    time_start: Optional[str] = None
    time_end: Optional[str] = None
    location: Optional[str] = None
    note: Optional[str] = None
    creator_id: Optional[int] = None
    is_notified: Optional[int] = 0
    is_auto_generated: Optional[int] = 0


class EventCreate(EventBase):
    pass


class EventUpdate(EventBase):
    pass


class EventRead(EventBase):
    id: int

    class Config:
        from_attributes = True


class EventFlutterRead(BaseModel):
    """DTO sự kiện gửi tới Flutter Client"""
    id: str
    title: str
    eventType: Optional[str] = "custom"  # "birthday", "death_anniversary", "custom", "meeting", "worship"
    lunarDate: Optional[LunarDateSchema] = None
    solarDate: Optional[str] = None
    dateRange: str
    time: str
    date: str  # ISO date YYYY-MM-DD
    note: Optional[str] = ""
    creatorName: Optional[str] = ""
    creatorAvatarUrl: Optional[str] = ""
    isNotified: Optional[bool] = False
    isAutoGenerated: Optional[bool] = False
    memberId: Optional[int] = None
    familyId: Optional[int] = None
    location: Optional[str] = None


class EventFlutterCreate(BaseModel):
    """DTO nhận từ Flutter Client khi thêm / sửa sự kiện"""
    title: str
    familyId: Optional[int] = None
    memberId: Optional[int] = None
    eventType: Optional[str] = "custom"
    lunarDay: Optional[int] = None
    lunarMonth: Optional[int] = None
    lunarYear: Optional[int] = None
    solarDate: Optional[str] = None  # dd/MM/yyyy hoặc yyyy-MM-dd
    timeStart: Optional[str] = None
    timeEnd: Optional[str] = None
    time: Optional[str] = None
    location: Optional[str] = None
    note: Optional[str] = None
    creatorId: Optional[int] = None



class TransactionCreateFlutter(BaseModel):
    """Schema nhận từ Flutter khi thêm mới khoản thu / chi / công đức"""
    title: str
    amount: float
    type: str  # "income", "expense", "merit"
    personName: str
    category: Optional[str] = ""
    date: Optional[str] = None  # YYYY-MM-DD hoặc ISO
    note: Optional[str] = ""
    requiresApproval: Optional[bool] = False
    familyId: Optional[int] = None
    memberId: Optional[int] = None


class TransactionReadFlutter(BaseModel):
    """Schema trả về Flutter khớp 100% với TransactionModel"""
    id: str
    title: str
    amount: float
    type: str  # "income", "expense", "merit"
    personName: str
    category: str
    date: str  # ISO format string
    note: Optional[str] = ""
    status: Optional[str] = "approved"  # "approved", "pending", "rejected"
    requiresApproval: Optional[bool] = False
    familyId: Optional[int] = None
    memberId: Optional[int] = None
    createdById: Optional[int] = None


class FinanceSummary(BaseModel):
    """Schema tổng kết dòng tiền quỹ gia tộc"""
    totalBalance: float
    totalIncome: float
    totalExpense: float
    totalMerit: float
    transactionCount: int

