# STF-05 — Admin: danh sách nhân sự và bộ lọc

## Entry point

Đăng nhập tài khoản Admin/Super Admin → tab **Thành viên** → màn **Nhân sự**.
Route giữ nguyên `/admin/members` trong Admin role shell.

## Chức năng

- Danh sách Coach, Head Coach, Lễ tân, Admin, Super Admin từ API thật.
- Card compact: tên nổi bật, role, chi nhánh và trạng thái tài khoản.
- Tìm tên/email/SĐT bằng query server `q`, debounce 350ms, hỗ trợ submit bàn phím.
- Popup bộ lọc vai trò, trạng thái ACTIVE/LOCKED/DISABLED và chi nhánh.
- Bộ lọc áp dụng đồng thời; đổi tìm kiếm/bộ lọc đưa về trang 1.
- Phân trang server 20 dòng/trang, tổng số kết quả, trang trước/sau.
- Làm mới bằng nút hoặc pull-to-refresh; giữ bộ lọc khi refresh.
- Chạm card để mở popup hồ sơ từ dữ liệu list: liên hệ, vai trò, trạng thái, chi nhánh và cờ đổi mật khẩu tạm.
- Loading, empty, API error/retry; lỗi không bị biến thành danh sách rỗng.
- Cache theo query và user hiện tại; response tìm kiếm cũ không ghi đè query mới.

## API phụ thuộc

```http
GET /api/v1/admin/staff?q=&role=&status=&branchId=&page=1&limit=20
```

Dùng `ApiClient`/Dio hiện có: tự gửi Bearer token, tenant header và xử lý refresh/error theo nền tảng.
Backend cần có module nhân sự STF-01. Nếu chạy backend main chưa có STF-01, màn sẽ báo lỗi API thay vì hiển thị dữ liệu mock.

Options chi nhánh ưu tiên `GET /branches` (BR-01). Chỉ khi endpoint trả 404, repository mới đọc các trang nhân sự không filter để tổng hợp chi nhánh có nhân sự.
Fallback giữ đúng branch ID thực tế và loại trùng; không hiển thị chi nhánh chưa có nhân sự nếu BR-01 chưa có.
Lỗi 401/403/5xx của API chi nhánh không bị che bằng fallback. Người dùng có thể retry chi nhánh hoặc tiếp tục lọc role/status.

## Cấu trúc

```text
mobile/lib/features/staff/
  domain/staff_models.dart
  domain/staff_repository.dart
  data/staff_dto.dart
  data/staff_repository_impl.dart
  presentation/staff_providers.dart
  presentation/screens/staff_directory_screen.dart
  presentation/widgets/staff_filter_sheet.dart
  presentation/widgets/staff_member_card.dart
```

STF-05 là màn danh sách/tìm kiếm và hồ sơ read-only. Form tạo nhân sự, đổi quyền, reset mật khẩu không thuộc task FE này.

## Chạy và kiểm tra

```sh
flutter run -d chrome --web-port=3000 --dart-define=API_BASE_URL=http://localhost:4000/api/v1
flutter analyze
flutter test test/features/staff
flutter test
```

Tests mới bao gồm parsing DTO/nullables/multiple roles, query/header/pagination, branch fallback qua nhiều trang,
lỗi quyền, tìm kiếm debounce, lọc kết hợp, xem hồ sơ, next page, retry và response đến muộn.

Đã xác minh: `flutter analyze --no-pub` không có lỗi; 14 test STF-05 pass và toàn bộ 135 Flutter tests pass.
STF-05 được đóng gói thành commit FE riêng trên nhánh nhân sự, tiếp sau các task STF-01–04.
