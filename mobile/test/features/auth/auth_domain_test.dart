import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/features/auth/domain/auth_user.dart';
import 'package:hvp_forging/features/auth/domain/auth_validators.dart';

void main() {
  group('AuthValidators', () {
    test('identifier accepts an email or a phone number', () {
      expect(AuthValidators.identifier('a@b.vn'), isNull);
      expect(AuthValidators.identifier('0912 345 678'), isNull);
      expect(AuthValidators.identifier('+84912345678'), isNull);
      expect(AuthValidators.identifier(''), isNotNull);
      expect(AuthValidators.identifier('abc@'), isNotNull);
      expect(AuthValidators.identifier('12345'), isNotNull);
    });

    test('newPassword needs 6+ characters with letters and digits', () {
      expect(AuthValidators.newPassword('abc123'), isNull);
      expect(AuthValidators.newPassword('abc12'), isNotNull);
      expect(AuthValidators.newPassword('abcdefg'), isNotNull);
      expect(AuthValidators.newPassword('1234567'), isNotNull);
      expect(AuthValidators.newPassword(''), isNotNull);
    });

    test('confirmPassword must match', () {
      expect(AuthValidators.confirmPassword('abc123', 'abc123'), isNull);
      expect(AuthValidators.confirmPassword('abc123', 'abc124'), isNotNull);
      expect(AuthValidators.confirmPassword('abc123', ''), isNotNull);
    });

    test('pin is exactly six digits', () {
      expect(AuthValidators.pin('123456'), isNull);
      expect(AuthValidators.pin('12345'), isNotNull);
      expect(AuthValidators.pin('12a456'), isNotNull);
    });

    test('email is required and must be well formed', () {
      expect(AuthValidators.email(''), 'Vui lòng nhập email.');
      expect(AuthValidators.email('x@y.vn'), isNull);
      expect(AuthValidators.email('x@'), 'Email chưa đúng định dạng.');
    });

    test('fullName and phone', () {
      expect(AuthValidators.fullName('An'), isNull);
      expect(AuthValidators.fullName('A'), isNotNull);
      expect(AuthValidators.phone('0912345678'), isNull);
      expect(AuthValidators.phone('09123'), isNotNull);
    });
  });

  group('AuthUser', () {
    test('parses the /auth/me payload', () {
      final user = AuthUser.fromJson(<String, dynamic>{
        'id': 'u1',
        'fullName': 'Học Viên Mẫu',
        'email': null,
        'phone': '0912345678',
        'avatarUrl': null,
        'roles': <String>['MEMBER'],
        'appRole': 'student',
        'branchId': 'b1',
      });
      expect(user.id, 'u1');
      expect(user.appRole, AppRole.student);
      expect(user.email, isNull);
      expect(user.roles, <String>['MEMBER']);
      expect(user.branchId, 'b1');
    });

    test('AppRole.parse maps the four app roles and defaults to student', () {
      expect(AppRole.parse('admin'), AppRole.admin);
      expect(AppRole.parse('coach'), AppRole.coach);
      expect(AppRole.parse('reception'), AppRole.reception);
      expect(AppRole.parse('student'), AppRole.student);
      expect(AppRole.parse('something'), AppRole.student);
      expect(AppRole.parse(null), AppRole.student);
      expect(AppRole.coach.basePath, '/coach');
    });
  });
}
