# routers/flutter_members.py
# API chuyên dụng cho Flutter app - không yêu cầu xác thực (development mode)
# Tự động chuyển đổi giữa format backend (snake_case, male/female, Date)
# và format Flutter (camelCase, Nam/Nữ, dd/MM/yyyy)

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session
from db.mysql_connection import get_db
from models import User, Member
from schemas import MemberFlutterRead, MemberFlutterCreate
from typing import List, Optional
from datetime import datetime
from pydantic import BaseModel
from db.neo4j_connection import (
    add_person_to_graph,
    delete_person_from_graph,
    delete_family_from_graph,
    create_relationship_in_graph,
    neo4j_conn,
)
# Alias helper neo4j
add_member_to_graph = add_person_to_graph
delete_member_from_graph = delete_person_from_graph

router = APIRouter(prefix="/api/flutter/members", tags=["Flutter Members"])


# ===========================================================================
# HÀM CHUYỂN ĐỔI DỮ LIỆU (CONVERTER)
# ===========================================================================

def _gender_to_vn(gender: str) -> str:
    """Chuyển male/female → Nam/Nữ"""
    mapping = {"male": "Nam", "female": "Nữ", "other": "Khác"}
    return mapping.get(gender, gender if gender in ["Nam", "Nữ"] else "Nam")


def _gender_to_db(gender: str) -> str:
    """Chuyển Nam/Nữ → male/female"""
    mapping = {"Nam": "male", "Nữ": "female", "Khác": "other"}
    return mapping.get(gender, gender if gender in ["male", "female"] else "male")


def _date_to_vn(d) -> Optional[str]:
    """Chuyển Date object → dd/MM/yyyy string"""
    if d is None:
        return None
    try:
        return d.strftime("%d/%m/%Y")
    except Exception:
        return str(d)


def _date_from_vn(s: Optional[str]):
    """Chuyển dd/MM/yyyy string → Date object"""
    if not s:
        return None
    try:
        return datetime.strptime(s, "%d/%m/%Y").date()
    except Exception:
        try:
            return datetime.strptime(s, "%Y-%m-%d").date()
        except Exception:
            return None


def _get_parent_name(db: Session, parent_id: Optional[int]) -> Optional[str]:
    """Tra cứu tên cha/mẹ từ DB"""
    if parent_id is None:
        return None
    parent = db.query(Member).filter(Member.id == parent_id).first()
    if parent:
        last = parent.last_name or ""
        first = parent.first_name or ""
        return f"{last} {first}".strip()
    return None


def _split_full_name(full_name: str):
    """Tách fullName thành (last_name, first_name) theo quy tắc tiếng Việt.
    Ví dụ: 'Nguyễn Văn An' → last_name='Nguyễn Văn', first_name='An'
    """
    parts = full_name.strip().split()
    if len(parts) == 0:
        return "", ""
    if len(parts) == 1:
        return "", parts[0]
    return " ".join(parts[:-1]), parts[-1]


def _member_to_flutter(db: Session, m: Member, request: Optional[Request] = None) -> dict:
    """Chuyển đổi Member DB record → dict theo format MemberFlutterRead."""
    full_name = getattr(m, 'full_name', None) or f"{getattr(m, 'last_name', '') or ''} {getattr(m, 'first_name', '') or ''}".strip()

    # Xác định status từ date_of_death
    status = "Đã mất" if m.date_of_death else "Còn sống"

    created_at_str = None
    if getattr(m, 'created_at', None):
        try:
            created_at_str = m.created_at.strftime("%d/%m/%Y %H:%M:%S")
        except Exception:
            created_at_str = str(m.created_at)

    return {
        "id": str(m.id),
        "userId": getattr(m, 'user_id', None),
        "familyId": getattr(m, 'family_id', None),
        "fullName": full_name,
        "gender": _gender_to_vn(m.gender),
        "role": getattr(m, 'role', 'member') or 'member',
        "status": status,
        "dateOfBirth": _date_to_vn(m.date_of_birth),
        "placeOfBirth": m.place_of_birth,
        "fatherId": str(m.father_id) if m.father_id else None,
        "fatherName": _get_parent_name(db, m.father_id),
        "motherId": str(m.mother_id) if m.mother_id else None,
        "motherName": _get_parent_name(db, m.mother_id),
        "phoneNumber": m.phone_number,
        "email": getattr(m, 'email', None),
        "currentAddress": getattr(m, 'currentAddress', None) or m.permanent_address,
        "permanentAddress": m.permanent_address,
        "dateOfDeath": _date_to_vn(m.date_of_death),
        "placeOfDeath": getattr(m, 'place_of_death', None),
        "occupation": getattr(m, 'occupation', None),
        "notes": getattr(m, 'notes', None) or getattr(m, 'biography', None),
        "avatarUrl": (str(request.base_url).rstrip('/') + m.avatar_url) if (m.avatar_url and request and m.avatar_url.startswith('/')) else m.avatar_url,
        "generation": getattr(m, 'generation', None),
        "identityCard": m.cccd,
        "createdAt": created_at_str,
    }


# Alias for backward compatibility
_person_to_flutter = _member_to_flutter


# ===========================================================================
# API ENDPOINTS
# ===========================================================================

@router.get("/", response_model=List[MemberFlutterRead])
def get_all_members(
    request: Request,
    family_id: Optional[int] = Query(None, description="Lọc theo gia phả (tùy chọn)"),
    status: Optional[str] = Query("approved", description="Lọc theo trạng thái phê duyệt (mặc định approved)"),
    db: Session = Depends(get_db),
):
    """Lấy danh sách thành viên chính thức (approved) của gia phả."""
    from sqlalchemy import or_    
    query = db.query(Member)
    if family_id:
        query = query.filter(Member.family_id == family_id)
    if status == "approved":
        query = query.filter(
            or_(Member.status == "approved", Member.status.is_(None)),
            Member.requires_approval != True
        )
    elif status == "pending":
        query = query.filter(
            or_(Member.status == "pending", Member.requires_approval == True)
        )
    elif status != "all":
        query = query.filter(Member.status == status)

    member = query.all()
    return [_member_to_flutter(db, p, request) for p in members]


@router.get("/{member_id}", response_model=MemberFlutterRead)
def get_member_by_id(request: Request, member_id: int, db: Session = Depends(get_db)):
    """Lấy chi tiết một thành viên theo ID."""
    member = db.query(Member).filter(Member.id == member_id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Không tìm thấy thành viên")
    return _member_to_flutter(db, member, request)


@router.post("/", response_model=MemberFlutterRead)
def create_member(request: Request, data: MemberFlutterCreate, db: Session = Depends(get_db)):
    """Thêm thành viên mới từ Flutter app."""
    last_name, first_name = _split_full_name(data.fullName)

    def _safe_int(val):
        try:
            if val is None:
                return None
            s = str(val).strip()
            if s == "":
                return None
            return int(s)
        except Exception:
            return None

    member = Member(
        first_name=first_name,
        last_name=last_name,
        gender=_gender_to_db(data.gender),
        role=data.role or "member",
        date_of_birth=_date_from_vn(data.dateOfBirth),
        date_of_death=_date_from_vn(data.dateOfDeath),
        place_of_birth=data.placeOfBirth,
        phone_number=data.phoneNumber,
        permanent_address=data.permanentAddress or data.currentAddress,
        avatar_url=data.avatarUrl,
        biography=data.notes,
        occupation=data.occupation,
        generation=data.generation,
        place_of_death=data.placeOfDeath,
        cccd=data.identityCard,
        father_id=_safe_int(data.fatherId),
        mother_id=_safe_int(data.motherId),
        family_id=data.familyId,
    )

    db.add(member)
    db.commit()
    db.refresh(member)

    # Sync to Neo4j (best-effort)
    try:
        add_member_to_graph(
            id=member.id,
            full_name=f"{member.last_name or ''} {member.first_name or ''}".strip(),
            gender=member.gender,
            family_id=member.family_id,
            father_id=member.father_id,
            mother_id=member.mother_id,
        )
    except Exception as e:
        print(f"[!] Neo4j sync failed on create: {e}")
    return _member_to_flutter(db, member, request)


@router.put("/{member_id}", response_model=MemberFlutterRead)
def update_member(request: Request, member_id: int, data: MemberFlutterCreate, db: Session = Depends(get_db)):
    """Cập nhật thông tin thành viên."""
    person = db.query(Member).filter(Member.id == member_id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Không tìm thấy thành viên")

    def _safe_int(val):
        try:
            if val is None:
                return None
            s = str(val).strip()
            if s == "":
                return None
            return int(s)
        except Exception:
            return None

    last_name, first_name = _split_full_name(data.fullName)

    member.first_name = first_name
    member.last_name = last_name
    member.gender = _gender_to_db(data.gender)
    if data.role:
        member.role = data.role
    if data.familyId is not None:
        member.family_id = data.familyId
    member.date_of_birth = _date_from_vn(data.dateOfBirth)
    member.date_of_death = _date_from_vn(data.dateOfDeath)
    member.place_of_birth = data.placeOfBirth
    member.phone_number = data.phoneNumber
    member.permanent_address = data.permanentAddress or data.currentAddress
    member.avatar_url = data.avatarUrl
    member.biography = data.notes
    member.occupation = data.occupation
    member.generation = data.generation
    member.place_of_death = data.placeOfDeath
    member.cccd = data.identityCard

    if data.fatherId is not None:
        member.father_id = _safe_int(data.fatherId)
    if data.motherId is not None:
        member.mother_id = _safe_int(data.motherId)
        
    # Đồng bộ avatar sang tài khoản User liên kết nếu có
    if member.user_id and data.avatarUrl:
        u = db.query(User).filter(User.id == member.user_id).first()
        if u:
            u.avatar_url = data.avatarUrl

    db.commit()
    db.refresh(member)

    # Sync to Neo4j: replace node (delete+create) to keep relationships in sync
    try:
        delete_member_from_graph(member.id)
        add_member_to_graph(
            id=member.id,
            full_name=f"{member.last_name or ''} {member.first_name or ''}".strip(),
            gender=member.gender,
            family_id=member.family_id,
            father_id=member.father_id,
            mother_id=member.mother_id,
        )
    except Exception as e:
        print(f"[!] Neo4j sync failed on update: {e}")
    return _member_to_flutter(db, member, request)


@router.delete("/{member_id}")
def delete_member(member_id: int, db: Session = Depends(get_db)):
    """Xóa thành viên theo ID."""
    member = db.query(Member).filter(Member.id == member_id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Không tìm thấy thành viên")

    try:
        # 1. Hủy liên kết cha/mẹ của các con trong gia phả
        db.query(Member).filter(Member.father_id == member_id).update(
            {Member.father_id: None}, synchronize_session=False
        )
        db.query(Member).filter(Member.mother_id == member_id).update(
            {Member.mother_id: None}, synchronize_session=False
        )

        # 2. Xóa các quan hệ trực tiếp (vợ/chồng, v.v.) liên quan tới thành viên này
        db.query(Relationship).filter(
            (Relationship.person1_id == member_id) | (Relationship.person2_id == member_id)
        ).delete(synchronize_session=False)

        # 3. Xóa dữ liệu Face Recognition embeddings nếu có
        db.query(FaceEmbedding).filter(
            FaceEmbedding.member_id == member_id
        ).delete(synchronize_session=False)

        # 4. Xử lý các sự kiện liên kết:
        # - Xóa sự kiện tự động sinh (sinh nhật, ngày giỗ của người này)
        # - Giữ lại sự kiện tùy chỉnh khác nhưng set member_id = None
        db.query(Event).filter(
            Event.member_id == member_id,
            Event.is_auto_generated == 1
        ).delete(synchronize_session=False)
        db.query(Event).filter(
            Event.member_id == member_id
        ).update({Event.member_id: None}, synchronize_session=False)

        # 5. Xử lý các giao dịch thu chi liên kết (giữ lại lịch sử tài chính, chỉ gỡ liên kết member_id)
        db.query(Transaction).filter(
            Transaction.member_id == member_id
        ).update({Transaction.member_id: None}, synchronize_session=False)

        # 6. Xóa bản ghi thành viên khỏi MySQL
        db.delete(member)
        db.commit()
    except Exception as e:
        db.rollback()
        print(f"[!] Lỗi khi xóa thành viên DB ID={member_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Lỗi khi xóa thành viên: {str(e)}")

    # Sync delete to Neo4j (best-effort)
    try:
        delete_person_from_graph(member_id)
    except Exception as e:
        print(f"[!] Neo4j sync failed on delete: {e}")
    return {"detail": f"Đã xóa thành viên ID={member_id}"}

class MemberRoleUpdateRequest(BaseModel):
    role: str  # 'admin', 'editor', 'member'


@router.put("/{member_id}/role")
def update_member_role(member_id: int, data: MemberRoleUpdateRequest, db: Session = Depends(get_db)):
    """Phân quyền hoặc hủy quyền cho thành viên trong gia phả."""
    member = db.query(Member).filter(Member.id == member_id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Không tìm thấy thành viên")

    target_role = data.role.strip().lower()
    if target_role not in ["admin", "editor", "member"]:
        raise HTTPException(status_code=400, detail="Vai trò không hợp lệ (admin, editor, member)")

    member.role = target_role
    db.commit()
    db.refresh(member)
    return {"message": f"Đã cập nhật vai trò thành {target_role}", "role": member.role}


# ---------------------------------------------------------------------------
# Neo4j helpers for debugging / bulk sync
# ---------------------------------------------------------------------------
@router.get('/neo4j/status')
def neo4j_status():
    """Trả về trạng thái kết nối Neo4j (debug endpoint)."""
    return {"connected": getattr(neo4j_conn, 'is_connected', False), "uri": getattr(neo4j_conn, 'uri', None)}


@router.post('/neo4j/resync_family/{family_id}')
def neo4j_resync_family(family_id: int, db: Session = Depends(get_db)):
    """Xoá toàn bộ nodes của family_id trên Neo4j rồi import lại từ MySQL (best-effort).
    Dùng khi cần tái đồng bộ toàn bộ cây gia phả.
    """
    # 1) Delete family in graph
    try:
        delete_family_from_graph(family_id)
    except Exception as e:
        print(f"[!] Neo4j delete_family failed: {e}")

    # 2) Recreate nodes and parent relationships
    members = db.query(Member).filter(Member.family_id == family_id).all()
    for m in members:
        try:
            add_member_to_graph(
                id=m.id,
                full_name=f"{m.last_name or ''} {m.first_name or ''}".strip(),
                gender=m.gender,
                family_id=m.family_id,
                father_id=m.father_id,
                mother_id=m.mother_id,
            )
        except Exception as e:
            print(f"[!] Neo4j add_member failed for {m.id}: {e}")

    # 3) Ensure explicit parent edges (MERGE in create_relationship will dedupe)
    for m in members:
        if m.father_id:
            try:
                create_relationship_in_graph(m.father_id, m.id, 'FATHER_OF')
            except Exception as e:
                print(f"[!] Neo4j create relationship failed: {e}")
        if m.mother_id:
            try:
                create_relationship_in_graph(m.mother_id, m.id, 'MOTHER_OF')
            except Exception as e:
                print(f"[!] Neo4j create relationship failed: {e}")

    return {"detail": f"Resync requested for family_id={family_id}", "count": len(members)}


@router.post('/neo4j/resync_all')
def neo4j_resync_all(db: Session = Depends(get_db)):
    """Đồng bộ lại toàn bộ dữ liệu Member (theo family_id) từ MySQL lên Neo4j.
    Cẩn thận: có thể tốn thời gian với nhiều bản ghi.
    """
    # Lấy danh sách family_id duy nhất
    family_ids = db.query(Member.family_id).distinct().all()
    families = [fid[0] for fid in family_ids if fid[0] is not None]
    total = 0
    for fam in families:
        try:
            delete_family_from_graph(fam)
        except Exception as e:
            print(f"[!] Neo4j delete_family failed for {fam}: {e}")

        members = db.query(Member).filter(Member.family_id == fam).all()
        for m in members:
            try:
                add_person_to_graph(
                    id=m.id,
                    full_name=f"{m.last_name or ''} {m.first_name or ''}".strip(),
                    gender=m.gender,
                    family_id=m.family_id,
                    father_id=m.father_id,
                    mother_id=m.mother_id,
                )
                total += 1
            except Exception as e:
                print(f"[!] Neo4j add_person failed for {m.id}: {e}")

        for m in members:
            if m.father_id:
                try:
                    create_relationship_in_graph(m.father_id, m.id, 'FATHER_OF')
                except Exception as e:
                    print(f"[!] Neo4j create relationship failed: {e}")
            if m.mother_id:
                try:
                    create_relationship_in_graph(m.mother_id, m.id, 'MOTHER_OF')
                except Exception as e:
                    print(f"[!] Neo4j create relationship failed: {e}")

    return {"detail": "Resync all requested", "families": len(families), "nodes_processed": total}
