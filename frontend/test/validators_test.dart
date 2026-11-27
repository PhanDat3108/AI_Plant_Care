import 'package:flutter_test/flutter_test.dart';
import 'package:ai_plant_care/core/validators.dart';

void main() {
  test('Email rejects missing and whitespace-only input', () {
    expect(Validators.email(null), isNotNull);
    expect(Validators.email('   '), isNotNull);
  });
  test('Email rejects malformed addresses before calling API', () {
    for (final email in ['a', 'a@', 'a@b', 'a b@example.com']) {
      expect(Validators.email(email), isNotNull, reason: email);
    }
  });
  test('Email accepts surrounding whitespace', () {
    expect(Validators.email(' user@example.com '), isNull);
  });
  test('Login accepts an existing short password but rejects empty', () {
    expect(Validators.requiredPassword('old123'), isNull);
    expect(Validators.requiredPassword(''), isNotNull);
  });
  test('Registration enforces minimum password boundary', () {
    expect(Validators.newPassword('1234567'), isNotNull);
    expect(Validators.newPassword('12345678'), isNull);
  });
  test('Registration enforces maximum password boundary', () {
    expect(Validators.newPassword('a' * 256), isNull);
    expect(Validators.newPassword('a' * 257), isNotNull);
  });
  test('Name must contain non-whitespace characters', () {
    expect(Validators.fullName('  '), isNotNull);
    expect(Validators.fullName(' Đạt Phan '), isNull);
  });
  test('Confirmation reads the latest password after editing', () {
    var password = 'original123';
    final confirm = Validators.confirmPassword(() => password);
    expect(confirm(password), isNull);
    password = 'changed123';
    expect(confirm('original123'), isNotNull);
    expect(confirm(password), isNull);
    expect(confirm(null), isNotNull);
  });
}
