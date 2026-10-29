/** Notification event types stored in notifications.event_type / staff_notifications.event_type. */
export const NotificationEvent = {
  // Learner-facing
  SESSION_COMPLETED: 'SESSION_COMPLETED',
  NEAR_RANK: 'NEAR_RANK',
  RANK_EARNED: 'RANK_EARNED',
  RANK_LOST: 'RANK_LOST',
  STREAK_WARNING: 'STREAK_WARNING',
  STREAK_LOST: 'STREAK_LOST',
  STREAK: 'STREAK',
  INACTIVE_7D: 'INACTIVE_7D',
  INACTIVE_WARNING: 'INACTIVE_WARNING',
  ACCOUNT_INACTIVE: 'ACCOUNT_INACTIVE',
  ARMORY_READY: 'ARMORY_READY',
  ARMORY_CREATED: 'ARMORY_CREATED',
  ARMORY_DELIVERED: 'ARMORY_DELIVERED',
  ARMORY_REJECTED: 'ARMORY_REJECTED',
  MEMBERSHIP_EXPIRE: 'MEMBERSHIP_EXPIRE',
  MEMBERSHIP_STATUS: 'MEMBERSHIP_STATUS',
  COMEBACK_BONUS: 'COMEBACK_BONUS',
  RENEWAL_SENT: 'RENEWAL_SENT',
  RENEWAL_COMPLETED: 'RENEWAL_COMPLETED',
  RENEWAL_CANCELLED: 'RENEWAL_CANCELLED',
  BOOK_COMPLETED: 'BOOK_COMPLETED',
  CHALLENGE: 'CHALLENGE',
  EXAM: 'EXAM',
  SESSION_CANCELLED: 'SESSION_CANCELLED',
  ABSENT: 'ABSENT',
  BELOW_THRESHOLD: 'BELOW_THRESHOLD',
  ACADEMY_FAILED: 'ACADEMY_FAILED',
  DP_ADJUSTED: 'DP_ADJUSTED',
  RANK_TRIAL_REQUESTED: 'RANK_TRIAL_REQUESTED',
  RANK_TRIAL_FAILED: 'RANK_TRIAL_FAILED',
  WELCOME: 'WELCOME',
  BROADCAST: 'BROADCAST',
  // Staff-facing
  RENEWAL_REQUEST: 'RENEWAL_REQUEST',
  RANK_TRIAL_REQUEST: 'RANK_TRIAL_REQUEST',
  RANK_TRIAL_ADMIN: 'RANK_TRIAL_ADMIN',
  CHALLENGE_EVIDENCE: 'CHALLENGE_EVIDENCE',
  ARMORY_ORDER: 'ARMORY_ORDER',
  RANK_UP: 'RANK_UP',
  RANK_DOWN: 'RANK_DOWN',
} as const;

export type NotificationEventType = (typeof NotificationEvent)[keyof typeof NotificationEvent];

export interface TemplateDefinition {
  event: string;
  name: string;
  timing: string;
  title: string;
  body: string;
}

/**
 * Default (Vietnamese) copy for the automatic notifications of PRD section 14, taken from the
 * customer-approved prototype. Tenants can override title/body/enabled in
 * `notification_templates`; placeholders use {name}.
 */
export const DEFAULT_TEMPLATES: TemplateDefinition[] = [
  {
    event: NotificationEvent.SESSION_COMPLETED,
    name: 'WORK DONE',
    timing: 'Ngay sau khi coach xác nhận',
    title: 'WORK DONE',
    body: 'WORK DONE. Buổi tập đã được xác nhận - {dp} DP vừa được cộng vào tài khoản của bạn.',
  },
  {
    event: NotificationEvent.NEAR_RANK,
    name: '{x} DP REMAIN',
    timing: 'Khi còn ≤120 DP tới hạng kế',
    title: '{remain} DP REMAIN',
    body: '{remain} DP REMAIN. Bạn chỉ còn {remain} DP nữa để chạm tới {nextRank}.',
  },
  {
    event: NotificationEvent.RANK_EARNED,
    name: 'RANK EARNED',
    timing: 'Ngay khi hệ thống mở hạng mới',
    title: 'RANK EARNED',
    body: 'RANK EARNED: {rank}. Không ai trao nó cho bạn. Bạn tự tạo ra nó.',
  },
  {
    event: NotificationEvent.STREAK_WARNING,
    name: 'ĐỪNG ĐỂ CHUỖI DỪNG LẠI',
    timing: 'Thứ Bảy nếu chưa đủ buổi tuần',
    title: 'ĐỪNG ĐỂ CHUỖI DỪNG LẠI',
    body: 'Bạn mới có {done}/{target} buổi tuần này - thêm {missing} buổi để giữ streak {streak} tuần.',
  },
  {
    event: NotificationEvent.STREAK_LOST,
    name: 'THE STREAK ENDS',
    timing: 'Sau khi chốt tuần không đạt & hết Freeze',
    title: 'THE STREAK ENDS',
    body: 'THE STREAK ENDS. Chuỗi {streak} tuần đã dừng lại. Bắt đầu lại từ hôm nay.',
  },
  {
    event: NotificationEvent.INACTIVE_7D,
    name: "YOU'VE BEEN GONE FOR 7 DAYS",
    timing: 'Sau 7 ngày không check-in',
    title: "YOU'VE BEEN GONE FOR 7 DAYS",
    body: "YOU'VE BEEN GONE FOR 7 DAYS. Sàn đấu vẫn đang chờ bạn.",
  },
  {
    event: NotificationEvent.ARMORY_READY,
    name: 'YOUR MARKS ARE WAITING',
    timing: 'Khi đơn đổi quà sẵn sàng nhận',
    title: 'YOUR MARKS ARE WAITING',
    body: 'YOUR MARKS ARE WAITING. Phần quà của bạn đã sẵn sàng tại quầy {branch}.',
  },
  {
    event: NotificationEvent.MEMBERSHIP_EXPIRE,
    name: 'EARNED. NOT GIVEN.',
    timing: '7 ngày trước khi gói hết hạn',
    title: 'EARNED. NOT GIVEN.',
    body: 'EARNED. NOT GIVEN. Gói tập của bạn sắp hết hạn - {rank} không tự đến, đừng để nó dừng lại.',
  },
  {
    event: NotificationEvent.COMEBACK_BONUS,
    name: 'WELCOME BACK',
    timing: 'Tự động - khi quay lại sau ≥14 ngày vắng',
    title: 'WELCOME BACK',
    body: 'WELCOME BACK. Sau {days} ngày vắng, bạn nhận +{dp} DP.',
  },
];

export const TEMPLATE_BY_EVENT: ReadonlyMap<string, TemplateDefinition> = new Map(
  DEFAULT_TEMPLATES.map((t) => [t.event, t]),
);

export function fillTemplate(text: string, vars: Record<string, string | number>): string {
  return text.replace(/\{(\w+)\}/g, (_, key: string) => (key in vars ? String(vars[key]) : `{${key}}`));
}
