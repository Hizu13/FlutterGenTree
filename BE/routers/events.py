# routers/events.py
# API quản lý sự kiện gia đình cho Flutter app
# Xử lý sự kiện như: Giỗ tổ, họp họ, lễ tảo mộ, sinh nhật...

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session
from db.mysql_connection import get_db
from models import Event, Person
from schemas import EventFlutterRead, EventFlutterCreate
from typing import List, Optional
from datetime import datetime

router = APIRouter(prefix="/api/flutter/events", tags=["Flutter Events"])


# ===========================================================================
# HÀM CHUYỂN ĐỔI DỮ LIỆU (CONVERTER)
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


def _get_person_info(db: Session, person_id: Optional[int]) -> tuple:
    """Tra cứu thông tin người tạo sự kiện từ DB
    Returns: (full_name, avatar_url)
    """
    if person_id is None:
        return "", ""
    
    person = db.query(Person).filter(Person.id == person_id).first()
    if person:
        full_name = f"{person.last_name or ''} {person.first_name or ''}".strip()
        avatar_url = person.avatar_url or ""
        return full_name, avatar_url
    return "", ""


def _event_to_flutter(db: Session, event: Event, request: Optional[Request] = None) -> dict:
    """Chuyển đổi Event DB record → dict theo format EventFlutterRead."""
    
    # Xử lý lunar date
    lunar_date = None
    if event.lunar_day and event.lunar_month and event.lunar_year:
        lunar_date = {
            "day": event.lunar_day,
            "month": event.lunar_month,
            "year": event.lunar_year
        }
    
    # Format solar date
    solar_date_str = _date_to_vn(event.solar_date) if event.solar_date else None
    
    # Tạo date range string
    date_range = ""
    if lunar_date:
        lunar_str = f"{lunar_date['day']:02d}/{lunar_date['month']:02d} Âm lịch"
        if solar_date_str:
            date_range = f"{lunar_str} → {solar_date_str}"
        else:
            date_range = lunar_str
    elif solar_date_str:
        date_range = solar_date_str
    
    # Format time
    time_str = ""
    if event.time_start and event.time_end:
        time_str = f"{event.time_start} - {event.time_end}"
    elif event.time_start:
        time_str = event.time_start
    
    # Lấy thông tin creator
    creator_name, creator_avatar = _get_person_info(db, event.creator_id)
    
    # Adjust avatar URL to full path if needed
    if creator_avatar and request and creator_avatar.startswith('/'):
        creator_avatar = str(request.base_url).rstrip('/') + creator_avatar
    
    # ISO date for calendar (use solar_date or current date as fallback)
    iso_date = event.solar_date.isoformat() if event.solar_date else datetime.now().date().isoformat()
    
    return {
        "id": str(event.id),
        "title": event.title,
        "lunarDate": lunar_date,
        "solarDate": solar_date_str,
        "dateRange": date_range,
        "time": time_str,
        "date": iso_date,
        "note": event.note or "",
        "creatorName": creator_name,
        "creatorAvatarUrl": creator_avatar,
        "isNotified": bool(event.is_notified),
    }


# ===========================================================================
# API ENDPOINTS
# ===========================================================================

@router.get("/", response_model=List[EventFlutterRead])
def get_all_events(
    request: Request,
    family_id: Optional[int] = Query(None, description="Lọc theo gia phả (tùy chọn)"),
    year: Optional[int] = Query(None, description="Lọc theo năm (tùy chọn)"),
    month: Optional[int] = Query(None, description="Lọc theo tháng (tùy chọn)"),
    db: Session = Depends(get_db),
):
    """Lấy toàn bộ danh sách sự kiện. Có thể lọc theo gia phả, năm, tháng."""
    query = db.query(Event)
    
    if family_id:
        query = query.filter(Event.family_id == family_id)
    
    # Filter by year/month if provided
    if year:
        query = query.filter(
            (Event.solar_date.isnot(None)) &
            (Event.solar_date >= datetime(year, 1, 1).date()) &
            (Event.solar_date < datetime(year + 1, 1, 1).date())
        )
    
    if month and year:
        if month == 12:
            next_month = datetime(year + 1, 1, 1).date()
        else:
            next_month = datetime(year, month + 1, 1).date()
        query = query.filter(
            (Event.solar_date >= datetime(year, month, 1).date()) &
            (Event.solar_date < next_month)
        )
    
    events = query.order_by(Event.solar_date.desc()).all()
    return [_event_to_flutter(db, e, request) for e in events]


@router.get("/{event_id}", response_model=EventFlutterRead)
def get_event_by_id(request: Request, event_id: int, db: Session = Depends(get_db)):
    """Lấy chi tiết một sự kiện theo ID."""
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Không tìm thấy sự kiện")
    return _event_to_flutter(db, event, request)


@router.post("/", response_model=EventFlutterRead)
def create_event(request: Request, data: EventFlutterCreate, db: Session = Depends(get_db)):
    """Thêm sự kiện mới từ Flutter app."""
    
    # Parse solar date
    solar_date = _date_from_vn(data.solarDate) if data.solarDate else None
    
    event = Event(
        family_id=data.familyId,
        title=data.title,
        lunar_day=data.lunarDay,
        lunar_month=data.lunarMonth,
        lunar_year=data.lunarYear,
        solar_date=solar_date,
        time_start=data.timeStart,
        time_end=data.timeEnd,
        note=data.note,
        creator_id=data.creatorId,
        is_notified=0,
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
    """Cập nhật thông tin sự kiện."""
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Không tìm thấy sự kiện")
    
    # Update fields
    event.title = data.title
    event.lunar_day = data.lunarDay
    event.lunar_month = data.lunarMonth
    event.lunar_year = data.lunarYear
    event.solar_date = _date_from_vn(data.solarDate) if data.solarDate else None
    event.time_start = data.timeStart
    event.time_end = data.timeEnd
    event.note = data.note
    event.updated_at = datetime.now()
    
    db.commit()
    db.refresh(event)
    
    return _event_to_flutter(db, event, request)


@router.delete("/{event_id}")
def delete_event(event_id: int, db: Session = Depends(get_db)):
    """Xóa sự kiện theo ID."""
    event = db.query(Event).filter(Event.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Không tìm thấy sự kiện")
    
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
    """Lấy danh sách sự kiện sắp tới trong X ngày."""
    from datetime import timedelta
    
    today = datetime.now().date()
    end_date = today + timedelta(days=days)
    
    query = db.query(Event).filter(
        Event.solar_date.isnot(None),
        Event.solar_date >= today,
        Event.solar_date <= end_date
    )
    
    if family_id:
        query = query.filter(Event.family_id == family_id)
    
    events = query.order_by(Event.solar_date.asc()).all()
    return [_event_to_flutter(db, e, request) for e in events]
