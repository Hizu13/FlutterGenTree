# routers/finance.py
# API quản lý tài chính gia phả cho Flutter app
# Xử lý các giao dịch: Thu, Chi, Công đức

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session
from db.mysql_connection import get_db
from models import Transaction, Person
from schemas import TransactionFlutterRead, TransactionFlutterCreate
from typing import List, Optional
from datetime import datetime

router = APIRouter(prefix="/api/flutter/finance", tags=["Flutter Finance"])


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


def _get_person_name(db: Session, person_id: Optional[int]) -> str:
    """Tra cứu tên người từ DB"""
    if person_id is None:
        return "Không rõ"
    
    person = db.query(Person).filter(Person.id == person_id).first()
    if person:
        return f"{person.last_name or ''} {person.first_name or ''}".strip()
    return "Không rõ"


def _transaction_type_to_vn(type_str: str) -> str:
    """Chuyển đổi type sang tiếng Việt cho hiển thị"""
    mapping = {
        "income": "Thu",
        "expense": "Chi",
        "merit": "Công đức"
    }
    return mapping.get(type_str, type_str)


def _transaction_to_flutter(db: Session, txn: Transaction, request: Optional[Request] = None) -> dict:
    """Chuyển đổi Transaction DB record → dict theo format TransactionFlutterRead."""
    
    person_name = _get_person_name(db, txn.person_id)
    
    # ISO date for sorting/filtering
    iso_date = txn.transaction_date.isoformat() if txn.transaction_date else datetime.now().date().isoformat()
    
    return {
        "id": str(txn.id),
        "title": txn.title,
        "amount": float(txn.amount),
        "type": txn.type.value if hasattr(txn.type, 'value') else txn.type,  # Handle enum
        "personName": person_name,
        "category": txn.category or "Khác",
        "date": iso_date,
        "note": txn.note or "",
        "requiresApproval": bool(txn.requires_approval),
    }


# ===========================================================================
# API ENDPOINTS
# ===========================================================================

@router.get("/", response_model=List[TransactionFlutterRead])
def get_all_transactions(
    request: Request,
    family_id: Optional[int] = Query(None, description="Lọc theo gia phả (tùy chọn)"),
    type: Optional[str] = Query(None, description="Lọc theo loại: income, expense, merit"),
    start_date: Optional[str] = Query(None, description="Từ ngày (dd/MM/yyyy)"),
    end_date: Optional[str] = Query(None, description="Đến ngày (dd/MM/yyyy)"),
    db: Session = Depends(get_db),
):
    """Lấy toàn bộ danh sách giao dịch. Có thể lọc theo gia phả, loại, khoảng thời gian."""
    query = db.query(Transaction)
    
    if family_id:
        query = query.filter(Transaction.family_id == family_id)
    
    if type and type in ["income", "expense", "merit"]:
        query = query.filter(Transaction.type == type)
    
    if start_date:
        start = _date_from_vn(start_date)
        if start:
            query = query.filter(Transaction.transaction_date >= start)
    
    if end_date:
        end = _date_from_vn(end_date)
        if end:
            query = query.filter(Transaction.transaction_date <= end)
    
    transactions = query.order_by(Transaction.transaction_date.desc()).all()
    return [_transaction_to_flutter(db, t, request) for t in transactions]


@router.get("/summary")
def get_financial_summary(
    family_id: Optional[int] = Query(None, description="Lọc theo gia phả"),
    start_date: Optional[str] = Query(None, description="Từ ngày (dd/MM/yyyy)"),
    end_date: Optional[str] = Query(None, description="Đến ngày (dd/MM/yyyy)"),
    db: Session = Depends(get_db),
):
    """Lấy tổng hợp tài chính: Tổng thu, tổng chi, tổng công đức, số dư."""
    from sqlalchemy import func
    
    query = db.query(Transaction)
    
    if family_id:
        query = query.filter(Transaction.family_id == family_id)
    
    if start_date:
        start = _date_from_vn(start_date)
        if start:
            query = query.filter(Transaction.transaction_date >= start)
    
    if end_date:
        end = _date_from_vn(end_date)
        if end:
            query = query.filter(Transaction.transaction_date <= end)
    
    # Calculate totals by type
    income_total = query.filter(Transaction.type == "income").with_entities(
        func.coalesce(func.sum(Transaction.amount), 0)
    ).scalar() or 0
    
    expense_total = query.filter(Transaction.type == "expense").with_entities(
        func.coalesce(func.sum(Transaction.amount), 0)
    ).scalar() or 0
    
    merit_total = query.filter(Transaction.type == "merit").with_entities(
        func.coalesce(func.sum(Transaction.amount), 0)
    ).scalar() or 0
    
    balance = income_total - expense_total
    
    return {
        "totalIncome": float(income_total),
        "totalExpense": float(expense_total),
        "totalMerit": float(merit_total),
        "balance": float(balance),
        "currency": "VNĐ"
    }


@router.get("/{transaction_id}", response_model=TransactionFlutterRead)
def get_transaction_by_id(request: Request, transaction_id: int, db: Session = Depends(get_db)):
    """Lấy chi tiết một giao dịch theo ID."""
    transaction = db.query(Transaction).filter(Transaction.id == transaction_id).first()
    if not transaction:
        raise HTTPException(status_code=404, detail="Không tìm thấy giao dịch")
    return _transaction_to_flutter(db, transaction, request)


@router.post("/", response_model=TransactionFlutterRead)
def create_transaction(request: Request, data: TransactionFlutterCreate, db: Session = Depends(get_db)):
    """Thêm giao dịch mới từ Flutter app."""
    
    # Validate type
    if data.type not in ["income", "expense", "merit"]:
        raise HTTPException(status_code=400, detail="Loại giao dịch không hợp lệ")
    
    # Parse date
    transaction_date = _date_from_vn(data.date)
    if not transaction_date:
        transaction_date = datetime.now().date()
    
    transaction = Transaction(
        family_id=data.familyId,
        person_id=data.personId,
        title=data.title,
        amount=int(data.amount),
        type=data.type,
        category=data.category,
        transaction_date=transaction_date,
        note=data.note,
        requires_approval=1 if data.requiresApproval else 0,
        is_approved=0 if data.requiresApproval else 1,  # Nếu cần duyệt thì chưa duyệt
        created_at=datetime.now(),
        updated_at=datetime.now(),
    )
    
    db.add(transaction)
    db.commit()
    db.refresh(transaction)
    
    return _transaction_to_flutter(db, transaction, request)


@router.put("/{transaction_id}", response_model=TransactionFlutterRead)
def update_transaction(
    request: Request,
    transaction_id: int,
    data: TransactionFlutterCreate,
    db: Session = Depends(get_db)
):
    """Cập nhật thông tin giao dịch."""
    transaction = db.query(Transaction).filter(Transaction.id == transaction_id).first()
    if not transaction:
        raise HTTPException(status_code=404, detail="Không tìm thấy giao dịch")
    
    # Validate type
    if data.type not in ["income", "expense", "merit"]:
        raise HTTPException(status_code=400, detail="Loại giao dịch không hợp lệ")
    
    # Parse date
    transaction_date = _date_from_vn(data.date)
    if not transaction_date:
        transaction_date = datetime.now().date()
    
    # Update fields
    transaction.title = data.title
    transaction.amount = int(data.amount)
    transaction.type = data.type
    transaction.category = data.category
    transaction.transaction_date = transaction_date
    transaction.note = data.note
    transaction.requires_approval = 1 if data.requiresApproval else 0
    transaction.updated_at = datetime.now()
    
    db.commit()
    db.refresh(transaction)
    
    return _transaction_to_flutter(db, transaction, request)


@router.delete("/{transaction_id}")
def delete_transaction(transaction_id: int, db: Session = Depends(get_db)):
    """Xóa giao dịch theo ID."""
    transaction = db.query(Transaction).filter(Transaction.id == transaction_id).first()
    if not transaction:
        raise HTTPException(status_code=404, detail="Không tìm thấy giao dịch")
    
    db.delete(transaction)
    db.commit()
    
    return {"detail": f"Đã xóa giao dịch ID={transaction_id}"}


@router.patch("/{transaction_id}/approve")
def approve_transaction(
    transaction_id: int,
    approver_id: int = Query(..., description="ID người phê duyệt"),
    db: Session = Depends(get_db)
):
    """Phê duyệt một giao dịch."""
    transaction = db.query(Transaction).filter(Transaction.id == transaction_id).first()
    if not transaction:
        raise HTTPException(status_code=404, detail="Không tìm thấy giao dịch")
    
    if not transaction.requires_approval:
        raise HTTPException(status_code=400, detail="Giao dịch này không cần phê duyệt")
    
    transaction.is_approved = 1
    transaction.approved_by = approver_id
    transaction.updated_at = datetime.now()
    db.commit()
    
    return {"detail": f"Đã phê duyệt giao dịch ID={transaction_id}"}


@router.get("/by-category/summary")
def get_category_summary(
    family_id: Optional[int] = Query(None, description="Lọc theo gia phả"),
    type: Optional[str] = Query(None, description="Lọc theo loại: income, expense, merit"),
    start_date: Optional[str] = Query(None, description="Từ ngày (dd/MM/yyyy)"),
    end_date: Optional[str] = Query(None, description="Đến ngày (dd/MM/yyyy)"),
    db: Session = Depends(get_db),
):
    """Lấy tổng hợp chi tiêu theo danh mục."""
    from sqlalchemy import func
    
    query = db.query(
        Transaction.category,
        func.sum(Transaction.amount).label('total'),
        func.count(Transaction.id).label('count')
    )
    
    if family_id:
        query = query.filter(Transaction.family_id == family_id)
    
    if type and type in ["income", "expense", "merit"]:
        query = query.filter(Transaction.type == type)
    
    if start_date:
        start = _date_from_vn(start_date)
        if start:
            query = query.filter(Transaction.transaction_date >= start)
    
    if end_date:
        end = _date_from_vn(end_date)
        if end:
            query = query.filter(Transaction.transaction_date <= end)
    
    results = query.group_by(Transaction.category).all()
    
    return [
        {
            "category": r.category or "Khác",
            "total": float(r.total),
            "count": r.count
        }
        for r in results
    ]
