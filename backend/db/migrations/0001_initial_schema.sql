-- =====================================================================
-- HVP — THE FORGING SYSTEM  ·  DATABASE SCHEMA v3.0 (multi-tenant, tinh giản)
-- =====================================================================
-- Thiết kế lại từ đầu theo quy trình 11 bước trong
-- Mỗi khối lớn dưới đây = 1 "bước" trong quy trình, có ghi chú vì sao.
--
-- v3.0: đối chiếu lại với bản prototype demo khách hàng MỚI NHẤT
-- (HVP-Prototype.html, "bản demo khách hàng", chốt với KH cuối 09/2026 -
-- đầu 10/2026). Đây là những QUY TẮC NGHIỆP VỤ ĐÃ THAY ĐỔI so với v2.1,
-- lấy trực tiếp từ code thật của prototype (không suy diễn):
--   1) Marks KHÔNG BAO GIỜ bị đóng băng khi hết hạn gói — chỉ status
--      INACTIVE mới chặn đổi quà. Bỏ hẳn khái niệm "marks_status".
--   2) Rớt hạng (demotion) là tự động khi DP xuống dưới ngưỡng — huy
--      hiệu (badge) của hạng đó bị GỠ. Đủ DP lại thì được KHÔI PHỤC
--      ngay, không phải thi lại (nhờ "peak_rank_id" — hạng cao nhất đã
--      từng đạt).
--   3) Sổ cái điểm (point_transactions) trong thực tế là 1 DÒNG/1 sự
--      kiện mang CẢ HAI loại điểm (DP và Marks) cùng lúc — không phải
--      2 dòng riêng theo loại điểm như v2.1 giả định.
--   4) Trạng thái tài khoản (active/frozen/inactive) có lý do, người/
--      hệ thống đổi, qua kênh nào — lưu TRỰC TIẾP trên members, không
--      chỉ nằm trong audit_logs.
--   5) The Armory: phần thưởng chỉ cần "giá Marks" + "số lượng tồn" đơn
--      giản — không cần giá VNĐ/hệ số quy đổi lưu trong DB (Admin tự
--      nhập thẳng số Marks). Marks "đang giữ" (held) tính TRỰC TIẾP từ
--      các đơn PENDING_PICKUP, không cache riêng.
--   6) Thêm: gộp tài khoản trùng (merge), QR theo chi nhánh, xác nhận
--      minh chứng Challenge bởi Coach, lịch sử batch job, thông báo
--      broadcast theo chi nhánh/hạng, thông báo riêng cho nhân sự.
-- Xem ghi chú "CẬP NHẬT v3" / "TINH GIẢN v3" rải trong file để biết
-- bằng chứng cụ thể (tên hàm, dòng code) dẫn tới từng quyết định.
--
-- DBMS: PostgreSQL 15+.
--
-- QUY ƯỚC CHUNG (áp dụng nguyên tắc A3–A5 trong tài liệu nguyên tắc):
--  - PK: uuid, gen_random_uuid(), trừ bảng danh mục dùng code làm PK
--        và bảng log rất lớn dùng bigint identity (rẻ hơn, tuần tự).
--  - FK: tên cột = <bảng_số_ít>_id.
--  - Timestamp luôn timestamptz, set bởi server (default now()).
--  - Trạng thái: text + CHECK, không dùng ENUM gốc (dễ mở rộng sau).
--  - KHÔNG hard-delete dữ liệu nghiệp vụ — dùng status / *_at.
-- =====================================================================

create extension if not exists pgcrypto;   -- gen_random_uuid()
create extension if not exists citext;     -- email không phân biệt hoa/thường


-- #####################################################################
-- BƯỚC 1 — DOMAIN 0: TENANCY
-- #####################################################################

create table tenants (
  id           uuid primary key default gen_random_uuid(),
  code         text unique not null,              -- 'hvp', 'abc-fitness' — dùng trong URL/subdomain
  name         text not null,                      -- 'HVP Boxing'
  plan         text not null default 'STANDARD',   -- gói SaaS họ mua, tự định nghĩa sau
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table tenants is
  'Domain 0. Một dòng = một khách hàng SaaS (một công ty phòng gym). '
  'branches (chi nhánh) thuộc về 1 tenant; đừng nhầm 2 khái niệm.';


-- #####################################################################
-- BƯỚC 2 — DOMAIN 1: IDENTITY & ACCESS
-- #####################################################################

create table roles (
  code         text primary key,                  -- MEMBER · COACH · HEAD_COACH · RECEPTIONIST · ADMIN · SUPER_ADMIN
  name         text not null,
  description  text
);

create table branches (
  id                 uuid primary key default gen_random_uuid(),
  tenant_id          uuid not null references tenants(id),
  code               text not null,
  name               text not null,
  address            text,
  latitude           numeric,
  longitude          numeric,
  geofence_radius_m  int not null default 100,
  qr_prefix          text,                          -- CẬP NHẬT v3: tiền tố mã QR check-in riêng của chi nhánh
  qr_version         text,                           -- CẬP NHẬT v3: updateBranchQr() — đổi để "làm mới" QR cũ
  is_active          boolean not null default true,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (tenant_id, code)
);

create table users (
  id                 uuid primary key default gen_random_uuid(),
  tenant_id          uuid not null references tenants(id),
  email              citext,
  phone              text,
  password_hash      text not null,
  full_name          text not null,
  avatar_url         text,
  date_of_birth      date,
  gender             text check (gender in ('MALE','FEMALE','OTHER')),
  branch_id          uuid references branches(id),        -- chi nhánh nhà / chi nhánh làm việc
  account_status     text not null default 'ACTIVE' check (account_status in ('ACTIVE','LOCKED','DISABLED')),
  email_verified_at  timestamptz,
  phone_verified_at  timestamptz,
  last_login_at      timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint users_contact_required check (email is not null or phone is not null),
  unique (tenant_id, email),
  unique (tenant_id, phone)
);

create table user_roles (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references tenants(id),
  user_id      uuid not null references users(id),
  role_code    text not null references roles(code),
  granted_by   uuid references users(id),
  granted_at   timestamptz not null default now(),
  revoked_by   uuid references users(id),
  revoked_at   timestamptz
);
create unique index ux_user_roles_active on user_roles (user_id, role_code) where (revoked_at is null);

create table refresh_tokens (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references tenants(id),
  user_id      uuid not null references users(id),
  token_hash   text not null unique,
  device_info  text,
  expires_at   timestamptz not null,
  revoked_at   timestamptz,
  created_at   timestamptz not null default now()
);

create table password_reset_requests (
  id             uuid primary key default gen_random_uuid(),
  tenant_id      uuid not null references tenants(id),
  user_id        uuid not null references users(id),
  channel        text not null default 'SMS' check (channel in ('SMS','EMAIL')),
  destination    text not null,
  pin_hash       text not null,
  attempt_count  smallint not null default 0,
  expires_at     timestamptz not null,
  verified_at    timestamptz,
  used_at        timestamptz,
  created_at     timestamptz not null default now()
);

create table auth_logs (
  id           bigint generated always as identity primary key,
  tenant_id    uuid not null references tenants(id),
  user_id      uuid references users(id),
  event        text not null check (event in ('LOGIN','LOGIN_FAILED','LOGOUT','TOKEN_REFRESH','PASSWORD_RESET')),
  identifier   text,
  ip_address   inet,
  user_agent   text,
  created_at   timestamptz not null default now()
);

create table device_tokens (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references tenants(id),
  user_id       uuid not null references users(id),
  platform      text not null check (platform in ('ANDROID','IOS','WEB')),
  provider      text not null default 'FCM' check (provider in ('FCM','APNS')),
  token         text not null unique,
  is_valid      boolean not null default true,
  last_seen_at  timestamptz not null default now(),
  created_at    timestamptz not null default now()
);


-- #####################################################################
-- BƯỚC 3 — DOMAIN 2: CONFIGURATION (forward-only, versioned — nguyên tắc A9)
-- #####################################################################

create table system_configs (
  tenant_id     uuid not null references tenants(id),
  key           text not null,                     -- 'dp.monthly_cap', 'streak.target_sessions'...
  config_group  text not null check (config_group in
                 ('POINTS','RANK','STREAK','CHALLENGE','ARMORY','MEMBERSHIP','NOTIFICATION','CHECKIN','SECURITY')),
  value         jsonb not null,
  value_type    text not null check (value_type in ('INT','DECIMAL','BOOL','TEXT','TIME','JSON')),
  description   text,
  updated_by    uuid references users(id),
  updated_at    timestamptz not null default now(),
  primary key (tenant_id, key)
);

-- TINH GIẢN (giữ từ v2.1): bỏ bảng system_config_versions riêng — dùng lại
-- audit_logs (entity_type='SYSTEM_CONFIG') qua trigger fn_system_configs_audit
-- ở BƯỚC 14. Rollback = tạo 1 bản ghi audit mới, khớp đúng với
-- rollbackConfig() của prototype (không có bảng version riêng phía app).

create table session_types (
  tenant_id            uuid not null references tenants(id),
  code                 text not null,               -- GROUP · PT · ACADEMY · WORKSHOP · SPARRING
  name                 text not null,
  max_dp               int not null,
  max_dp_upper         int,
  counts_daily_limit   boolean not null default true,
  is_active            boolean not null default true,
  primary key (tenant_id, code)
);

create table point_rules (
  id                  uuid primary key default gen_random_uuid(),
  tenant_id           uuid not null references tenants(id),
  rule_code           text not null,                 -- SESSION_COMPLETION, ON_TIME, EARLY_RENEWAL...
  point_type          text not null check (point_type in ('DP','MARKS')),
  session_type_code   text,                           -- null = áp dụng mọi loại buổi
  amount              int not null,
  counts_toward_cap   boolean not null default true,
  limit_per_period    int,
  limit_period        text check (limit_period in ('SESSION','DAY','WEEK','MONTH','CYCLE','LIFETIME')),
  description         text,
  effective_from      timestamptz not null default now(),
  effective_to        timestamptz,
  created_by          uuid references users(id),
  created_at          timestamptz not null default now(),
  foreign key (tenant_id, session_type_code) references session_types(tenant_id, code)
);
create unique index ux_point_rules_current on point_rules
  (tenant_id, rule_code, point_type, coalesce(session_type_code, '*'))
  where (effective_to is null);


-- #####################################################################
-- BƯỚC 4 — DOMAIN 3: RANKS & CURRICULUM
-- #####################################################################

create table courses (
  id                uuid primary key default gen_random_uuid(),
  tenant_id         uuid not null references tenants(id),
  code              text not null,                  -- FOUNDATION
  name              text not null,
  duration_weeks    smallint not null,
  total_lessons     smallint not null,
  description       text,
  is_active         boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (tenant_id, code)
);

create table lesson_plans (
  id             uuid primary key default gen_random_uuid(),
  tenant_id      uuid not null references tenants(id),
  course_id      uuid not null references courses(id),
  lesson_no      smallint not null,
  week_no        smallint,
  title          text not null,                     -- "JAB (1)"
  subtitle       text,
  objectives     text,
  content        jsonb,
  is_assessment  boolean not null default false,
  is_graduation  boolean not null default false,
  is_advanced    boolean not null default false,     -- ẩn với gói 1 tháng
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (course_id, lesson_no)
);

create table ranks (
  id                  uuid primary key default gen_random_uuid(),
  tenant_id           uuid not null references tenants(id),
  rank_order          smallint not null,
  code                text not null,                 -- THE_UNKNOWN ...
  name_en             text not null,
  name_vi             text,
  dp_threshold        int not null,
  min_active_months   smallint not null default 0,    -- time-gate
  requires_trial      boolean not null default false,  -- trial-gate
  approval_role       text check (approval_role in ('COACH','HEAD_COACH','ADMIN')),
  is_honorary         boolean not null default false,
  badge_url           text,
  description         text,
  benefits            text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (tenant_id, rank_order),
  unique (tenant_id, code)
);
-- CẬP NHẬT v3: bỏ cột ranks.required_course_id (1 FK) — prototype cho thấy
-- 1 hạng có thể cần NHIỀU khóa (hạng VII cần ['book_4','book_5']) → tách
-- bảng n-n rank_required_courses dưới đây. Đồng thời bỏ ranks.trial_level
-- (STANDARD/ADVANCED) — không còn bằng chứng dùng trong luồng Rank Trial
-- thật của prototype (chỉ approval_role quyết định ai chấm).

create table rank_required_courses (
  tenant_id   uuid not null references tenants(id),
  rank_id     uuid not null references ranks(id),
  course_id   uuid not null references courses(id),
  primary key (rank_id, course_id)
);
comment on table rank_required_courses is
  'CẬP NHẬT v3. 1 hạng có thể yêu cầu hoàn thành nhiều khóa (course-gate n-n). '
  'Ví dụ prototype: hạng VII yêu cầu cả book_4 và book_5.';


-- #####################################################################
-- BƯỚC 5 — DOMAIN 4: MEMBERSHIP (gói tập)
-- #####################################################################

create table package_types (
  id                    uuid primary key default gen_random_uuid(),
  tenant_id             uuid not null references tenants(id),
  code                  text not null,
  name                  text not null,
  duration_days         int,                          -- null = không giới hạn ngày
  total_sessions        int,                           -- null = không giới hạn buổi
  sessions_per_week     smallint,
  is_trial              boolean not null default false,
  unlocks_course_id     uuid references courses(id),
  max_rank_order        smallint,                       -- gói trial: chặn ở rank II
  expire_on_zero_sessions boolean not null default true,
  price_vnd             numeric(12,0),
  description           text,
  is_active             boolean not null default true,
  sort_order            smallint not null default 0,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  unique (tenant_id, code)
);

-- Members = hồ sơ gamification của 1 user có role MEMBER (1:1, class-table
-- inheritance: PK trùng users.id).
create table members (
  user_id                     uuid primary key references users(id),
  tenant_id                   uuid not null references tenants(id),
  member_code                 text not null,               -- hiển thị ở quầy
  home_branch_id              uuid references branches(id),
  joined_at                   timestamptz not null default now(),

  -- CẬP NHẬT v3: trạng thái tài khoản — lý do/người đổi/qua kênh nào lưu
  -- TRỰC TIẾP ở đây (khớp setAccountStatus(id,status,reason,by,via) của
  -- prototype — statusReason/statusBy/statusVia/statusSince là field thật
  -- trên member, không chỉ nằm trong audit_logs). Ưu tiên: INACTIVE > FROZEN.
  status                      text not null default 'ACTIVE' check (status in ('ACTIVE','FROZEN','INACTIVE')),
  status_reason               text,
  status_changed_by           uuid references users(id),       -- null = System (batch)
  status_changed_via          text check (status_changed_via in ('MANUAL','BATCH','RENEWAL')),
  status_since                timestamptz,

  current_rank_id             uuid references ranks(id),
  peak_rank_id                uuid references ranks(id),        -- CẬP NHẬT v3: hạng cao nhất ĐÃ TỪNG đạt —
                                                                  -- dùng để miễn thi lại khi khôi phục sau rớt hạng
  dp_balance                  int not null default 0 check (dp_balance >= 0),
  marks_balance                int not null default 0 check (marks_balance >= 0),

  current_streak_weeks        int not null default 0,
  longest_streak_weeks        int not null default 0,
  streak_started_week         date,
  last_completed_session_at   timestamptz,
  last_activity_at            timestamptz,               -- KHÔNG tính login (chỉ hoạt động thật)

  duplicate_of_member_id       uuid references members(user_id),  -- CẬP NHẬT v3: gộp tài khoản trùng (mergeMembers)

  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now(),
  unique (tenant_id, member_code),
  constraint members_status_since_required check (status = 'ACTIVE' or status_since is not null)
);
-- TINH GIẢN v3: bỏ marks_status + marks_held khỏi members — xem ghi chú ở
-- BƯỚC 7 (point_transactions) và view v_member_wallet (BƯỚC 16). Bỏ
-- rank_progress_status + target_rank_id — đây là giá trị TÍNH TOÁN được
-- (computeRankProgress() của prototype tính lại mỗi lần cần, không cache),
-- cache ở đây chỉ tạo rủi ro lệch dữ liệu, không đổi UX.
comment on column members.duplicate_of_member_id is
  'Set bởi mergeMembers(keep,drop): dòng NÀY là bản trùng, dữ liệu giao dịch '
  '(point_transactions, attendances, redemptions, rank_trial_requests, '
  'challenge_participations) đã được UPDATE member_id sang bản "keep". '
  'Hồ sơ KHÔNG bị xóa — chỉ đánh dấu, để còn tra cứu lịch sử/khôi phục nhầm.';

create table memberships (
  id                     uuid primary key default gen_random_uuid(),
  tenant_id              uuid not null references tenants(id),
  member_id              uuid not null references members(user_id),
  package_type_id        uuid not null references package_types(id),
  branch_id              uuid references branches(id),
  start_date             date not null,
  end_date               date,                          -- null với gói không giới hạn ngày
  total_sessions         int,                            -- snapshot tại thời điểm bán
  used_sessions          int not null default 0,
  status                 text not null default 'ACTIVE'
      check (status in ('SCHEDULED','ACTIVE','COMPLETED','EXPIRED','CANCELLED')),
  previous_membership_id uuid references memberships(id),  -- chuỗi gia hạn
  price_paid_vnd         numeric(12,0),
  payment_evidence_url   text,                              -- CẬP NHẬT v3: ảnh minh chứng thu phí
  activated_by           uuid references users(id),
  activated_at           timestamptz not null default now(),
  expired_at             timestamptz,
  cancelled_by           uuid references users(id),
  cancel_reason          text,
  note                   text,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);
-- A10: mỗi học viên chỉ có tối đa 1 gói ACTIVE (gói SCHEDULED nối tiếp
-- không tính — khớp m.scheduled là 1 slot riêng, có thể tồn tại song song).
create unique index ux_memberships_one_active on memberships (member_id) where (status = 'ACTIVE');
create unique index ux_memberships_one_scheduled on memberships (member_id) where (status = 'SCHEDULED');
-- CẬP NHẬT v3: status thêm 'COMPLETED' (gói hết buổi tự hoàn thành, khác
-- EXPIRED là hết ngày) — khớp ms.status==='completed' trong prototype.

create table renewal_requests (
  id                       uuid primary key default gen_random_uuid(),
  tenant_id                uuid not null references tenants(id),
  member_id                uuid not null references members(user_id),
  current_membership_id    uuid references memberships(id),
  desired_package_type_id  uuid references package_types(id),
  note                     text,
  status                   text not null default 'PENDING' check (status in ('PENDING','COMPLETED','CANCELLED')),
  handled_by               uuid references users(id),
  handled_at               timestamptz,
  reason                   text,                               -- lý do huỷ (hoặc ghi chú xử lý khác)
  payment_evidence_url     text,                                -- CẬP NHẬT v3: ảnh thu phí khi duyệt
  resulting_membership_id  uuid references memberships(id),
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);
create unique index ux_renewal_one_pending on renewal_requests (member_id) where (status = 'PENDING');
-- TINH GIẢN v3: bỏ contact_channel + contact_attempts — khách hàng đã xác
-- nhận BỎ kênh liên hệ trong luồng gia hạn (ghi chú trong chính code
-- prototype: "đã BỎ kênh liên hệ"). Không còn field này ở form thật.


-- #####################################################################
-- BƯỚC 6 — DOMAIN 5: TRAINING (lớp / buổi / check-in / điểm danh)
-- #####################################################################

create table classes (
  id                  uuid primary key default gen_random_uuid(),
  tenant_id           uuid not null references tenants(id),
  branch_id           uuid not null references branches(id),
  name                text not null,
  session_type_code   text not null,
  course_id           uuid references courses(id),
  default_coach_id    uuid references users(id),
  weekdays            smallint[] not null default '{}',   -- ISO 1=Mon..7=Sun
  start_time          time not null,
  duration_minutes    smallint not null,
  capacity            smallint,
  is_active           boolean not null default true,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  foreign key (tenant_id, session_type_code) references session_types(tenant_id, code)
);

create table class_enrollments (
  id             uuid primary key default gen_random_uuid(),
  tenant_id      uuid not null references tenants(id),
  class_id       uuid not null references classes(id),
  member_id      uuid not null references members(user_id),
  membership_id  uuid references memberships(id),
  start_date     date not null,
  end_date       date,
  status         text not null default 'ACTIVE' check (status in ('ACTIVE','ENDED','CANCELLED')),
  created_by     uuid references users(id),
  created_at     timestamptz not null default now()
);
create unique index ux_class_enrollment_active on class_enrollments (class_id, member_id) where (status = 'ACTIVE');

create table sessions (
  id                     uuid primary key default gen_random_uuid(),
  tenant_id              uuid not null references tenants(id),
  class_id               uuid references classes(id),            -- null với PT/event
  branch_id              uuid not null references branches(id),
  session_type_code      text not null,
  coach_id               uuid not null references users(id),      -- dùng để giới hạn phạm vi coach
  lesson_plan_id         uuid references lesson_plans(id),
  title                  text,
  starts_at              timestamptz not null,
  ends_at                timestamptz not null,
  checkin_opens_at       timestamptz,
  checkin_closes_at      timestamptz,
  on_time_grace_minutes  smallint,
  max_dp_override        int,
  is_exam                boolean not null default false,          -- CẬP NHẬT v3: createExamSession() — buổi kiểm tra
  counts_daily_limit     boolean,                                 -- null = theo session_types mặc định
  capacity               smallint,
  status                 text not null default 'SCHEDULED' check (status in ('SCHEDULED','IN_PROGRESS','COMPLETED','CANCELLED')),
  notes                  text,
  created_by             uuid references users(id),
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  foreign key (tenant_id, session_type_code) references session_types(tenant_id, code)
);
-- CẬP NHẬT v3: đổi has_assessment -> is_exam (khớp tên nghiệp vụ
-- createExamSession/occIsAcademy của prototype: "buổi kiểm tra", Coach và
-- Admin đều tạo được).

create table checkin_codes (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references tenants(id),
  branch_id    uuid not null references branches(id),
  code         text not null unique,
  valid_from   timestamptz not null default now(),
  valid_until  timestamptz not null,
  is_used      boolean not null default false,
  used_by      uuid references members(user_id),
  used_at      timestamptz,
  created_at   timestamptz not null default now()
);

create table attendances (
  id                    uuid primary key default gen_random_uuid(),
  tenant_id             uuid not null references tenants(id),
  session_id            uuid not null references sessions(id),
  member_id             uuid not null references members(user_id),
  membership_id         uuid references memberships(id),          -- gói bị trừ buổi
  checkin_at            timestamptz,
  checkin_evidence_url  text,                                      -- CẬP NHẬT v3: checkinMember(...,evidence)
  checkin_code_id       uuid references checkin_codes(id),
  checkin_latitude      numeric,
  checkin_longitude     numeric,
  checked_in_by         uuid references users(id),
  -- CẬP NHẬT v3: trạng thái thật khớp coachConfirmAttendance() — học viên
  -- check-in xong luôn ở AWAITING_COACH (chờ Coach xác nhận có mặt/%hoàn
  -- thành), Coach mới quyết CONFIRMED_PASS/CONFIRMED_FAIL/ABSENT.
  attendance_status     text not null default 'UPCOMING'
      check (attendance_status in ('UPCOMING','AWAITING_COACH','CONFIRMED_PASS','CONFIRMED_FAIL','ABSENT')),
  completion_percent    smallint,
  dp_awarded            int not null default 0,                    -- snapshot kết quả award() cho buổi này
  marks_awarded         int not null default 0,
  attitude_granted      boolean not null default false,            -- mỗi học viên 1 lần/buổi
  attitude_reason       text,
  coach_note            text,
  confirmed_by          uuid references users(id),
  confirmed_at          timestamptz,
  -- CẬP NHẬT v3: gộp academy_results vào đây (xem ghi chú TINH GIẢN dưới).
  academy_result        text check (academy_result in ('PASS','FAIL')),
  academy_note          text,
  completed_on          date,
  counts_daily_limit    boolean not null default true,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  unique (session_id, member_id)
);
-- A10 chống gian lận: tối đa 1 lượt hoàn thành thường/ngày (PRD §12)
create unique index ux_attendance_one_completion_per_day on attendances (member_id, completed_on)
  where (attendance_status = 'CONFIRMED_PASS' and counts_daily_limit);

-- TINH GIẢN v3: bỏ bảng academy_results riêng. Trong prototype, kết quả
-- kiểm tra Academy (coachSubmitAcademyResult) chỉ là 2 field thêm NGAY
-- TRÊN dòng attendances của buổi kiểm tra đó (academyResult/academyNote),
-- không phải một thực thể độc lập — buổi kiểm tra đã là 1 session riêng
-- (is_exam=true), nên không cần bảng con nữa.

create table course_enrollments (
  id                 uuid primary key default gen_random_uuid(),
  tenant_id          uuid not null references tenants(id),
  member_id          uuid not null references members(user_id),
  course_id          uuid not null references courses(id),
  membership_id      uuid references memberships(id),
  status             text not null default 'IN_PROGRESS' check (status in ('IN_PROGRESS','COMPLETED','DROPPED')),
  lessons_completed  smallint not null default 0,
  started_at         timestamptz not null default now(),
  completed_at       timestamptz,
  confirmed_by       uuid references users(id),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create unique index ux_course_enrollment_open on course_enrollments (member_id, course_id) where (status <> 'DROPPED');


-- #####################################################################
-- BƯỚC 7 — DOMAIN 6: POINT LEDGER (DP & HVP Marks) — nguyên tắc A7 + A8
-- Sổ cái BẤT BIẾN. members.dp_balance/marks_balance chỉ là cache, được
-- trigger cập nhật — ứng dụng KHÔNG BAO GIỜ ghi trực tiếp 2 cột đó.
--
-- CẬP NHẬT v3 — THAY ĐỔI QUAN TRỌNG NHẤT CỦA LẦN NÀY: prototype thật
-- (hàm pushTx/award trong state.js) cho thấy sổ cái là 1 DÒNG/1 SỰ KIỆN
-- mang CẢ HAI loại điểm cùng lúc (dp VÀ marks trên cùng 1 dòng), không
-- phải 2 dòng tách theo point_type như v2.1 giả định. Ví dụ thật:
--   pushTx('mem_demo', { type:'SESSION', dp:45, marks:15, ... })
-- Thiết kế lại point_transactions theo đúng hình dạng này: bỏ cột
-- point_type, thay bằng dp_amount + marks_amount trên cùng 1 dòng.
-- #####################################################################

create table point_transactions (
  id                          uuid primary key default gen_random_uuid(),
  tenant_id                   uuid not null references tenants(id),
  member_id                   uuid not null references members(user_id),
  source                      text not null check (source in (
      'OPENING','SESSION','ATTITUDE','ACADEMY','STREAK_MILESTONE','CHALLENGE',
      'RANK_TRIAL','EARLY_RENEWAL','COMEBACK','ARMORY_REDEEM',
      'MANUAL_ADJUSTMENT','REVERSAL')),
  dp_amount                   int not null default 0,              -- số thực đã ghi (có dấu)
  marks_amount                int not null default 0,
  is_capped                   boolean not null default false,       -- có bị cắt theo hạn mức tháng không
  note                        text,
  status                      text not null default 'POSTED' check (status in ('PENDING_APPROVAL','POSTED','REJECTED')),
  idempotency_key             text,                                  -- chỉ 1 số luồng cần (vd EARLY_RENEWAL); null = không cần chống trùng
  point_rule_id               uuid references point_rules(id),      -- rule đang hiệu lực khi phát sinh (nếu có)
  reversal_of_id              uuid references point_transactions(id),
  attendance_id               uuid references attendances(id),
  challenge_participation_id  uuid,                                  -- FK thêm ở BƯỚC 9 (tránh vòng phụ thuộc)
  rank_trial_request_id       uuid,                                  -- FK thêm ở BƯỚC 8
  redemption_id               uuid,                                  -- FK thêm ở BƯỚC 10
  membership_id               uuid references memberships(id),
  reason                      text,                                  -- bắt buộc khi source=MANUAL_ADJUSTMENT
  created_by                  uuid references users(id),             -- null = SYSTEM
  approved_by                 uuid references users(id),
  approved_at                 timestamptz,
  occurred_at                 timestamptz not null default now(),
  created_at                  timestamptz not null default now(),
  unique (reversal_of_id),
  constraint pt_dp_not_redeemed check (source <> 'ARMORY_REDEEM' or dp_amount = 0),
  constraint pt_manual_needs_reason check (source <> 'MANUAL_ADJUSTMENT' or reason is not null)
);
-- chỉ chống trùng khi CÓ idempotency_key (không phải mọi dòng cần) — khớp
-- award(..., ref) chỉ truyền ref ở vài luồng cụ thể (gia hạn sớm...).
create unique index ux_pt_idempotency on point_transactions (idempotency_key) where (idempotency_key is not null);
create unique index ux_pt_redemption_debit on point_transactions (redemption_id) where (source = 'ARMORY_REDEEM');

-- TINH GIẢN (giữ từ v2.1): bỏ member_monthly_point_totals + comeback_cycles.
-- Point Engine tự SUM() trực tiếp khi cần cap tháng:
--   SELECT sum(dp_amount), sum(marks_amount) FROM point_transactions
--   WHERE member_id=? AND occurred_at >= date_trunc('month', now())
--     AND source IN ('SESSION','ATTITUDE','ACADEMY','CHALLENGE','COMEBACK')
--   -- đúng danh sách CAP_SOURCES trong prototype — RANK_TRIAL/OPENING/
--   -- EARLY_RENEWAL/MANUAL_ADJUSTMENT/REVERSAL/ARMORY_REDEEM KHÔNG bị cap.
-- Chống cộng trùng comeback dùng idempotency_key ('renewal:{membershipId}'
-- kiểu tương tự) hoặc kiểm tra tồn tại dòng COMEBACK gần nhất theo
-- member_id + occurred_at, không cần bảng riêng.


-- #####################################################################
-- BƯỚC 8 — DOMAIN 7: RANK PROGRESSION
-- #####################################################################

create table rank_trial_requests (
  id                     uuid primary key default gen_random_uuid(),
  tenant_id              uuid not null references tenants(id),
  member_id              uuid not null references members(user_id),
  target_rank_id         uuid not null references ranks(id),
  status                 text not null default 'PENDING' check (status in ('PENDING','SCHEDULED','PASSED','FAILED','CANCELLED')),
  approver_role          text not null check (approver_role in ('COACH','HEAD_COACH','ADMIN')),
  assigned_to            uuid references users(id),
  scheduled_at           timestamptz,
  eligibility_snapshot   jsonb not null,           -- DP, số tháng active, trạng thái khóa học tại thời điểm request
  result_note            text,
  evaluated_by           uuid references users(id),
  evaluated_at           timestamptz,
  requested_at           timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);
create unique index ux_rank_trial_open on rank_trial_requests (member_id) where (status in ('PENDING','SCHEDULED'));

alter table point_transactions
  add constraint fk_pt_rank_trial foreign key (rank_trial_request_id) references rank_trial_requests(id);

-- CẬP NHẬT v3: member_rank_history giờ đóng 2 vai trò — (1) log BẤT BIẾN
-- mọi lần đổi hạng (lên/xuống/khôi phục), VÀ (2) nguồn dữ liệu cho "huy
-- hiệu hiện đang có" của học viên. Khớp đúng cơ chế grantBadge()/
-- reevaluateRank() của prototype: khi RỚT HẠNG, badge bị GỠ (không xóa
-- lịch sử cũ — mà GHI THÊM 1 dòng mới đánh dấu is_revoked=true ngay lúc
-- insert, vẫn giữ bảng append-only). Khi KHÔI PHỤC, ghi 1 dòng MỚI hoàn
-- toàn (lý do/thời điểm mới) — không "un-revoke" dòng cũ, đúng như
-- grantBadge() tạo lại từ đầu.
-- "Huy hiệu đang có" = với mỗi to_rank_id, lấy dòng mới nhất (earned_at)
-- của member đó; nếu is_revoked=false thì đang có badge hạng đó.
create table member_rank_history (
  id                      uuid primary key default gen_random_uuid(),
  tenant_id               uuid not null references tenants(id),
  member_id               uuid not null references members(user_id),
  from_rank_id            uuid references ranks(id),
  to_rank_id              uuid not null references ranks(id),
  earned_via              text not null
      check (earned_via in ('INITIAL','AUTO_UPGRADE','AUTO_DEMOTE','RESTORED','RANK_TRIAL_PASSED','MANUAL')),
  reason                  text not null,                      -- câu lý do hiển thị cho học viên (vd "Đạt 500 DP, đủ 1 tháng")
  rank_trial_request_id   uuid references rank_trial_requests(id),
  dp_at_change            int not null,
  approved_by             uuid references users(id),
  is_revoked              boolean not null default false,      -- true nếu đây là dòng ghi nhận RỚT/GỠ badge
  revoked_at              timestamptz,
  earned_at               timestamptz not null default now()
);


-- #####################################################################
-- BƯỚC 9 — DOMAIN 8: STREAK
-- #####################################################################

create table streak_freeze_grants (
  id                  uuid primary key default gen_random_uuid(),
  tenant_id           uuid not null references tenants(id),
  member_id           uuid not null references members(user_id),
  grant_source        text not null default 'MONTHLY' check (grant_source in ('MONTHLY','RANK','PACKAGE','ADMIN')),
  granted_for_month   date,
  granted_at          timestamptz not null default now(),
  expires_at          timestamptz,
  used_week_start     date,
  used_at             timestamptz
);
create unique index ux_freeze_monthly on streak_freeze_grants (member_id, granted_for_month) where (grant_source = 'MONTHLY');

create table streak_logs (
  id                uuid primary key default gen_random_uuid(),
  tenant_id         uuid not null references tenants(id),
  member_id         uuid not null references members(user_id),
  week_start        date not null,                -- Thứ 2 theo giờ server
  sessions_count    smallint not null,
  target_sessions   smallint not null,             -- snapshot cấu hình tuần đó
  result            text not null check (result in ('INCREASED','FROZEN','RESET','SKIPPED')),
  streak_before     int not null,
  streak_after      int not null,
  freeze_grant_id   uuid references streak_freeze_grants(id),
  created_at        timestamptz not null default now(),
  unique (member_id, week_start)
);
-- TINH GIẢN v3: bỏ cột all_on_time (không còn bằng chứng dùng trong
-- batchStreak() của prototype — streak chỉ tính theo SỐ buổi hợp lệ/tuần).


-- #####################################################################
-- BƯỚC 10 — DOMAIN 9: CHALLENGES & BADGES
-- #####################################################################

create table challenges (
  id                 uuid primary key default gen_random_uuid(),
  tenant_id          uuid not null references tenants(id),
  code               text,
  title              text not null,
  description        text,
  challenge_type     text not null check (challenge_type in ('DAILY','WEEKLY','MONTHLY','EVENT')),
  -- CẬP NHẬT v3: context thay cho condition_type/condition_params —
  -- khớp createChallenge({context}) + bumpChallenges(): điều kiện tính
  -- tiến độ chỉ còn 3 kiểu thật trong prototype.
  context            text not null default 'SESSION' check (context in ('SESSION','WORKSHOP','EXAM')),
  target             int not null default 1,            -- số lượt hợp lệ cần đạt
  reward_dp          int not null default 0,
  reward_marks       int not null default 0,
  starts_at          timestamptz not null,
  ends_at            timestamptz not null,
  status             text not null default 'DRAFT' check (status in ('DRAFT','OPEN','CLOSED','CANCELLED')),
  created_by         uuid references users(id),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (tenant_id, code)
);
-- TINH GIẢN v3: bỏ is_main (mô hình "1 thử thách chính/tháng" không còn
-- đúng — giới hạn thật là 1 config SỐ LƯỢNG thử thách được thưởng/tháng
-- cho MỌI challenge, xem config_group=CHALLENGE key 'challenge_monthly_limit'
-- ở BƯỚC 3). Bỏ condition_type/condition_params/audience/max_participants/
-- requires_join/join_deadline — không có bằng chứng dùng trong code thật;
-- Challenge trong prototype luôn mở cho mọi học viên active, luôn cần
-- joinChallenge() (hằng số, không phải cấu hình).

create table challenge_participations (
  id              uuid primary key default gen_random_uuid(),
  tenant_id       uuid not null references tenants(id),
  challenge_id    uuid not null references challenges(id),
  member_id       uuid not null references members(user_id),
  -- CẬP NHẬT v3: AWAITING_COACH thay cho COMPLETED — Coach phải xác nhận
  -- minh chứng trước khi phát thưởng (coachConfirmChallenge).
  status          text not null default 'JOINED' check (status in ('JOINED','AWAITING_COACH','REWARDED','EXPIRED')),
  progress_value  int not null default 0,
  evidence_url    text,                                  -- CẬP NHẬT v3: attachChallengeEvidence()
  evidence_at     timestamptz,
  joined_at       timestamptz not null default now(),
  completed_at    timestamptz,                             -- lúc đạt target, chuyển AWAITING_COACH
  confirmed_by    uuid references users(id),                -- CẬP NHẬT v3: Coach xác nhận
  confirmed_at    timestamptz,
  is_limited      boolean not null default false,           -- CẬP NHẬT v3: đạt giới hạn thưởng/tháng, không cộng điểm
  rewarded_at     timestamptz,
  updated_at      timestamptz not null default now(),
  unique (challenge_id, member_id)
);

alter table point_transactions
  add constraint fk_pt_challenge foreign key (challenge_participation_id) references challenge_participations(id);

-- TINH GIẢN (giữ từ v2.1): bỏ achievements/member_achievements — Battle
-- Marks CHÍNH LÀ badges, 1-1 với hạng. "Huy hiệu hiện có" tra từ
-- member_rank_history (xem ghi chú ở BƯỚC 8), không cần bảng riêng.


-- #####################################################################
-- BƯỚC 11 — DOMAIN 10: THE ARMORY (đổi quà) — nguyên tắc A6 (state machine)
--
-- CẬP NHẬT v3: prototype thật (redeemReward/confirmDelivery/
-- rejectRedemption/adjustStock) đơn giản hơn nhiều so với v2.1:
--   - rewards chỉ cần GIÁ MARKS trực tiếp (Admin tự nhập) + 1 cột tồn
--     kho duy nhất — KHÔNG lưu giá VNĐ/hệ số quy đổi trong DB.
--   - Marks "đang giữ" (held) của 1 học viên = tính TRỰC TIẾP từ
--     SUM(marks_cost) các đơn status=PENDING_PICKUP, không cache cột
--     riêng trên members (xem lại BƯỚC 14/16).
--   - Không có trạng thái "READY" trung gian — đơn vào thẳng
--     PENDING_PICKUP rồi ra DELIVERED/REJECTED/CANCELLED/EXPIRED.
-- #####################################################################

create table reward_tiers (
  tenant_id    uuid not null references tenants(id),
  code         text not null,                -- FIELD_SUPPLIES ...
  name         text not null,
  min_marks    int not null,
  max_marks    int,                           -- null = mở (BLACK VAULT 2000+)
  sort_order   smallint not null,
  primary key (tenant_id, code)
);

create table rewards (
  id                uuid primary key default gen_random_uuid(),
  tenant_id         uuid not null references tenants(id),
  sku               text not null,
  name              text not null,
  description       text,
  image_url         text,
  tier_code         text,
  marks_cost        int not null check (marks_cost > 0),    -- CẬP NHẬT v3: Admin nhập thẳng, không quy đổi VNĐ
  stock             int not null default 0 check (stock >= 0),  -- CẬP NHẬT v3: 1 cột tồn duy nhất
  per_member_limit  int,
  limit_period      text check (limit_period in ('MONTH','YEAR','LIFETIME')),
  min_rank_id       uuid references ranks(id),
  pickup_days       smallint,                            -- null = theo cấu hình mặc định
  sale_starts_at    timestamptz,
  sale_ends_at      timestamptz,
  is_active         boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (tenant_id, sku),
  foreign key (tenant_id, tier_code) references reward_tiers(tenant_id, code)
);
-- TINH GIẢN v3: bỏ hẳn bảng reward_value_groups + cột cost_vnd/coefficient/
-- rounding_step/computed_marks/published_marks/stock_on_hand/stock_reserved
-- (xem ghi chú đầu BƯỚC 11). "stock" ở đây đã LÀ số còn có thể đổi — bị
-- trừ ngay khi tạo đơn PENDING_PICKUP (không phải giữ chỗ riêng), hoàn lại
-- khi đơn bị huỷ/hết hạn — khớp đúng rw.stock -= 1 / += 1 trong prototype.

create table redemptions (
  id                     uuid primary key default gen_random_uuid(),
  tenant_id              uuid not null references tenants(id),
  redemption_code        text not null unique,                    -- mã đưa cho nhân viên tại quầy khi nhận quà
  member_id              uuid not null references members(user_id),
  reward_id              uuid not null references rewards(id),
  pickup_branch_id       uuid not null references branches(id),   -- chi nhánh học viên CHỌN nhận hàng
  marks_cost             int not null,                      -- snapshot giá Marks tại thời điểm đổi
  status                 text not null default 'PENDING_PICKUP'
      check (status in ('PENDING_PICKUP','DELIVERED','REJECTED','CANCELLED','EXPIRED')),
  idempotency_key        text not null unique,                     -- chống bấm đúp khi tạo đơn (giữ lại theo yêu cầu, prototype không model nhưng vẫn cần ở DB thật)
  requested_at           timestamptz not null default now(),
  decided_by             uuid references users(id),               -- người xử lý trạng thái cuối (null = System/batch)
  decided_at             timestamptz,
  reason                 text,                                     -- lý do REJECTED/EXPIRED/CANCELLED
  delivery_evidence_url  text,                                      -- ảnh lúc giao quà (DELIVERED)
  updated_at             timestamptz not null default now()
);
-- TINH GIẢN v3: bỏ quantity (luôn 1 đơn/lần đổi), trạng thái READY,
-- prepared_by/ready_at, cost_vnd_snapshot/coefficient_snapshot (không còn
-- vì rewards không còn 2 cột đó), và tách delivered_by/delivered_at/
-- closed_* — prototype dùng CHUNG decided_by/decided_at/reason cho mọi
-- kết quả cuối (DELIVERED/REJECTED/EXPIRED).
-- redemption_code + idempotency_key KHÔNG có trong prototype demo (vốn
-- chỉ là code JS phía client, không chống bấm đúp ở tầng lưu trữ), nhưng
-- vẫn giữ lại ở DB thật theo yêu cầu — double-submit (bấm 2 lần nút "Đổi
-- quà") là rủi ro thật khi lên production, nên tầng DB cần chặn bằng
-- UNIQUE chứ không chỉ disable nút phía UI.
-- Marks "đang giữ" của 1 học viên = SUM(marks_cost) WHERE status =
-- 'PENDING_PICKUP' — xem view v_member_wallet ở BƯỚC 16.

alter table point_transactions
  add constraint fk_pt_redemption foreign key (redemption_id) references redemptions(id);

create table inventory_movements (
  id              bigint generated always as identity primary key,
  tenant_id       uuid not null references tenants(id),
  reward_id       uuid not null references rewards(id),
  movement_type   text not null check (movement_type in ('IN','OUT')),   -- CẬP NHẬT v3: khớp adjustStock(type)
  quantity        int not null check (quantity > 0),
  redemption_id   uuid references redemptions(id),                       -- set khi OUT do giao quà (confirmDelivery)
  actor_id        uuid references users(id),
  reason          text,
  created_at      timestamptz not null default now()
);


-- #####################################################################
-- BƯỚC 12 — DOMAIN 11: NOTIFICATIONS
--
-- CẬP NHẬT v3: thêm thông báo BROADCAST (theo chi nhánh/hạng, không gắn
-- 1 user cụ thể — khớp sendBroadcast()/matchesBroadcast()) và tách riêng
-- luồng thông báo cho NHÂN SỰ theo vai trò (notifyStaff — khớp
-- staffNotificationsFor(role), không phải thông báo gắn 1 user).
-- #####################################################################

create table notification_templates (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references tenants(id),
  event_type    text not null,                 -- SESSION_COMPLETED, RANK_EARNED ...
  title         text not null,
  body          text not null,                  -- có placeholder {dp} {rank} {reward}
  channels      text[] not null default '{PUSH,IN_APP}',
  send_time     time,                            -- null = gửi ngay
  audience      jsonb,
  dedupe_period text not null default 'NONE' check (dedupe_period in ('NONE','DAY','WEEK','MONTH','CYCLE')),
  is_enabled    boolean not null default true,
  updated_by    uuid references users(id),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (tenant_id, event_type)
);

create table notifications (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references tenants(id),
  user_id       uuid references users(id),               -- CẬP NHẬT v3: nullable — null khi là BROADCAST
  branch_id     uuid references branches(id),             -- CẬP NHẬT v3: target BROADCAST theo chi nhánh
  rank_id       uuid references ranks(id),                 -- CẬP NHẬT v3: target BROADCAST theo hạng
  sent_by       uuid references users(id),                 -- CẬP NHẬT v3: ai gửi broadcast (null nếu không phải)
  template_id   uuid references notification_templates(id),
  event_type    text not null,
  title         text not null,
  body          text not null,
  payload       jsonb,
  dedupe_key    text unique,                     -- vd INACTIVE_WARNING:{member}:{date}
  read_at       timestamptz,
  created_at    timestamptz not null default now(),
  constraint notifications_user_or_broadcast check (user_id is not null or event_type = 'BROADCAST')
);

-- CẬP NHẬT v3: bảng mới — thông báo cho NHÂN SỰ theo VAI TRÒ (không theo
-- 1 user_id cụ thể), khớp notifyStaff(to, event, title, body) +
-- staffNotificationsFor(role)/markStaffRead(role) của prototype.
create table staff_notifications (
  id            bigint generated always as identity primary key,
  tenant_id     uuid not null references tenants(id),
  to_role       text not null references roles(code),     -- 'ADMIN' · 'COACH' · 'RECEPTIONIST' ...
  event_type    text not null,
  title         text not null,
  body          text not null,
  read_at       timestamptz,
  created_at    timestamptz not null default now()
);

create table notification_logs (
  id                bigint generated always as identity primary key,
  tenant_id         uuid not null references tenants(id),
  notification_id   uuid references notifications(id),
  user_id           uuid references users(id),
  event_type        text not null,
  channel           text not null check (channel in ('PUSH','IN_APP','EMAIL','SMS')),
  device_token_id   uuid references device_tokens(id),
  status            text not null check (status in ('QUEUED','SENT','FAILED','SKIPPED')),
  skip_reason       text,
  error_message     text,
  attempt_count     smallint not null default 0,
  next_retry_at     timestamptz,
  sent_at           timestamptz,
  created_at        timestamptz not null default now()
);


-- #####################################################################
-- BƯỚC 13 — DOMAIN 12: AUDIT
-- #####################################################################

create table audit_logs (
  id           bigint generated always as identity primary key,
  tenant_id    uuid not null references tenants(id),
  actor_id     uuid references users(id),          -- null = SYSTEM
  actor_type   text not null default 'USER' check (actor_type in ('USER','SYSTEM')),
  action       text not null,                       -- MEMBERSHIP_RENEW, DP_ADJUSTED, CONFIG_CHANGE, ACCOUNTS_MERGED...
  entity_type  text not null,
  entity_id    text not null,
  before_data  jsonb,
  after_data   jsonb,
  reason       text,
  ip_address   inet,
  created_at   timestamptz not null default now()
);


-- #####################################################################
-- BƯỚC 13B — DOMAIN 13: BATCH JOBS
-- CẬP NHẬT v3: bảng mới — lịch sử các lần chạy batch (hết hạn gói, nhắc
-- gia hạn, quét inactive, chốt streak, comeback, chốt challenge, nhắc
-- streak/vắng, huỷ đơn quà quá hạn), khớp recordBatch()/BATCHES/runBatch()
-- của prototype — Admin tự bấm chạy để demo, hoặc chạy theo lịch thật.
-- #####################################################################

create table batch_runs (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references tenants(id),
  batch_key     text not null check (batch_key in
                 ('expiry','reminder','inactive','streak','comeback','challenge','nudge','armory')),
  name          text not null,
  result_lines  jsonb not null default '[]',     -- mảng chuỗi mô tả kết quả từng dòng, hiển thị cho Admin
  run_by        uuid references users(id),        -- null = chạy tự động theo lịch (System)
  run_at        timestamptz not null default now()
);
comment on table batch_runs is
  'CẬP NHẬT v3. Lịch sử chạy batch job — mỗi lần chạy = 1 dòng, append-only. '
  'undoStreakWeek() (chỉ phục vụ demo) KHÔNG xóa dòng này, chỉ ghi thêm 1 '
  'audit_logs action=BATCH_UNDO — xem BƯỚC 13.';


-- #####################################################################
-- BƯỚC 14 — TRIGGERS: nơi DB tự bảo vệ tính đúng (nguyên tắc A7, A8, A10)
-- #####################################################################

-- 14.1 Append-only chung, dùng cho các bảng log không cho sửa/xóa
create or replace function fn_block_update_delete() returns trigger as $$
begin
  raise exception '% is append-only: % is not allowed on this table', TG_TABLE_NAME, TG_OP;
end;
$$ language plpgsql;

do $$
declare t text;
begin
  foreach t in array array['audit_logs','inventory_movements','auth_logs',
                            'member_rank_history','streak_logs','batch_runs']
  loop
    execute format('create trigger trg_%1$s_no_update before update on %1$I for each row execute function fn_block_update_delete()', t);
    execute format('create trigger trg_%1$s_no_delete before delete on %1$I for each row execute function fn_block_update_delete()', t);
  end loop;
end $$;

-- 14.2 point_transactions: chặn sửa/xóa dòng đã chốt (chỉ PENDING_APPROVAL mới đổi được)
create or replace function fn_pt_guard() returns trigger as $$
begin
  if TG_OP = 'DELETE' then
    raise exception 'point_transactions is append-only: delete is not allowed (id=%)', OLD.id;
  end if;
  if OLD.status <> 'PENDING_APPROVAL' then
    raise exception 'point_transactions % is already finalized (status=%), cannot modify', OLD.id, OLD.status;
  end if;
  if NEW.status not in ('POSTED','REJECTED') then
    raise exception 'a PENDING_APPROVAL row can only move to POSTED or REJECTED';
  end if;
  if NEW.member_id <> OLD.member_id or NEW.dp_amount <> OLD.dp_amount or NEW.marks_amount <> OLD.marks_amount then
    raise exception 'only status/approved_by/approved_at may change on a pending point_transactions row';
  end if;
  return NEW;
end;
$$ language plpgsql;
create trigger trg_pt_guard_upd before update on point_transactions for each row execute function fn_pt_guard();
create trigger trg_pt_guard_del before delete on point_transactions for each row execute function fn_pt_guard();

-- 14.3 point_transactions: validate dòng REVERSAL trước khi cho insert
-- CẬP NHẬT v3: so khớp cả dp_amount và marks_amount (1 dòng có cả 2 loại).
create or replace function fn_pt_reversal_check() returns trigger as $$
declare orig point_transactions%rowtype;
begin
  if NEW.source = 'REVERSAL' then
    if NEW.reversal_of_id is null then
      raise exception 'a REVERSAL row must set reversal_of_id';
    end if;
    select * into orig from point_transactions where id = NEW.reversal_of_id;
    if not found then
      raise exception 'reversal_of_id % not found', NEW.reversal_of_id;
    end if;
    if orig.source = 'REVERSAL' then
      raise exception 'cannot reverse a reversal (id=%)', orig.id;
    end if;
    if exists (select 1 from point_transactions where reversal_of_id = NEW.reversal_of_id) then
      raise exception 'transaction % already has a reversal', NEW.reversal_of_id;
    end if;
    if orig.member_id <> NEW.member_id then
      raise exception 'reversal must match the original member_id';
    end if;
    if orig.dp_amount <> -NEW.dp_amount or orig.marks_amount <> -NEW.marks_amount then
      raise exception 'reversal amounts must be exactly -original (original dp=%, marks=% / reversal dp=%, marks=%)',
        orig.dp_amount, orig.marks_amount, NEW.dp_amount, NEW.marks_amount;
    end if;
  end if;
  return NEW;
end;
$$ language plpgsql;
create trigger trg_pt_reversal before insert on point_transactions for each row execute function fn_pt_reversal_check();

-- 14.4 point_transactions -> cập nhật cache số dư khi dòng POSTED.
-- CẬP NHẬT v3: 1 dòng cập nhật CẢ HAI cột cùng lúc (không branch theo point_type nữa).
create or replace function fn_pt_apply() returns trigger as $$
begin
  if NEW.status = 'POSTED' and (TG_OP = 'INSERT' or OLD.status is distinct from 'POSTED') then
    update members
       set dp_balance = dp_balance + NEW.dp_amount,
           marks_balance = marks_balance + NEW.marks_amount,
           updated_at = now()
     where user_id = NEW.member_id;
  end if;
  return NEW;
end;
$$ language plpgsql;
create trigger trg_pt_apply_ins after insert on point_transactions for each row execute function fn_pt_apply();
create trigger trg_pt_apply_upd after update on point_transactions for each row execute function fn_pt_apply();

-- TINH GIẢN v3: bỏ hẳn fn_redemptions_hold + fn_check_marks_held +
-- members.marks_held. Lý do (khớp đúng heldMarks()/availableMarks() của
-- prototype): Marks "đang giữ" không phải cache cần trigger bảo vệ — nó
-- là 1 SUM() tính trực tiếp từ redemptions WHERE status='PENDING_PICKUP'
-- (xem view v_member_wallet ở BƯỚC 16). Ghi log trạng thái đổi quà vào
-- audit_logs cũng do APPLICATION tự gọi audit() khi confirmDelivery/
-- rejectRedemption, giống Point Engine — không cần trigger DB làm việc đó.
-- Đây là ví dụ thực hành nguyên tắc A13/A14: đo đúng cái cần enforce ở DB,
-- bỏ cái KHÔNG cần (ít trigger hơn = ít chỗ để bug hơn).

-- 14.5 system_configs: mỗi lần đổi giá trị -> tự ghi vào audit_logs
create or replace function fn_system_configs_audit() returns trigger as $$
begin
  if NEW.value is distinct from OLD.value then
    insert into audit_logs (tenant_id, actor_id, actor_type, action, entity_type, entity_id, before_data, after_data)
    values (NEW.tenant_id, NEW.updated_by, case when NEW.updated_by is null then 'SYSTEM' else 'USER' end,
            'CONFIG_CHANGE', 'SYSTEM_CONFIG', NEW.key, OLD.value, NEW.value);
  end if;
  return NEW;
end;
$$ language plpgsql;
create trigger trg_system_configs_audit before update on system_configs for each row execute function fn_system_configs_audit();


-- #####################################################################
-- BƯỚC 15 — ROW-LEVEL SECURITY: lưới an toàn cuối cùng chống rò dữ liệu
-- chéo tenant (nguyên tắc A12).
-- #####################################################################

do $$
declare
  t text;
  tenant_tables text[] := array[
    'branches','users','user_roles','refresh_tokens','password_reset_requests','auth_logs','device_tokens',
    'system_configs','session_types','point_rules',
    'courses','lesson_plans','ranks','rank_required_courses',
    'package_types','members','memberships','renewal_requests',
    'classes','class_enrollments','sessions','checkin_codes','attendances','course_enrollments',
    'point_transactions',
    'rank_trial_requests','member_rank_history',
    'streak_freeze_grants','streak_logs',
    'challenges','challenge_participations',
    'reward_tiers','rewards','redemptions','inventory_movements',
    'notification_templates','notifications','staff_notifications','notification_logs',
    'audit_logs','batch_runs'
  ];
begin
  foreach t in array tenant_tables loop
    execute format('alter table %I enable row level security', t);
    execute format(
      'create policy tenant_isolation on %1$I using (tenant_id = current_setting(''app.current_tenant_id'', true)::uuid) '
      'with check (tenant_id = current_setting(''app.current_tenant_id'', true)::uuid)', t);
  end loop;
end $$;
-- Lưu ý: role DB dùng cho job nền/migration cần BYPASSRLS hoặc chạy dưới quyền chủ bảng.


-- #####################################################################
-- BƯỚC 16 — VIEWS ĐỐI CHIẾU (reconciliation) — nguyên tắc A7
-- #####################################################################

create view v_member_balance_check as
select
  m.user_id as member_id,
  m.tenant_id,
  m.dp_balance                                                       as dp_balance_cache,
  coalesce(sum(pt.dp_amount) filter (where pt.status = 'POSTED'), 0)     as dp_balance_ledger,
  m.marks_balance                                                    as marks_balance_cache,
  coalesce(sum(pt.marks_amount) filter (where pt.status = 'POSTED'), 0)  as marks_balance_ledger
from members m
left join point_transactions pt on pt.member_id = m.user_id
group by m.user_id, m.tenant_id, m.dp_balance, m.marks_balance;

-- CẬP NHẬT v3: marks_held không còn là cột cache — tính trực tiếp từ các
-- đơn đang chờ nhận. can_redeem khớp canRedeem(m) của prototype: CHỈ
-- INACTIVE mới chặn đổi quà (status FROZEN vẫn đổi quà được).
create view v_member_wallet as
select
  m.user_id as member_id,
  m.tenant_id,
  m.status,
  m.marks_balance,
  coalesce(held.held_marks, 0)                         as marks_held,
  m.marks_balance - coalesce(held.held_marks, 0)       as marks_available,
  (m.status <> 'INACTIVE')                              as can_redeem
from members m
left join (
  select member_id, sum(marks_cost) as held_marks
  from redemptions
  where status = 'PENDING_PICKUP'
  group by member_id
) held on held.member_id = m.user_id;

-- CẬP NHẬT v3: view tiện tra "huy hiệu hiện đang có" của 1 học viên — mỗi
-- hạng lấy dòng member_rank_history MỚI NHẤT, chỉ giữ nếu chưa bị revoke.
-- Khớp đúng mảng badges[] hiển thị trên Fighter Record của prototype.
create view v_member_current_badges as
select distinct on (member_id, to_rank_id)
  member_id, tenant_id, to_rank_id as rank_id, reason, earned_via, earned_at
from member_rank_history
order by member_id, to_rank_id, earned_at desc;
-- Lọc is_revoked=false ở lớp gọi (vd: ... from v_member_current_badges b
-- join member_rank_history h on h.member_id=b.member_id and h.to_rank_id=
-- b.rank_id and h.earned_at=b.earned_at where not h.is_revoked) — hoặc đơn
-- giản hơn, thêm is_revoked vào SELECT rồi WHERE not is_revoked ở view cha.


-- #####################################################################
-- BƯỚC 17 — SEED TỐI THIỂU (minh họa: tenant HVP)
-- #####################################################################

insert into roles (code, name, description) values
  ('MEMBER','Học viên', null),
  ('COACH','Coach', null),
  ('HEAD_COACH','Head Coach', null),
  ('RECEPTIONIST','Lễ tân / Nhân viên', null),
  ('ADMIN','Quản trị viên', null),
  ('SUPER_ADMIN','Quản trị hệ thống (platform)', null);

insert into tenants (id, code, name, plan) values
  ('00000000-0000-0000-0000-000000000001', 'hvp', 'HVP Boxing', 'STANDARD');

-- set phiên làm việc để seed (RLS sẽ lọc theo biến này)
set app.current_tenant_id = '00000000-0000-0000-0000-000000000001';

insert into branches (tenant_id, code, name) values
  ('00000000-0000-0000-0000-000000000001', 'Q1', 'HVP Boxing - Quận 1'),
  ('00000000-0000-0000-0000-000000000001', 'Q7', 'HVP Boxing - Quận 7');

insert into session_types (tenant_id, code, name, max_dp, max_dp_upper, counts_daily_limit) values
  ('00000000-0000-0000-0000-000000000001','GROUP','Group Class',60,null,true),
  ('00000000-0000-0000-0000-000000000001','PT','PT 1:1',65,null,true),
  ('00000000-0000-0000-0000-000000000001','ACADEMY','Academy Lesson',70,null,true),
  ('00000000-0000-0000-0000-000000000001','WORKSHOP','Workshop',80,100,false),
  ('00000000-0000-0000-0000-000000000001','SPARRING','Sparring Day',100,150,false);

-- 7 hạng theo DP V2 (mục 2, HVP_DP_V2_Lo_Trinh_Khoa_3_Thang.docx)
insert into ranks (tenant_id, rank_order, code, name_en, name_vi, dp_threshold, min_active_months, requires_trial, approval_role) values
  ('00000000-0000-0000-0000-000000000001',1,'THE_UNKNOWN','THE UNKNOWN','Kẻ vô danh',0,0,false,null),
  ('00000000-0000-0000-0000-000000000001',2,'THE_INITIATED','THE INITIATED','Người nhập cuộc',500,1,false,null),
  ('00000000-0000-0000-0000-000000000001',3,'THE_DISCIPLINED','THE DISCIPLINED','Người có kỷ luật',2500,3,true,null),
  ('00000000-0000-0000-0000-000000000001',4,'THE_FORGED','THE FORGED','Người được tôi luyện',5000,6,true,null),
  ('00000000-0000-0000-0000-000000000001',5,'THE_FIGHTER','THE FIGHTER','Võ sĩ',9000,12,true,null),
  ('00000000-0000-0000-0000-000000000001',6,'THE_UNBROKEN','THE UNBROKEN','Kẻ không thể khuất phục',15000,18,true,'HEAD_COACH'),
  ('00000000-0000-0000-0000-000000000001',7,'THE_LEGACY','THE LEGACY','Người để lại di sản',24000,24,true,'ADMIN');

insert into reward_tiers (tenant_id, code, name, min_marks, max_marks, sort_order) values
  ('00000000-0000-0000-0000-000000000001','FIELD_SUPPLIES','FIELD SUPPLIES',50,100,1),
  ('00000000-0000-0000-0000-000000000001','TRAINING_GEAR','TRAINING GEAR',200,400,2),
  ('00000000-0000-0000-0000-000000000001','FIGHTER_EQUIPMENT','FIGHTER EQUIPMENT',500,800,3),
  ('00000000-0000-0000-0000-000000000001','BLACK_VAULT','THE BLACK VAULT',1000,null,4);

-- Ghi chú: seed đầy đủ 36 lesson_plans (TÊN GIÁO ÁN.docx), point_rules chi tiết
-- theo mục 3-6 DP V2, và package_types (5 gói của KH) nên làm ở file
-- seed riêng (hvp_seed_full.sql), tránh làm phình file schema này.

-- =====================================================================
-- PHÂN CHIA: DB ENFORCE vs BACKEND ENFORCE (nguyên tắc A10)
-- =====================================================================
-- DB (trigger/constraint) lo:
--   - Idempotency (UNIQUE key, khi có)          - Append-only cho log/ledger
--   - Balance cache = SUM(ledger)                 - Reversal hợp lệ (cả 2 loại điểm)
--   - Không âm kho (stock >= 0)                   - Không trùng gói ACTIVE/SCHEDULED
--   - Không trùng hoàn thành/ngày                 - Không trùng Rank Trial mở
--
-- Backend (Point Engine / job nền) lo:
--   - Tính DP/Marks theo point_rules + session_type (công thức, tổng hợp)
--   - Áp monthly cap: SUM(dp_amount/marks_amount) FROM point_transactions
--     WHERE member_id=... AND occurred_at trong tháng AND source IN (...)
--   - Xét điều kiện lên hạng (DP + time-gate + course-gate + trial-gate),
--     RỚT HẠNG khi DP tụt dưới ngưỡng, KHÔI PHỤC khi đủ DP lại (so với peak_rank_id)
--   - Tính streak cuối tuần, cấp/dùng Streak Freeze
--   - Job hết hạn gói / inactive 12 tháng / phát hiện comeback (batch_runs)
--   - Marks "đang giữ" = SUM(redemptions.marks_cost WHERE PENDING_PICKUP)
--     (view v_member_wallet) — không trigger nào cache lại số này
--   - Gộp tài khoản trùng (mergeMembers): UPDATE member_id trên
--     point_transactions/attendances/redemptions/rank_trial_requests/
--     challenge_participations sang tài khoản giữ lại, rồi set
--     duplicate_of_member_id trên tài khoản bị gộp
--   - Kiểm tra phạm vi coach, cửa sổ check-in, vị trí geofence
--   - Render & gửi notification, retry/backoff
-- =====================================================================
