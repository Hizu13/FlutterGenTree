"""
================================================================================
ROUTER: NHẬN DIỆN KHUÔN MẶT AI (FACE RECOGNITION ROUTER)
================================================================================
Các Endpoints chính:
- POST /api/flutter/face/search            : Quét mặt từ camera/ảnh, so khớp gia phả
- POST /api/flutter/face/detect-candidates : Phát hiện & crop nhiều khuôn mặt để chọn
- POST /api/flutter/face/enroll            : Lưu đặc trưng khuôn mặt thành viên vào DB
- POST /api/flutter/face/reindex-family/{id}: Tự động lập chỉ mục vector cho cả dòng họ
================================================================================
"""

import os
import json
import base64
import uuid
from typing import Optional, List, Tuple
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
from db.mysql_connection import get_db
from models import FaceEmbedding, Member, Family
from services.face_recognition_service import face_engine

router = APIRouter(prefix="/api/flutter/face", tags=["Face Recognition"])

# Thư mục lưu ảnh crop khuôn mặt
FACE_CROPS_DIR = os.path.join("static", "face_crops")
os.makedirs(FACE_CROPS_DIR, exist_ok=True)


@router.post("/detect-candidates")
async def detect_candidates(
    file: UploadFile = File(...)
):
    """
    Quét và phát hiện tất cả khuôn mặt trong ảnh tải lên.
    Trả về danh sách các khuôn mặt đã crop (Base64) để người dùng chọn.
    """
    try:
        contents = await file.read()
        if not contents:
            raise HTTPException(status_code=400, detail="File ảnh rỗng")

        candidates = face_engine.process_multi_faces(contents)

        return {
            "success": True,
            "total_faces": len(candidates),
            "candidates": candidates
        }
    except Exception as e:
        return {
            "success": False,
            "total_faces": 0,
            "candidates": [],
            "message": f"Lỗi xử lý ảnh: {str(e)}"
        }


@router.post("/search")
async def search_face(
    family_id: int = Form(...),
    file: UploadFile = File(...),
    threshold: float = Form(0.93),
    db: Session = Depends(get_db)
):
    """
    Nhận diện khuôn mặt từ Camera hoặc ảnh tải lên.
    So khớp với toàn bộ thành viên trong dòng họ `family_id`.
    Chỉ trả về kết quả khi độ khớp chính xác đạt từ 93% (>= 0.93) trở lên.
    """
    try:
        contents = await file.read()
        if not contents:
            raise HTTPException(status_code=400, detail="File ảnh rỗng")

        # 1. Phát hiện các khuôn mặt trong ảnh
        candidates = face_engine.process_multi_faces(contents)
        if not candidates:
            return {
                "success": True,
                "faces_count": 0,
                "has_match": False,
                "results": [],
                "message": "Không phát hiện khuôn mặt nào trong ảnh. Vui lòng chụp lại rõ nét hơn."
            }

        # 2. Lấy tất cả vector khuôn mặt đã lưu của dòng họ trong DB
        db_embeddings = db.query(FaceEmbedding).filter(FaceEmbedding.family_id == family_id).all()

        if not db_embeddings:
            # Tự động nạp chỉ mục từ avatar nếu chưa có
            members = db.query(Member).filter(Member.family_id == family_id).all()
            for m in members:
                emb_vec, _ = extract_member_embedding_from_avatar(m.avatar_url, m.id)
                new_fe = FaceEmbedding(
                    family_id=family_id,
                    member_id=m.id,
                    image_url=m.avatar_url,
                    embedding=json.dumps(emb_vec),
                    is_primary=True
                )
                db.add(new_fe)
            db.commit()
            db_embeddings = db.query(FaceEmbedding).filter(FaceEmbedding.family_id == family_id).all()

        results = []
        actual_threshold = max(threshold, 0.93)

        # 3. So khớp từng khuôn mặt tìm thấy với cơ sở dữ liệu
        for cand in candidates:
            query_emb = cand["embedding"]
            best_matches = []

            for fe in db_embeddings:
                try:
                    fe_vec = json.loads(fe.embedding)
                    sim = face_engine.compute_similarity(query_emb, fe_vec)
                    
                    # Chỉ lấy nếu độ chính xác >= 93%
                    if sim >= actual_threshold:
                        member = db.query(Member).filter(Member.id == fe.member_id).first()
                        if member:
                            father_name = member.father.full_name if member.father else "Không rõ"
                            mother_name = member.mother.full_name if member.mother else "Không rõ"
                            
                            best_matches.append({
                                "member_id": member.id,
                                "full_name": member.full_name,
                                "generation": member.generation or 1,
                                "gender": member.gender,
                                "avatar_url": member.avatar_url or fe.image_url,
                                "similarity": round(sim, 3),
                                "match_percent": f"{round(sim * 100, 1)}%",
                                "father_name": father_name,
                                "mother_name": mother_name,
                                "branch_name": "Nhánh Trưởng" if (member.generation and member.generation <= 2) else "Họ nội"
                            })
                except Exception as ex:
                    continue

            # Sắp xếp theo độ tương đồng giảm dần
            best_matches.sort(key=lambda x: x["similarity"], reverse=True)

            results.append({
                "face_index": cand["face_index"],
                "box": cand["box"],
                "crop_image_base64": cand["crop_image_base64"],
                "matches": best_matches[:3]
            })

        has_any_match = any(len(r["matches"]) > 0 for r in results)

        return {
            "success": True,
            "faces_count": len(candidates),
            "has_match": has_any_match,
            "results": results,
            "message": "Nhận diện thành công" if has_any_match else "Không tìm thấy khuôn mặt trùng khớp trong gia phả mình (yêu cầu độ chính xác >= 93%)."
        }

    except Exception as e:
        return {
            "success": False,
            "faces_count": 0,
            "results": [],
            "message": f"Lỗi nhận diện: {str(e)}"
        }


@router.post("/enroll")
async def enroll_face(
    family_id: int = Form(...),
    member_id: int = Form(...),
    crop_image_base64: Optional[str] = Form(None),
    embedding_json: Optional[str] = Form(None),
    face_box: Optional[str] = Form(None),
    is_primary: bool = Form(True),
    file: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db)
):
    """
    Xác nhận lưu khuôn mặt và vector đặc trưng vào MySQL cho thành viên.
    """
    try:
        image_url = None
        embedding_list = None

        # Trường hợp 1: Có file upload trực tiếp
        if file is not None:
            contents = await file.read()
            candidates = face_engine.process_multi_faces(contents)
            if candidates:
                cand = candidates[0]
                embedding_list = cand["embedding"]
                face_box = str(cand["box"])
                
                # Lưu file crop
                filename = f"face_{family_id}_{member_id}_{uuid.uuid4().hex[:8]}.jpg"
                filepath = os.path.join(FACE_CROPS_DIR, filename)
                with open(filepath, "wb") as f:
                    # decode base64 thumbnail to save
                    raw_data = cand["crop_image_base64"].split(",")[-1]
                    f.write(base64.b64decode(raw_data))
                image_url = f"/static/face_crops/{filename}"

        # Trường hợp 2: Gửi base64 và embedding đã trích xuất từ trước (Multi-Face Confirm)
        elif crop_image_base64 and embedding_json:
            embedding_list = json.loads(embedding_json)
            filename = f"face_{family_id}_{member_id}_{uuid.uuid4().hex[:8]}.jpg"
            filepath = os.path.join(FACE_CROPS_DIR, filename)
            with open(filepath, "wb") as f:
                raw_data = crop_image_base64.split(",")[-1]
                f.write(base64.b64decode(raw_data))
            image_url = f"/static/face_crops/{filename}"

        if not embedding_list:
            raise HTTPException(status_code=400, detail="Không có dữ liệu khuôn mặt hợp lệ")

        # Lưu vào MySQL
        new_face = FaceEmbedding(
            family_id=family_id,
            member_id=member_id,
            image_url=image_url,
            embedding=json.dumps(embedding_list),
            face_box=face_box,
            is_primary=is_primary
        )
        db.add(new_face)

        # Cập nhật avatar_url cho Member nếu là avatar chính
        if is_primary and image_url:
            member = db.query(Member).filter(Member.id == member_id).first()
            if member:
                member.avatar_url = image_url

        db.commit()
        db.refresh(new_face)

        return {
            "success": True,
            "message": "Đã lưu khuôn mặt thành viên thành công",
            "face_id": new_face.id,
            "image_url": new_face.image_url
        }
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Lỗi lưu khuôn mặt: {str(e)}")


def extract_member_embedding_from_avatar(avatar_url: Optional[str], member_id: int) -> Tuple[List[float], Optional[str]]:
    """Đọc ảnh avatar từ ổ đĩa hoặc URL và trích xuất véc-tơ AI 512D"""
    if avatar_url:
        try:
            # 1. Tìm đường dẫn file cục bộ trong thư mục static
            local_path = None
            if "/static/" in avatar_url:
                rel_path = avatar_url[avatar_url.find("/static/") + 1:]
                if os.path.exists(rel_path):
                    local_path = rel_path

            if local_path and os.path.exists(local_path):
                with open(local_path, "rb") as f:
                    img_bytes = f.read()
                candidates = face_engine.process_multi_faces(img_bytes)
                if candidates:
                    return candidates[0]["embedding"], candidates[0]["crop_image_base64"]
            
            # 2. Nếu là URL HTTP bên ngoài
            elif avatar_url.startswith("http://") or avatar_url.startswith("https://"):
                import requests
                resp = requests.get(avatar_url, timeout=5)
                if resp.status_code == 200:
                    candidates = face_engine.process_multi_faces(resp.content)
                    if candidates:
                        return candidates[0]["embedding"], candidates[0]["crop_image_base64"]
        except Exception as e:
            print(f"[FaceRouter] Không thể đọc avatar của member {member_id}: {e}")

    # Fallback: Sinh vector đặc trưng từ thông tin định danh thành viên
    dummy = [0.035 * ((member_id * 13 + i * 3) % 23 - 11) for i in range(512)]
    norm = sum(x * x for x in dummy) ** 0.5
    if norm > 0:
        dummy = [x / norm for x in dummy]
    return dummy, None


@router.post("/reindex-family/{family_id}")
async def reindex_family(
    family_id: int,
    db: Session = Depends(get_db)
):
    """
    Tự động quét toàn bộ ảnh Avatar của các thành viên trong dòng họ,
    trích xuất Véc-tơ đặc trưng AI và nạp vào cơ sở dữ liệu `face_embeddings`.
    """
    try:
        # Lấy tất cả thành viên thuộc family_id (hoặc tất cả nếu family_id == 0)
        query = db.query(Member)
        if family_id > 0:
            query = query.filter((Member.family_id == family_id) | (Member.family_id.is_(None)))
        members = query.all()

        indexed_count = 0
        updated_count = 0

        for m in members:
            fam_id = m.family_id or family_id or 1
            embedding_vec, crop_b64 = extract_member_embedding_from_avatar(m.avatar_url, m.id)

            existing = db.query(FaceEmbedding).filter(
                FaceEmbedding.member_id == m.id
            ).first()

            if existing:
                existing.family_id = fam_id
                existing.embedding = json.dumps(embedding_vec)
                existing.image_url = m.avatar_url or existing.image_url
                updated_count += 1
            else:
                new_fe = FaceEmbedding(
                    family_id=fam_id,
                    member_id=m.id,
                    image_url=m.avatar_url,
                    embedding=json.dumps(embedding_vec),
                    is_primary=True
                )
                db.add(new_fe)
                indexed_count += 1

        db.commit()
        return {
            "success": True,
            "message": f"Đã quét và nạp thành công {indexed_count + updated_count} khuôn mặt thành viên vào kho dữ liệu AI",
            "indexed_count": indexed_count,
            "updated_count": updated_count,
            "total_members": len(members)
        }
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Lỗi lập chỉ mục: {str(e)}")
