# routers/families.py
# API quản lý Gia phả (Family) - Bảng families
# Hỗ trợ tạo gia phả mới, lấy danh sách gia phả của tôi, tham gia bằng mã join_code

import random
import string
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query, BackgroundTasks
from pydantic import BaseModel
from sqlalchemy.orm import Session

from db.mysql_connection import get_db
from models import Family, Member, User
from routers.auth import get_current_user
from db.neo4j_connection import add_person_to_graph

router = APIRouter(prefix="/api/families", tags=["Families"])


def _safe_sync_to_graph(id: int, full_name: str, gender: str, family_id: int):
    try:
        add_person_to_graph(
            id=id,
            full_name=full_name,
            gender=gender,
            family_id=family_id,
        )
    except Exception as e:
        print(f"[!] Neo4j background sync error: {e}")


# ===========================================================================
# PYDANTIC SCHEMAS
# ===========================================================================

class FamilyCreateRequest(BaseModel):
    name: str
    description: Optional[str] = None
    origin_location: Optional[str] = None
    join_code: Optional[str] = None


class FamilyUpdateRequest(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    origin_location: Optional[str] = None
    join_code: Optional[str] = None


class FamilyJoinRequest(BaseModel):
    join_code: str
    branch_type: Optional[str] = "Họ nội"  # "Họ nội" hoặc "Họ ngoại"


class FamilyResponse(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    origin_location: Optional[str] = None
    join_code: Optional[str] = None
    owner_id: Optional[int] = None
    created_at: Optional[str] = None
    user_role: Optional[str] = "member"  # 'owner', 'admin', 'member'
    member_count: Optional[int] = 0

    class Config:
        from_attributes = True


# ===========================================================================
# HELPER FUNCTIONS
# ===========================================================================

def _generate_join_code(length: int = 6) -> str:
    """Sinh mã gia phả ngẫu nhiên (Ví dụ: NGU889, FAM78A, v.v.)"""
    chars = string.ascii_uppercase + string.digits
    return "".join(random.choices(chars, k=length))


def _family_to_dict(family: Family, db: Session, current_user_id: Optional[int] = None) -> dict:
    created_at_str = None
    if family.created_at:
        try:
            created_at_str = family.created_at.strftime("%d/%m/%Y %H:%M:%S")
        except Exception:
            created_at_str = str(family.created_at)

    # Đếm số lượng thành viên chính thức trong gia phả
    from sqlalchemy import or_
    member_count = (
        db.query(Member)
        .filter(
            Member.family_id == family.id,
            or_(Member.status == "approved", Member.status.is_(None)),
            Member.requires_approval != True
        )
        .count()
    )

    # Xác định vai trò của user trong gia phả này (chỉ xét khi đã được duyệt hoặc là chủ gia phả)
    user_role = "member"
    if current_user_id:
        if family.owner_id == current_user_id:
            user_role = "owner"
        else:
            member_record = (
                db.query(Member)
                .filter(
                    Member.family_id == family.id,
                    Member.user_id == current_user_id,
                    or_(Member.status == "approved", Member.status.is_(None)),
                    Member.requires_approval != True
                )
                .first()
            )
            if member_record and member_record.role:
                user_role = member_record.role

    return {
        "id": family.id,
        "name": family.name,
        "description": family.description,
        "origin_location": family.origin_location,
        "originLocation": family.origin_location,
        "join_code": family.join_code,
        "joinCode": family.join_code,
        "owner_id": family.owner_id,
        "ownerId": family.owner_id,
        "created_at": created_at_str,
        "createdAt": created_at_str,
        "user_role": user_role,
        "userRole": user_role,
        "member_count": member_count,
        "memberCount": member_count,
    }


# ===========================================================================
# API ENDPOINTS
# ===========================================================================

@router.get("/my", summary="Lấy danh sách gia phả của người dùng hiện tại")
@router.get("/my-families", summary="Lấy danh sách gia phả của người dùng hiện tại (alias)")
def get_my_families(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Kiểm tra và trả về tất cả các gia phả mà user hiện tại:
    1. Là chủ sở hữu (owner_id = current_user.id)
    2. Đã chính thức tham gia làm thành viên (Member.user_id = current_user.id)
    Yêu cầu người dùng phải nhập mã gia phả (join_code) để tham gia thay vì tự động liên kết ngầm.
    """
    # 1. Tìm các gia phả user là owner
    owned_families = db.query(Family).filter(Family.owner_id == current_user.id).all()
    owned_ids = {f.id for f in owned_families}

    # 2. Tìm các gia phả user đã tham gia (chỉ xét các bản ghi Member có user_id đã được liên kết chính thức)
    from sqlalchemy import or_
    member_family_ids = (
        db.query(Member.family_id)
        .filter(
            Member.family_id.isnot(None),
            Member.user_id == current_user.id,
            or_(Member.status == "approved", Member.status.is_(None)),
            Member.requires_approval != True
        )
        .distinct()
        .all()
    )
    joined_ids = {item[0] for item in member_family_ids if item[0] is not None}

    all_family_ids = owned_ids.union(joined_ids)

    if not all_family_ids:
        return {
            "success": True,
            "has_family": False,
            "count": 0,
            "data": [],
        }

    families = db.query(Family).filter(Family.id.in_(all_family_ids)).all()
    result = [_family_to_dict(f, db, current_user.id) for f in families]

    return {
        "success": True,
        "has_family": True,
        "count": len(result),
        "data": result,
    }


@router.post("", status_code=status.HTTP_201_CREATED, summary="Tạo gia phả mới")
@router.post("/", status_code=status.HTTP_201_CREATED, summary="Tạo gia phả mới (slash)")
def create_family(
    data: FamilyCreateRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Tạo gia phả mới với các trường:
    - name: Tên gia phả (Bắt buộc)
    - description: Mô tả / Giới thiệu
    - origin_location: Quê quán / Nguồn gốc
    - join_code: Mã tham gia (nếu để trống, hệ thống sẽ tự sinh)
    """
    family_name = data.name.strip()
    if not family_name:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tên gia phả không được để trống",
        )

    # Xử lý join_code
    join_code = data.join_code.strip().upper() if data.join_code else None
    if join_code:
        existing = db.query(Family).filter(Family.join_code == join_code).first()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Mã gia phả '{join_code}' đã được sử dụng. Vui lòng chọn mã khác.",
            )
    else:
        # Tự động sinh mã duy nhất
        for _ in range(10):
            generated_code = _generate_join_code()
            if not db.query(Family).filter(Family.join_code == generated_code).first():
                join_code = generated_code
                break
        if not join_code:
            join_code = f"GP{int(datetime.now().timestamp()) % 1000000}"

    new_family = Family(
        name=family_name,
        description=data.description.strip() if data.description else None,
        origin_location=data.origin_location.strip() if data.origin_location else None,
        join_code=join_code,
        owner_id=current_user.id,
        created_at=datetime.now(),
    )

    db.add(new_family)
    db.commit()
    db.refresh(new_family)

    # Tự động tạo một Member trưởng họ đại diện cho tài khoản này trong bảng members
    user_gender_db = "male"
    if current_user.gender:
        user_gender_db = "female" if current_user.gender in ["Nữ", "female"] else "male"

    new_member = Member(
        family_id=new_family.id,
        user_id=current_user.id,
        cccd=current_user.cccd,
        first_name=current_user.first_name or "Trưởng họ",
        last_name=current_user.last_name or "",
        gender=user_gender_db,
        role="admin",  # Quyền quản trị dòng họ
        date_of_birth=current_user.date_of_birth,
        place_of_birth=current_user.place_of_birth,
        avatar_url=current_user.avatar_url,
        generation=1,
        created_at=datetime.now(),
    )
    db.add(new_member)
    db.commit()
    db.refresh(new_member)

    # Đồng bộ sang Neo4j ở Background (không làm chậm HTTP response)
    background_tasks.add_task(
        _safe_sync_to_graph,
        id=new_member.id,
        full_name=new_member.full_name,
        gender=new_member.gender,
        family_id=new_family.id,
    )

    return {
        "success": True,
        "message": f"Tạo gia phả '{new_family.name}' thành công",
        "data": _family_to_dict(new_family, db, current_user.id),
        "member_id": new_member.id,
    }


@router.post("/join", summary="Tham gia gia phả bằng mã join_code")
def join_family(
    data: FamilyJoinRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Người dùng tham gia vào một gia phả đã có bằng cách nhập mã join_code.
    """
    code = data.join_code.strip().upper()
    if not code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vui lòng nhập mã gia phả",
        )

    family = db.query(Family).filter(Family.join_code == code).first()
    if not family:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Không tìm thấy gia phả với mã '{code}'. Vui lòng kiểm tra lại.",
        )

    # 1. Kiểm tra xem user đã liên kết với Member nào trong gia phả này chưa
    existing_member = (
        db.query(Member)
        .filter(Member.family_id == family.id, Member.user_id == current_user.id)
        .first()
    )

    # 2. Nếu chưa liên kết theo user_id, kiểm tra xem có Member nào trong gia phả có cùng CCCD không
    if not existing_member and current_user.cccd and current_user.cccd.strip():
        existing_member = (
            db.query(Member)
            .filter(Member.family_id == family.id, Member.cccd == current_user.cccd.strip())
            .first()
        )

    # Nếu user là chủ gia phả -> Duyệt tự động luôn
    is_owner = (family.owner_id == current_user.id)

    # ── TRƯỜNG HỢP 1: Đã có node thành viên trùng CCCD hoặc trùng User ID ──
    if existing_member:
        # Tự động map và đồng bộ tài khoản (user_id) và thông tin cá nhân với node đó trên cây gia phả
        existing_member.user_id = current_user.id
        if current_user.first_name:
            existing_member.first_name = current_user.first_name
        if current_user.last_name:
            existing_member.last_name = current_user.last_name
        if current_user.gender:
            existing_member.gender = "female" if current_user.gender in ["Nữ", "female"] else "male"
        if current_user.date_of_birth:
            existing_member.date_of_birth = current_user.date_of_birth
        if current_user.place_of_birth:
            existing_member.place_of_birth = current_user.place_of_birth
        if current_user.avatar_url:
            existing_member.avatar_url = current_user.avatar_url
        if getattr(current_user, 'phone_number', None):
            existing_member.phone_number = current_user.phone_number

        if is_owner:
            existing_member.status = "approved"
            existing_member.requires_approval = False
            db.commit()
            db.refresh(existing_member)

            background_tasks.add_task(
                _safe_sync_to_graph,
                id=existing_member.id,
                full_name=existing_member.full_name,
                gender=existing_member.gender,
                family_id=family.id,
            )
            return {
                "success": True,
                "requires_approval": False,
                "message": f"Bạn đã là chủ sở hữu và thành viên chính thức của gia phả '{family.name}'",
                "data": _family_to_dict(family, db, current_user.id),
                "member_id": existing_member.id,
            }
        else:
            # Chuyển trạng thái chờ Quản trị viên duyệt
            existing_member.status = "pending"
            existing_member.requires_approval = True
            db.commit()
            db.refresh(existing_member)

            return {
                "success": True,
                "requires_approval": True,
                "message": f"Đã tìm thấy thông tin của bạn trên cây gia phả '{family.name}'. Yêu cầu liên kết tài khoản đã được gửi tới Quản trị viên phê duyệt!",
                "data": None,
                "member_id": existing_member.id,
            }

    # ── TRƯỜNG HỢP 2: Chưa có node trùng CCCD -> Tham gia như 1 thành viên mới ──
    user_gender_db = "male"
    if current_user.gender:
        user_gender_db = "female" if current_user.gender in ["Nữ", "female"] else "male"

    role = "admin" if is_owner else "member"
    initial_status = "approved" if is_owner else "pending"
    initial_requires_approval = not is_owner

    new_member = Member(
        family_id=family.id,
        user_id=current_user.id,
        cccd=current_user.cccd,
        first_name=current_user.first_name or "Thành viên",
        last_name=current_user.last_name or "",
        gender=user_gender_db,
        role=role,
        status=initial_status,
        requires_approval=initial_requires_approval,
        date_of_birth=current_user.date_of_birth,
        place_of_birth=current_user.place_of_birth,
        avatar_url=current_user.avatar_url,
        phone_number=getattr(current_user, 'phone_number', None),
        biography=f"Nhánh: {data.branch_type}" if data.branch_type else None,
        created_at=datetime.now(),
    )

    db.add(new_member)
    db.commit()
    db.refresh(new_member)

    if is_owner:
        background_tasks.add_task(
            _safe_sync_to_graph,
            id=new_member.id,
            full_name=new_member.full_name,
            gender=new_member.gender,
            family_id=family.id,
        )
        return {
            "success": True,
            "requires_approval": False,
            "message": f"Tham gia gia phả '{family.name}' thành công",
            "data": _family_to_dict(family, db, current_user.id),
            "member_id": new_member.id,
        }

    return {
        "success": True,
        "requires_approval": True,
        "message": f"Đã gửi yêu cầu tham gia gia phả '{family.name}' như thành viên mới. Vui lòng chờ Quản trị viên phê duyệt!",
        "data": None,
        "member_id": new_member.id,
    }



@router.get("/{family_id}", summary="Xem thông tin chi tiết của gia phả")
def get_family_detail(
    family_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    family = db.query(Family).filter(Family.id == family_id).first()
    if not family:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy gia phả",
        )

    return {
        "success": True,
        "data": _family_to_dict(family, db, current_user.id),
    }


@router.put("/{family_id}", summary="Cập nhật thông tin gia phả")
def update_family(
    family_id: int,
    data: FamilyUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    family = db.query(Family).filter(Family.id == family_id).first()
    if not family:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy gia phả",
        )

    # Kiểm tra quyền: phải là chủ sở hữu hoặc admin
    if family.owner_id != current_user.id and current_user.role != "admin":
        # Kiểm tra role trong bảng member
        user_member = (
            db.query(Member)
            .filter(Member.family_id == family.id, Member.user_id == current_user.id)
            .first()
        )
        if not user_member or user_member.role not in ["admin", "editor"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Bạn không có quyền chỉnh sửa thông tin gia phả này",
            )

    if data.name is not None:
        family.name = data.name.strip()
    if data.description is not None:
        family.description = data.description.strip()
    if data.origin_location is not None:
        family.origin_location = data.origin_location.strip()
    if data.join_code is not None:
        new_code = data.join_code.strip().upper()
        if new_code != family.join_code:
            existing = db.query(Family).filter(Family.join_code == new_code).first()
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Mã gia phả '{new_code}' đã tồn tại",
                )
            family.join_code = new_code

    db.commit()
    db.refresh(family)

    return {
        "success": True,
        "message": "Cập nhật thông tin gia phả thành công",
        "data": _family_to_dict(family, db, current_user.id),
    }