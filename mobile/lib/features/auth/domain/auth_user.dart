import '../../../core/utils/json_utils.dart';

/// Which of the four experiences the signed-in user lands in.
enum AppRole {
  student,
  coach,
  reception,
  admin;

  static AppRole parse(String? value) {
    switch (value) {
      case 'admin':
        return AppRole.admin;
      case 'coach':
        return AppRole.coach;
      case 'reception':
        return AppRole.reception;
      default:
        return AppRole.student;
    }
  }

  /// Base path of the role shell.
  String get basePath => '/$name';
}

/// Authenticated principal returned by `/auth/login`, `/auth/register`, `/auth/me`.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.appRole,
    this.email,
    this.phone,
    this.avatarUrl,
    this.roles = const <String>[],
    this.branchId,
  });

  factory AuthUser.fromJson(JsonMap j) => AuthUser(
        id: str(j, 'id'),
        fullName: str(j, 'fullName'),
        email: strOrNull(j, 'email'),
        phone: strOrNull(j, 'phone'),
        avatarUrl: strOrNull(j, 'avatarUrl'),
        roles: stringList(j['roles']),
        appRole: AppRole.parse(strOrNull(j, 'appRole')),
        branchId: strOrNull(j, 'branchId'),
      );

  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final List<String> roles;
  final AppRole appRole;
  final String? branchId;

  AuthUser copyWith({String? fullName, String? avatarUrl, String? email, String? phone}) => AuthUser(
        id: id,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        roles: roles,
        appRole: appRole,
        branchId: branchId,
      );
}
