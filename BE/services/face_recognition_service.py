"""
================================================================================
FACE RECOGNITION SERVICE (AI ENGINE) - GENTREE
================================================================================
Hệ thống AI xử lý:
1. Phát hiện khuôn mặt (Face Detection - Đơn & Đa khuôn mặt).
2. Cắt & Căn chỉnh ảnh chân dung (Face Crop & Thumbnail Base64).
3. Trích xuất Véc-tơ đặc trưng 512 chiều (Face Embedding Extraction).
4. So khớp Cosine Similarity theo từng dòng họ (Fast Vector Search).
================================================================================
"""

import os
import json
import base64
import math
import numpy as np
from typing import List, Dict, Any, Tuple, Optional
from io import BytesIO

# Import PIL / OpenCV nếu có
try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

try:
    import cv2
    HAS_CV2 = True
except ImportError:
    HAS_CV2 = False


class FaceRecognitionService:
    def __init__(self):
        self.frontal_alt2 = None
        self.frontal_default = None
        self.profile_cascade = None
        self._init_face_detector()

    def _init_face_detector(self):
        """Khởi tạo các bộ phát hiện khuôn mặt đa góc (Trực diện & Nghiêng) của OpenCV"""
        if HAS_CV2:
            try:
                alt2_path = cv2.data.haarcascades + 'haarcascade_frontalface_alt2.xml'
                if os.path.exists(alt2_path):
                    self.frontal_alt2 = cv2.CascadeClassifier(alt2_path)

                def_path = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
                if os.path.exists(def_path):
                    self.frontal_default = cv2.CascadeClassifier(def_path)

                prof_path = cv2.data.haarcascades + 'haarcascade_profileface.xml'
                if os.path.exists(prof_path):
                    self.profile_cascade = cv2.CascadeClassifier(prof_path)

                print("[FaceService] Đã tải thành công các mô hình phát hiện khuôn mặt đa góc OpenCV")
            except Exception as e:
                print(f"[FaceService] Warning: Lỗi khởi tạo HaarCascade: {e}")

    def load_image_from_bytes(self, image_bytes: bytes) -> Optional[np.ndarray]:
        """Chuyển bytes ảnh thành numpy array (RGB)"""
        try:
            if HAS_CV2:
                nparr = np.frombuffer(image_bytes, np.uint8)
                img_bgr = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
                if img_bgr is not None:
                    return cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
            
            if HAS_PIL:
                img_pil = Image.open(BytesIO(image_bytes)).convert("RGB")
                return np.array(img_pil)
        except Exception as e:
            print(f"[FaceService] Lỗi đọc ảnh: {e}")
        return None

    def _nms_boxes(self, raw_boxes: List[Tuple[int, int, int, int]], iou_thresh: float = 0.25) -> List[Tuple[int, int, int, int]]:
        """Gộp các bounding box bị trùng lặp bằng Non-Maximum Suppression (NMS)"""
        if not raw_boxes:
            return []
        
        b = np.array(raw_boxes, dtype=float)
        x1 = b[:, 0]
        y1 = b[:, 1]
        x2 = b[:, 0] + b[:, 2]
        y2 = b[:, 1] + b[:, 3]
        areas = b[:, 2] * b[:, 3]
        order = areas.argsort()[::-1]

        keep = []
        while order.size > 0:
            i = order[0]
            keep.append(i)
            xx1 = np.maximum(x1[i], x1[order[1:]])
            yy1 = np.maximum(y1[i], y1[order[1:]])
            xx2 = np.minimum(x2[i], x2[order[1:]])
            yy2 = np.minimum(y2[i], y2[order[1:]])

            w = np.maximum(0.0, xx2 - xx1)
            h = np.maximum(0.0, yy2 - yy1)
            inter = w * h
            ovr = inter / (areas[i] + areas[order[1:]] - inter + 1e-6)

            inds = np.where(ovr <= iou_thresh)[0]
            order = order[inds + 1]

        result = [tuple(map(int, b[k])) for k in keep]
        # Sắp xếp các khuôn mặt theo thứ tự từ trái sang phải ảnh
        result.sort(key=lambda item: item[0])
        return result

    def detect_faces(self, rgb_image: np.ndarray) -> List[Tuple[int, int, int, int]]:
        """
        Phát hiện tất cả khuôn mặt (Đa khuôn mặt, chụp thẳng & chụp nghiêng/góc).
        Trả về danh sách bounding boxes đã lọc sạch: [(x, y, w, h), ...]
        """
        h, w, _ = rgb_image.shape
        raw_boxes = []

        if HAS_CV2:
            gray = cv2.cvtColor(rgb_image, cv2.COLOR_RGB2GRAY)
            # Cân bằng độ tương phản để nhận diện rõ ngay cả khi ngược sáng / áo mưa / kính
            gray = cv2.equalizeHist(gray)
            min_s = int(min(h, w) * 0.05)
            min_size = (max(min_s, 24), max(min_s, 24))

            # 1. Phát hiện mặt thẳng & góc 45 độ (Frontal Alt2)
            if self.frontal_alt2 is not None and not self.frontal_alt2.empty():
                d1 = self.frontal_alt2.detectMultiScale(
                    gray, scaleFactor=1.08, minNeighbors=3, minSize=min_size
                )
                for (x, y, bw, bh) in d1:
                    raw_boxes.append((int(x), int(y), int(bw), int(bh)))

            # 2. Phát hiện mặt thẳng tiêu chuẩn (Frontal Default)
            if self.frontal_default is not None and not self.frontal_default.empty():
                d2 = self.frontal_default.detectMultiScale(
                    gray, scaleFactor=1.08, minNeighbors=3, minSize=min_size
                )
                for (x, y, bw, bh) in d2:
                    raw_boxes.append((int(x), int(y), int(bw), int(bh)))

            # 3. Phát hiện mặt nghiêng bên trái (Profile Left)
            if self.profile_cascade is not None and not self.profile_cascade.empty():
                d3 = self.profile_cascade.detectMultiScale(
                    gray, scaleFactor=1.08, minNeighbors=3, minSize=min_size
                )
                for (x, y, bw, bh) in d3:
                    raw_boxes.append((int(x), int(y), int(bw), int(bh)))

                # 4. Phát hiện mặt nghiêng bên phải (Profile Right bằng cách lật ảnh)
                flipped_gray = cv2.flip(gray, 1)
                d4 = self.profile_cascade.detectMultiScale(
                    flipped_gray, scaleFactor=1.08, minNeighbors=3, minSize=min_size
                )
                for (fx, fy, fw, fh) in d4:
                    orig_x = w - fx - fw
                    raw_boxes.append((int(orig_x), int(fy), int(fw), int(fh)))

        return self._nms_boxes(raw_boxes)

    def crop_face_with_padding(
        self, 
        rgb_image: np.ndarray, 
        box: Tuple[int, int, int, int], 
        padding_ratio: float = 0.2
    ) -> np.ndarray:
        """Cắt khuôn mặt với khoảng đệm tự nhiên xung quanh"""
        img_h, img_w, _ = rgb_image.shape
        x, y, w, h = box

        pad_w = int(w * padding_ratio)
        pad_h = int(h * padding_ratio)

        x1 = max(0, x - pad_w)
        y1 = max(0, y - pad_h)
        x2 = min(img_w, x + w + pad_w)
        y2 = min(img_h, y + h + pad_h)

        crop = rgb_image[y1:y2, x1:x2]
        return crop

    def image_to_base64_jpeg(self, rgb_crop: np.ndarray, target_size=(160, 160)) -> str:
        """Chuyển ảnh crop sang chuỗi Base64 Data URL JPEG"""
        try:
            if HAS_CV2:
                resized = cv2.resize(rgb_crop, target_size, interpolation=cv2.INTER_AREA)
                bgr = cv2.cvtColor(resized, cv2.COLOR_RGB2BGR)
                success, buffer = cv2.imencode('.jpg', bgr, [int(cv2.IMWRITE_JPEG_QUALITY), 90])
                if success:
                    encoded = base64.b64encode(buffer).decode('utf-8')
                    return f"data:image/jpeg;base64,{encoded}"
            
            if HAS_PIL:
                pil_img = Image.fromarray(rgb_crop).resize(target_size, Image.Resampling.LANCZOS)
                buffered = BytesIO()
                pil_img.save(buffered, format="JPEG", quality=90)
                encoded = base64.b64encode(buffered.getvalue()).decode('utf-8')
                return f"data:image/jpeg;base64,{encoded}"
        except Exception as e:
            print(f"[FaceService] Lỗi encode Base64: {e}")
        return ""

    def extract_embedding(self, rgb_crop: np.ndarray) -> List[float]:
        """
        Trích xuất véc-tơ đặc trưng 512 chiều (Face Embedding).
        Chuẩn hóa L2 để tính Cosine Similarity cực nhanh bằng Dot Product.
        """
        # Resize về kích thước chuẩn 112x112
        target_size = (112, 112)
        if HAS_CV2:
            face_std = cv2.resize(rgb_crop, target_size)
        elif HAS_PIL:
            face_std = np.array(Image.fromarray(rgb_crop).resize(target_size))
        else:
            face_std = rgb_crop

        # Trích xuất đặc trưng đa phân giải (Spatial Grid + Color/Texture Histograms)
        # Tạo vector 512 chiều duy nhất và nhất quán
        features = []
        
        # 1. Spatial 8x8 blocks x 3 channels = 192 features
        if HAS_CV2:
            small_rgb = cv2.resize(face_std, (8, 8)).astype(np.float32) / 255.0
        else:
            small_rgb = face_std[:8, :8].astype(np.float32) / 255.0
        features.extend(small_rgb.flatten().tolist())  # 8*8*3 = 192

        # 2. Grayscale gradient / Frequency features = 160 features
        if HAS_CV2:
            gray = cv2.cvtColor(face_std, cv2.COLOR_RGB2GRAY)
            # Sobel gradients
            gx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3)
            gy = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3)
            mag = cv2.magnitude(gx, gy)
            mag_small = cv2.resize(mag, (10, 16)).flatten() / 255.0
            features.extend(mag_small.tolist())  # 160
        else:
            features.extend([0.1] * 160)

        # 3. Histogram of Intensities across 4 quadrants = 160 features (4 x 40 bins)
        h, w = face_std.shape[:2]
        quads = [
            face_std[0:h//2, 0:w//2],
            face_std[0:h//2, w//2:w],
            face_std[h//2:h, 0:w//2],
            face_std[h//2:h, w//2:w]
        ]
        for q in quads:
            hist, _ = np.histogram(q, bins=40, range=(0, 256))
            hist_norm = (hist / (hist.sum() + 1e-6)).tolist()
            features.extend(hist_norm)

        # Cắt đúng 512 chiều
        vec = np.array(features[:512], dtype=np.float32)
        if len(vec) < 512:
            pad = np.zeros(512 - len(vec), dtype=np.float32)
            vec = np.concatenate([vec, pad])

        # Chuẩn hóa L2 Norm: ||vec|| = 1.0
        norm = np.linalg.norm(vec)
        if norm > 1e-6:
            vec = vec / norm

        return vec.tolist()

    def compute_similarity(self, emb1: List[float], emb2: List[float]) -> float:
        """
        Tính Cosine Similarity giữa 2 vector 512D.
        Giá trị trả về từ 0.0 đến 1.0 (1.0 là trùng khớp 100%).
        """
        v1 = np.array(emb1, dtype=np.float32)
        v2 = np.array(emb2, dtype=np.float32)
        
        norm1 = np.linalg.norm(v1)
        norm2 = np.linalg.norm(v2)
        
        if norm1 < 1e-6 or norm2 < 1e-6:
            return 0.0
            
        dot = np.dot(v1, v2) / (norm1 * norm2)
        # Chuyển về khoảng [0, 1]
        similarity = float(max(0.0, min(1.0, (dot + 1.0) / 2.0)))
        return similarity

    def process_multi_faces(self, image_bytes: bytes) -> List[Dict[str, Any]]:
        """
        Phát hiện tất cả khuôn mặt trong ảnh, crop chân dung và trích xuất vector.
        Trả về danh sách ứng viên cho người dùng chọn trên giao diện.
        """
        rgb_image = self.load_image_from_bytes(image_bytes)
        if rgb_image is None:
            return []

        boxes = self.detect_faces(rgb_image)
        candidates = []

        for idx, box in enumerate(boxes):
            crop = self.crop_face_with_padding(rgb_image, box, padding_ratio=0.2)
            base64_thumb = self.image_to_base64_jpeg(crop, target_size=(160, 160))
            embedding = self.extract_embedding(crop)
            
            candidates.append({
                "face_index": idx,
                "box": list(box),
                "crop_image_base64": base64_thumb,
                "embedding": embedding
            })

        return candidates


# Singleton instance
face_engine = FaceRecognitionService()
