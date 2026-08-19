# routers/events.py
# API quản lý & tự động đồng bộ sự kiện gia tộc (Sinh nhật, Ngày giỗ, Họp họ, Giỗ tổ...) cho Flutter app
# Phân quyền: Chỉ Admin / Trưởng họ hoặc Biên tập viên (Editor) mới có quyền Thêm, Sửa, Xóa sự kiện. Thành viên thường chỉ xem.

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.orm import Session
from db.mysql_connection import get_db
from models import Event, Member, Family, User
from schemas import EventFlutterRead, EventFlutterCreate
from typing import List, Optional
from datetime import datetime, date
import re

router = APIRouter(prefix="/api/flutter/events", tags=["Flutter Events"])


# ===========================================================================
# 1. HÀM CHUYỂN ĐỔI NGÀY THÁNG & PHÂN QUYỀN
# ===========================================================================

def _date_to_vn(d) -> Optional[str]:
    """Chuyển Date object → dd/MM/yyyy string"""
    if d is None:
        return None
    try:
        return d.strftime("%d/%m/%Y")
    except Exception:
        return str(d)


def _date_from_vn(s: Optional[str]):
    """Chuyển chuỗi dd/MM/yyyy hoặc yyyy-MM-dd → Date object"""
    if not s:
        return None
    try:
        return datetime.strptime(s, "%d/%m/%Y").date()
    except Exception:
        try:
            return datetime.strptime(s, "%Y-%m-%d").date()
        except Exception:
            return None


def _parse_lunar_string(lunar_str: Optional[str]) -> tuple:
    """Trích xuất ngày và tháng âm lịch từ chuỗi mô tả (vd: '15/01', '15/1/2023', '15-01')
    Returns: (day, month, year)
    """
    if not lunar_str:
        return None, None, None
    try:
        nums = re.findall(r'\d+', lunar_str)
        if len(nums) >= 2:
            day = int(nums[0])
            month = int(nums[1])
            year = int(nums[2]) if len(nums) >= 3 else datetime.now().year
            return day, month, year
    except Exception:
        pass
    return None, None, None


def _get_request_user(request: Request, db: Session) -> Optional[User]:
    """Lấy thông tin User hiện tại từ JWT Token hoặc Cookie"""
    auth_header = request.headers.get("Authorization")
    token = None
    if auth_header and auth_header.startswith("Bearer "):
        token = auth_header.split(" ")[1]
    if not token:
        token = request.cookies.get("user_session")
    if not token:
        return None
    try:
        from routers.auth import serializer, SESSION_EXPIRE_SECONDS
        payload = serializer.loads(token, max_age=SESSION_EXPIRE_SECONDS)
        user_id = payload.get("user_id")
        return db.query(User).filter(User.id == user_id).first()
    except Exception:
        return None


def _require_can_manage_events(db: Session, family_id: Optional[int], request: Request):
    """
    Kiểm tra phân quyền:
    Chỉ cho phép Admin hệ thống, Trưởng họ (Family Owner) hoặc Editor trong gia phả thực hiện thêm/sửa/xóa.
    Thành viên thường (Member) sẽ bị chặn 403 Forbidden.
    """
    user = _get_request_user(request, db)
    if not user:
        # Nếu chưa đăng nhập hoặc không gửi token, chặn thao tác
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Vui lòng đăng nhập để thực hiện thao tác quản lý sự kiện."
        )

    # 1. Admin / Owner hệ thống
    if user.role in ["admin", "owner"]:
        return user

    # 2. Trưởng họ (Family Owner)
    if family_id:
        family = db.query(Family).filter(Family.id == family_id).first()
        if family and family.owner_id == user.id:
            return user

        # 3. Editor trong bảng Member của gia phả này
        member = db.query(Member).filter(
            Member.family_id == family_id,
            (Member.user_id == user.id) | ((Member.cccd == user.cccd) & (Member.cccd.isnot(None)))
        ).first()
        if member and member.role in ["admin", "owner", "editor"]:
            return user

    # Chặn nếu là thành viên thông thường (Member)
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Bạn không có quyền thực hiện thao tác này. Chỉ Trưởng họ hoặc Biên tập viên (Editor) mới có quyền thêm, sửa, xóa sự kiện."
    )


def _get_creator_info(db: Session, creator_id: Optional[int], member_id: Optional[int]) -> tuple:
    """Tra cứu tên và avatar của người tạo / người liên kết sự kiện"""
    if member_id:
        member = db.query(Member).filter(Member.id == member_id).first()
        if member:
            return member.full_name, member.avatar_url or ""

    if creator_id:
        user = db.query(User).filter(User.id == creator_id).first()
        if user:
            return user.full_name or user.username, user.avatar_url or ""

    return "Hệ thống Gia phả", ""


def _event_to_flutter(db: Session, event: Event, request: Optional[Request] = None) -> dict:
    """Chuyển đổi Event DB record → dict theo format EventFlutterRead."""

    # 1. Xử lý lunar date
    lunar_date = None
    if event.lunar_day and event.lunar_month:
        lunar_date = {
            "day": event.lunar_day,
            "month": event.lunar_month,
            "year": event.lunar_year or datetime.now().year
        }

    # 2. Format solar date
    solar_date_str = _date_to_vn(event.solar_date) if event.solar_date else None

    # 3. Tạo date range string hiển thị trên thẻ sự kiện
    date_range = ""
    if lunar_date:
        lunar_str = f"{lunar_date['day']:02d}/{lunar_date['month']:02d} Âm lịch"
        if solar_date_str:
            date_range = f"{lunar_str} → {solar_date_str}"
        else:
            date_range = lunar_str
    elif solar_date_str:
        date_range = solar_date_str

    # 4. Format time
    time_str = "08:00 - 11:30"
    if event.time_start and event.time_end:
        time_str = f"{event.time_start} - {event.time_end}"
    elif event.time_start:
        time_str = event.time_start

    # 5. Lấy thông tin creator / member avatar
    creator_name, creator_avatar = _get_creator_info(db, event.creator_id, event.member_id)

    # Chuẩn hóa URL avatar nếu cần
    if creator_avatar and request and creator_avatar.startswith('/'):
        creator_avatar = str(request.base_url).rstrip('/') + creator_avatar

    # 6. ISO date cho Calendar (YYYY-MM-DD)
    iso_date = event.solar_date.isoformat() if event.solar_date else datetime.now().date().isoformat()

    return {
        "id": str(event.id),
        "title": event.title,
        "eventType": event.event_type or "custom",
        "lunarDate": lunar_date,
        "solarDate": solar_date_str,
        "dateRange": date_range,
        "time": time_str,
        "date": iso_date,
        "note": event.note or "",
        "creatorName": creator_name,
        "creatorAvatarUrl": creator_avatar,
        "isNotified": bool(event.is_notified),
        "isAutoGenerated": bool(event.is_auto_generated),
        "memberId": event.member_id,
        "familyId": event.family_id,
        "location": event.location or "",
    }


# ===========================================================================
# 2. LOGIC TỰ ĐỘNG ĐỒNG BỘ TỪ BẢNG MEMBERS (SINH NHẬT & NGÀY GIỖ)
# ===========================================================================

def auto_sync_family_events(db: Session, family_id: int):
    """
    Tự động quét toàn bộ thành viên trong gia phả (bảng `members`):
    1. Thành viên còn sống có date_of_birth -> Đồng bộ sự kiện "Sinh nhật [Họ Tên]"
    2. Thành viên đã mất có date_of_death / lunar_date_of_death -> Đồng bộ sự kiện "Ngày giỗ [Họ Tên]"
    """
    if not family_id:
        return

    current_year = datetime.now().year
    members = db.query(Member).filter(Member.family_id == family_id).all()

    for m in members:
        # A. Xử lý SINH NHẬT cho thành viên còn sống
        is_alive = (m.date_of_death is None and not m.lunar_date_of_death and not m.place_of_death)
        if is_alive and m.date_of_birth:
            try:
                b_month = m.date_of_birth.month
                b_day = m.date_of_birth.day
                if b_month == 2 and b_day == 29:
                    b_day = 28
                birthday_this_year = date(current_year, b_month, b_day)

                existing_evt = db.query(Event).filter(
                    Event.family_id == family_id,
                    Event.member_id == m.id,
                    Event.event_type == "birthday",
                    Event.is_auto_generated == 1
                ).first()

                title = f"Sinh nhật {m.full_name}"
                note = f"Chúc mừng sinh nhật thành viên {m.full_name} (sinh ngày {_date_to_vn(m.date_of_birth)})."

                if existing_evt:
                    existing_evt.title = title
                    existing_evt.solar_date = birthday_this_year
                    existing_evt.note = note
                    existing_evt.updated_at = datetime.now()
                else:
                    new_evt = Event(
                        family_id=family_id,
                        member_id=m.id,
                        title=title,
                        event_type="birthday",
                        solar_date=birthday_this_year,
                        time_start="08:00",
                        time_end="21:00",
                        note=note,
                        is_notified=0,
                        is_auto_generated=1,
                        created_at=datetime.now(),
                        updated_at=datetime.now()
                    )
                    db.add(new_evt)
            except Exception as e:
                print(f"[!] Error syncing birthday for member {m.id}: {e}")

        # B. Xử lý NGÀY GIỖ cho thành viên đã mất
        is_deceased = (m.date_of_death is not None or m.lunar_date_of_death or m.place_of_death)
        if is_deceased:
            try:
                l_day, l_month, l_year = _parse_lunar_string(m.lunar_date_of_death)

                solar_death_date = None
                if m.date_of_death:
                    d_month = m.date_of_death.month
                    d_day = m.date_of_death.day
                    if d_month == 2 and d_day == 29:
                        d_day = 28
                    solar_death_date = date(current_year, d_month, d_day)

                existing_evt = db.query(Event).filter(
                    Event.family_id == family_id,
                    Event.member_id == m.id,
                    Event.event_type == "death_anniversary",
                    Event.is_auto_generated == 1
                ).first()

                title = f"Ngày giỗ {m.full_name}"
                note = f"Lễ giỗ tưởng nhớ {m.full_name}."
                if m.lunar_date_of_death:
                    note += f" (Ngày mất âm lịch: {m.lunar_date_of_death})"

                if existing_evt:
                    existing_evt.title = title
                    existing_evt.solar_date = solar_death_date or existing_evt.solar_date or date(current_year, 1, 1)
                    if l_day and l_month:
                        existing_evt.lunar_day = l_day
                        existing_evt.lunar_month = l_month
                        existing_evt.lunar_year = current_year
                    existing_evt.note = note
                    existing_evt.updated_at = datetime.now()
                else:
                    new_evt = Event(
                        family_id=family_id,
                        member_id=m.id,
                        title=title,
                        event_type="death_anniversary",
                        solar_date=solar_death_date or date(current_year, 1, 1),
                        lunar_day=l_day,
                        lunar_month=l_month,
                        lunar_year=current_year if l_day else None,
                        time_start="09:00",
                        time_end="12:00",
                        note=note,
                        is_notified=0,
                        is_auto_generated=1,
                        created_at=datetime.now(),
                        updated_at=datetime.now()
                    )
                    db.add(new_evt)
            except Exception as e:
                print(f"[!] Error syncing death anniversary for member {m.id}: {e}")

    db.commit()


# ===========================================================================
# 3. API ENDPOINTS (GET/POST/PUT/DELETE)
# ===========================================================================

@router.get("/", response_model=List[EventFlutterRead])
def get_all_events(
    request: Request,
    family_id: Optional[int] = Query(None, description="Lọc theo gia phả"),
    year: Optional[int] = Query(None, description="Lọc theo năm"),
    month: Optional[int] = Query(None, description="Lọc theo tháng"),
    auto_sync: bool = Query(True, description="Tự động đồng bộ từ thành viên"),
    db: Session = Depends(get_db),
):
    """
    Lấy danh sách sự kiện dòng họ (Tất cả thành viên đều có quyền xem).
    Tự động đồng bộ sinh nhật & ngày giỗ từ cơ sở dữ liệu các thành viên (`members`).
    """
    # 1. Tự động đồng bộ nếu có family_id
    if family_id and auto_sync:
        try:
            auto_sync_family_events(db, family_id)
        except Exception as e:
            print(f"[!] Auto-sync events warning: {e}")

    # 2. Truy vấn sự kiện
    query = db.query(Event)
    if family_id:
        query = query.filter(Event.family_id == family_id)

    if year:
        query = query.filter(
            (Event.solar_date.isnot(None)) &
            (Event.solar_date >= date(year, 1, 1)) &
            (Event.solar_date < date(year + 1, 1, 1))
        )

    if month and year:
        if month == 12:
            next_month = date(year + 1, 1, 1)
        else:
            next_month = date(year, month + 1, 1)
        query = query.filter(
            (Event.solar_date >= date(year, month, 1)) &
            (Event.solar_date < next_month)
        )

    events = query.order_by(Event.solar_date.asc(), Event.id.asc()).all()
    return [_event_to_flutter(db, e, request) for e in events]


@router.post("/sync/{family_id}")
def sync_events_for_family(family_id: int, request: Request, db: Session = Depends(get_db)):
    """Kích hoạt đồng bộ thủ công toàn bộ sinh nhật & ngày giỗ cho gia phả (Chỉ Admin & Editor)."""
    _require_can_manage_events(db, family_id, request)

    family = db.query(Family).filter(Family.id == family_id).first()
    if not family:
        raise HTTPException(status_code=404, detail="Không tìm thấy gia phả")

    auto_sync_family_events(db, family_id)
    return {"status": "success", "message": f"Đã đồng bộ sự kiện tự động cho gia phả '{family.name}'"}


@router.get("/{event_id}", response_model=EventFlutterRead)
def get_event_by_id(request: Request, event_id: int, db: Session = Depends(get_db)):
    """Lấy chi tiết một sự kiện theo ID (Mọi thành viên đều xem được)."""
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Không tìm thấy sự kiện")
    return _event_to_flutter(db, event, request)


@router.post("/", response_model=EventFlutterRead)
def create_event(request: Request, data: EventFlutterCreate, db: Session = Depends(get_db)):
    """
    Thêm sự kiện mới từ Flutter app.
    Phân quyền: Chỉ Trưởng họ (Admin) hoặc Biên tập viên (Editor) mới có quyền tạo sự kiện.
    """
    user = _require_can_manage_events(db, data.familyId, request)
    solar_date = _date_from_vn(data.solarDate) if data.solarDate else None

    # Tách giờ nếu truyền dạng "08:00 - 11:30"
    time_start = data.timeStart
    time_end = data.timeEnd
    if data.time and ("-" in data.time):
        parts = data.time.split("-")
        time_start = parts[0].strip()
        time_end = parts[1].strip()
    elif data.time:
        time_start = data.time.strip()

    creator_id = user.id if user else data.creatorId

    event = Event(
        family_id=data.familyId,
        member_id=data.memberId,
        title=data.title,
        event_type=data.eventType or "custom",
        lunar_day=data.lunarDay,
        lunar_month=data.lunarMonth,
        lunar_year=data.lunarYear,
        solar_date=solar_date,
        time_start=time_start,
        time_end=time_end,
        location=data.location,
        note=data.note,
        creator_id=creator_id,
        is_notified=0,
        is_auto_generated=0,
        created_at=datetime.now(),
        updated_at=datetime.now(),
    )

    db.add(event)
    db.commit()
    db.refresh(event)

    return _event_to_flutter(db, event, request)


@router.put("/{event_id}", response_model=EventFlutterRead)
def update_event(
    request: Request,
    event_id: int,
    data: EventFlutterCreate,
    db: Session = Depends(get_db)
):
    """
    Cập nhật thông tin sự kiện.
    Phân quyền: Chỉ Trưởng họ (Admin) hoặc Biên tập viên (Editor) mới có quyền chỉnh sửa sự kiện.
    """
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Không tìm thấy sự kiện")

    _require_can_manage_events(db, event.family_id, request)

    # Tách giờ nếu có
    time_start = data.timeStart or event.time_start
    time_end = data.timeEnd or event.time_end
    if data.time and ("-" in data.time):
        parts = data.time.split("-")
        time_start = parts[0].strip()
        time_end = parts[1].strip()
    elif data.time:
        time_start = data.time.strip()

    # Cập nhật các trường
    event.title = data.title
    if data.eventType:
        event.event_type = data.eventType
    event.lunar_day = data.lunarDay
    event.lunar_month = data.lunarMonth
    event.lunar_year = data.lunarYear
    if data.solarDate:
        event.solar_date = _date_from_vn(data.solarDate)
    event.time_start = time_start
    event.time_end = time_end
    if data.location is not None:
        event.location = data.location
    if data.note is not None:
        event.note = data.note
    event.updated_at = datetime.now()

    db.commit()
    db.refresh(event)

    return _event_to_flutter(db, event, request)


@router.delete("/{event_id}")
def delete_event(request: Request, event_id: int, db: Session = Depends(get_db)):
    """
    Xóa sự kiện theo ID.
    Phân quyền: Chỉ Trưởng họ (Admin) hoặc Biên tập viên (Editor) mới có quyền xóa sự kiện.
    """
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Không tìm thấy sự kiện")

    _require_can_manage_events(db, event.family_id, request)

    db.delete(event)
    db.commit()

    return {"detail": f"Đã xóa sự kiện ID={event_id}"}


@router.patch("/{event_id}/notify")
def mark_event_notified(event_id: int, db: Session = Depends(get_db)):
    """Đánh dấu sự kiện đã được thông báo."""
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Không tìm thấy sự kiện")

    event.is_notified = 1
    event.updated_at = datetime.now()
    db.commit()

    return {"detail": f"Đã đánh dấu sự kiện ID={event_id} là đã thông báo"}


@router.get("/upcoming/all", response_model=List[EventFlutterRead])
def get_upcoming_events(
    request: Request,
    family_id: Optional[int] = Query(None, description="Lọc theo gia phả"),
    days: int = Query(30, description="Số ngày tới cần lấy sự kiện"),
    db: Session = Depends(get_db),
):
    """Lấy danh sách sự kiện sắp tới trong X ngày (Tất cả thành viên đều xem được)."""
    from datetime import timedelta

    today = datetime.now().date()
    end_date = today + timedelta(days=days)

    if family_id:
        try:
            auto_sync_family_events(db, family_id)
        except Exception:
            pass

    query = db.query(Event).filter(
        Event.solar_date.isnot(None),
        Event.solar_date >= today,
        Event.solar_date <= end_date
    )

    if family_id:
        query = query.filter(Event.family_id == family_id)

    events = query.order_by(Event.solar_date.asc()).all()
    return [_event_to_flutter(db, e, request) for e in events]
