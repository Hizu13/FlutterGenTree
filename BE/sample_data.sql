-- Sample Data for Events and Finance Modules
-- Run this after the tables are created

-- ============================================================================
-- SAMPLE EVENTS DATA
-- ============================================================================

-- Giỗ tổ ông Nguyễn Văn A
INSERT INTO events (family_id, title, lunar_day, lunar_month, lunar_year, solar_date, time_start, time_end, note, creator_id, is_notified, created_at, updated_at)
VALUES 
(1, 'Giỗ Tổ Ông Nguyễn Văn A', 15, 1, 2026, '2026-02-12', '09:00', '11:00', 'Chuẩn bị hương hoa và lễ vật đầy đủ', 1, 0, NOW(), NOW()),
(1, 'Giỗ Tổ Ông Nguyễn Văn B', 10, 1, 2026, '2026-02-11', '10:00', '12:00', 'Họp mặt tại nhà thờ họ', 2, 0, NOW(), NOW()),
(1, 'Lễ tảo mộ Xuân', 23, 1, 2026, '2026-02-20', '08:30', '10:00', 'Chuẩn bị hương hoa và lễ vật', 1, 0, NOW(), NOW()),
(1, 'Họp họ đầu Năm', 30, 1, 2026, '2026-03-01', '14:00', '16:00', 'Kiểm tra danh sách thành viên và kế hoạch năm', 3, 0, NOW(), NOW()),
(1, 'Giỗ Tổ Ông Nguyễn Văn C', 28, 2, 2026, '2026-04-12', '09:30', '11:30', 'Chuẩn bị cơm lễ và rượu', 2, 0, NOW(), NOW()),
(1, 'Sinh nhật Bà Tổ', 5, 3, 2026, '2026-04-25', '10:00', '12:00', 'Tổ chức tiệc sinh nhật tại nhà văn hóa', 1, 0, NOW(), NOW()),
(1, 'Lễ cúng Tết Đoan Ngọ', 5, 5, 2026, '2026-06-20', '09:00', '11:00', 'Chuẩn bị bánh tro và rượu nếp', 3, 0, NOW(), NOW());

-- ============================================================================
-- SAMPLE FINANCE DATA - INCOME (Thu)
-- ============================================================================

INSERT INTO transactions (family_id, person_id, title, amount, type, category, transaction_date, note, requires_approval, is_approved, created_at, updated_at)
VALUES 
(1, 1, 'Thu tiền công đức tháng 1/2026', 5000000, 'income', 'Công đức', '2026-01-15', 'Thu từ 10 thành viên @ 500k/người', 0, 1, NOW(), NOW()),
(1, 2, 'Thu tiền công đức tháng 2/2026', 4500000, 'income', 'Công đức', '2026-02-10', 'Thu từ 9 thành viên', 0, 1, NOW(), NOW()),
(1, 3, 'Quyên góp sửa mộ', 10000000, 'income', 'Quyên góp', '2026-01-20', 'Quyên góp từ các chi nhánh', 0, 1, NOW(), NOW()),
(1, 1, 'Lì xì đầu năm', 2000000, 'income', 'Lì xì', '2026-02-01', 'Các thành viên đóng góp lì xì cho quỹ', 0, 1, NOW(), NOW());

-- ============================================================================
-- SAMPLE FINANCE DATA - EXPENSE (Chi)
-- ============================================================================

INSERT INTO transactions (family_id, person_id, title, amount, type, category, transaction_date, note, requires_approval, is_approved, created_at, updated_at)
VALUES 
(1, 1, 'Mua hương hoa cho giỗ tổ', 1500000, 'expense', 'Lễ vật', '2026-02-10', 'Hương, hoa, bánh kẹo, trái cây', 0, 1, NOW(), NOW()),
(1, 2, 'Chi phí nhà thờ họ', 2000000, 'expense', 'Bảo trì', '2026-01-25', 'Sửa chữa mái nhà và sơn lại', 1, 1, NOW(), NOW()),
(1, 3, 'Mua lễ vật tảo mộ', 800000, 'expense', 'Lễ vật', '2026-02-18', 'Hương, hoa, vàng mã', 0, 1, NOW(), NOW()),
(1, 1, 'Chi phí tổ chức họp họ', 1200000, 'expense', 'Tổ chức', '2026-02-28', 'Thuê địa điểm, nước uống, in tài liệu', 0, 1, NOW(), NOW()),
(1, 2, 'Sửa mộ Ông Tổ', 8000000, 'expense', 'Sửa mộ', '2026-02-15', 'Sửa chữa và làm mới khu mộ', 1, 1, NOW(), NOW());

-- ============================================================================
-- SAMPLE FINANCE DATA - MERIT (Công đức)
-- ============================================================================

INSERT INTO transactions (family_id, person_id, title, amount, type, category, transaction_date, note, requires_approval, is_approved, created_at, updated_at)
VALUES 
(1, 1, 'Công đức Nguyễn Văn A', 500000, 'merit', 'Công đức', '2026-01-15', 'Công đức tháng 1', 0, 1, NOW(), NOW()),
(1, 2, 'Công đức Nguyễn Văn B', 500000, 'merit', 'Công đức', '2026-01-15', 'Công đức tháng 1', 0, 1, NOW(), NOW()),
(1, 3, 'Công đức Nguyễn Văn C', 500000, 'merit', 'Công đức', '2026-01-15', 'Công đức tháng 1', 0, 1, NOW(), NOW()),
(1, 4, 'Công đức Nguyễn Văn D', 1000000, 'merit', 'Công đức', '2026-01-20', 'Công đức đặc biệt cho quỹ sửa mộ', 0, 1, NOW(), NOW()),
(1, 1, 'Công đức Nguyễn Văn A', 500000, 'merit', 'Công đức', '2026-02-10', 'Công đức tháng 2', 0, 1, NOW(), NOW());

-- ============================================================================
-- QUERIES TO CHECK DATA
-- ============================================================================

-- Kiểm tra events
-- SELECT * FROM events ORDER BY solar_date;

-- Kiểm tra transactions
-- SELECT * FROM transactions ORDER BY transaction_date DESC;

-- Tổng hợp tài chính
-- SELECT 
--     type,
--     SUM(amount) as total,
--     COUNT(*) as count
-- FROM transactions
-- WHERE family_id = 1
-- GROUP BY type;

-- Tổng hợp theo category
-- SELECT 
--     category,
--     type,
--     SUM(amount) as total,
--     COUNT(*) as count
-- FROM transactions
-- WHERE family_id = 1
-- GROUP BY category, type
-- ORDER BY total DESC;
