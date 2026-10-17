# API nền tảng (đã có)

Base URL `/api/v1`. Header: `Authorization: Bearer <accessToken>`; `X-Tenant-Code` (tuỳ chọn, mặc định `hvp`).
Response thành công `{ "data": …, "meta"?: … }`; lỗi `{ "error": { "code", "message", "details"? } }`.
Phân trang: `?page=1&pageSize=20` → `meta { page, pageSize, total … }`. Ngày giờ ISO-8601 (UTC); ngày lịch `YYYY-MM-DD`.
Chi tiết field của từng endpoint: đọc `backend/src/modules/<module>/*.routes.ts` (schema zod ở đầu file là hợp đồng chính thức).

Ký hiệu vai trò: **M** = học viên (MEMBER), **S** = staff (COACH, HEAD_COACH, RECEPTIONIST, ADMIN), **FD** = lễ tân + admin, **CS** = coach + admin, **A** = admin.

## Auth (`/auth`)
| Method | Path | Quyền | Ghi chú |
|---|---|---|---|
| POST | `/auth/register/otp` | công khai | Gửi mã OTP 6 số tới email đăng ký → `{ requestId, maskedDestination, devPin? }`; email đã có → 409 `EMAIL_TAKEN` |
| POST | `/auth/register` | công khai | Bắt buộc `email` + `otpRequestId` + `otp` (sai/hết hạn → 400 `OTP_INVALID`). Tạo học viên, đánh dấu email đã xác thực, khởi tạo hạng I; chặn trùng SĐT/email (`PHONE_TAKEN`, `EMAIL_TAKEN`) |
| POST | `/auth/login` | công khai | `identifier` = email hoặc SĐT. INACTIVE → 403 `ACCOUNT_INACTIVE`; FROZEN vẫn đăng nhập được |
| POST | `/auth/refresh` | công khai | Refresh token xoay vòng, dùng một lần |
| POST | `/auth/logout` | đăng nhập | Thu hồi refresh token |
| GET | `/auth/me` | đăng nhập | Thông tin user + `roles` + `appRole` (`student|coach|reception|admin`) |
| POST | `/auth/password/forgot` → `/verify-pin` → `/reset` | công khai | Quên mật khẩu: nhập `email` → PIN gửi qua email (`EMAIL_NOT_REGISTERED` nếu chưa có); sai quá `security.pin_max_attempts` lần thì mã bị khoá (dev: trả `devPin`) |
| POST | `/auth/devices` | đăng nhập | Đăng ký device token push |

## Thành viên (`members`)
| Method | Path | Quyền |
|---|---|---|
| GET/PATCH | `/me/profile` | M |
| GET | `/members?q=&status=&branchId=` | S |
| GET | `/members/:memberId`, `/members/:memberId/duplicates` | S / FD |
| POST | `/members` (tạo tài khoản, trả mật khẩu tạm một lần) | FD |
| POST | `/members/:memberId/status` (ACTIVE/FROZEN/INACTIVE + lý do) | FD (gỡ INACTIVE: chỉ admin) |
| POST | `/admin/members/merge` (gộp tài khoản trùng) | A |

## Điểm (`points`)
| Method | Path | Quyền |
|---|---|---|
| GET | `/me/points/transactions?source=`, `/me/points/monthly` | M |
| GET | `/members/:memberId/points/transactions` | S |
| POST | `/admin/members/:memberId/points/adjust` (> 500 DP cần `confirmed: true`) | A |
| POST | `/admin/points/transactions/:transactionId/reverse` | A |

## Hạng (`ranks`)
| Method | Path | Quyền |
|---|---|---|
| GET | `/me/rank`, `/me/badges`, `/me/rank-history`, `/me/rank-trials` | M |
| POST | `/me/rank-trials` (yêu cầu Rank Trial) | M |
| GET | `/ranks` | đăng nhập |
| GET | `/rank-trials?status=OPEN|ALL` | CS |
| POST | `/rank-trials/:id/decision` `{result: PASS|FAIL, note}` | CS (hạng do ADMIN duyệt: coach chỉ đề xuất) |

## Thông báo
| Method | Path | Quyền |
|---|---|---|
| GET | `/me/notifications`, `/me/notifications/unread-count` | M |
| POST | `/me/notifications/read-all`, `/me/notifications/:id/read` | M |
| GET/POST | `/staff/notifications`, `/staff/notifications/read-all` | S |
| POST | `/admin/notifications/broadcast` (theo chi nhánh / hạng / tất cả) | A |
| GET/PUT | `/admin/notifications/templates[/:event]` | A |

## Khác
| Method | Path | Quyền |
|---|---|---|
| GET/PUT | `/admin/settings[/:key]` | A |
| GET | `/admin/audit-logs` | A |
| POST | `/uploads?purpose=evidence|avatar` (multipart `file`, ≤ 8MB; trả `{ url }`) | đăng nhập |
| GET | `/health`, `/files/*` (ảnh đã upload) | công khai |
