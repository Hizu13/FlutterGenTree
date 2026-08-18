from sqlalchemy import (
    Column, Integer, String, Date, ForeignKey, Text, Enum, TIMESTAMP, UniqueConstraint
)
from sqlalchemy.orm import relationship
from db.mysql_connection import Base
import enum


class User(Base):
    """
    Model quản lý thông tin tài khoản người dùng trong hệ thống.
    - Định danh cá nhân qua: username, email, cccd, phone_number.
    - Mật khẩu được băm bằng bcrypt (password_hash).
    - Vai trò hệ thống: role (admin, member, v.v.)
    """
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    first_name = Column(String(50), nullable=True)
    last_name = Column(String(50), nullable=True)
    gender = Column(String(20), nullable=True)
    date_of_birth = Column(Date, nullable=True)
    place_of_birth = Column(String(255), nullable=True)
    email = Column(String(100), unique=True, index=True, nullable=False)
    cccd = Column(String(20), nullable=True)
    avatar_url = Column(String(255), nullable=True)
    role = Column(String(20), default="member", nullable=False)
    created_at = Column(TIMESTAMP, nullable=True)

    @property
    def full_name(self):
        last = self.last_name or ""
        first = self.first_name or ""
        return f"{last} {first}".strip()


class Family(Base):
    __tablename__ = "families"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    origin_location = Column(String(255), nullable=True)
    join_code = Column(String(10), unique=True, nullable=True)
    owner_id = Column(Integer, nullable=True)
    created_at = Column(TIMESTAMP, nullable=True)

    members = relationship("Person", back_populates="family")


class Member(Base):
    __tablename__ = "members"

    id = Column(Integer, primary_key=True, index=True)
    family_id = Column(Integer, ForeignKey("families.id"), nullable=True)
    user_id = Column(Integer, nullable=True)
    cccd = Column(String(20), unique=False, nullable=True)
    first_name = Column(String(50), nullable=True)
    last_name = Column(String(50), nullable=True)
    gender = Column(String(20), nullable=False)
    role = Column(String(20), default="member")
    date_of_birth = Column(Date, nullable=True)
    date_of_death = Column(Date, nullable=True)
    place_of_birth = Column(String(255), nullable=True)
    place_of_death = Column(String(255), nullable=True)
    phone_number = Column(String(20), nullable=True)
    permanent_address = Column(String(255), nullable=True)
    avatar_url = Column(String(255), nullable=True)
    father_id = Column(Integer, ForeignKey("members.id"), nullable=True)
    mother_id = Column(Integer, ForeignKey("members.id"), nullable=True)
    biography = Column(Text, nullable=True)
    occupation = Column(String(100), nullable=True)
    generation = Column(Integer, nullable=True)
    lunar_date_of_death = Column(String(100), nullable=True)
    created_at = Column(TIMESTAMP, nullable=True)

    # Relationships
    family = relationship("Family", back_populates="members")
    father = relationship("Member", remote_side=[id], foreign_keys=[father_id], post_update=True)
    mother = relationship("Member", remote_side=[id], foreign_keys=[mother_id], post_update=True)

    @property
    def full_name(self):
        last = self.last_name or ""
        first = self.first_name or ""
        return f"{last} {first}".strip()

    @property
    def currentAddress(self):
        return self.permanent_address

    @property
    def notes(self):
        return self.biography


# Alias Person to Member để tương thích ngược với các hàm xử lý cũ
Person = Member

class Relationship(Base):
    __tablename__ = "relationships"

    id = Column(Integer, primary_key=True, index=True)
    person1_id = Column(Integer, ForeignKey("persons.id"), nullable=False)
    person2_id = Column(Integer, ForeignKey("persons.id"), nullable=False)
    type = Column(String(50), nullable=False)

    person1 = relationship("Person", foreign_keys=[person1_id])
    person2 = relationship("Person", foreign_keys=[person2_id])

# ============================================================================
# EVENT MODELS - Quản lý sự kiện gia đình (Giỗ, họp họ, lễ tảo mộ...)
# ============================================================================

class Event(Base):
    __tablename__ = "events"

    id = Column(Integer, primary_key=True, index=True)
    family_id = Column(Integer, ForeignKey("families.id"), nullable=False)
    title = Column(String(255), nullable=False)
    
    # Ngày âm lịch
    lunar_day = Column(Integer, nullable=True)
    lunar_month = Column(Integer, nullable=True)
    lunar_year = Column(Integer, nullable=True)
    
    # Ngày dương lịch (tính toán từ âm lịch hoặc nhập trực tiếp)
    solar_date = Column(Date, nullable=True)
    
    # Thời gian sự kiện
    time_start = Column(String(10), nullable=True)  # "09:00"
    time_end = Column(String(10), nullable=True)    # "11:00"
    
    # Thông tin thêm
    note = Column(Text, nullable=True)
    creator_id = Column(Integer, ForeignKey("persons.id"), nullable=True)
    is_notified = Column(Integer, default=0)  # 0: chưa thông báo, 1: đã thông báo
    
    created_at = Column(TIMESTAMP, nullable=True)
    updated_at = Column(TIMESTAMP, nullable=True)

    # Relationships
    family = relationship("Family")
    creator = relationship("Person", foreign_keys=[creator_id])


# ============================================================================
# FINANCE MODELS - Quản lý tài chính gia phả (Thu, chi, công đức)
# ============================================================================

class TransactionTypeEnum(enum.Enum):
    income = "income"      # Thu
    expense = "expense"    # Chi
    merit = "merit"        # Công đức

class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True, index=True)
    family_id = Column(Integer, ForeignKey("families.id"), nullable=False)
    person_id = Column(Integer, ForeignKey("persons.id"), nullable=True)  # Người thực hiện giao dịch
    
    title = Column(String(255), nullable=False)
    amount = Column(Integer, nullable=False)  # Số tiền (VNĐ)
    type = Column(Enum(TransactionTypeEnum), nullable=False)
    category = Column(String(100), nullable=True)  # Danh mục: "Lễ vật", "Quà tặng", "Sửa mộ"...
    
    transaction_date = Column(Date, nullable=False)
    note = Column(Text, nullable=True)
    
    # Trạng thái phê duyệt (cho các khoản chi lớn)
    requires_approval = Column(Integer, default=0)  # 0: không cần, 1: cần phê duyệt
    is_approved = Column(Integer, default=1)  # 0: chưa duyệt, 1: đã duyệt
    approved_by = Column(Integer, ForeignKey("persons.id"), nullable=True)
    
    created_at = Column(TIMESTAMP, nullable=True)
    updated_at = Column(TIMESTAMP, nullable=True)

    # Relationships
    family = relationship("Family")
    person = relationship("Person", foreign_keys=[person_id])
    approver = relationship("Person", foreign_keys=[approved_by])
