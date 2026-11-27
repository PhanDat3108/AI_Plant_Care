import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ai_plant_care/services/token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'Login persists both tokens and refresh replaces the old pair',
    () async {
      await TokenStorage.save(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
      );
      await TokenStorage.save(
        accessToken: 'new-access',
        refreshToken: 'new-refresh',
      );
      expect(await TokenStorage.readAccess(), 'new-access');
      expect(await TokenStorage.readRefresh(), 'new-refresh');
    },
  );
  test('Logout removes both credentials', () async {
    await TokenStorage.save(accessToken: 'access', refreshToken: 'refresh');
    await TokenStorage.clear();
    expect(await TokenStorage.readAccess(), isNull);
    expect(await TokenStorage.readRefresh(), isNull);
  });
}
