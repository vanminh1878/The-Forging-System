# Kiến trúc tổng quan

## 1. Nguyên tắc

- **Dự án quyết định công nghệ, không phải kỹ năng cá nhân**: Flutter + Riverpod cho mobile; Node.js/TypeScript/Express/PostgreSQL cho API.
- **Monorepo**: `backend/`, `mobile/`, `docker/`, `docs/` (docs không commit).
- **SOLID + hướng module**: mỗi nghiệp vụ là một module độc lập, giao tiếp qua *port* (interface) và *domain event*, không import repository của nhau.
- Code, comment, tên biến: tiếng Anh. Văn bản hiển thị cho người dùng và tài liệu: tiếng Việt.

## 2. Backend

```
HTTP request
  -> middleware (helmet, cors, resolveTenant, requireAuth, requireRoles, validate)
  -> routes   : validate input (zod), gọi service, trả { data, meta }
  -> service  : luật nghiệp vụ, điều phối repository/port; KHÔNG biết req/res
  -> repository : SQL thuần (qua sql.* helpers), KHÔNG chứa luật nghiệp vụ
  -> PostgreSQL (RLS theo app.current_tenant_id)
```

### Giao dịch & đa tenant
- `handle()` mở **một transaction cho mỗi request** (`db.tenantTx`) và đặt `app.current_tenant_id`; commit xong mới trả response.
- API kết nối bằng role **`hvp_app`** (không phải owner, không BYPASSRLS) nên RLS luôn có hiệu lực. Migration chạy bằng `hvp_owner`.
- `db.afterCommit(fn)` cho side-effect không cần nhất quán (push notification).

### Giao tiếp giữa module
| Cơ chế | Dùng khi | Ví dụ |
|---|---|---|
| **Port** (`src/shared/ports.ts`, `*Port` trong module) | Module A cần *hỏi/ra lệnh* module B | `PointsPort.award`, `NotifierPort`, `MembershipPort` |
| **Domain event** (`src/common/events`, payload ở `src/shared/events.ts`) | Module A *thông báo* việc đã xảy ra, B/C phản ứng | `ATTENDANCE_CONFIRMED`, `POINTS_AWARDED`, `RANK_CHANGED` |

Event được `await` tuần tự **trong cùng transaction** với hành động gốc: hành động và mọi phản ứng cùng commit hoặc cùng rollback.

### Composition root
`src/container.ts` là nơi DUY NHẤT tạo object và nối dependency (DI thủ công). Thêm module = thêm một khối tại các anchor `// [imports|services|modules|routers:feature-modules]`.

### Sổ cái điểm (trái tim hệ thống)
- Chỉ `PointsService` (qua `PointsPort.award`) được ghi `point_transactions`. 1 dòng mang cả `dp_amount` và `marks_amount`.
- Bất biến: dòng POSTED không sửa/xóa; sửa sai bằng giao dịch đảo (`REVERSAL`) hoặc `MANUAL_ADJUSTMENT` có lý do + audit.
- Trigger DB giữ `members.dp_balance/marks_balance` đồng bộ và chặn số dư âm.
- Idempotency: `idempotencyKey` (đã prefix tenant) chặn cộng trùng khi thao tác bị retry.
- Monthly cap (DP 1.200 / Marks 150, cấu hình được) chỉ áp cho nguồn SESSION, ATTITUDE, ACADEMY, CHALLENGE, COMEBACK; Rank Trial, Early Renewal, điều chỉnh tay và Armory không bị cap.

### Hạng (rank)
`rank.engine.ts` là hàm thuần: DP + time-gate + course-gate + trial-gate. Mọi thay đổi DP phát `POINTS_AWARDED` → `RankService.reevaluate` (lên/xuống/khôi phục hạng, cấp/gỡ huy hiệu). Xuống hạng tự động; khôi phục hạng ≤ đỉnh cũ không cần thi lại.

### Thời gian
Không dùng `new Date()` trong nghiệp vụ: dùng `clock.now()` và `common/utils/time.ts` (múi giờ `APP_TIMEZONE`, tuần Thứ 2–CN). Nhờ đó test và batch job "du hành thời gian" được.

### Cấu hình
Mọi con số nghiệp vụ (cap, ngưỡng, hạn…) nằm ở `settings.catalog.ts`, admin ghi đè vào `system_configs`. Không hardcode.

## 3. Mobile

Feature-first + Clean layering (`domain` / `data` / `presentation`), Riverpod, go_router với 4 shell theo role (`student|coach|reception|admin`). Xem `docs/MOBILE_GUIDE.md`.

## 4. Đa chi nhánh (đã chốt với khách hàng)
1 tài khoản dùng chung mọi chi nhánh; học viên tập/check-in ở mọi chi nhánh; Coach chi nhánh A xác nhận được học viên chi nhánh B; kho quà là kho chung, học viên chọn chi nhánh nhận.
