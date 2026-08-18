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
    created_at = Column(TIMESTAMP, nullable=True)

    members = relationship("Person", back_populates="family")


class Person(Base):
    __tablename__ = "persons"

    id = Column(Integer, primary_key=True, index=True)
    family_id = Column(Integer, ForeignKey("families.id"), nullable=True)
    cccd = Column(String(12), unique=False, nullable=True)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=True)
    gender = Column(Enum("male", "female", "other"), nullable=False)
    role = Column(Enum("admin", "editor", "member"), default="member")
    date_of_birth = Column(Date, nullable=True)
    date_of_death = Column(Date, nullable=True)
    place_of_birth = Column(String(255), nullable=True)
    phone_number = Column(String(20), nullable=True)
    permanent_address = Column(String(255), nullable=True)
    avatar_url = Column(String(255), nullable=True)
    father_id = Column(Integer, ForeignKey("persons.id"), nullable=True)
    mother_id = Column(Integer, ForeignKey("persons.id"), nullable=True)
    biography = Column(Text, nullable=True)
    occupation = Column(String(100), nullable=True)
    generation = Column(Integer, nullable=True)
    place_of_death = Column(String(255), nullable=True)
    lunar_date_of_death = Column(String(50), nullable=True)
    created_at = Column(TIMESTAMP, nullable=True)

    family = relationship("Family", back_populates="members")
    father = relationship("Person", remote_side=[id], foreign_keys=[father_id], post_update=True)
    mother = relationship("Person", remote_side=[id], foreign_keys=[mother_id], post_update=True)

    __table_args__ = (
        UniqueConstraint("family_id", "cccd", name="uq_family_member_cccd"),
    )


class Relationship(Base):
    __tablename__ = "relationships"

    id = Column(Integer, primary_key=True, index=True)
    person1_id = Column(Integer, ForeignKey("persons.id"), nullable=False)
    person2_id = Column(Integer, ForeignKey("persons.id"), nullable=False)
    type = Column(String(50), nullable=False)

    person1 = relationship("Person", foreign_keys=[person1_id])
    person2 = relationship("Person", foreign_keys=[person2_id])
