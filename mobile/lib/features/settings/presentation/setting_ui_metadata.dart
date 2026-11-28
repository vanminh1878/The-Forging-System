import '../domain/admin_setting.dart';

class SettingUiMetadata {
  const SettingUiMetadata(
      {required this.title,
      required this.description,
      this.unit,
      this.min,
      this.max,
      this.section});
  final String title;
  final String description;
  final String? unit;
  final int? min;
  final int? max;
  final String? section;
}

const _m = <String, SettingUiMetadata>{
  'points.dp_monthly_cap': SettingUiMetadata(
      title: 'Hạn mức DP mỗi tháng',
      description: 'DP tối đa từ các hoạt động thường trong một tháng.',
      unit: 'DP',
      min: 0,
      section: 'Hạn mức'),
  'points.marks_monthly_cap': SettingUiMetadata(
      title: 'Hạn mức Marks mỗi tháng',
      description: 'Marks tối đa từ các hoạt động thường trong một tháng.',
      unit: 'Marks',
      min: 0,
      section: 'Hạn mức'),
  'points.completion_threshold': SettingUiMetadata(
      title: 'Ngưỡng hoàn thành buổi tập',
      description: 'Tỷ lệ hoàn thành tối thiểu để buổi tập được ghi nhận.',
      unit: '%',
      min: 1,
      max: 100,
      section: 'Buổi tập'),
  'points.marks_per_dp_divisor': SettingUiMetadata(
      title: 'Tỷ lệ quy đổi Marks',
      description: 'Số DP dùng để quy đổi ra một Marks.',
      unit: 'DP / Marks',
      min: 1,
      section: 'Buổi tập'),
  'points.attitude_dp': SettingUiMetadata(
      title: 'Thưởng DP thái độ',
      description: 'DP thưởng cho thái độ tốt trong một buổi tập.',
      unit: 'DP',
      min: 0,
      section: 'Thưởng'),
  'points.attitude_marks': SettingUiMetadata(
      title: 'Thưởng Marks thái độ',
      description: 'Marks thưởng cho thái độ tốt trong một buổi tập.',
      unit: 'Marks',
      min: 0,
      section: 'Thưởng'),
  'points.academy_pass_dp': SettingUiMetadata(
      title: 'DP đạt bài Academy',
      description: 'DP khi học viên hoàn thành Academy hoặc kiểm tra.',
      unit: 'DP',
      min: 0,
      section: 'Thưởng'),
  'points.academy_pass_marks': SettingUiMetadata(
      title: 'Marks đạt bài Academy',
      description: 'Marks khi học viên hoàn thành Academy hoặc kiểm tra.',
      unit: 'Marks',
      min: 0,
      section: 'Thưởng'),
  'points.coach_attitude_limit_per_day': SettingUiMetadata(
      title: 'Giới hạn thưởng thái độ mỗi ngày',
      description: 'Số lượt thưởng thái độ tối đa mỗi HLV được cấp trong ngày.',
      unit: 'lượt',
      min: 0,
      section: 'Giới hạn HLV'),
  'points.coach_attitude_limit_per_month': SettingUiMetadata(
      title: 'Giới hạn thưởng thái độ mỗi tháng',
      description:
          'Số lượt thưởng thái độ tối đa mỗi HLV được cấp trong tháng.',
      unit: 'lượt',
      min: 0,
      section: 'Giới hạn HLV'),
  'points.rank_trial_bonus_dp': SettingUiMetadata(
      title: 'DP đạt Rank Trial',
      description: 'DP thưởng khi học viên vượt qua Rank Trial.',
      unit: 'DP',
      min: 0,
      section: 'Thưởng'),
  'points.rank_trial_bonus_marks': SettingUiMetadata(
      title: 'Marks đạt Rank Trial',
      description: 'Marks thưởng khi học viên vượt qua Rank Trial.',
      unit: 'Marks',
      min: 0,
      section: 'Thưởng'),
  'points.early_renewal_marks': SettingUiMetadata(
      title: 'Marks gia hạn sớm',
      description: 'Marks thưởng một lần cho mỗi lần gia hạn sớm.',
      unit: 'Marks',
      min: 0,
      section: 'Thưởng'),
  'points.comeback_dp': SettingUiMetadata(
      title: 'DP quay lại tập',
      description: 'DP thưởng khi học viên quay lại sau thời gian vắng mặt.',
      unit: 'DP',
      min: 0,
      section: 'Thưởng'),
  'points.comeback_gap_days': SettingUiMetadata(
      title: 'Số ngày vắng để nhận thưởng quay lại',
      description: 'Thời gian vắng tối thiểu để kích hoạt thưởng quay lại.',
      unit: 'ngày',
      min: 1,
      section: 'Thưởng'),
  'streak.weekly_min_sessions': SettingUiMetadata(
      title: 'Số buổi tối thiểu mỗi tuần',
      description: 'Số buổi hợp lệ cần có để duy trì chuỗi tập.',
      unit: 'buổi',
      min: 1,
      max: 14),
  'streak.freeze_every_weeks': SettingUiMetadata(
      title: 'Chu kỳ nhận Streak Freeze',
      description: 'Cứ bao nhiêu tuần chuỗi tập thì nhận một lượt bảo vệ.',
      unit: 'tuần',
      min: 1),
  'streak.max_freeze_per_month': SettingUiMetadata(
      title: 'Giới hạn Streak Freeze mỗi tháng',
      description: 'Số lượt bảo vệ chuỗi tập tối đa dùng trong một tháng.',
      unit: 'lượt',
      min: 0),
  'streak.milestones': SettingUiMetadata(
      title: 'Mốc thưởng chuỗi tập',
      description: 'DP thưởng tại từng mốc tuần chuỗi tập.'),
  'checkin.code_ttl_seconds': SettingUiMetadata(
      title: 'Thời hạn mã check-in',
      description:
          'Thời gian hiệu lực của mã check-in luân phiên tại chi nhánh.',
      unit: 'giây',
      min: 10),
  'checkin.opens_before_minutes': SettingUiMetadata(
      title: 'Mở check-in trước buổi tập',
      description: 'Học viên được check-in trước giờ bắt đầu buổi tập.',
      unit: 'phút',
      min: 0),
  'checkin.closes_after_minutes': SettingUiMetadata(
      title: 'Đóng check-in sau buổi tập',
      description: 'Check-in vẫn khả dụng sau giờ bắt đầu buổi tập.',
      unit: 'phút',
      min: 0),
  'checkin.geofence_enabled': SettingUiMetadata(
      title: 'Yêu cầu vị trí chi nhánh',
      description: 'Từ chối check-in khi học viên ở ngoài khu vực chi nhánh.'),
};

SettingUiMetadata settingUi(AdminSetting setting) =>
    _m[setting.key] ??
    SettingUiMetadata(title: setting.key, description: setting.description);

const groupUi = <String, ({String title, String description, String? warning})>{
  'POINTS': (
    title: 'Điểm & hạng',
    description: 'Thiết lập hạn mức, quy đổi và phần thưởng DP/Marks.',
    warning: 'Các thay đổi chỉ áp dụng cho giao dịch phát sinh sau khi lưu.'
  ),
  'STREAK': (
    title: 'Chuỗi tập',
    description: 'Thiết lập điều kiện duy trì, bảo vệ và mốc thưởng chuỗi tập.',
    warning: null
  ),
  'CHECKIN': (
    title: 'Check-in',
    description: 'Thiết lập mã QR, khung thời gian và yêu cầu vị trí check-in.',
    warning: 'Thay đổi thời hạn mã sẽ ảnh hưởng ngay tới các mã đang phát hành.'
  ),
};
