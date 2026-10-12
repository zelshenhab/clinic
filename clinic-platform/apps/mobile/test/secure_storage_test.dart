import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:clinic_mobile/core/security/secure_session_storage.dart';

class MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  test(
    'session persistence uses secure storage and removes it on signout',
    () async {
      final storage = MockStorage();
      when(
        () => storage.write(
          key: SecureSessionStorage.key,
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => storage.read(key: SecureSessionStorage.key),
      ).thenAnswer((_) async => 'session-json');
      when(
        () => storage.delete(key: SecureSessionStorage.key),
      ).thenAnswer((_) async {});
      final adapter = SecureSessionStorage(storage);
      await adapter.persistSession('session-json');
      expect(await adapter.accessToken(), 'session-json');
      await adapter.removePersistedSession();
      verify(
        () =>
            storage.write(key: SecureSessionStorage.key, value: 'session-json'),
      ).called(1);
      verify(() => storage.delete(key: SecureSessionStorage.key)).called(1);
    },
  );
}
