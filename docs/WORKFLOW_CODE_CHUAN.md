# WORKFLOW CODE CHUẨN – HVP Forging System (v3)

Nguyên tắc: rule nào máy kiểm tra được thì để lint/test/CI chặn, không chỉ ghi chữ.
Developer hay nghĩ tới "chạy đúng"; tester nghĩ tới "chạy sai". Khi tự test, luôn nghĩ như tester.

Luồng:
Nhận task → [1] Nạp context + Plan → ⛔ Người dùng confirm → Code → [2] Checklist tự kiểm → [3] Báo cáo
(Rule ở mục 3 áp dụng suốt quá trình. Mục 4 là bug đã gặp. Mục 5 là cách ép rule bằng máy.)

> **Ghi chú:** Cấu trúc 5 mục lớn và rule 1–42 giữ nguyên. Nội dung bổ sung (từ `PROJECT_WORKFLOW.md`) được gài vào đúng mục liên quan và đánh dấu **(bổ sung)**.

---

## 1. NẠP CONTEXT + PLAN (chờ "OK" mới được sửa file)

### 1.1 Luôn nạp

- CLAUDE.md, dòng task trong bảng kế hoạch (mã, mô tả, phụ thuộc)
- git status + nhánh hiện tại (tránh đụng thay đổi dang dở)
- Mục 3 và 4 của workflow này

### 1.2 Theo loại task

Backend:

- docs/BACKEND_GUIDE.md, docs/ARCHITECTURE.md
- Module tham chiếu ranks/ hoặc points/
- src/container.ts, shared/ports.ts, shared/events.ts
- Migration gần nhất + 0002 (mẫu RLS) nếu có bảng mới
- settings/settings.catalog.ts nếu có con số nghiệp vụ
- tests/helpers/test-app.ts

Mobile:

- docs/MOBILE_GUIDE.md, mobile/README.md (công thức 7 bước)
- Feature mẫu fighter_record
- lib/app/routes/\<role\>\_routes.dart, route_paths.dart, role_redirect.dart
- test/helpers/scripted_adapter.dart, pumpHvp
- Theme tokens (context.hvp / context.txt) và widget dùng chung (AsyncBody, EmptyState, nút, field)

Task đụng điểm/tiền: points.rules.ts + trigger trong migration.
Task có màn hình mới: đọc luôn mục 4 để không lặp lại lỗi cũ.

### 1.3 Mẫu Plan gửi người dùng

```text
PLAN – <MÃ TASK>: <tên>
1. Hiểu yêu cầu (diễn đạt lại 1–3 dòng, theo 5W1H: Ai dùng? Màn hình nào? Khi nào? Vì sao? Làm thế nào?). Ngoài phạm vi: ...
2. Context đã đọc + điểm chưa rõ (câu hỏi cho người dùng)
3. Thiết kế: luồng route→service→repo (BE) / domain-data-presentation (mobile); event/port; bảng/cột mới
4. File sẽ TẠO / SỬA / không đụng
5. Migration + setting mới (key, mặc định)
6. Màn hình & field: liệt kê từng field với kiểu, bắt buộc?, maxlength, định dạng, thông báo lỗi
7. Kế hoạch test: positive / negative / biên / ad-hoc (xem 2.D)
8. Rủi ro, phụ thuộc
9. Lệnh kiểm chứng sẽ chạy
→ Người dùng trả lời: OK / sửa mục X
```

Task rất nhỏ (typo, đổi chữ): ghi plan 1 dòng rồi làm.

### 1.4 Pre-flight trước khi sửa bất kỳ file nào (bổ sung)

Làm xong pre-flight rồi mới gửi Plan (1.3). Chưa có "OK" thì chỉ được đọc, không được sửa/tạo/xóa file.

| ID   | Bước                                                                       | Cách thực hiện                                                                                                                            |
| ---- | -------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| S-01 | Xác định **task, actor, branch/worktree đích, danh sách file dự kiến sửa** | Trích từ yêu cầu; nếu thiếu → hỏi (1.5)                                                                                                   |
| S-02 | Đọc tài liệu liên quan                                                     | `CLAUDE.md`, tài liệu API/workflow trong `docs/`, route backend, feature tương ứng (xem 1.2)                                              |
| S-03 | Kiểm tra trạng thái Git                                                    | `git status --short`, `git diff --stat`, `git diff --cached --stat`; ghi nhận file đã bị sửa/staged **trước** khi mình bắt đầu (baseline) |
| S-04 | Xác minh endpoint bằng **route backend + `requireRoles`**                  | Mở file route thực tế; không dựa vào tên endpoint hay tài liệu đơn lẻ                                                                     |
| S-05 | Nêu assumption                                                             | Liệt kê; nếu assumption ảnh hưởng data model, role semantics, state nghiệp vụ hoặc API → **hỏi** (1.5)                                    |
| S-06 | **Cổng duyệt Plan**                                                        | Sau pre-flight, trả Plan (1.3) rồi **chờ người dùng trả lời "OK"**. Ngoại lệ: loại rút gọn ở 2.H                                          |

Baseline (S-03) là tập file đã thay đổi khi bắt đầu; mọi file trong baseline là "không do mình tạo" (xem rule 53).

Đầu ra pre-flight (ghi trong phản hồi đầu tiên của task):

```yaml
preflight:
  task: "<mô tả ngắn>"
  actor: "<MEMBER|COACH|RECEPTIONIST|ADMIN|...>"
  branch: "<tên branch hiện tại>"
  target_branch_confirmed: true|false
  planned_files: ["path/a", "path/b"]
  baseline_dirty_files: ["path/x"] # file đã dirty trước khi bắt đầu
  docs_read: ["CLAUDE.md", "docs/..."]
  endpoints_verified: [{ path: "/...", method: "GET", roles: ["..."], source: "file:line" }]
  assumptions: ["..."]
  blocking_questions: ["..."] # nếu không rỗng → dừng, không code
  plan_approved: false # chỉ đổi thành true khi người dùng trả lời OK (S-06)
```

### 1.5 Điểm phải dừng và hỏi người dùng (bổ sung)

Phải dừng ngay, **không code tiếp**, khi gặp một trong các tình huống sau. Không thay "hỏi" bằng assumption hoặc workaround UI.

| ID   | Tình huống                                                                                                                                 |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Q-01 | Chưa rõ branch/worktree đích, hoặc scope gồm nhiều feature độc lập.                                                                        |
| Q-02 | API trả 401/403, endpoint không có route/RBAC cho actor hiện tại, hoặc client/backend contract khác nhau.                                  |
| Q-03 | Cần đổi personal ↔ shared semantics, actor/recipient, read state, state transition, reward hoặc ownership.                                 |
| Q-04 | Cần schema/migration mới, endpoint mới, hoặc thay đổi shared component ảnh hưởng feature khác.                                             |
| Q-05 | Cần xóa/revert/stage thay đổi chưa rõ nguồn gốc.                                                                                           |
| Q-06 | Tài liệu mâu thuẫn với code/contract và chưa có chỉ dẫn chọn bên (xem 2.I).                                                                |
| Q-07 | Lệnh kiểm tra bắt buộc không xác định được (P-00 ở 1.6).                                                                                   |
| Q-08 | Tag/mã task, dependency, scope, branch hoặc yêu cầu trong task mâu thuẫn nhau; không rõ phần nào phải làm.                                 |
| Q-09 | Nghiệp vụ mơ hồ hoặc chưa được chốt (ví dụ ý nghĩa của một trường, quy tắc gia hạn, quyền của một role, điều kiện hủy/đóng băng) — rule 6. |

**Q-08:** Ngay khi phát hiện mâu thuẫn giữa tag/mã task (ví dụ danh sách có `STK-*` nhưng branch hoặc yêu cầu nhắc `GFT-*`), phải dùng định dạng câu hỏi bên dưới để xin xác nhận scope. Không tự suy diễn rằng tag phụ thuộc, code đã tồn tại, hoặc một yêu cầu xuất hiện trước/sau có nghĩa là phần đó được phép làm hoặc được bỏ qua.

Định dạng câu hỏi:

```md
### Cần xác nhận trước khi tiếp tục

- Tình huống: <ID Q-xx>
- Điều đã xác minh: <file:line / lệnh / kết quả>
- Câu hỏi cụ thể: <một câu hỏi đóng, càng ít lựa chọn càng tốt>
- Lựa chọn khả dĩ: (A) ... (B) ...
- Ảnh hưởng nếu chọn mỗi phương án: ...
- Trạng thái hiện tại: chưa sửa file nào / đã sửa: <danh sách>
```

### 1.6 Cách áp dụng rule (bổ sung)

1. Mỗi rule có số hoặc ID. Khi báo cáo, trích dẫn số rule (hoặc ID như `G-01`) thay vì diễn giải lại.
2. Mức độ: rule ở mục 3 mặc định là **MUST / MUST NOT** — chỉ được ngoại lệ khi người dùng xác nhận rõ ràng **bằng văn bản trong task hiện tại** (xác nhận ở task cũ không áp dụng cho task mới). **SHOULD**: nên làm; nếu bỏ qua phải nêu lý do.
3. Hai rule có vẻ mâu thuẫn: áp dụng rule **an toàn hơn** (ít thay đổi hơn, ít quyền hơn) rồi **dừng và hỏi** (1.5).
4. Không chắc một hành động có nằm trong scope hay không: coi như **không nằm trong scope** và hỏi.
5. Nguồn chuẩn **nghiệp vụ** khi mâu thuẫn: `người dùng (văn bản, task hiện tại)` > `CLAUDE.md` > `docs/` của domain > code hiện hành. Workflow này không tự định nghĩa nghiệp vụ.
6. Nguồn chuẩn **quy trình/an toàn**: workflow này là bắt buộc cho scope, Git, kiểm thử, báo cáo và điểm dừng; không dùng code hiện hành hoặc tài liệu domain để bỏ qua.
7. Đúng nghiệp vụ, RBAC và API contract quan trọng hơn tốc độ tạo UI. Không suy diễn workflow từ tên feature, route tồn tại hoặc UI đang hiển thị được.
8. `flutter analyze`, typecheck hoặc widget test pass **không phải** bằng chứng workflow đã đúng.

**P-00:** Nếu lệnh của một gate không có trong bảng biến lệnh (2.A), không được tự đoán. Tìm trong `package.json` / `pubspec.yaml` / `CLAUDE.md`; nếu vẫn không có thì ghi gate là `BLOCKED` ("không xác định được lệnh") và hỏi người dùng (Q-07).

### 1.7 Checklist thực thi tổng thể (bổ sung)

```text
[ ] 1. Pre-flight đầy đủ (1.4), ghi block `preflight`
[ ] 2. Có điểm dừng nào (1.5)? → hỏi, không code
[ ] 3. Gửi Plan (1.3) và CHỜ "OK" của người dùng (S-06)
[ ] 4. Chỉ sửa file trong planned_files; không chạm baseline_dirty_files (rule 53, G-02, G-07)
[ ] 5. Tuân thủ rule mục 3 (backend / mobile / UI-UX) liên quan
[ ] 6. Viết/cập nhật test theo 2.G và thiết kế ca theo 2.D
[ ] 7. Cập nhật tài liệu domain (D-01)
[ ] 8. Chạy gate theo 2.H (hoặc rút gọn nếu đủ điều kiện), gồm ui_ux và test_design khi áp dụng
[ ] 9. Đối chiếu git status với scope; không tự stage/commit (G-03, G-05)
[ ] 10. Báo cáo theo mẫu 2.F + 2.H; Overall theo trạng thái ở 2.H
```

### 1.8 Prompt mẫu để giao việc cho AI agent (bổ sung)

```text
Bạn đang làm việc trong repo HVP Forging System. Trước khi làm bất cứ điều gì,
đọc và tuân thủ `CLAUDE.md` và workflow code chuẩn của dự án.

Task: <mô tả>
Actor: <role>
Branch đích: <tên branch>
Được phép: <ví dụ: sửa file, chạy test>
KHÔNG được phép (trừ khi tôi nói rõ ở đây): commit, push, stage, tạo PR, đổi branch.

Yêu cầu đầu ra:
1. Trả block `preflight` (1.4), rồi trả Plan (1.3) và CHỜ tôi trả lời "OK" trước khi sửa file.
2. Nếu gặp điểm dừng (1.5), hỏi theo định dạng quy định và dừng.
3. Nếu task có màn hình/field mới: tuân thủ checklist 2.C và thiết kế test theo 2.D.
4. Cuối task, trả báo cáo theo mẫu 2.F + 2.H kèm block `result` dạng YAML.
5. Không ghi PASS nếu còn gate bắt buộc chưa chạy.
```

---

## 2. CHECKLIST SAU KHI CODE XONG

### A. Chạy máy (bắt buộc, dán kết quả thật; chưa chạy thì ghi "chưa kiểm chứng")

```text
Backend: npm run typecheck ; npm run lint ; npm test ; npm run test:integration
Mobile:  dart format lib test ; flutter analyze ; flutter test ; python3 tool/check_imports.py lib test
```

**Biến lệnh của repo (bổ sung):**

| Biến                       | Giá trị                                                                    |
| -------------------------- | -------------------------------------------------------------------------- |
| `BACKEND_DIR`              | `backend/`                                                                 |
| `MOBILE_DIR`               | `mobile/`                                                                  |
| `CMD_BACKEND_FORMAT_CHECK` | `npx prettier --check "{src,tests}/**/*.ts"` (chạy trong `BACKEND_DIR`)    |
| `CMD_BACKEND_TYPECHECK`    | `npm run typecheck` (chạy trong `BACKEND_DIR`)                             |
| `CMD_BACKEND_LINT`         | `npm run lint` (chạy trong `BACKEND_DIR`)                                  |
| `CMD_BACKEND_UNIT`         | `npm test` (chạy trong `BACKEND_DIR`)                                      |
| `CMD_BACKEND_INTEGRATION`  | `npm run test:integration` (chạy trong `BACKEND_DIR`, cần Docker/Postgres) |
| `CMD_MOBILE_FORMAT_CHECK`  | `dart format --set-exit-if-changed lib test` (chạy trong `MOBILE_DIR`)     |
| `CMD_MOBILE_ANALYZE`       | `flutter analyze` (chạy trong `MOBILE_DIR`)                                |
| `CMD_MOBILE_TEST`          | `flutter test` (chạy trong `MOBILE_DIR`; dùng path scope khi phù hợp)      |

Quy tắc chạy lệnh (bổ sung):

- Chạy lệnh **đúng thư mục** (`BACKEND_DIR` / `MOBILE_DIR`); ghi **lệnh chính xác** và kết quả (exit code, số test pass/fail).
- `dart format --set-exit-if-changed lib test` có thể báo file ngoài scope. Nếu fail do file **không thuộc task**: ghi `PARTIAL` + liệt kê file đó, **không** format file ngoài scope (G-02, G-06).
- Không nói "đã test" nếu Docker, device, API hoặc môi trường cần thiết chưa chạy. Ghi `BLOCKED`.

### B. Logic & kiến trúc

Backend:

- [ ] route → service → repository; service không có req/res; SQL chỉ ở repository
- [ ] Bảng mới có tenant_id + RLS tenant_isolation
- [ ] Không import repository module khác (dùng port / domain event)
- [ ] Điểm chỉ qua PointsPort.award, có idempotencyKey nếu retry được
- [ ] Staff/admin action có audit.record + lý do
- [ ] Lỗi dùng badRequest/forbidden/... , message tiếng Việt, code UPPER_SNAKE
- [ ] Số nghiệp vụ ở settings.catalog.ts; không new Date()/Date.now()
- [ ] requireAuth / requireRoles / validate(zod) đúng chỗ; module đã đăng ký container.ts
- [ ] Trạng thái cấm thao tác (VD lớp ngừng hoạt động) bị chặn Ở BACKEND, không chỉ ẩn nút

Mobile:

- [ ] Đúng domain/data/presentation; domain là Dart thuần; Riverpod, không codegen
- [ ] Không hex màu, không TextStyle thủ công; không dart:io ở code dùng chung
- [ ] Mỗi màn hình có đủ loading (AsyncBody) / empty (EmptyState) / error
- [ ] Path API trong mobile khớp đúng route backend (đã gọi thử thật, không "route not found")

### C. UI/UX

Form / field:

- [ ] Field bắt buộc đặt lên đầu form, label có dấu \* ; dùng Floating Label (không dùng placeholder thay label)
- [ ] Field KHÔNG in đậm: label/giá trị phân cấp bằng cỡ chữ, màu, floating label; chỉ tiêu đề trang/mục mới đậm
- [ ] Có maxLength cho MỌI field text; độ rộng field tương ứng maxLength (không để dư quá nhiều)
- [ ] Field số: chặn chữ (keyboard số + inputFormatter), số lớn có dấu phân cách hàng nghìn (1,000,000)
- [ ] Ngày/giờ: dùng date/time picker VÀ cho gõ trực tiếp có chặn ký tự chữ; không bắt cuộn danh sách dài
- [ ] Giá trị "không giới hạn": dùng công tắc/checkbox "Không giới hạn" rõ ràng, không dùng "để trống = không giới hạn"
- [ ] Trường mã tự sinh: hiển thị readonly, không cho nhập
- [ ] Tọa độ: chọn bằng bản đồ, không bắt gõ kinh/vĩ độ
- [ ] Dialog/form mở ra thì tự focus field đầu; Tab/Enter sang field kế, Shift+Tab lùi (bản web)
- [ ] Locale mặc định vi (picker, menu copy/paste, thông báo hệ thống bằng tiếng Việt)
- [ ] Combobox/Select hiển thị "Mã – Tên" và tìm được theo cả mã lẫn tên
- [ ] Tên field & vị trí trong form giống tên/vị trí cột trong bảng

Validate:

- [ ] Chỉ validate khi blur hoặc submit (không báo lỗi khi đang gõ lần đầu); đang sửa field đã lỗi thì validate ngay
- [ ] Lỗi hiện inline dưới từng field + tự focus field lỗi đầu tiên
- [ ] Lỗi validate KHÔNG xóa dữ liệu người dùng đã nhập; quay lại trang vẫn giữ dữ liệu
- [ ] Mọi input đã trim() trước khi validate và trước khi gửi/lưu

Nút:

- [ ] Phân cấp: Primary (nổi bật nhất: Lưu, Gửi) / Secondary (outline: Hủy, Quay lại) / Tertiary (text button)
- [ ] Icon phù hợp ý nghĩa, không dùng dấu "+" trơn; icon lạ/ít gặp phải kèm nhãn chữ; cùng một phong cách icon (line hoặc solid)
- [ ] Nút Xóa/Hủy/Đóng băng (khó hoàn tác) dùng màu đỏ + có hộp thoại xác nhận
- [ ] Chức năng không dùng được trong ngữ cảnh → disable hoặc ẩn; có lý do hiển thị nếu cần
- [ ] Nút submit disable ngay khi bấm + hiện trạng thái "Đang xử lý…" (chống double request)
- [ ] Nút hành động đặt gần dữ liệu; hành động hay dùng ở vị trí thuận tiện; không gian hẹp: 1–2 nút + menu "…"
- [ ] Vùng chạm ≥ 48dp, khoảng cách các vùng chạm hợp lý; nút chính nằm vùng ngón cái với màn mobile
- [ ] Web: cursor pointer + hiệu ứng hover cho phần tử bấm được

Thông báo:

- [ ] Màu/icon theo mức: Lỗi = đỏ, Cảnh báo/Xác nhận = vàng hoặc xanh dương, Thành công = xanh lá; chữ và nền đủ tương phản
- [ ] Lỗi validate = inline; kết quả hành động (thành công, không tìm thấy) = toast/popup
- [ ] Loading: 0.5–3s hiện spinner; >3s hiện progress bar (có % hoặc bước)

Bảng / danh sách:

- [ ] Chữ căn trái, chữ ngắn căn giữa, số căn phải; tiêu đề cột in đậm + căn giữa
- [ ] Độ rộng cột vừa với max-length dữ liệu, không cắt chữ, không thừa; kiểm tra nhiều cỡ màn hình
- [ ] Tên dài tối đa 2 dòng rồi "…" + tooltip hiện đủ
- [ ] Cột liên quan đặt gần nhau (Họ tên → Hồ sơ → Hành động → Trạng thái → …)
- [ ] Trạng thái ít loại: dùng màu nền/chip phân biệt
- [ ] Tìm kiếm/lọc mới → quay về trang 1
- [ ] Sắp xếp tiếng Việt đúng (collation vi), nhất quán giữa SQL và code
- [ ] Bộ lọc/đối tượng đã chọn được giữ khi chuyển giữa các màn hình liên quan
- [ ] Danh sách rỗng: có EmptyState + nút gợi ý hành động ("Tạo mới", "Quay lại")

Chung:

- [ ] Một bộ font; bo góc thống nhất; tiêu đề trang to nhất; căn lề thẳng hàng
- [ ] Light + Dark mode đều đẹp; nút bật Dark mode thấy được ở màn Login
- [ ] Thanh điều hướng (nav) có màu/trạng thái chọn rõ ràng theo theme, không chỉ trắng
- [ ] Menu/dropdown đóng được khi bấm ra ngoài
- [ ] Ảnh đúng kích thước quy định, không kéo giãn sai tỉ lệ
- [ ] Trang dài có nút "Back to top"

### D. Test theo Self-test (viết TRƯỚC khi báo xong)

Mỗi field text/số, tối thiểu các ca:

- [ ] Rỗng; chỉ toàn dấu cách (trim); ký tự đặc biệt; emoji
- [ ] Tiếng Việt có dấu (kể cả NFC/NFD), full-width/half-width
- [ ] Giá trị biên theo độ dài/giá trị: min-1, min, min+1, max-1, max, max+1
- [ ] Số: âm, thập phân, 0, rất lớn; paste từ clipboard

Ngày/giờ: biên ngày (hôm nay, hôm qua, mai), giờ mở > giờ đóng, qua nửa đêm, múi giờ APP_TIMEZONE.
Quyền: gọi API/URL khi không có quyền (401/403), user A mở link của user B, role khác truy cập màn hình khác.
Trạng thái: vẽ bảng chuyển trạng thái (VD lớp active→inactive, gói active→đóng băng→hết hạn); test ca hợp lệ VÀ ca bị cấm.
Bảng quyết định: với logic nhiều điều kiện (gia hạn, hủy buổi, đóng băng) liệt kê tổ hợp đầu vào → kết quả.
Ad-hoc: bấm submit nhiều lần liên tiếp; 2 người thao tác cùng lúc (còn 1 chỗ trống); đăng nhập 2 thiết bị; mạng chậm/mất mạng giữa chừng; mở nhiều tab; upload khi đang đổi tên/xóa file; file tên có dấu/ký tự đặc biệt.
Mỗi chức năng có đủ positive + negative; mỗi endpoint mobile gọi có integration test.

### E. Vệ sinh & phạm vi

- [ ] Diff chỉ gồm những gì plan đã duyệt
- [ ] Không còn log debug, TODO treo, code chết, file bí mật
- [ ] Docs liên quan (tiếng Việt) đã cập nhật
- [ ] File test/upload chỉ dùng dummy file; lỡ up nhầm dữ liệu thật thì xóa ngay và báo người quản lý
- [ ] (bổ sung) `git diff --check` sạch; `git status --short` chỉ có file trong `planned_files` + `baseline_dirty_files`; file lạ → báo cáo, không tự xử lý
- [ ] (bổ sung) Không tự stage/commit khi chưa được yêu cầu

### F. Mẫu báo cáo cuối task

```text
✅ Đã làm: ...
📁 File: tạo X / sửa Y
🧪 Kiểm chứng: <lệnh> → <kết quả thật>
🖥️ UI đã soi theo checklist C: <các mục áp dụng / N/A>
⚠️ Chưa làm / chưa kiểm chứng: ...
❓ Cần người dùng quyết: ...
```

(Bổ sung) Báo cáo kèm trạng thái từng gate và Overall: xem mẫu ở 2.H.

### G. Chọn loại test theo rủi ro (bổ sung)

| Loại thay đổi                                | Kiểm tra tối thiểu                                                  |
| -------------------------------------------- | ------------------------------------------------------------------- |
| UI / route / RBAC client                     | Widget/app-flow test cho **role** và navigation thực tế             |
| Repository / API mapping                     | Test `ScriptedAdapter`: path, query, method, body, response mapping |
| Business rule / state change                 | Backend unit test                                                   |
| Transaction / RLS / permission / DB workflow | Backend **integration** test (DB thật)                              |
| Shared UI primitive                          | Regression test cho **mọi** role/feature đang dùng primitive đó     |

Khi nào **bắt buộc** integration test:

- Khi thay endpoint, role guard, SQL/repository, migration, RLS, transaction, scheduler/job hoặc cross-module event.
- Widget/repository mock test chỉ chứng minh client gọi đúng contract; **không** chứng minh backend cho phép role đó.
- Docker/Postgres không chạy → gate là `BLOCKED` (ví dụ `docker daemon unavailable`); không ghi overall PASS.
- Integration test fail do fixture: chỉ được đổi fixture sau khi chứng minh fixture trái contract; ghi nguyên nhân và **rerun toàn bộ scope**.

### H. Quality gate và trạng thái bàn giao (bổ sung)

**Quy tắc:**

| ID   | Quy tắc                                                                                                                 |
| ---- | ----------------------------------------------------------------------------------------------------------------------- |
| Q-G1 | MUST NOT gọi task là **PASS / hoàn thành / sẵn sàng merge** nếu còn gate bắt buộc chưa chạy hoặc đang fail.             |
| Q-G2 | MUST NOT sửa assertion để "xanh" khi chưa chứng minh assertion đó sai nghiệp vụ.                                        |
| Q-G3 | MUST NOT dùng unit/widget test thay cho integration test khi thay đổi có DB, RLS, transaction, route RBAC hoặc job.     |
| Q-G4 | MUST NOT coi HTTP 200 là pass nếu quyền role, state transition, idempotency, audit hoặc side effect chưa được kiểm tra. |
| Q-G5 | Mỗi lỗi tái phạm MUST được thêm test hoặc lint chặn lại (mục 5), không chỉ ghi chú vào tài liệu.                        |

**Gate** (đánh dấu từng mục: `PASS` | `N/A` + lý do | `BLOCKED` + blocker + lệnh chưa chạy | `FAIL`):

| Gate                  | Bắt buộc khi                                                                 | Điều kiện PASS                                                                              |
| --------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `scope_diff`          | Mọi task                                                                     | `git diff --check` sạch; mọi file sửa/stage thuộc đúng scope/branch và Plan đã duyệt        |
| `format`              | Mọi source đã sửa                                                            | Backend: `CMD_BACKEND_FORMAT_CHECK`; Mobile: `CMD_MOBILE_FORMAT_CHECK`                      |
| `static`              | Chạm backend/mobile tương ứng                                                | Backend `CMD_BACKEND_TYPECHECK` (+ `CMD_BACKEND_LINT`); Mobile `CMD_MOBILE_ANALYZE`         |
| `unit`                | Có rule/service/repository/helper mới hoặc sửa                               | Test đúng rule mới; edge/error/idempotency liên quan pass                                   |
| `widget_flow`         | Chạm UI, role shell, route hoặc shared widget                                | Render/loading/empty/error + action/navigation thật của actor bị ảnh hưởng pass             |
| `api_repo`            | Chạm client API mapping                                                      | Path, method, query/body, role endpoint, success/error mapping pass; path khớp route BE     |
| `backend_integration` | Chạm route/service/repository/schema/job/RBAC                                | DB thật pass: success, 401/403, tenant/RLS, transaction và rollback/idempotency nếu áp dụng |
| `manual_device`       | Camera, file upload, push, browser permission, responsive, external provider | Case thực tế trên môi trường phù hợp được ghi nhận; không thay bằng mock                    |
| `regression`          | Sửa primitive/shared workflow                                                | Mọi feature/role **bị ảnh hưởng trực tiếp** bởi primitive đó có regression pass             |
| `ui_ux`               | Chạm màn hình, form, bảng, nút, nav, theme                                   | Đã soi checklist 2.C; ghi rõ mục áp dụng / `N/A` + lý do; light + dark đã xem               |
| `test_design`         | Có field hoặc chức năng mới                                                  | Có ca theo 2.D (biên, negative, sai quyền, bảng trạng thái/quyết định nếu áp dụng)          |

**Rút gọn cho thay đổi rủi ro thấp** — chỉ khi **toàn bộ** diff thuộc một loại sau, và phải ghi rõ loại được áp dụng:

| Loại                                        | Gate tối thiểu                   | Ghi `N/A` cho                                 |
| ------------------------------------------- | -------------------------------- | --------------------------------------------- |
| Chỉ sửa tài liệu `.md` (không đổi contract) | `scope_diff`                     | các gate còn lại                              |
| Typo/comment/string không ảnh hưởng hành vi | `scope_diff`, `format`, `static` | unit, widget, integration, ui_ux, test_design |

Thay đổi nào chạm logic, route, RBAC, schema, shared primitive **không** được dùng bảng rút gọn. Loại rút gọn được bỏ qua cổng duyệt Plan (S-06) nhưng vẫn phải nêu 1 dòng việc sẽ làm.

**Task chạm cả backend và mobile:** đánh giá gate **riêng từng phần**, rồi tổng hợp. Overall = trạng thái **xấu nhất** theo thứ tự `FAIL` > `BLOCKED` > `PARTIAL` > `PASS`. Phần mobile PASS không che được phần backend BLOCKED.

**Trạng thái bàn giao hợp lệ:**

| Trạng thái  | Nghĩa                                                                                                                   |
| ----------- | ----------------------------------------------------------------------------------------------------------------------- |
| **PASS**    | Tất cả gate bắt buộc theo scope pass; không còn blocker hoặc fail chưa triage                                           |
| **PARTIAL** | Code/static/unit pass nhưng có gate bắt buộc chưa áp dụng xong hoặc workflow chưa chốt; không được merge như hoàn thành |
| **BLOCKED** | Không thể chạy gate bắt buộc do môi trường/quyền/dependency; ghi chính xác blocker, impact, lệnh cần rerun              |
| **FAIL**    | Có test, static check, contract hoặc business rule fail; không được che bằng báo cáo pass phần khác                     |

**Báo cáo theo gate** (dùng cùng mẫu 2.F):

```md
## Verification

- Scope diff: PASS — `git diff --check`
- Format: PASS — `<exact command>`
- Mobile analyze: PASS — `flutter analyze`
- Mobile tests: PASS — `<exact command>` (N passed)
- Backend typecheck: PASS — `npm run typecheck`
- UI/UX: PASS — đã soi 2.C (áp dụng: ...; N/A: ...)
- Test design: PASS — các ca biên/negative/sai quyền theo 2.D
- Backend integration: BLOCKED — docker daemon unavailable;
  cần rerun `<exact command>` trước khi task được gọi là PASS.

## Overall: PARTIAL

## Bàn giao

- Outcome: ...
- File thay đổi: ...
- Quyết định workflow/RBAC: ...
- Giới hạn còn lại: ...
- Cần người dùng quyết: ...
- Rule đã áp dụng: 7, 15, 25, 32, ... / G-01, S-06, ...
```

Dạng máy đọc được (nên đính kèm cuối báo cáo):

```yaml
result:
  overall: PASS|PARTIAL|BLOCKED|FAIL
  gates:
    scope_diff: { status: PASS, cmd: "git diff --check" }
    format: { status: PASS, cmd: "..." }
    static: { status: PASS, cmd: "..." }
    unit: { status: PASS, cmd: "..." }
    widget_flow: { status: N/A, reason: "không chạm UI" }
    api_repo: { status: N/A, reason: "..." }
    backend_integration: { status: BLOCKED, blocker: "docker daemon unavailable", rerun: "<cmd>" }
    manual_device: { status: N/A, reason: "..." }
    regression: { status: N/A, reason: "..." }
    ui_ux: { status: N/A, reason: "..." }
    test_design: { status: PASS, cases: "..." }
  files_changed: ["..."]
  open_questions: ["..."]
```

### I. Tài liệu và bàn giao (bổ sung)

| ID   | Quy tắc                                                                                                                                 |
| ---- | --------------------------------------------------------------------------------------------------------------------------------------- |
| D-01 | MUST cập nhật file `.md` **chính** của domain khi contract/workflow thay đổi; không chỉ thêm test report.                               |
| D-02 | MUST NOT tạo tài liệu, implementation hoặc test thuộc feature khác với scope branch (G-01).                                             |
| D-03 | Spec riêng của từng domain (ví dụ Notification) MUST nằm trong file domain dưới `docs/`; workflow chung chỉ giữ link và rule quy trình. |
| D-04 | Code, comment, định danh bằng tiếng Anh; chuỗi hiển thị cho người dùng và tài liệu bằng tiếng Việt.                                     |

Nội dung bàn giao (bắt buộc): outcome, danh sách file thay đổi, quyết định workflow/RBAC, test đã chạy (lệnh + kết quả), giới hạn còn lại, phần UI/UX đã soi.

Xử lý mâu thuẫn tài liệu ↔ code:

1. Nêu mâu thuẫn cụ thể: `<file:line tài liệu>` vs `<file:line code>`.
2. **Không tự chọn bên đúng** nếu thay đổi ảnh hưởng hành vi nghiệp vụ → hỏi (Q-06).
3. Trong lúc chờ trả lời, mặc định **không sửa** phần liên quan; tiếp tục phần không bị ảnh hưởng nếu độc lập, và đánh dấu `PARTIAL`.
4. Thứ tự nguồn nghiệp vụ ở 1.6 chỉ để **đề xuất**, không thay thế xác nhận của người dùng.

Domain workflow cần đọc thêm: Notification → `docs/NOTIFICATION_WORKFLOW.md` (khi chạm bell, inbox, unread/read, push, template, broadcast hoặc notification event). Không copy domain workflow vào file này; khi chưa có file chuẩn cho domain đang đổi, kích hoạt Q-06 và hỏi người dùng.

---

## 3. RULE KHÔNG ĐƯỢC VI PHẠM

### A. Quy trình

1. Không sửa file khi chưa có "OK" cho plan (trừ task rất nhỏ).
2. Không báo "xong" khi chưa chạy lệnh kiểm chứng; không nói test pass nếu chưa chạy.
3. Không mở rộng phạm vi ngoài plan; thấy việc khác thì ghi lại và hỏi.
4. Không commit/push khi chưa được yêu cầu; không commit file bí mật.
5. Không sửa migration đã merge.
6. Không tự đoán nghiệp vụ mơ hồ: ghi vào mục "Cần người dùng quyết" trong plan/báo cáo và hỏi trước khi code.

### B. Backend

7. Không new Date()/Date.now(); dùng clock.now().
8. Không import repository module khác.
9. Không ghi point_transactions ngoài PointsService; không sửa/xóa dòng POSTED.
10. Không hardcode số nghiệp vụ; dùng settings.getNumber.
11. Không tạo bảng thiếu tenant_id + RLS.
12. Không UPDATE/DELETE bảng append-only (audit_logs, auth_logs, member_rank_history, streak_logs, batch_runs, inventory_movements).
13. Lỗi người dùng phải có message tiếng Việt + code ổn định; không throw Error thô.
14. SQL chỉ ở \*.repository.ts / db/sql.ts.
15. Mọi điều kiện cấm thao tác (lớp ngừng hoạt động, gói hết hạn…) phải được chặn ở backend, UI chỉ là lớp phụ.
16. Mọi input từ client phải qua zod: có min/max length, kiểu, định dạng; trim trước khi dùng.
17. Không truyền dữ liệu dài/nhạy cảm qua query string GET; dùng POST.
18. Upload file: validate đuôi file sau khi toLowerCase (.MP4 = .mp4), mã hóa/làm sạch tên file khi tạo URL, xử lý ở backend (không để token/khóa lưu trữ lộ ra client).
19. Link/URL tài nguyên phải kiểm quyền truy cập; không có quyền → 403 + popup hoặc chuyển về trang chủ.
20. Gửi email/thông báo/file có tiếng Việt: dùng UTF-8, test chữ có dấu.

### C. Mobile

21. Không hex màu, không TextStyle thủ công trong widget feature.
22. Không dart:io ở code dùng chung.
23. Không logic nghiệp vụ trong widget; Riverpod, không codegen; không golden test.
24. Không màn hình nào thiếu loading/empty/error.
25. Không đưa path API tự đặt; phải khớp route backend và có test.
26. Dọn tài nguyên: dispose controller/stream/listener, không để media nặng autoplay.

### D. UI/UX

27. Không dùng placeholder thay label; field bắt buộc phải có \*.
28. Không validate khi đang gõ lần đầu; phải validate khi blur/submit, hiện lỗi inline và focus field lỗi đầu tiên.
29. Không xóa dữ liệu người dùng khi có lỗi validate hoặc chuyển trang rồi quay lại.
30. Mọi field text phải có maxLength; mọi field ngày/giờ phải có picker; field số phải chặn chữ.
31. Không in đậm field/giá trị thông thường; in đậm chỉ cho tiêu đề.
32. Nút nguy hiểm (xóa, hủy, đóng băng) phải màu đỏ + xác nhận; nút chính phải nổi bật nhất; không dùng "+" trơn làm icon.
33. Không để nút submit bấm được nhiều lần; phải disable khi đang xử lý.
34. Không icon lạ thiếu nhãn chữ; không trộn nhiều phong cách icon.
35. Không để danh sách rỗng không hướng dẫn; phải có CTA.
36. Không "để trống = không giới hạn" mơ hồ; dùng công tắc rõ ràng.
37. Không cắt chữ trong bảng; không cột quá rộng/hẹp so với max-length.
38. Không cố định chỉ màu trắng cho thành phần giao diện; mọi màu qua theme light/dark.
39. Vùng chạm tối thiểu 48dp.

### E. Test & chất lượng

40. Mỗi field mới phải có test biên (min-1…max+1) + ký tự đặc biệt + tiếng Việt có dấu.
41. Mỗi chức năng phải có negative test và ca sai quyền (401/403).
42. Mọi lỗi tái phạm phải được thêm test hoặc lint chặn lại (xem mục 5), không chỉ ghi chú.

### F. Bổ sung từ workflow dự án (rule 43–54)

Backend / nghiệp vụ:

43. Mọi endpoint phải áp RBAC bằng `requireRoles`; client không được gọi endpoint của actor khác; có test 403 cho role khác.
44. Không thay đổi state machine, read semantics, reward, inventory, ledger, audit hoặc idempotency chỉ để UI "có nút bấm"; nếu buộc phải đổi → dừng và hỏi (Q-03, mục 1.5).
45. Không tự tạo endpoint/migration để lấp chỗ thiếu khi semantics nghiệp vụ chưa chốt → dừng và hỏi (Q-04, mục 1.5).
46. Mọi mutation staff/admin phải có audit (kèm lý do); có test xác nhận bản ghi audit.
47. Mọi retryable operation phải có idempotency; test gọi lặp cùng key → kết quả không đổi, không side effect lặp.
48. Side effect push (notification, webhook…) chạy **sau commit** (`db.afterCommit`) khi không bắt buộc nằm trong transaction.
49. Migration mới phải forward-only, có `tenant_id` và RLS policy phù hợp; `git diff --name-status` không được có `M` trên migration cũ.

Mobile:

50. Tái sử dụng shared widget, status mapping, pagination, loading/empty/error primitive đã có; không tạo bản trùng lặp theo role.
51. Widget không chứa business rule/RBAC; repository/provider gọi endpoint đúng actor; backend là source of truth.
52. Route declaration **không** là bằng chứng màn hình dùng được: phải kiểm tra navigation shell, tap target, responsive layout và runtime API authorization.

Quy trình / Git / báo cáo:

53. Tuân thủ scope và Git theo bảng G-01..G-08 bên dưới: không sửa, stage, format, revert hoặc xóa thay đổi **không do mình tạo** (kể cả file đã dirty trước khi bắt đầu).
54. Không gọi task là PASS / hoàn thành / sẵn sàng merge khi còn gate bắt buộc chưa chạy hoặc đang fail (xem 2.H).

| ID   | Quy tắc                                                                                                                                                                  |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| G-01 | MUST NOT đưa feature/task khác vào branch hiện tại (ví dụ task Challenge không được thêm UI, route, test hoặc tài liệu Streak).                                          |
| G-02 | MUST NOT sửa, stage, unstage, format, revert hoặc xóa thay đổi **không do mình tạo** (kể cả file trong baseline) khi chưa có chỉ dẫn rõ ràng.                            |
| G-03 | MUST NOT tự commit, push, tạo PR, đổi branch hoặc chuyển worktree nếu người dùng chưa yêu cầu **trong task hiện tại**.                                                   |
| G-04 | MUST NOT dùng `git reset --hard`, `git checkout -- <path>`, `git clean -fd`, `git restore` trên file không phải của mình, xóa hàng loạt, hoặc thao tác phá hủy tương tự. |
| G-05 | MUST NOT stage tự động. Trước khi stage phải báo chính xác danh sách file thuộc task và chờ xác nhận (trừ khi người dùng đã ra lệnh stage cụ thể file đó).               |
| G-06 | MUST NOT format toàn repo/thư mục khi chỉ sửa vài file nếu việc đó chạm file ngoài scope. Chỉ format file mình sửa.                                                      |
| G-07 | MUST NOT mở rộng phạm vi ngoài Plan đã duyệt (S-06). Thấy việc khác → ghi lại và hỏi.                                                                                    |
| G-08 | MUST NOT để lại log debug, TODO treo, code chết hoặc file bí mật trong diff.                                                                                             |

Quy trình branch:

- Một branch chỉ chứa **một scope** có thể review/merge độc lập.
- Khi người dùng yêu cầu chuyển feature sang branch khác: chỉ chuẩn bị danh sách file/commit để cherry-pick; **hỏi branch đích** nếu chưa được nêu.
- Chỉ dùng patch chọn lọc (`git apply -R` trên đúng hunk mình thêm, hoặc sửa tay đúng phần mình thêm) để bỏ phần mình vừa thêm. Không revert toàn file nếu file có thay đổi của người khác.

Khi nào được commit/push (làm rõ G-03) — chỉ khi người dùng ghi rõ trong task hiện tại (ví dụ "commit giúp tôi", "tạo PR"). Khi được phép:

1. Chỉ commit file thuộc scope đã được xác nhận (G-05).
2. Chạy toàn bộ gate bắt buộc **trước** khi commit; ghi trạng thái gate trong commit message hoặc mô tả PR nếu gate chưa PASS.
3. Không push `--force` nếu không được yêu cầu rõ.
4. Không commit file có thể chứa bí mật (`.env`, key, token).

---

## 4. BUG ĐÃ GẶP → RULE CHỐNG TÁI PHẠM (soi lại trước khi báo xong)

**UI chung**

- Nút phải nổi bật, icon đúng nghĩa thay vì "+" → rule 32, 34
- Dark mode phải hiện nổi ở Login → checklist C "Chung"
- Field đang in đậm, xử lý khác → rule 31 (floating label, hierarchy bằng màu/cỡ)
- Locale textbox mặc định tiếng Anh → locale vi trong MaterialApp + delegates
- Thanh navigation cấu hình chỉ có màu trắng → rule 38; thiết kế lại theo theme + trạng thái chọn

**Chi nhánh – Admin**

- Icon "Thêm chi nhánh" làm lại → rule 32, 34
- Mã chi nhánh phải tự tạo → field readonly, backend sinh
- Kinh độ/vĩ độ dùng bản đồ → chọn từ map picker
- Chưa có maxLength → rule 30
- Giờ mở cửa: chặn chữ + date/time picker → rule 30
- Mã QR chi nhánh để làm gì? → hỏi lại người dùng trước khi code; nếu giữ thì UI phải có giải thích

**Lớp học – Admin**

- Chưa validate maxLength → rule 30
- Giờ phải dùng picker → rule 30
- "Trống = không giới hạn" cần thiết kế lại → rule 36
- Tạo "buổi kiểm tra": tên buổi hiện "route not found", không tạo được → rule 25 (đối chiếu path FE/BE, thêm integration test)
- Lớp ngừng hoạt động thì không cho tạo buổi kiểm tra → rule 15 (chặn ở BE, disable ở UI)
- Chức năng hủy buổi chưa được test → mục 2.D (state transition + negative)

**Lớp học – Coach**

- Chưa xem được lớp học và bài học → kiểm quyền/endpoint/route role coach

**Lớp học – Lễ tân, Hệ thống**

- Chưa có → hỏi lại người dùng về logic nghiệp vụ trước khi code (rule 6)

**Gói tập – Học viên**

- Chọn tháng bị che, không xem được → picker/overlay phải nằm trong vùng hiển thị (bottom sheet / dialog), test nhiều cỡ màn hình
- Gia hạn: gia hạn gói hiện tại hay gói mới? Gói mới có được không? → hỏi lại người dùng trước khi code (rule 6)

**Gói tập – Lễ tân**

- Cần màn hình thông báo; đẩy "Hồ sơ" xuống navigation → thiết kế lại nav lễ tân
- Lễ tân phải biết đang có những lớp nào → hiển thị danh sách lớp (đúng quyền)
- Đóng băng: UI đóng băng cho NGUYÊN học viên + thêm icon → rule 32; theo bảng trạng thái (2.D)

**Hồ sơ**

- Upload ảnh: chưa lưu mà đã hiện như đã lưu → trạng thái rõ: chọn ảnh → xem trước (chưa lưu) → bấm Lưu → đang tải → đã lưu; hủy thì khôi phục ảnh cũ; up file test chỉ dùng dummy

---

## 5. ÉP RULE BẰNG MÁY

- ESLint no-restricted-syntax: cấm new Date()/Date.now() trong business code
- ESLint no-restricted-imports: cấm import repository module khác; cấm import pg ngoài db/ và \*.repository.ts
- Integration test quét information_schema: bảng nào thiếu tenant_id/RLS thì fail
- Test: bảng append-only từ chối UPDATE/DELETE
- Script mobile (cạnh check_imports.py): cấm Color(0x...) và dart:io trong lib/features và code dùng chung
- Test hợp đồng route: mọi path trong \*\_api.dart phải tồn tại ở backend (chống "route not found")
- Test widget dùng chung: field có maxLength, nút submit disable khi đang gửi, đủ 3 trạng thái màn hình
- Quy tắc vận hành: mỗi lần mắc một lỗi, thêm một lint/test chặn lỗi đó thay vì chỉ thêm chữ vào CLAUDE.md

**Lệnh tự kiểm tra tạm thời khi chưa có lint tương ứng (bổ sung)** — kết quả phải rỗng:

```bash
# Rule 8: import repository của module khác
grep -rn "from '.*/modules/<other>/.*repository" <module-dir>

# Rule 7: new Date()/Date.now() trong business logic (trừ test/clock implementation)
git diff -U0 | grep -nE "new Date\(|Date\.now\("

# Rule 21: màu/style hard-code trong feature widget (Colors.transparent là hợp lệ)
git diff -U0 -- '<MOBILE_DIR>/lib/features' | grep -nE "Color\(0x|Colors\.[a-zA-Z]+|TextStyle\(" | grep -v "Colors.transparent"

# Rule 22: dart:io trong code dùng chung
git diff -U0 -- '<MOBILE_DIR>/lib' | grep -n "dart:io"
```
