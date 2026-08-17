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

    class Config:
        from_attributes = True


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


# ============================================================================
# EVENT SCHEMAS - Schemas cho sự kiện
# ============================================================================

class LunarDateSchema(BaseModel):
    day: int
    month: int
    year: int

    class Config:
        from_attributes = True


class EventBase(BaseModel):
    title: str
    lunar_day: Optional[int] = None
    lunar_month: Optional[int] = None
    lunar_year: Optional[int] = None
    solar_date: Optional[date] = None
    time_start: Optional[str] = None
    time_end: Optional[str] = None
    note: Optional[str] = None
    is_notified: Optional[int] = 0


class EventCreate(EventBase):
    family_id: int
    creator_id: Optional[int] = None


class EventUpdate(EventBase):
    pass


class EventRead(EventBase):
    id: int
    family_id: int
    creator_id: Optional[int] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None

    class Config:
        from_attributes = True


class EventFlutterRead(BaseModel):
    id: str
    title: str
    lunarDate: Optional[dict] = None  # {day, month, year}
    solarDate: Optional[str] = None  # dd/MM/yyyy
    dateRange: str
    time: str
    date: str  # ISO format for calendar
    note: Optional[str] = None
    creatorName: Optional[str] = None
    creatorAvatarUrl: Optional[str] = None
    isNotified: bool


class EventFlutterCreate(BaseModel):
    title: str
    lunarDay: Optional[int] = None
    lunarMonth: Optional[int] = None
    lunarYear: Optional[int] = None
    solarDate: Optional[str] = None  # dd/MM/yyyy
    timeStart: Optional[str] = None
    timeEnd: Optional[str] = None
    note: Optional[str] = None
    familyId: int
    creatorId: Optional[int] = None


# ============================================================================
# FINANCE SCHEMAS - Schemas cho giao dịch tài chính
# ============================================================================

class TransactionBase(BaseModel):
    title: str
    amount: int
    type: str  # "income", "expense", "merit"
    category: Optional[str] = None
    transaction_date: date
    note: Optional[str] = None
    requires_approval: Optional[int] = 0
    is_approved: Optional[int] = 1


class TransactionCreate(TransactionBase):
    family_id: int
    person_id: Optional[int] = None


class TransactionUpdate(TransactionBase):
    approved_by: Optional[int] = None


class TransactionRead(TransactionBase):
    id: int
    family_id: int
    person_id: Optional[int] = None
    approved_by: Optional[int] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None

    class Config:
        from_attributes = True


class TransactionFlutterRead(BaseModel):
    id: str
    title: str
    amount: float
    type: str  # "income", "expense", "merit"
    personName: str
    category: str
    date: str  # ISO format
    note: Optional[str] = None
    requiresApproval: bool


class TransactionFlutterCreate(BaseModel):
    title: str
    amount: float
    type: str  # "income", "expense", "merit"
    category: str
    date: str  # dd/MM/yyyy
    note: Optional[str] = None
    requiresApproval: bool = False
    familyId: int
    personId: Optional[int] = None
