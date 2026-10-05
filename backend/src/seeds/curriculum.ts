/**
 * Reference curriculum: five courses (khóa) - course 5 keeps growing over time -
 * each a 12-week programme of 3 sessions per week. Weekly themes come from the
 * customer-approved prototype; admins can edit titles/content afterwards.
 */
export interface CourseSeed {
  code: string;
  name: string;
  goal: string;
  weeks: string[];
}

export const COURSES: CourseSeed[] = [
  {
    code: 'FOUNDATION',
    name: 'FOUNDATION',
    goal: 'Nền tảng bộ pháp, tư thế thủ, jab–cross–hook.',
    weeks: ['Tư thế & bộ pháp cơ bản', 'Jab & cross', 'Hook & uppercut', 'Phòng thủ: block & parry', 'Slip & roll', 'Combo 2–3 đòn', 'Đấm bao: nhịp & lực', 'Target mitt cùng coach', 'Phối hợp công – thủ', 'Thể lực chuyên biệt', 'Đối kháng nhẹ có kiểm soát', 'Ôn tập & kiểm tra cuối khóa'],
  },
  {
    code: 'THE_STANDARD',
    name: 'THE STANDARD',
    goal: 'Chuẩn hoá kỹ thuật, nhịp thở, combo 4–6 đòn.',
    weeks: ['Chuẩn hoá tư thế', 'Combo 4 đòn', 'Bộ pháp nâng cao', 'Phản đòn', 'Nhịp thở & tốc độ', 'Mitt kỹ thuật', 'Đòn thân', 'Kiểm soát cự ly', 'Sparring kỹ thuật 1', 'Sparring kỹ thuật 2', 'Sức bền theo hiệp', 'Ôn tập & kiểm tra'],
  },
  {
    code: 'THE_PERSON',
    name: 'THE PERSON',
    goal: 'Tâm lý thi đấu, kỷ luật tập luyện, kiểm soát cảm xúc.',
    weeks: ['Kỷ luật tập luyện', 'Kiểm soát cảm xúc', 'Tập trung dưới áp lực', 'Shadow có mục tiêu', 'Nhịp độ cá nhân', 'Giao tiếp trong đối kháng', 'Chịu áp lực thể lực', 'Đọc đối thủ cơ bản', 'Đối kháng kiểm soát cảm xúc', 'Tự đánh giá & phản hồi', 'Xây thói quen dài hạn', 'Ôn tập & kiểm tra'],
  },
  {
    code: 'THE_FIGHTER',
    name: 'THE FIGHTER',
    goal: 'Đối kháng có kiểm soát, chiến thuật thi đấu.',
    weeks: ['Chiến thuật theo đối thủ', 'Đọc nhịp', 'Đòn phản công', 'Kiểm soát vòng đấu', 'Sparring chiến thuật 1', 'Phân tích video', 'Sparring chiến thuật 2', 'Quản lý thể lực theo hiệp', 'Xử lý tình huống áp lực', 'Mô phỏng thi đấu', 'Hồi phục & phòng chấn thương', 'Ôn tập & kiểm tra'],
  },
  {
    code: 'THE_EXAMPLE',
    name: 'THE EXAMPLE',
    goal: 'Hoàn thiện phong cách cá nhân, sẵn sàng dẫn dắt người mới.',
    weeks: ['Dẫn dắt người mới', 'Truyền đạt kỹ thuật', 'Phong cách cá nhân', 'Hướng dẫn kèm cặp', 'Tổ chức buổi tập nhóm', 'Trình diễn kỹ thuật', 'Phản hồi xây dựng', 'Đạo đức võ đường', 'Chuẩn bị thi đấu cho người khác', 'Cố vấn dài hạn', 'Trình diễn tổng hợp', 'Ôn tập & đánh giá'],
  },
];

export interface LessonSeed {
  lessonNo: number;
  weekNo: number;
  title: string;
  subtitle: string;
  objectives: string;
  drills: string[];
  isAssessment: boolean;
  isGraduation: boolean;
}

/** 36 lessons per course: lesson k belongs to week ceil(k/3). */
export function buildLessons(course: CourseSeed): LessonSeed[] {
  const lessons: LessonSeed[] = [];
  for (let k = 1; k <= course.weeks.length * 3; k++) {
    const week = Math.ceil(k / 3);
    const part = ((k - 1) % 3) + 1;
    const theme = course.weeks[week - 1];
    const [focus, ending] = (
      [
        ['Học kỹ thuật chủ đề', 'Làm quen & chuẩn hoá động tác'],
        ['Ứng dụng trên bao / mitt', 'Luyện nhịp và độ chính xác'],
        ['Đối kháng nhẹ & tổng kết tuần', 'Vận dụng và nhận phản hồi từ Coach'],
      ] as const
    )[part - 1];
    const last = k === course.weeks.length * 3;
    lessons.push({
      lessonNo: k,
      weekNo: week,
      title: `${course.name} — Tuần ${week}, buổi ${part}`,
      subtitle: `Tuần ${week} · ${theme}`,
      objectives: `Chủ đề tuần ${week}: ${theme}. ${ending}.`,
      drills: [
        'Khởi động & giãn cơ (10p)',
        `${focus}: ${theme} (3 hiệp)`,
        'Bài tập kết hợp theo cặp (4 hiệp)',
        part === 3 ? 'Đối kháng nhẹ có kiểm soát (3 hiệp)' : 'Bao cát / mitt theo chủ đề (4 hiệp)',
        'Hạ nhiệt & nhận xét của Coach (10p)',
      ],
      isAssessment: last,
      isGraduation: last,
    });
  }
  return lessons;
}

export interface PackageSeed {
  code: string;
  name: string;
  courseCode?: string;
  durationDays: number;
  totalSessions: number | null;
  sessionsPerWeek: number | null;
  priceVnd: number;
  isTrial: boolean;
  sortOrder: number;
}

/** Packages (gói tập). One course (khóa) is sold through its own package. */
export const PACKAGES: PackageSeed[] = [
  ...COURSES.map<PackageSeed>((c, i) => ({
    code: `BOOK_${i + 1}`,
    name: `BOOK ${['I', 'II', 'III', 'IV', 'V'][i]} — ${c.name}`,
    courseCode: c.code,
    durationDays: 84,
    totalSessions: 36,
    sessionsPerWeek: 3,
    priceVnd: [8_900_000, 9_800_000, 10_800_000, 11_900_000, 13_100_000][i],
    isTrial: false,
    sortOrder: i + 1,
  })),
  { code: 'HSSV', name: 'HSSV — Học sinh, Sinh viên', durationDays: 30, totalSessions: null, sessionsPerWeek: 3, priceVnd: 800_000, isTrial: true, sortOrder: 10 },
  { code: 'GT_1M', name: 'Group Training — 1 tháng', durationDays: 30, totalSessions: null, sessionsPerWeek: 3, priceVnd: 1_500_000, isTrial: true, sortOrder: 11 },
  { code: 'GT_3M', name: 'Group Training — 3 tháng', durationDays: 90, totalSessions: null, sessionsPerWeek: 3, priceVnd: 3_900_000, isTrial: false, sortOrder: 12 },
  { code: 'GT_6M', name: 'Group Training — 6 tháng', durationDays: 180, totalSessions: null, sessionsPerWeek: null, priceVnd: 6_900_000, isTrial: false, sortOrder: 13 },
  { code: 'GT_12M', name: 'Group Training — 12 tháng', durationDays: 360, totalSessions: null, sessionsPerWeek: null, priceVnd: 12_000_000, isTrial: false, sortOrder: 14 },
];

/**
 * Course gate per rank (rank order -> course codes). Rank III needs the first
 * 3-month course (DP V2); later gates follow the approved prototype. Editable
 * data, not code: change rows in rank_required_courses to retune.
 */
export const RANK_COURSE_GATES: Record<number, string[]> = {
  3: ['FOUNDATION'],
  4: ['THE_STANDARD'],
  5: ['THE_PERSON'],
  6: ['THE_FIGHTER'],
  7: ['THE_FIGHTER', 'THE_EXAMPLE'],
};
