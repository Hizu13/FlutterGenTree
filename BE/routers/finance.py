"""
================================================================================
FINANCE ROUTER (API THU CHI & QUỸ DÒNG HỌ FLUTTER)
================================================================================
Quản lý các khoản thu, chi, công đức của gia tộc:
- Admin / Trưởng họ / Editor: Thêm trực tiếp, duyệt hoặc từ chối yêu cầu, sửa, xóa giao dịch.
- Thành viên thường (Member): Xem danh sách thu chi, tạo yêu cầu thêm khoản thu / chi / công đức (trạng thái pending chờ duyệt).
"""

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional
from datetime import datetime, date

from db.mysql_connection import get_db
from models import Transaction, Family, Member, User
from schemas import (
    TransactionCreateFlutter,
    TransactionReadFlutter,
    FinanceSummary,
)

router = APIRouter(prefix="/api/flutter/finance", tags=["Finance (Flutter)"])


def _get_request_user(request: Request, db: Session) -> Optional[User]:
    """Lấy thông tin User hiện tại từ JWT Token hoặc Cookie."""
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


def _check_user_can_manage(db: Session, family_id: Optional[int], user: Optional[User]) -> bool:
    """Kiểm tra quyền Quản trị / Biên tập của User đối với gia phả."""
    if not user:
        return False
    if (user.role or "").lower() in ["admin", "owner"]:
        return True

    if family_id:
        family = db.query(Family).filter(Family.id == family_id).first()
        if family and family.owner_id == user.id:
            return True

        member = db.query(Member).filter(
            Member.family_id == family_id,
            Member.user_id == user.id
        ).first()
        if member and (member.role or "").lower() in ["admin", "owner", "editor"]:
            return True

    return False


def _transaction_to_flutter(t: Transaction) -> TransactionReadFlutter:
    """Chuyển đổi ORM Transaction sang DTO Flutter."""
    iso_date = t.date.isoformat() if t.date else datetime.now().date().isoformat()
    return TransactionReadFlutter(
        id=str(t.id),
        title=t.title,
        amount=float(t.amount or 0),
        type=t.type or "income",
        personName=t.person_name or "Thành viên",
        category=t.category or "",
        date=iso_date,
        note=t.note or "",
        status=t.status or "approved",
        requiresApproval=bool(t.requires_approval),
        familyId=t.family_id,
        memberId=t.member_id,
        createdById=t.created_by_user_id,
    )


@router.get("/", response_model=List[TransactionReadFlutter])
def get_transactions(
    request: Request,
    family_id: Optional[int] = Query(None, description="ID dòng họ"),
    type: Optional[str] = Query(None, description="Loại giao dịch: all, income, expense, merit"),
    start_date: Optional[str] = Query(None, description="Từ ngày (YYYY-MM-DD)"),
    end_date: Optional[str] = Query(None, description="Đến ngày (YYYY-MM-DD)"),
    search: Optional[str] = Query(None, description="Từ khóa tìm kiếm"),
    status: Optional[str] = Query(None, description="Trạng thái: approved, pending, rejected"),
    db: Session = Depends(get_db),
):
    """
    Lấy danh sách các giao dịch thu chi của gia phả.
    Hỗ trợ lọc theo loại, khoảng thời gian, từ khóa tìm kiếm và trạng thái duyệt.
    """
    query = db.query(Transaction)

    if family_id:
        query = query.filter(Transaction.family_id == family_id)

    if type and type.lower() != "all":
        query = query.filter(Transaction.type == type.lower())

    if status:
        query = query.filter(Transaction.status == status)

    if start_date:
        try:
            sd = date.fromisoformat(start_date)
            query = query.filter(Transaction.date >= sd)
        except ValueError:
            pass

    if end_date:
        try:
            ed = date.fromisoformat(end_date)
            query = query.filter(Transaction.date <= ed)
        except ValueError:
            pass

    if search:
        kw = f"%{search.strip()}%"
        query = query.filter(
            (Transaction.title.ilike(kw)) |
            (Transaction.person_name.ilike(kw)) |
            (Transaction.category.ilike(kw)) |
            (Transaction.note.ilike(kw))
        )

    # Sắp xếp mới nhất lên đầu
    transactions = query.order_by(Transaction.date.desc(), Transaction.id.desc()).all()
    return [_transaction_to_flutter(t) for t in transactions]


@router.get("/summary", response_model=FinanceSummary)
def get_finance_summary(
    family_id: int = Query(..., description="ID dòng họ"),
    db: Session = Depends(get_db),
):
    """
    Lấy tổng kết Quỹ gia tộc: Tổng số dư, Tổng thu, Tổng chi, Tổng công đức.
    (Chỉ tính các giao dịch đã được phê duyệt 'approved').
    """
    approved_query = db.query(Transaction).filter(
        Transaction.family_id == family_id,
        Transaction.status == "approved"
    )

    # Tính tổng thu (income)
    income_val = approved_query.filter(Transaction.type == "income").with_entities(
        func.coalesce(func.sum(Transaction.amount), 0.0)
    ).scalar() or 0.0

    # Tính tổng chi (expense)
    expense_val = approved_query.filter(Transaction.type == "expense").with_entities(
        func.coalesce(func.sum(Transaction.amount), 0.0)
    ).scalar() or 0.0

    # Tính tổng công đức (merit)
    merit_val = approved_query.filter(Transaction.type == "merit").with_entities(
        func.coalesce(func.sum(Transaction.amount), 0.0)
    ).scalar() or 0.0

    count_val = approved_query.count()

    total_balance = float(income_val + merit_val - expense_val)

    return FinanceSummary(
        totalBalance=total_balance,
        totalIncome=float(income_val),
        totalExpense=float(expense_val),
        totalMerit=float(merit_val),
        transactionCount=count_val,
    )


@router.post("/", response_model=TransactionReadFlutter)
def create_transaction(
    request: Request,
    data: TransactionCreateFlutter,
    db: Session = Depends(get_db),
):
    """
    Tạo mới một khoản thu, chi hoặc công đức:
    - Nếu người tạo là Admin / Trưởng họ / Editor -> status = 'approved', requires_approval = False (Thêm trực tiếp).
    - Nếu người tạo là Member -> status = 'pending', requires_approval = True (Gửi yêu cầu phê duyệt).
    """
    user = _get_request_user(request, db)
    can_manage = _check_user_can_manage(db, data.familyId, user)

    # Phân quyền phê duyệt
    if can_manage:
        final_status = "approved"
        requires_approval = False
    else:
        final_status = "pending"
        requires_approval = True

    # Parse ngày giao dịch
    tx_date = datetime.now().date()
    if data.date:
        try:
            # Hỗ trợ format YYYY-MM-DD hoặc ISO
            if "T" in data.date:
                tx_date = datetime.fromisoformat(data.date).date()
            else:
                tx_date = date.fromisoformat(data.date)
        except Exception:
            try:
                tx_date = datetime.strptime(data.date, "%d/%m/%Y").date()
            except Exception:
                tx_date = datetime.now().date()

    # Tự động gán default category nếu để trống
    cat = (data.category or "").strip()
    if not cat:
        if data.type == "income":
            cat = "Khoản thu"
        elif data.type == "expense":
            cat = "Khoản chi"
        elif data.type == "merit":
            cat = "Công đức"

    new_tx = Transaction(
        family_id=data.familyId or 1,
        member_id=data.memberId,
        title=data.title.strip(),
        amount=float(data.amount),
        type=data.type.lower(),
        person_name=data.personName.strip(),
        category=cat,
        date=tx_date,
        note=(data.note or "").strip(),
        status=final_status,
        requires_approval=requires_approval,
        created_by_user_id=user.id if user else None,
        created_at=datetime.now(),
        updated_at=datetime.now(),
    )
    db.add(new_tx)
    db.commit()
    db.refresh(new_tx)

    return _transaction_to_flutter(new_tx)


@router.patch("/{transaction_id}/approve", response_model=TransactionReadFlutter)
def approve_transaction(
    transaction_id: int,
    request: Request,
    db: Session = Depends(get_db),
):
    """
    Phê duyệt giao dịch (Chỉ dành cho Admin / Editor).
    """
    tx = db.query(Transaction).filter(Transaction.id == transaction_id).first()
    if not tx:
        raise HTTPException(status_code=404, detail="Không tìm thấy giao dịch")

    user = _get_request_user(request, db)
    if not _check_user_can_manage(db, tx.family_id, user):
        raise HTTPException(status_code=403, detail="Chỉ Quản trị viên hoặc Biên tập viên mới có quyền phê duyệt")

    tx.status = "approved"
    tx.requires_approval = False
    tx.approved_by_user_id = user.id if user else None
    tx.updated_at = datetime.now()
    db.commit()
    db.refresh(tx)

    return _transaction_to_flutter(tx)


@router.patch("/{transaction_id}/reject", response_model=TransactionReadFlutter)
def reject_transaction(
    transaction_id: int,
    request: Request,
    db: Session = Depends(get_db),
):
    """
    Từ chối giao dịch (Chỉ dành cho Admin / Editor).
    """
    tx = db.query(Transaction).filter(Transaction.id == transaction_id).first()
    if not tx:
        raise HTTPException(status_code=404, detail="Không tìm thấy giao dịch")

    user = _get_request_user(request, db)
    if not _check_user_can_manage(db, tx.family_id, user):
        raise HTTPException(status_code=403, detail="Chỉ Quản trị viên hoặc Biên tập viên mới có quyền từ chối")

    tx.status = "rejected"
    tx.requires_approval = False
    tx.updated_at = datetime.now()
    db.commit()
    db.refresh(tx)

    return _transaction_to_flutter(tx)


@router.delete("/{transaction_id}")
def delete_transaction(
    transaction_id: int,
    request: Request,
    db: Session = Depends(get_db),
):
    """
    Xóa một giao dịch (Chỉ dành cho Admin / Editor).
    """
    tx = db.query(Transaction).filter(Transaction.id == transaction_id).first()
    if not tx:
        raise HTTPException(status_code=404, detail="Không tìm thấy giao dịch")

    user = _get_request_user(request, db)
    if not _check_user_can_manage(db, tx.family_id, user):
        raise HTTPException(status_code=403, detail="Chỉ Quản trị viên hoặc Biên tập viên mới có quyền xóa giao dịch")

    db.delete(tx)
    db.commit()
    return {"detail": f"Đã xóa giao dịch ID={transaction_id}"}
