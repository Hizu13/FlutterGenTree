"""
================================================================================
ADMIN ROUTER (API QUẢN TRỊ GIA TỘC & DASHBOARD DÀNH CHO ADMIN / EDITOR)
================================================================================
- Thống kê Dashboard: Tổng thành viên, Chờ duyệt, Gia nhập mới, Số quỹ dư
- Quản lý danh sách các yêu cầu chờ duyệt tập trung (Sự kiện, Thu chi, Thành viên)
- Phân quyền vai trò dòng họ (Admin / Editor / Member)
- Import gia phả từ tệp Excel (.xlsx, .xls)
================================================================================
"""

import io
from datetime import datetime, timedelta, date
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Request, UploadFile, File
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import func
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
from fastapi.responses import Response
from db.mysql_connection import get_db
from models import Family, Member, Transaction, Event, User, Relationship
from routers.auth import get_current_user
from db.neo4j_connection import add_person_to_graph, create_relationship_in_graph

router = APIRouter(prefix="/api/flutter/admin", tags=["Admin Dashboard (Flutter)"])


def _format_currency_short(amount: float) -> str:
    """Định dạng số tiền ngắn gọn cho dashboard (vd: 10,5 tr, 310 tr, 500k)"""
    if amount >= 1_000_000_000:
        val = amount / 1_000_000_000
        return f"{val:,.1f} tỷ".replace(".", ",")
    elif amount >= 1_000_000:
        val = amount / 1_000_000
        if val == int(val):
            return f"{int(val)} tr"
        return f"{val:,.1f} tr".replace(".", ",")
    elif amount >= 1_000:
        val = amount / 1_000
        return f"{int(val)}k"
    else:
        return f"{int(amount)} đ"

def _check_family_admin_permission(family_id: int, user: User, db: Session):
    """Kiểm tra quyền Admin/Owner/Editor của user trong dòng họ này."""
    if user.role in ["admin", "owner"]:
        return
    family = db.query(Family).filter(Family.id == family_id).first()
    if not family:
        raise HTTPException(status_code=404, detail="Không tìm thấy gia phả")
    if family.owner_id == user.id:
        return
    member = db.query(Member).filter(
        Member.family_id == family_id,
        Member.user_id == user.id,
        Member.status == "approved",
        Member.requires_approval != True
    ).first()
    if member and member.role in ["admin", "owner", "editor"]:
        return
    raise HTTPException(
        status_code=403,
        detail="Bạn không có quyền quản trị trong gia phả này."
    )


# ==============================================================================
# 1. API THỐNG KÊ DASHBOARD
# ==============================================================================
@router.get("/dashboard-stats")
def get_admin_dashboard_stats(
    family_id: int = Query(..., description="ID dòng họ"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Lấy toàn bộ số liệu thống kê cho Dashboard Quản trị.
    """
    _check_family_admin_permission(family_id, current_user, db)
    family = db.query(Family).filter(Family.id == family_id).first()
    if not family:
        raise HTTPException(status_code=404, detail="Không tìm thấy gia phả")

   # 1. Tổng thành viên chính thức
    total_members = (
        db.query(func.count(Member.id))
        .filter(
            Member.family_id == family_id,
            (Member.status == "approved") | (Member.status.is_(None)),
            Member.requires_approval != True
        )
        .scalar()
        or 0
    )
    # 2. Thành viên gia nhập mới chờ duyệt
    pending_members = (
        db.query(func.count(Member.id))
        .filter(
             Member.family_id == family_id,
            (Member.status == "pending") | (Member.requires_approval == True)
        )
        .scalar()
        or 0
    )

    # 3. Sự kiện chờ duyệt
    pending_events = (
        db.query(func.count(Event.id))
        .filter(
            Event.family_id == family_id,
            (Event.status == "pending") | (Event.requires_approval == True)
        )
        .scalar()
        or 0
    )

    # 4. Các khoản thu/chi chờ duyệt
    pending_txs = (
        db.query(func.count(Transaction.id))
        .filter(
            Transaction.family_id == family_id,
            (Transaction.status == "pending") | (Transaction.requires_approval == True)
        )
        .scalar()
        or 0
    )

    # 5. Tổng quỹ số dư
    total_income = (
        db.query(func.coalesce(func.sum(Transaction.amount), 0.0))
        .filter(
            Transaction.family_id == family_id,
            Transaction.status == "approved",
            Transaction.type == "income"
        )
        .scalar()
        or 0.0
    )

    total_merit = (
        db.query(func.coalesce(func.sum(Transaction.amount), 0.0))
        .filter(
            Transaction.family_id == family_id,
            Transaction.status == "approved",
            Transaction.type == "merit"
        )
        .scalar()
        or 0.0
    )

    total_expense = (
        db.query(func.coalesce(func.sum(Transaction.amount), 0.0))
        .filter(
            Transaction.family_id == family_id,
            Transaction.status == "approved",
            Transaction.type == "expense"
        )
        .scalar()
        or 0.0
    )

    total_balance = (total_income + total_merit) - total_expense
    formatted_balance = _format_currency_short(total_balance)

    # Tổng số lượng cần phải xử lý của admin
    total_pending = pending_members + pending_events + pending_txs

    return {
        "family_id": family_id,
        "family_name": family.name,
        "total_members": total_members,
        "pending_approvals": total_pending,
        "pending_members": pending_members,        
        "pending_transactions": pending_txs,
        "pending_events": pending_events,
        "new_joins": pending_members,
        "total_balance": total_balance,
        "formatted_balance": formatted_balance,
        "raw_balance": total_balance,
    }


# ==============================================================================
# 2. API PHÊ DUYỆT TẬP TRUNG (DANH SÁCH YÊU CẦU CHỜ DUYỆT)
# ==============================================================================
@router.get("/pending-items")
def get_pending_items(
    family_id: int = Query(..., description="ID dòng họ"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Lấy danh sách các yêu cầu đang chờ phê duyệt (Thu chi & Sự kiện).
    """
    _check_family_admin_permission(family_id, current_user, db)
    # 1. Giao dịch thu chi chờ duyệt
    pending_txs = (
        db.query(Transaction)
        .filter(
            Transaction.family_id == family_id,
            (Transaction.status == "pending") | (Transaction.requires_approval == True)
        )
        .order_by(Transaction.id.desc())
        .all()
    )

    # 2. Sự kiện chờ duyệt
    pending_events = (
        db.query(Event)
        .filter(
            Event.family_id == family_id,
            Event.status == "pending"
        )
        .order_by(Event.id.desc())
        .all()
    )

    items = []
    for tx in pending_txs:
        items.append({
            "id": tx.id,
            "category": "finance",
            "type": tx.type,
            "title": tx.title,
            "amount": tx.amount,
            "person_name": tx.person_name,
            "date": tx.date.strftime("%d/%m/%Y") if tx.date else "",
            "note": tx.note or "",
            "status": "pending",
            "created_at": tx.created_at.strftime("%d/%m/%Y %H:%M") if tx.created_at else "",
        })

    for ev in pending_events:
        items.append({
            "id": ev.id,
            "category": "event",
            "type": ev.event_type,
            "title": ev.title,
            "amount": 0,
            "person_name": "",
            "date": ev.solar_date.strftime("%d/%m/%Y") if ev.solar_date else (ev.date.strftime("%d/%m/%Y") if ev.date else ""),
            "note": ev.description or "",
            "status": "pending",
            "created_at": ev.created_at.strftime("%d/%m/%Y %H:%M") if ev.created_at else "",
        })

    return {
        "family_id": family_id,
        "total": len(items),
        "items": items
    }


# ==============================================================================
# 3. API DUYỆT SỰ KIỆN (CHỜ DUYỆT & ĐÃ DUYỆT)
# ==============================================================================
@router.get("/events")
def get_admin_events_by_status(
    family_id: int = Query(..., description="ID dòng họ"),
    status: str = Query("pending", description="Trạng thái: pending hoặc approved"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Lấy danh sách sự kiện theo trạng thái 'pending' hoặc 'approved'.
    """
    _check_family_admin_permission(family_id, current_user, db)
    query = db.query(Event).filter(Event.family_id == family_id)
    if status == "pending":
        query = query.filter(
            (Event.status == "pending") | (Event.requires_approval == True)
        )
    else:
        query = query.filter(
            (Event.status == "approved") & (Event.requires_approval == False)
        )

    events = query.order_by(Event.id.desc()).all()
    results = []
    for ev in events:
        creator_name = "Thành viên gia đình"
        if ev.creator_id:
            u = db.query(User).filter(User.id == ev.creator_id).first()
            if u:
                creator_name = u.full_name or u.username

        d_str = ""
        if ev.solar_date:
            d_str = ev.solar_date.strftime("%d/%m/%Y")

        results.append({
            "id": ev.id,
            "title": ev.title,
            "creator_name": creator_name,
            "date": d_str,
            "location": ev.location or "Nhà thờ họ",
            "note": ev.note or "",
            "event_type": ev.event_type,
            "status": ev.status or "pending",
        })

    return {
        "family_id": family_id,
        "status": status,
        "total": len(results),
        "events": results,
    }


# ==============================================================================
# 4. API DUYỆT THÀNH VIÊN VÀO GIA PHẢ (CHỜ DUYỆT & ĐÃ DUYỆT)
# ==============================================================================
@router.get("/members")
def get_admin_members_by_status(
    family_id: int = Query(..., description="ID dòng họ"),
    status: str = Query("pending", description="Trạng thái: pending hoặc approved"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Lấy danh sách thành viên theo trạng thái 'pending' hoặc 'approved'.
    """
    _check_family_admin_permission(family_id, current_user, db)
    query = db.query(Member).filter(Member.family_id == family_id)
    if status == "pending":
        query = query.filter(
            Member.status == "pending",
            Member.requires_approval == True        )
    else:
        query = query.filter(
            (Member.status == "approved") | (Member.status.is_(None))
        ).filter(
            Member.requires_approval != True        )

    members = query.order_by(Member.id.desc()).all()
    results = []

    # Map name helper
    for m in members:
        father_name = ""
        mother_name = ""
        if m.father_id:
            f = db.query(Member).filter(Member.id == m.father_id).first()
            if f:
                father_name = f.full_name
        if m.mother_id:
            mo = db.query(Member).filter(Member.id == m.mother_id).first()
            if mo:
                mother_name = mo.full_name

        b_str = ""
        if m.date_of_birth:
            b_str = m.date_of_birth.strftime("%d/%m/%Y")

        gender_vn = "Nam" if m.gender == "male" else "Nữ"

        results.append({
            "id": m.id,
            "full_name": m.full_name,
            "gender": gender_vn,
            "birth_date": b_str,
            "address": m.permanent_address or m.place_of_birth or "Hà Nội",
            "father_name": father_name,
            "mother_name": mother_name,
            "avatar_url": m.avatar_url,
            "generation": m.generation or 1,
            "phone_number": m.phone_number or "",
            "status": m.status or "pending",
        })

    return {
        "family_id": family_id,
        "status": status,
        "total": len(results),
        "members": results,
    }


@router.patch("/members/{member_id}/approve")
def approve_member(
    member_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Phê duyệt thành viên vào gia phả."""
    m = db.query(Member).filter(Member.id == member_id).first()
    if not m:
        raise HTTPException(status_code=404, detail="Không tìm thấy thành viên")
    
    _check_family_admin_permission(m.family_id, current_user, db)
    m.status = "approved"
    m.requires_approval = False
    db.commit()
    db.refresh(m)

    try:
        add_person_to_graph(
            id=m.id,
            full_name=m.full_name,
            gender=m.gender,
            family_id=m.family_id,
        )
    except Exception as e:
        print(f"[!] Neo4j approve node error: {e}")

    return {"detail": f"Đã phê duyệt thành viên {m.full_name} vào gia phả"}


@router.patch("/members/{member_id}/reject")
def reject_member(
    member_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Từ chối thành viên."""
    m = db.query(Member).filter(Member.id == member_id).first()
    if not m:
        raise HTTPException(status_code=404, detail="Không tìm thấy thành viên")

    _check_family_admin_permission(m.family_id, current_user, db)
    m.status = "rejected"
    db.commit()

    return {"detail": f"Đã từ chối yêu cầu gia nhập của {m.full_name}"}


# ==============================================================================
# 5. API PHÂN QUYỀN THÀNH VIÊN (DANH SÁCH USER TÀI KHOẢN TRONG DÒNG HỌ)
# ==============================================================================
@router.get("/users")
def get_family_users(
    family_id: int = Query(..., description="ID dòng họ"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Lấy danh sách các tài khoản User (người dùng thực) trong dòng họ để phân quyền.
    """
    _check_family_admin_permission(family_id, current_user, db)
    family = db.query(Family).filter(Family.id == family_id).first()
    if not family:
        raise HTTPException(status_code=404, detail="Không tìm thấy gia phả")

    # 1. Lấy user_ids từ Member thuộc family_id
    member_user_ids = [
        m.user_id for m in db.query(Member.user_id).filter(
            Member.family_id == family_id,
            Member.user_id.isnot(None)
        ).all() if m.user_id
    ]

    # 2. Thêm owner_id
    user_ids = set(member_user_ids)
    if family.owner_id:
        user_ids.add(family.owner_id)

    # Nếu chưa có user nào liên kết, lấy tất cả users
    if not user_ids:
        users = db.query(User).all()
    else:
        users = db.query(User).filter(User.id.in_(user_ids)).all()

    results = []
    for u in users:
        # Tìm member liên kết nếu có
        m = db.query(Member).filter(Member.family_id == family_id, Member.user_id == u.id).first()
        gen_str = f"Đời thứ {m.generation}" if (m and m.generation) else ""
        gender_str = u.gender or (m.gender if m else "Nam")
        if gender_str in ["male", "Nam"]:
            gender_str = "Nam"
        elif gender_str in ["female", "Nữ"]:
            gender_str = "Nữ"

        results.append({
            "id": u.id,
            "username": u.username,
            "full_name": u.full_name or u.username,
            "email": u.email,
            "role": u.role or "member",
            "gender": gender_str,
            "avatar_url": u.avatar_url or (m.avatar_url if m else None),
            "generation_info": gen_str,
            "is_owner": (u.id == family.owner_id),
        })

    return {
        "family_id": family_id,
        "total": len(results),
        "users": results,
    }


class UpdateRoleRequest(BaseModel):
    user_id: int
    family_id: int
    new_role: str  # "admin", "editor", "member"

@router.post("/change-role")
def change_member_role(
    payload: UpdateRoleRequest,
    db: Session = Depends(get_db),
):
    """
    Cập nhật vai trò (Role) của thành viên trong dòng họ.
    """
    user = db.query(User).filter(User.id == payload.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")

    role_val = payload.new_role.lower().strip()
    if role_val not in ["admin", "editor", "member", "owner"]:
        raise HTTPException(status_code=400, detail="Vai trò không hợp lệ (admin, editor, member)")

    user.role = role_val
    db.commit()
    db.refresh(user)

    return {
        "success": True,
        "user_id": user.id,
        "username": user.username,
        "new_role": user.role,
        "message": f"Đã cập nhật vai trò thành công sang '{payload.new_role}'"
    }


# ==============================================================================
# 4. API TẢI FILE EXCEL MẪU CHUẨN & IMPORT GIA PHẢ
# ==============================================================================
@router.get("/template-excel")
def download_genealogy_excel_template():
    """
    Tạo và tải về tệp Excel mẫu (.xlsx) có cấu trúc bảng chuẩn để nhập gia phả.
    Bao gồm các cột hướng dẫn, định dạng và dữ liệu mẫu ví dụ.
    """
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "DanhSachThanhVien"

    # Header columns
    headers = [
        "STT (*)",
        "Họ và tên (*)",
        "Giới tính (*)",
        "Đời thứ",
        "Ngày sinh",
        "Nơi sinh",
        "Số CCCD / CMND",
        "Số điện thoại",
        "Nghề nghiệp",
        "Địa chỉ thường trú",
        "Tình trạng",
        "Ngày mất",
        "Nơi an táng",
        "STT hoặc Tên Cha (Bố)",
        "STT hoặc Tên Mẹ",
        "Tiểu sử / Ghi chú",
    ]

    # Title
    ws.merge_cells("A1:P1")
    title_cell = ws["A1"]
    title_cell.value = "BẢNG MẪU NHẬP DỮ LIỆU THÀNH VIÊN GIA PHẢ"
    title_cell.font = Font(name="Arial", size=14, bold=True, color="FFFFFF")
    title_cell.fill = PatternFill(start_color="4E342E", end_color="4E342E", fill_type="solid")
    title_cell.alignment = Alignment(horizontal="center", vertical="center")
    ws.row_dimensions[1].height = 35

    # Subtitle / Notes
    ws.merge_cells("A2:P2")
    sub_cell = ws["A2"]
    sub_cell.value = "Lưu ý: Cột (*) là thông tin quan trọng. Cột Cha/Mẹ có thể điền STT trong file này (1, 2, 3...) hoặc Họ tên chính xác để tự động liên kết."
    sub_cell.font = Font(name="Arial", size=10, italic=True, color="5D4037")
    sub_cell.fill = PatternFill(start_color="EFEBE9", end_color="EFEBE9", fill_type="solid")
    sub_cell.alignment = Alignment(horizontal="center", vertical="center")
    ws.row_dimensions[2].height = 25

    # Headers styling
    header_font = Font(name="Arial", size=11, bold=True, color="FFFFFF")
    header_bg = PatternFill(start_color="6D4C41", end_color="6D4C41", fill_type="solid")
    thin_border = Border(
        left=Side(style="thin", color="BCAAA4"),
        right=Side(style="thin", color="BCAAA4"),
        top=Side(style="thin", color="BCAAA4"),
        bottom=Side(style="thin", color="BCAAA4"),
    )

    ws.row_dimensions[3].height = 28
    for col_num, header_title in enumerate(headers, 1):
        cell = ws.cell(row=3, column=col_num, value=header_title)
        cell.font = header_font
        cell.fill = header_bg
        cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        cell.border = thin_border

    # Sample rows (Dữ liệu mẫu chuẩn)
    sample_data = [
        [1, "Lê Văn Khởi", "Nam", 1, "10/05/1920", "Hà Nội", "", "", "Nông nghiệp", "Hà Nội", "Đã mất", "15/08/1990", "Nghĩa trang quê nhà", "", "", "Cụ Tổ đời thứ nhất"],
        [2, "Nguyễn Thị Sen", "Nữ", 1, "12/08/1923", "Hà Tây", "", "", "Nội trợ", "Hà Nội", "Đã mất", "20/10/1995", "Nghĩa trang quê nhà", "", "", "Vợ cụ Lê Văn Khởi"],
        [3, "Lê Văn An", "Nam", 2, "20/01/1950", "Hà Nội", "001050123456", "0912345678", "Kỹ sư", "Cầu Giấy, Hà Nội", "Còn sống", "", "", 1, 2, "Con trai trưởng cụ Khởi"],
        [4, "Trần Thị Mai", "Nữ", 2, "15/03/1955", "Bắc Ninh", "001055654321", "0987654321", "Bác sĩ", "Cầu Giấy, Hà Nội", "Còn sống", "", "", "", "", "Vợ ông Lê Văn An"],
        [5, "Lê Văn Hùng", "Nam", 3, "01/01/1980", "Hà Nội", "001080112233", "0901234567", "Lập trình viên", "Hà Nội", "Còn sống", "", "", 3, 4, "Cháu đích tôn"],
    ]

    for row_idx, row_vals in enumerate(sample_data, 4):
        ws.row_dimensions[row_idx].height = 22
        for col_num, val in enumerate(row_vals, 1):
            cell = ws.cell(row=row_idx, column=col_num, value=val)
            cell.font = Font(name="Arial", size=10)
            cell.alignment = Alignment(
                horizontal="center" if col_num in [1, 3, 4, 5, 11, 12, 14, 15] else "left",
                vertical="center",
            )
            cell.border = thin_border

    # Auto column width
    for col in ws.columns:
        max_len = max(len(str(cell.value or "")) for cell in col)
        col_letter = get_column_letter(col[0].column)
        ws.column_dimensions[col_letter].width = max(max_len + 4, 13)

    buf = io.BytesIO()
    wb.save(buf)
    buf.seek(0)

    headers_resp = {
        "Content-Disposition": 'attachment; filename="Mau_Nhap_Gia_Pha.xlsx"',
    }
    return Response(
        content=buf.getvalue(),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers=headers_resp,
    )


@router.post("/import-excel")
async def import_genealogy_excel(
    family_id: int = Query(..., description="ID dòng họ cần import"),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    """
    Đọc và import dữ liệu thành viên từ tệp Excel (.xlsx, .xls) vào Gia phả (MySQL & Neo4j).
    """
    if not file.filename.endswith((".xlsx", ".xls")):
        raise HTTPException(status_code=400, detail="Vui lòng tải lên tệp định dạng Excel (.xlsx hoặc .xls)")

    contents = await file.read()
    try:
        wb = openpyxl.load_workbook(io.BytesIO(contents), data_only=True)
        sheet = wb.active
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Không thể đọc file Excel: {str(e)}")

    rows = list(sheet.iter_rows(values_only=True))
    if not rows or len(rows) < 2:
        raise HTTPException(status_code=400, detail="Tệp Excel không có dữ liệu thành viên (cần ít nhất 1 dòng tiêu đề và 1 dòng dữ liệu)")

    # 1. Tìm dòng tiêu đề (Header Row) tự động
    header_row_idx = -1
    for idx, row in enumerate(rows):
        if not row:
            continue
        row_strs = [str(c).lower().strip() for c in row if c is not None]
        row_str_combined = " ".join(row_strs)
        if any(w in row_str_combined for w in ["họ và tên", "họ tên", "full_name", "fullname"]) and any(w in row_str_combined for w in ["giới tính", "gender", "sex"]):
            header_row_idx = idx
            break

    # Fallback nếu không tìm thấy dòng cả họ tên + giới tính
    if header_row_idx == -1:
        for idx, row in enumerate(rows):
            if not row:
                continue
            row_strs = [str(c).lower().strip() for c in row if c is not None]
            row_str_combined = " ".join(row_strs)
            if "họ và tên" in row_str_combined or "họ tên" in row_str_combined or "full_name" in row_str_combined:
                header_row_idx = idx
                break

    if header_row_idx == -1:
        raise HTTPException(status_code=400, detail="Tệp Excel thiếu cột 'Họ và tên' của thành viên")

    header = [str(cell).strip().lower() if cell is not None else "" for cell in rows[header_row_idx]]
    
    def get_col_index(possible_names: list) -> int:
        for idx, col in enumerate(header):
            for name in possible_names:
                if name in col:
                    return idx
        return -1

    stt_idx = get_col_index(["stt", "mã", "id", "no", "stt (*)"])
    name_idx = get_col_index(["họ và tên", "họ tên", "tên", "full_name", "fullname", "name", "họ và tên (*)"])
    gender_idx = get_col_index(["giới tính", "gioi tinh", "gender", "sex", "giới tính (*)"])
    gen_idx = get_col_index(["đời", "doi", "thế hệ", "the he", "generation", "gen", "đời thứ"])
    birth_idx = get_col_index(["ngày sinh", "ngay sinh", "năm sinh", "nam sinh", "birth", "dob"])
    pob_idx = get_col_index(["nơi sinh", "noi sinh", "quê quán", "que quan", "place_of_birth"])
    cccd_idx = get_col_index(["cccd", "cmnd", "căn cước", "identity", "identity_card", "số cccd / cmnd"])
    phone_idx = get_col_index(["số điện thoại", "so dien thoai", "phone", "sđt", "sdt"])
    job_idx = get_col_index(["nghề nghiệp", "nghe nghiep", "occupation", "job", "công việc"])
    address_idx = get_col_index(["địa chỉ", "dia chi", "thường trú", "permanent_address", "address"])
    alive_idx = get_col_index(["tình trạng", "trạng thái", "con song", "còn sống", "is_alive", "alive", "mất", "qua đời"])
    death_idx = get_col_index(["ngày mất", "ngay mat", "qua đời", "date_of_death", "death"])
    pod_idx = get_col_index(["nơi an táng", "noi an tang", "mộ phần", "an táng", "place_of_death"])
    father_idx = get_col_index(["cha", "bố", "father", "tên cha", "tên bố", "stt hoặc tên cha (bố)"])
    mother_idx = get_col_index(["mẹ", "mother", "tên mẹ", "stt hoặc tên mẹ"])
    bio_idx = get_col_index(["chú thích", "ghi chú", "tieu su", "tiểu sử", "note", "bio", "tiểu sử / ghi chú"])

    if name_idx == -1:
        raise HTTPException(status_code=400, detail="Tệp Excel thiếu cột 'Họ và tên' của thành viên")
    def parse_any_date(val):
        if not val:
            return None
        if isinstance(val, (datetime, date)):
            return val if isinstance(val, date) else val.date()
        s = str(val).strip()
        if not s:
            return None
        for fmt in ("%d/%m/%Y", "%d-%m-%Y", "%Y-%m-%d", "%d/%m/%y", "%Y/%m/%d"):
            try:
                return datetime.strptime(s, fmt).date()
            except Exception:
                pass
        try:
            year = int(float(s))
            if 1800 <= year <= 2100:
                return date(year, 1, 1)
        except Exception:
            pass
        return None
    imported_members = []
# Lưu thông tin liên kết cha mẹ: (member_obj, stt_val, raw_father_val, raw_mother_val)
    row_links = []
    stt_to_member = {}
    for row in rows[header_row_idx + 1:]:
        if not row or name_idx >= len(row) or row[name_idx] is None:
            continue

        raw_name = str(row[name_idx]).strip()
        if not raw_name or raw_name.startswith("Lưu ý") or raw_name.startswith("BẢNG MẪU"):
            continue

        # Tách Họ và Tên
        parts = raw_name.split()
        first_name = parts[-1] if parts else raw_name
        last_name = " ".join(parts[:-1]) if len(parts) > 1 else ""

        # Giới tính (Lưu vào DB dưới dạng 'male' hoặc 'female')
        gender = "male"
        if gender_idx != -1 and gender_idx < len(row) and row[gender_idx]:
            g_str = str(row[gender_idx]).strip().lower()
            if "nữ" in g_str or "nu" in g_str or "female" in g_str:
                gender = "female"
            elif "nam" in g_str or "male" in g_str:
                gender = "male"

        # Thế hệ / Đời
        generation = 1
        if gen_idx != -1 and gen_idx < len(row) and row[gen_idx]:
            try:
                generation = int(float(str(row[gen_idx]).strip()))
            except Exception:
                generation = 1

        # Ngày sinh, ngày mất
        dob = parse_any_date(row[birth_idx]) if (birth_idx != -1 and birth_idx < len(row)) else None
        dod = parse_any_date(row[death_idx]) if (death_idx != -1 and death_idx < len(row)) else None

        # Tình trạng còn sống / đã mất
        if alive_idx != -1 and alive_idx < len(row) and row[alive_idx]:
            a_str = str(row[alive_idx]).strip().lower()
            if "mất" in a_str or "đã mất" in a_str or "qua đời" in a_str or a_str in ["0", "false", "no"]:
                if dod is None:
                    dod = date(1900, 1, 1)  # Đánh dấu đã mất nếu chưa có ngày

        pob = str(row[pob_idx]).strip() if pob_idx != -1 and pob_idx < len(row) and row[pob_idx] else None
        pod = str(row[pod_idx]).strip() if pod_idx != -1 and pod_idx < len(row) and row[pod_idx] else None
        cccd_val = str(row[cccd_idx]).strip() if cccd_idx != -1 and cccd_idx < len(row) and row[cccd_idx] else None
        phone = str(row[phone_idx]).strip() if phone_idx != -1 and phone_idx < len(row) and row[phone_idx] else None
        job = str(row[job_idx]).strip() if job_idx != -1 and job_idx < len(row) and row[job_idx] else None
        address = str(row[address_idx]).strip() if address_idx != -1 and address_idx < len(row) and row[address_idx] else None
        bio = str(row[bio_idx]).strip() if bio_idx != -1 and bio_idx < len(row) and row[bio_idx] else None
        # Lấy giá trị STT của dòng
        stt_val = None
        if stt_idx != -1 and stt_idx < len(row) and row[stt_idx] is not None:
            try:
                stt_val = str(int(float(str(row[stt_idx]).strip())))
            except Exception:
                stt_val = str(row[stt_idx]).strip()

        father_val = str(row[father_idx]).strip() if father_idx != -1 and father_idx < len(row) and row[father_idx] else None
        mother_val = str(row[mother_idx]).strip() if mother_idx != -1 and mother_idx < len(row) and row[mother_idx] else None

        # Tạo đối tượng Member trong MySQL
        new_member = Member(
            family_id=family_id,
            first_name=first_name,
            last_name=last_name,
            gender=gender,
            generation=generation,
            date_of_birth=dob,
            date_of_death=dod,
            place_of_birth=pob,
            place_of_death=pod,
            cccd=cccd_val,
            phone_number=phone,
            occupation=job,
            permanent_address=address,
            biography=bio,
            role="member",
            status="approved",
            requires_approval=False,
            created_at=datetime.now(),
        )
        db.add(new_member)
        imported_members.append(new_member)
        if stt_val:
            stt_to_member[stt_val] = new_member
        if father_val or mother_val:
            row_links.append((new_member, father_val, mother_val))

    db.commit()

    # Refresh để lấy ID và đồng bộ Neo4j
    for m in imported_members:
        db.refresh(m)
        try:
            add_person_to_graph(
                id=m.id,
                full_name=f"{m.last_name or ''} {m.first_name or ''}".strip(),
                gender=m.gender,
                family_id=m.family_id,
            )
        except Exception as e:
            print(f"[!] Neo4j import node error: {e}")

    # Lấy danh sách thành viên hiện có trong gia phả để map tên
    all_family_members = db.query(Member).filter(Member.family_id == family_id).all()
    name_to_member = {f"{mem.last_name or ''} {mem.first_name or ''}".strip().lower(): mem for mem in all_family_members}

    # Gán cha mẹ tự động (qua STT trong file hoặc qua Tên)
    for child, f_val, m_val in row_links:
        if f_val:
            f_clean = f_val.strip()
            # 1. Thử tìm qua STT
            f_mem = stt_to_member.get(f_clean)
            if not f_mem:
                try:
                    f_stt_int = str(int(float(f_clean)))
                    f_mem = stt_to_member.get(f_stt_int)
                except Exception:
                    pass
            # 2. Thử tìm qua Tên
            if not f_mem:
                f_mem = name_to_member.get(f_clean.lower())

            if f_mem and f_mem.id != child.id:
                child.father_id = f_mem.id
                try:
                    create_relationship_in_graph(f_mem.id, child.id, "FATHER_OF")
                except Exception:
                    pass
        if m_val:
            m_clean = m_val.strip()
            # 1. Thử tìm qua STT
            m_mem = stt_to_member.get(m_clean)
            if not m_mem:
                try:
                    m_stt_int = str(int(float(m_clean)))
                    m_mem = stt_to_member.get(m_stt_int)
                except Exception:
                    pass
            # 2. Thử tìm qua Tên
            if not m_mem:
                m_mem = name_to_member.get(m_clean.lower())

            if m_mem and m_mem.id != child.id:
                child.mother_id = m_mem.id
                try:
                    create_relationship_in_graph(m_mem.id, child.id, "MOTHER_OF")
                except Exception:
                    pass

    db.commit()

    return {
        "success": True,
        "family_id": family_id,
        "total_imported": len(imported_members),
        "message": f"Đã nhập thành công {len(imported_members)} thành viên vào gia phả!",
    }
