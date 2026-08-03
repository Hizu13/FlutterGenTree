# Quy trình đẩy Code và Merge riêng cho từng Nhánh

> **Mục tiêu:** Đảm bảo các nhánh không đè code lên nhau và mỗi tính năng được phát triển, review, merge độc lập.

Mỗi tính năng phải tuân thủ đúng **5 bước** dưới đây.

---

## Bước 1: Rẽ nhánh riêng từ `develop` mới nhất

Tạo nhánh cho **DUY NHẤT 1 tính năng**.

Trước khi làm một tính năng mới, ví dụ `events`, luôn kéo code `develop` mới nhất về trước:

```bash
# Chuyển sang nhánh develop
git checkout develop

# Cập nhật develop mới nhất từ GitHub
git pull origin develop

# Tạo nhánh riêng cho tính năng
git checkout -b feature/hieu-events-ui
```

### Quy tắc

* Mỗi nhánh chỉ làm **một tính năng**.
* Không làm nhiều tính năng khác nhau trên cùng một branch.
* Luôn tạo branch mới từ `develop` mới nhất.
* Đặt tên branch theo quy ước:

```text
feature/<tên-người-làm>-<tên-tính-năng>
```

Ví dụ:

```text
feature/hieu-events-ui
feature/nam-login
feature/linh-family-tree
```

---

## Bước 2: Commit code thuộc về tính năng đó

Chỉ commit những file liên quan trực tiếp đến tính năng đang làm.

Ví dụ tính năng `events`:

```bash
git add lib/features/events/
git commit -m "feat: complete UI for events and calendar screen"
```

### Quy tắc Commit

Không nên commit toàn bộ project nếu chỉ đang làm một tính năng.

**Không nên:**

```bash
git add .
```

nếu trong project đang có nhiều thay đổi không liên quan.

**Nên:**

```bash
git add lib/features/events/
```

Hoặc chỉ add đúng các file cần thiết:

```bash
git add lib/features/events/events_screen.dart
git add lib/features/events/calendar_screen.dart
```

### Quy tắc đặt Commit Message

Có thể sử dụng Conventional Commits:

```text
feat: thêm tính năng mới
fix: sửa lỗi
ui: cập nhật giao diện
refactor: tái cấu trúc code
docs: cập nhật tài liệu
chore: công việc cấu hình/bảo trì
```

Ví dụ:

```bash
git commit -m "feat: complete UI for events and calendar screen"
```

---

## Bước 3: Sync code từ `develop` trước khi Push

Trước khi push branch lên GitHub, cần cập nhật `develop` mới nhất.

Điều này giúp lấy những thay đổi của các thành viên khác đã được merge vào `develop`.

### Cập nhật `develop`

```bash
# Chuyển sang develop
git checkout develop

# Lấy code mới nhất
git pull origin develop
```

### Merge `develop` vào branch cá nhân

```bash
# Quay lại branch đang làm
git checkout feature/hieu-events-ui

# Merge develop mới nhất vào branch
git merge develop
```

Nếu xảy ra conflict, xử lý conflict trước khi tiếp tục:

```bash
git status
```

Sau khi sửa conflict:

```bash
git add .
git commit -m "fix: resolve merge conflicts with develop"
```

### Mục đích của bước này

```text
develop
   │
   ├── Code của thành viên A
   ├── Code của thành viên B
   └── Code mới đã được merge
          │
          ▼
feature/hieu-events-ui
          │
          └── Cập nhật code mới nhất
```

> **Không nên bỏ qua bước này**, đặc biệt khi nhiều thành viên cùng phát triển project.

---

## Bước 4: Push nhánh riêng lên GitHub

Sau khi đã cập nhật `develop` và xử lý xong conflict nếu có, push branch cá nhân lên GitHub:

```bash
git push origin feature/hieu-events-ui
```

Nếu đây là lần đầu push branch:

```bash
git push -u origin feature/hieu-events-ui
```

Sau khi push thành công, branch sẽ xuất hiện trên GitHub:

```text
GitHub
│
├── develop
├── feature/hieu-events-ui
├── feature/nam-login
├── feature/linh-family-tree
└── ...
```

---

## Bước 5: Tạo Pull Request và Merge riêng trên GitHub

Sau khi push branch, vào GitHub để tạo **Pull Request (PR)**.

### Tạo Pull Request

Thiết lập:

```text
Base branch:
develop

Compare branch:
feature/hieu-events-ui
```

Tức là:

```text
feature/hieu-events-ui
          │
          │ Pull Request
          ▼
       develop
```

### Leader / thành viên review

Người phụ trách sẽ kiểm tra:

* Giao diện
* Chức năng
* Code
* Quy tắc đặt tên
* Không ảnh hưởng đến tính năng khác
* Không có code thừa
* Không có lỗi build

Nếu code đạt yêu cầu:

```text
Approve
   ↓
Merge Pull Request
```

### Cách Merge

Ưu tiên sử dụng:

```text
Squash and merge
```

hoặc:

```text
Merge pull request
```

Tùy theo quy định của nhóm.

Sau khi merge thành công:

```text
feature/hieu-events-ui
          │
          │ Pull Request
          ▼
       develop
          │
          ▼
     Code chính thức
```

### Xóa branch sau khi Merge

Sau khi merge thành công, xóa branch đã hoàn thành để repository gọn gàng:

```text
feature/hieu-events-ui
          │
          ▼
       MERGED
          │
          ▼
       DELETE
```

Có thể xóa trực tiếp trên GitHub bằng nút:

```text
Delete branch
```

Hoặc xóa branch local:

```bash
git branch -d feature/hieu-events-ui
```

---

# Tóm tắt 5 bước

| Bước  | Công việc                            | Lệnh chính                    |
| ----- | ------------------------------------ | ----------------------------- |
| **1** | Cập nhật `develop` và tạo branch     | `git checkout -b feature/...` |
| **2** | Commit code của tính năng            | `git add` → `git commit`      |
| **3** | Merge `develop` mới nhất vào branch  | `git merge develop`           |
| **4** | Push branch lên GitHub               | `git push origin feature/...` |
| **5** | Tạo PR → Review → Merge → Xóa branch | GitHub Pull Request           |

---

# Quy trình chuẩn

```text
                 ┌─────────────────┐
                 │     develop     │
                 └────────┬────────┘
                          │
                    git pull origin
                          │
                          ▼
                 ┌─────────────────┐
                 │ Tạo feature     │
                 │ branch riêng    │
                 └────────┬────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │  Code 1 tính    │
                 │     năng        │
                 └────────┬────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │      Commit     │
                 └────────┬────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │ Update develop  │
                 │ + merge vào     │
                 │ feature branch  │
                 └────────┬────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │ Push lên GitHub │
                 └────────┬────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │ Pull Request    │
                 │ feature →       │
                 │ develop         │
                 └────────┬────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │ Review + Approve│
                 └────────┬────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │      Merge      │
                 └────────┬────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │ Delete feature  │
                 │     branch      │
                 └─────────────────┘
```

---

# Nguyên tắc quan trọng của Team

> **1 Branch = 1 Feature = 1 Pull Request**

Ví dụ:

```text
feature/hieu-events-ui
        ↓
Events UI
        ↓
1 Pull Request
        ↓
develop
```

Không nên:

```text
feature/hieu
    ├── Events
    ├── Login
    ├── Family Tree
    └── Profile
```

Mà nên tách thành:

```text
feature/hieu-events-ui
feature/hieu-login
feature/hieu-family-tree
feature/hieu-profile
```

Như vậy khi một tính năng gặp lỗi hoặc chưa được duyệt, các tính năng khác **không bị ảnh hưởng**.
