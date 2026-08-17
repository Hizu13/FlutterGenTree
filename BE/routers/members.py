# routers/flutter_members.py
# API chuyên dụng cho Flutter app - không yêu cầu xác thực (development mode)
# Tự động chuyển đổi giữa format backend (snake_case, male/female, Date)
# và format Flutter (camelCase, Nam/Nữ, dd/MM/yyyy)

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session
from db.mysql_connection import get_db
from models import Person
from schemas import MemberFlutterRead, MemberFlutterCreate
from typing import List, Optional
from datetime import datetime
from db.neo4j_connection import (
    add_person_to_graph,
    delete_person_from_graph,
    delete_family_from_graph,
    create_relationship_in_graph,
    neo4j_conn,
)

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
    parent = db.query(Person).filter(Person.id == parent_id).first()
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


def _person_to_flutter(db: Session, p: Person, request: Optional[Request] = None) -> dict:
    """Chuyển đổi Person DB record → dict theo format MemberFlutterRead."""
    full_name = f"{p.last_name or ''} {p.first_name or ''}".strip()

    # Xác định status từ date_of_death
    status = "Đã mất" if p.date_of_death else "Còn sống"

    return {
        "id": str(p.id),
        "fullName": full_name,
        "gender": _gender_to_vn(p.gender),
        "status": status,
        "dateOfBirth": _date_to_vn(p.date_of_birth),
        "placeOfBirth": p.place_of_birth,
        "fatherId": str(p.father_id) if p.father_id else None,
        "fatherName": _get_parent_name(db, p.father_id),
        "motherId": str(p.mother_id) if p.mother_id else None,
        "motherName": _get_parent_name(db, p.mother_id),
        "phoneNumber": p.phone_number,
        "email": getattr(p, 'email', None),
        "currentAddress": p.permanent_address,
        "dateOfDeath": _date_to_vn(p.date_of_death),
        "placeOfDeath": getattr(p, 'place_of_death', None),
        "occupation": getattr(p, 'occupation', None),
        "notes": p.biography,
        "avatarUrl": (str(request.base_url).rstrip('/') + p.avatar_url) if (p.avatar_url and request and p.avatar_url.startswith('/')) else p.avatar_url,
        "generation": getattr(p, 'generation', None),
        "identityCard": p.cccd,
    }


# ===========================================================================
# API ENDPOINTS
# ===========================================================================

@router.get("/", response_model=List[MemberFlutterRead])
def get_all_members(
    request: Request,
    family_id: Optional[int] = Query(None, description="Lọc theo gia phả (tùy chọn)"),
    db: Session = Depends(get_db),
):
    """Lấy toàn bộ danh sách thành viên. Nếu có family_id thì lọc theo gia phả."""
    query = db.query(Person)
    if family_id:
        query = query.filter(Person.family_id == family_id)

    persons = query.all()
    return [_person_to_flutter(db, p, request) for p in persons]


@router.get("/{member_id}", response_model=MemberFlutterRead)
def get_member_by_id(request: Request, member_id: int, db: Session = Depends(get_db)):
    """Lấy chi tiết một thành viên theo ID."""
    person = db.query(Person).filter(Person.id == member_id).first()
    if not person:
        raise HTTPException(status_code=404, detail="Không tìm thấy thành viên")
    return _person_to_flutter(db, person, request)


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

    person = Person(
        first_name=first_name,
        last_name=last_name,
        gender=_gender_to_db(data.gender),
        date_of_birth=_date_from_vn(data.dateOfBirth),
        date_of_death=_date_from_vn(data.dateOfDeath),
        place_of_birth=data.placeOfBirth,
        phone_number=data.phoneNumber,
        permanent_address=data.currentAddress,
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

    db.add(person)
    db.commit()
    db.refresh(person)

    # Sync to Neo4j (best-effort)
    try:
        add_person_to_graph(
            id=person.id,
            full_name=f"{person.last_name or ''} {person.first_name or ''}".strip(),
            gender=person.gender,
            family_id=person.family_id,
            father_id=person.father_id,
            mother_id=person.mother_id,
        )
    except Exception as e:
        print(f"[!] Neo4j sync failed on create: {e}")
    return _person_to_flutter(db, person, request)


@router.put("/{member_id}", response_model=MemberFlutterRead)
def update_member(request: Request, member_id: int, data: MemberFlutterCreate, db: Session = Depends(get_db)):
    """Cập nhật thông tin thành viên."""
    person = db.query(Person).filter(Person.id == member_id).first()
    if not person:
        raise HTTPException(status_code=404, detail="Không tìm thấy thành viên")

    last_name, first_name = _split_full_name(data.fullName)

    person.first_name = first_name
    person.last_name = last_name
    person.gender = _gender_to_db(data.gender)
    person.date_of_birth = _date_from_vn(data.dateOfBirth)
    person.date_of_death = _date_from_vn(data.dateOfDeath)
    person.place_of_birth = data.placeOfBirth
    person.phone_number = data.phoneNumber
    person.permanent_address = data.currentAddress
    person.avatar_url = data.avatarUrl
    person.biography = data.notes
    person.occupation = data.occupation
    person.generation = data.generation
    person.place_of_death = data.placeOfDeath
    person.cccd = data.identityCard

    if data.fatherId is not None:
        person.father_id = _safe_int(data.fatherId)
    if data.motherId is not None:
        person.mother_id = _safe_int(data.motherId)

    db.commit()
    db.refresh(person)

    # Sync to Neo4j: replace node (delete+create) to keep relationships in sync
    try:
        delete_person_from_graph(person.id)
        add_person_to_graph(
            id=person.id,
            full_name=f"{person.last_name or ''} {person.first_name or ''}".strip(),
            gender=person.gender,
            family_id=person.family_id,
            father_id=person.father_id,
            mother_id=person.mother_id,
        )
    except Exception as e:
        print(f"[!] Neo4j sync failed on update: {e}")
    return _person_to_flutter(db, person, request)


@router.delete("/{member_id}")
def delete_member(member_id: int, db: Session = Depends(get_db)):
    """Xóa thành viên theo ID."""
    person = db.query(Person).filter(Person.id == member_id).first()
    if not person:
        raise HTTPException(status_code=404, detail="Không tìm thấy thành viên")

    # Xóa các liên kết cha/mẹ của con cái trước khi xóa
    children = db.query(Person).filter(
        (Person.father_id == member_id) | (Person.mother_id == member_id)
    ).all()
    for child in children:
        if child.father_id == member_id:
            child.father_id = None
        if child.mother_id == member_id:
            child.mother_id = None

    db.delete(person)
    db.commit()

    # Sync delete to Neo4j (best-effort)
    try:
        delete_person_from_graph(member_id)
    except Exception as e:
        print(f"[!] Neo4j sync failed on delete: {e}")
    return {"detail": f"Đã xóa thành viên ID={member_id}"}


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
    persons = db.query(Person).filter(Person.family_id == family_id).all()
    for p in persons:
        try:
            add_person_to_graph(
                id=p.id,
                full_name=f"{p.last_name or ''} {p.first_name or ''}".strip(),
                gender=p.gender,
                family_id=p.family_id,
                father_id=p.father_id,
                mother_id=p.mother_id,
            )
        except Exception as e:
            print(f"[!] Neo4j add_person failed for {p.id}: {e}")

    # 3) Ensure explicit parent edges (MERGE in create_relationship will dedupe)
    for p in persons:
        if p.father_id:
            try:
                create_relationship_in_graph(p.father_id, p.id, 'FATHER_OF')
            except Exception as e:
                print(f"[!] Neo4j create relationship failed: {e}")
        if p.mother_id:
            try:
                create_relationship_in_graph(p.mother_id, p.id, 'MOTHER_OF')
            except Exception as e:
                print(f"[!] Neo4j create relationship failed: {e}")

    return {"detail": f"Resync requested for family_id={family_id}", "count": len(persons)}


@router.post('/neo4j/resync_all')
def neo4j_resync_all(db: Session = Depends(get_db)):
    """Đồng bộ lại toàn bộ dữ liệu Person (theo family_id) từ MySQL lên Neo4j.
    Cẩn thận: có thể tốn thời gian với nhiều bản ghi.
    """
    # Lấy danh sách family_id duy nhất
    family_ids = db.query(Person.family_id).distinct().all()
    families = [fid[0] for fid in family_ids if fid[0] is not None]
    total = 0
    for fam in families:
        try:
            delete_family_from_graph(fam)
        except Exception as e:
            print(f"[!] Neo4j delete_family failed for {fam}: {e}")

        persons = db.query(Person).filter(Person.family_id == fam).all()
        for p in persons:
            try:
                add_person_to_graph(
                    id=p.id,
                    full_name=f"{p.last_name or ''} {p.first_name or ''}".strip(),
                    gender=p.gender,
                    family_id=p.family_id,
                    father_id=p.father_id,
                    mother_id=p.mother_id,
                )
                total += 1
            except Exception as e:
                print(f"[!] Neo4j add_person failed for {p.id}: {e}")

        for p in persons:
            if p.father_id:
                try:
                    create_relationship_in_graph(p.father_id, p.id, 'FATHER_OF')
                except Exception as e:
                    print(f"[!] Neo4j create relationship failed: {e}")
            if p.mother_id:
                try:
                    create_relationship_in_graph(p.mother_id, p.id, 'MOTHER_OF')
                except Exception as e:
                    print(f"[!] Neo4j create relationship failed: {e}")

    return {"detail": "Resync all requested", "families": len(families), "nodes_processed": total}
