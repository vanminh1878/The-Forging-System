# ARM-07 — Chi tiết quà và điều kiện

Từ tab Armory, chạm card quà để mở popup chi tiết: hình/tên/tầng, giá Marks, tồn kho, mô tả, hạng tối thiểu, giới hạn đổi, thời gian nhận và thời gian mở bán nếu API cung cấp.

ARM-01 hiện chỉ có API danh sách, không có endpoint chi tiết riêng. Popup dùng record catalog đã tải; không gọi API giả hoặc tự kết luận học viên đủ điều kiện. Giá/tồn là dữ liệu tại thời điểm tải danh sách, cần refresh để cập nhật.
Việc tạo đơn đổi quà thuộc task khác. Test: `flutter analyze --no-pub`, `flutter test --no-pub test/features/armory`.
