# ARM-06 — Danh sách quà theo tầng

Học viên mở tab **Armory**. Màn hình đọc `GET /api/v1/armory/tiers` và `GET /api/v1/armory/rewards` của ARM-01 bằng token MEMBER.
Chọn tầng sẽ lọc phía server và trở về trang 1; có lựa chọn Tất cả, phân trang, refresh và retry khi lỗi.
Card hiển thị tên, hình nếu có, tầng, giá Marks, số lượng/hết hàng, mô tả và điều kiện hạng/giới hạn khi API cung cấp.
Chỉ hiển thị catalog do ARM-01 trả về; không tự suy luận học viên đủ điều kiện đổi và không tạo đơn đổi quà.

Backend cần chạy code ARM-01 cùng tenant `hvp`. Test: `flutter analyze --no-pub` và `flutter test --no-pub test/features/armory`.
