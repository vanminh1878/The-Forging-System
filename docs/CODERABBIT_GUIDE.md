# Hướng dẫn kết nối CodeRabbit

CodeRabbit là bot review code tự động trên Pull Request. Cấu hình của dự án nằm ở `.coderabbit.yaml` (đã tạo sẵn ở thư mục gốc, **phải commit**).

## 1. Cài đặt (một lần)
1. Đẩy repo lên GitHub (khuyến nghị: nhánh `main` + `develop`).
2. Vào https://coderabbit.ai → **Login with GitHub** → chọn tổ chức/tài khoản → **Add repositories** → chọn repo này (cấp quyền đọc code + ghi comment PR).
3. Commit `.coderabbit.yaml` lên nhánh mặc định. Từ PR kế tiếp CodeRabbit tự review.
4. Kiểm tra cú pháp YAML (tuỳ chọn): https://docs.coderabbit.ai/configuration/yaml-validator

## 2. Quy trình làm việc đề xuất
1. Tạo nhánh `feature/<ten-tinh-nang>` → code → push → mở PR vào `develop`.
2. CI (`.github/workflows/ci.yml`) chạy typecheck/lint/test; CodeRabbit đăng *Walkthrough* + comment theo dòng.
3. Sửa theo comment hợp lý; có thể hỏi lại bot trong PR: `@coderabbitai giải thích rủi ro race condition ở đây`, hoặc `@coderabbitai review` để review lại sau khi sửa.
4. Merge khi CI xanh và đã xử lý các cảnh báo nghiêm trọng.

## 3. Lệnh trong comment PR
| Lệnh | Tác dụng |
|---|---|
| `@coderabbitai review` | review lại (khi đã tắt auto hoặc sau khi sửa) |
| `@coderabbitai full review` | review toàn bộ lại từ đầu |
| `@coderabbitai summary` | tạo lại bản tóm tắt PR |
| `@coderabbitai resolve` | đánh dấu đã xử lý toàn bộ comment của bot |
| `@coderabbitai pause` / `resume` | tạm dừng / tiếp tục tự review PR này |
| `@coderabbitai generate unit tests` | gợi ý unit test (nên kiểm tra kỹ trước khi dùng) |

Trong tiêu đề PR thêm `WIP` hoặc `DO NOT REVIEW` để bot bỏ qua (đã cấu hình `ignore_title_keywords`).

## 4. Cấu hình hiện tại làm gì
- Review bằng **tiếng Việt**, giọng ngắn gọn, `profile: assertive` (soi kỹ). Đổi `profile: chill` nếu thấy quá nhiều comment.
- Tự review PR vào `main` / `develop`, bỏ qua PR nháp.
- `path_instructions` dạy bot các luật riêng của dự án, ví dụ:
  - migration đã merge không được sửa, bảng mới phải có `tenant_id` + RLS;
  - chỉ ghi `point_transactions` qua `PointsPort.award`; không `new Date()`; không hardcode số nghiệp vụ;
  - mọi route có `requireRoles` + zod; kiến trúc routes → service → repository;
  - Flutter: không hex trong widget, không dùng `BuildContext` sau `await`, mọi màn có loading/empty/error.
- Bật linters: ESLint, Hadolint (Dockerfile), yamllint, gitleaks (phát hiện lộ secret), shellcheck.
- Bỏ qua: `node_modules`, `dist`, lockfile, file sinh tự động (`*.g.dart`).

## 5. Tinh chỉnh
- Giảm ồn: `reviews.profile: chill`, hoặc thêm đường dẫn vào `path_filters` (`"!**/seeds/**"`).
- Thêm luật mới: thêm một mục vào `path_instructions` (viết như hướng dẫn cho một reviewer).
- Dạy bot bằng phản hồi: trả lời comment của bot bằng `@coderabbitai` + lý do (nó ghi nhớ — mục `knowledge_base.learnings`).
- Bot là **trợ lý**, không thay review của người: luôn đọc kỹ gợi ý về nghiệp vụ điểm/hạng/quyền.

## 6. Bảo mật
Không commit `.env`, khoá FCM, mật khẩu thật. gitleaks của CodeRabbit chỉ là lớp phụ; `.gitignore` đã loại `.env*`.
