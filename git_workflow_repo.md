# Quy trình Tạo Pull Request (PR) và Merge Code trên GitHub

> **Mục tiêu:** Đảm bảo code từ các nhánh tính năng được kiểm tra, review và merge đúng vào `develop`, tránh ảnh hưởng đến `main` và các nhánh khác.

---

# 1. Tạo Pull Request (PR)

Sau khi đã push nhánh tính năng lên GitHub, mở trình duyệt và truy cập vào **repository của dự án** trên GitHub.

Ví dụ nhánh vừa push:

```text
feature/hieu-events-ui
```

## Cách 1: Sử dụng thông báo trên GitHub

Ngay đầu trang repository, GitHub thường hiển thị một khung thông báo màu vàng:

```text
feature/hieu-events-ui had recent pushes...
```

Bấm nút:

```text
Compare & pull request
```

## Cách 2: Tạo PR thủ công

Nếu không thấy khung thông báo trên, thực hiện:

```text
Pull requests
      ↓
New pull request
```

Sau đó chuyển sang màn hình tạo Pull Request.

---

# 2. Kiểm tra và Cấu hình Pull Request

Tại màn hình:

```text
Open a pull request
```

Cần kiểm tra thật kỹ các thông tin trước khi tạo PR.

---

## 2.1. Kiểm tra nhánh nhận và nhánh gửi

> ⚠️ **ĐÂY LÀ BƯỚC QUAN TRỌNG NHẤT**

Phải đảm bảo:

```text
base:    develop
compare: feature/hieu-events-ui
```

Trong đó:

### Base

Chọn:

```text
develop
```

> ❌ **Tuyệt đối không chọn `main`**

### Compare

Chọn đúng branch tính năng của mình:

```text
feature/hieu-events-ui
```

Kết quả phải có dạng:

```text
feature/hieu-events-ui  →  develop
```

Không được để:

```text
feature/hieu-events-ui  →  main
```

---

## 2.2. Kiểm tra trạng thái Merge

Ngay bên dưới phần chọn branch, kiểm tra thông báo của GitHub.

Nếu hiển thị:

```text
Able to merge
```

và có màu xanh lá:

```text
Able to merge
```

thì branch hiện tại **không có conflict** với `develop`.

Nếu GitHub thông báo có conflict, cần xử lý conflict trước khi tiếp tục.

---

# 2.3. Điền Title và Description

## Title

Đặt tên ngắn gọn, mô tả đúng task đã thực hiện.

Ví dụ:

```text
feat: implement events calendar UI
```

Một số ví dụ khác:

```text
feat: add family tree screen
fix: fix events calendar layout
ui: update member profile screen
feat: add event creation popup
```

---

## Description

Mô tả những công việc đã hoàn thành trong PR.

Ví dụ:

```markdown
## Changes

- Vẽ giao diện danh sách sự kiện
- Thêm giao diện lịch sự kiện
- Thêm popup tạo sự kiện
- Cập nhật responsive layout
```

Có thể sử dụng checklist để dễ theo dõi:

```markdown
## Completed

- [x] Vẽ giao diện danh sách sự kiện
- [x] Thêm giao diện lịch
- [x] Thêm popup tạo sự kiện
- [x] Kiểm tra responsive
```

---

# 2.4. Gán Người Review (Reviewers)

Ở cột bên phải của màn hình Pull Request, tìm mục:

```text
Reviewers
```

Bấm chọn người cần review code.

Ví dụ:

```text
Leader
```

hoặc một thành viên khác trong nhóm có nhiệm vụ review.

Sau khi kiểm tra tất cả thông tin:

```text
Base:       develop
Compare:    feature/hieu-events-ui
Title:      feat: implement events calendar UI
Reviewer:   Leader
```

Bấm:

```text
Create pull request
```

---

# 3. Duyệt Code — Dành cho Leader / Người Review

Sau khi Pull Request được tạo, người được gán Review sẽ nhận được thông báo.

Người review thực hiện:

```text
Repository
    ↓
Pull requests
    ↓
Chọn Pull Request cần review
```

---

## 3.1. Kiểm tra Files Changed

Tại màn hình Pull Request, chọn:

```text
Files changed
```

Tại đây người review có thể kiểm tra toàn bộ code đã thay đổi.

Cần kiểm tra:

* Code có đúng chức năng không?
* Có code thừa không?
* Có ảnh hưởng đến tính năng khác không?
* Có lỗi logic không?
* Có đúng quy tắc của project không?
* UI có đúng thiết kế không?
* Có file nào không liên quan bị đưa vào PR không?
* Có vấn đề về format hoặc naming không?

---

## 3.2. Approve Pull Request

Nếu code đạt yêu cầu:

```text
Conversation
      ↓
Review changes
      ↓
Approve
      ↓
Submit review
```

Sau khi Approve, Pull Request có thể được Merge nếu các điều kiện khác của repository đều đạt.

---

# 4. Gộp Code (Merge) và Dọn Dẹp Nhánh

Sau khi Pull Request đã được **Approve**, người có quyền Merge tiến hành gộp code vào `develop`.

Tại màn hình Pull Request, chọn:

```text
Squash and merge
```

Hoặc tùy cấu hình repository có thể sử dụng:

```text
Confirm merge
```

---

## 4.1. Squash and Merge

Nếu chọn:

```text
Squash and merge
```

GitHub sẽ gộp các commit trong Pull Request thành một commit trước khi đưa vào `develop`.

Ví dụ:

```text
feature/hieu-events-ui

    commit 1
    commit 2
    commit 3
    commit 4
         │
         ▼
   Squash and merge
         │
         ▼
develop

    1 commit
```

Sau đó bấm:

```text
Confirm squash and merge
```

---

# 4.2. Kiểm tra Merge thành công

Sau khi Merge thành công, GitHub sẽ hiển thị thông báo tương tự:

```text
Pull request successfully merged and closed
```

Điều này có nghĩa:

```text
feature/hieu-events-ui
          │
          │ Pull Request
          ▼
       develop
          │
          ▼
       MERGED
```

---

# 4.3. Xóa Feature Branch trên GitHub

Sau khi Merge thành công, GitHub sẽ hiển thị nút:

```text
Delete branch
```

Bấm:

```text
Delete branch
```

để xóa branch tính năng trên GitHub.

Ví dụ:

```text
feature/hieu-events-ui
```

sẽ được xóa sau khi đã Merge.

> Việc xóa branch sau khi hoàn thành giúp repository luôn gọn gàng và tránh nhầm lẫn với các branch cũ.

---

# 5. Thông báo cho Team sau khi Merge

Sau khi Merge thành công, người thực hiện nên thông báo lên nhóm để các thành viên khác biết code mới đã được cập nhật vào `develop`.

Ví dụ:

```text
Tớ vừa merge màn hình Events vào develop rồi nhé!
```

Các thành viên khác sau đó chuyển về `develop` ở máy local và cập nhật code mới nhất:

```bash
git checkout develop
git pull origin develop
```

Sau khi Pull thành công, máy local sẽ có code mới nhất từ `develop`.

---

# 6. Quy trình tổng thể

```text
┌─────────────────────────────┐
│  Push feature branch        │
│  lên GitHub                 │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Tạo Pull Request           │
│  feature → develop          │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Kiểm tra Base / Compare    │
│  base = develop             │
│  compare = feature/...      │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Kiểm tra "Able to merge"   │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Điền Title + Description   │
│  + Chọn Reviewer             │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Create Pull Request        │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Leader / Reviewer          │
│  kiểm tra Files changed     │
└──────────────┬──────────────┘
               │
               ▼
        ┌───────────────┐
        │ Code đạt yêu  │
        │ cầu?          │
        └───────┬───────┘
          Có    │    Không
          │     │
          │     └──────────────┐
          │                    ▼
          │              Sửa code
          │                    │
          │                    └──→ Review lại
          ▼
┌─────────────────────────────┐
│  Approve                    │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Squash and merge           │
│  → Confirm squash and merge │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Pull Request successfully  │
│  merged and closed          │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Delete branch              │
│  trên GitHub                │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Thông báo cho Team         │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ Các thành viên:             │
│ git checkout develop        │
│ git pull origin develop     │
└─────────────────────────────┘
```

---

# 7. Checklist trước khi Merge

Trước khi bấm **Merge**, cần đảm bảo:

```markdown
- [ ] Base branch là develop
- [ ] Compare branch là feature của mình
- [ ] Không chọn main
- [ ] Hiển thị Able to merge
- [ ] Title rõ ràng
- [ ] Description đầy đủ
- [ ] Đã chọn Reviewer
- [ ] Reviewer đã kiểm tra Files changed
- [ ] Reviewer đã Approve
- [ ] Không còn conflict
- [ ] Đã Squash and merge
- [ ] Đã Delete branch sau khi Merge
- [ ] Đã thông báo cho Team
```

---

# 8. Nguyên tắc quan trọng

> ## `feature` → `Pull Request` → `Review` → `develop`

**Không được tự ý:**

```text
feature → main
```

**Quy trình chuẩn của Team:**

```text
feature/hieu-events-ui
          │
          ▼
    Pull Request
          │
          ▼
       Review
          │
          ▼
       Approve
          │
          ▼
   Squash and Merge
          │
          ▼
       develop
          │
          ▼
   Delete feature branch
```

> **Quy tắc cốt lõi:** Mỗi tính năng tạo một branch riêng, mỗi branch tạo một Pull Request riêng, review riêng và merge riêng vào `develop`.
