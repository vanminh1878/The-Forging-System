# Bản đồ tính năng còn phải code

Nguồn: Danh sách Use Case v1.1 (28/09/2026), schema DB v3.0, prototype đã duyệt. **Schema đã đủ bảng cho mọi tính năng dưới đây** (migration 0001); chỉ thêm migration mới cho index/bảng phụ.
Trạng thái: ✅ đã có · ⬜ cần code. Gợi ý module = tên thư mục `backend/src/modules/<module>`.

## Đã có trong base
| UC | Nội dung | Ở đâu |
|---|---|---|
| HV-01..04, COACH-01, ADM-01 | Đăng ký, đăng nhập/xuất, quên mật khẩu, hồ sơ, đăng nhập staff | `auth`, `members` |
| HV-15..18, COACH-07 (một phần), ADM-09 | Fighter Record: hạng, điều kiện thiếu, sổ điểm, Rank Trial + duyệt | `ranks`, `points` |
| HV-06, HV-25 (hạ tầng) | Trung tâm thông báo, push provider, template, broadcast | `notifications` |
| ADM-02..04 (hạ tầng), ADM-07 | Bộ tham số cấu hình, mẫu thông báo | `settings`, `notifications` |
| ADM-08, ADM-11 | Điều chỉnh điểm tay (đảo giao dịch), Audit Log | `points`, `audit` |
| SYS-01, SYS-02, SYS-05 | Cộng điểm idempotent, tự mở/hạ/khôi phục hạng, monthly cap | `points`, `ranks` |
| LT-02 (một phần) | Tạo học viên có tra trùng, đổi trạng thái, gộp tài khoản trùng | `members` |

## Cần code (theo nhóm, gợi ý thứ tự phụ thuộc)

### A. Cấu trúc đào tạo
| UC | Module gợi ý | Bảng chính | Ghi chú |
|---|---|---|---|
| ADM-13 | `branches` | branches | CRUD chi nhánh, giờ mở cửa, `qr_version`; học viên đọc danh sách |
| ADM-10 | `staff` | users, user_roles | Tạo staff (mật khẩu tạm), gán vai trò + chi nhánh, vô hiệu hoá. Không phân quyền theo chức năng (khách hàng đã chốt) |
| HV-11, ADM(đào tạo) | `catalog` | courses, lesson_plans | 5 khóa, khóa 5 tăng dần; soft-delete bài học |
| HV-08, COACH-02 | `classes` | classes, class_enrollments, sessions | Tạo lớp, sinh buổi theo lịch (idempotent), buổi lẻ / Academy / kiểm tra (`is_exam`), lịch của học viên mọi chi nhánh |

### B. Gói tập
| UC | Module | Bảng | Ghi chú |
|---|---|---|---|
| HV-07, HV-09, HV-10, LT-02 | `memberships` | package_types, memberships, renewal_requests | Kích hoạt/gia hạn (xếp hàng SCHEDULED), ảnh minh chứng thu phí, +50 Marks gia hạn sớm (1 lần/gói), huỷ gói. Cài `MembershipPort` (`shared/ports.ts`) |
| SYS-06, SYS-07 | job trong `memberships` | members, memberships | Hết hạn → FROZEN, 12 tháng không hoạt động → INACTIVE (ưu tiên Inactive > Frozen) |
| (khóa học) | `course-progress` | course_enrollments | Lắng nghe `ATTENDANCE_CONFIRMED`, hoàn thành khóa → mở course-gate của hạng (gọi `ranks.reevaluate`) |

### C. Check-in & điểm danh
| UC | Module | Bảng | Ghi chú |
|---|---|---|---|
| HV-12, LT-01 | `checkin` | checkin_codes, attendances | QR xoay vòng theo chi nhánh (TTL `checkin.code_ttl_seconds`); học viên quét → chọn buổi hôm nay → xác nhận → `AWAITING_COACH`; FROZEN không check-in được; mọi chi nhánh |
| COACH-03..06, 08 | `attendance` | attendances | Coach xác nhận (≥ ngưỡng 70%) → cộng DP/Marks qua `PointsPort.award` (key `attendance:<id>`), phát `ATTENDANCE_CONFIRMED`; điểm thái độ (1 lần/buổi, giới hạn ngày/tháng của coach); kết quả Academy; comeback bonus; lịch sử xác nhận |
| HV-13, HV-14 | `attendance` | attendances | Work Log, ghi chú coach |
| SYS-03, SYS-04, HV-05 | `streak` | streak_logs, streak_freeze_grants | Chốt tuần, Streak Freeze tự dùng, mốc tuần 4/8/12 |

### D. Thử thách & Armory
| UC | Module | Bảng | Ghi chú |
|---|---|---|---|
| HV-19..21, ADM-05 | `challenges` | challenges, challenge_participations | Chỉ admin tạo; **không có yếu tố thi đua**; coach xác nhận bằng chứng; giới hạn thưởng 2/tháng |
| HV-22..24, LT-03..05, ADM-06, SYS-09 | `armory` | reward_tiers, rewards, redemptions, inventory_movements | Giữ Marks (tổng PENDING_PICKUP), trừ kho ngay khi đổi, hoàn kho/hoàn giữ khi từ chối/hết hạn, giao quà có ảnh minh chứng, chọn chi nhánh nhận. Cần `award()` hỗ trợ dòng Marks âm cho nguồn `ARMORY_REDEEM` (xem `points.rules.ts`) |

### E. Tổng hợp & vận hành
| UC | Module | Ghi chú |
|---|---|---|
| ADM-12 | `dashboard` | 7 nhóm chỉ số (hoạt động; mục tiêu tuần & streak; thử thách & hạng; Marks & chi phí; gia hạn & quay lại; nguy cơ rời bỏ; kho quà), lọc chi nhánh + khoảng thời gian |
| HV-05 | `home` | `GET /me/home` gộp: hạng, DP, streak, buổi tiếp theo, nhiệm vụ gần nhất, Marks |
| SYS-xx | `jobs/scheduler.ts` | 8 batch job (expiry, reminder, inactive, streak, comeback, challenge, nudge, armory) → ghi `batch_runs` |

## Điểm nối đã chuẩn bị sẵn
- **Port**: `MembershipPort` (`shared/ports.ts`), `PointsPort`, `RankPort`, `NotifierPort`.
- **Event**: `ATTENDANCE_CONFIRMED`, `MEMBERSHIP_*`, `MEMBER_STATUS_CHANGED`, `REDEMPTION_CREATED`, `RANK_CHANGED`, `POINTS_AWARDED` (payload ở `shared/events.ts`).
- **Cấu hình**: các key tham số của mọi tính năng trên đã nằm trong `settings.catalog.ts` (cap, ngưỡng 70%, thái độ, streak, gia hạn sớm, check-in, hết hạn nhận quà…).
- **Dữ liệu tham chiếu**: 5 khóa × 36 bài, 10 gói tập, rank gate, 9 mẫu thông báo (`seeds/`).
- **Mobile**: mỗi tab còn trống đã có route + `ComingSoonPage` sẵn.

## Câu hỏi cần xác nhận với khách hàng / quyết định sản phẩm
1. **Course-gate theo hạng** (`seeds/curriculum.ts` → `RANK_COURSE_GATES`): hiện là *giả định* (III cần Foundation, IV The Standard, V The Person, VI The Fighter, VII The Fighter + The Example). Cần số liệu thật từ tài liệu DP V2/khách hàng.
2. **Tên hạng & ngưỡng**: seed theo DP V2 (THE_UNKNOWN … THE_LEGACY), không theo dữ liệu mock của prototype.
3. **OTP/SMS**: mới có provider `console`; production cần nhà cung cấp SMS (hoặc đổi sang gửi email).
4. **Push**: mặc định `console`; FCM là tuỳ chọn (cần Firebase project + package mobile).
5. **Lưu trữ ảnh minh chứng**: đang lưu đĩa cục bộ; production nên dùng S3/MinIO (implement `StorageService`).
6. **Gộp tài khoản trùng**: sổ cái bất biến nên chuyển điểm bằng cặp dòng `MANUAL_ADJUSTMENT` và vô hiệu hoá tài khoản bị gộp; xác nhận cách này chấp nhận được.
7. **QR check-in**: dùng mã xoay vòng theo chi nhánh (TTL ~60s) thay vì mã tĩnh; xác nhận có bật geofence không.
8. **README**: đang để README.md được commit, các file hướng dẫn khác bị `.gitignore`.
