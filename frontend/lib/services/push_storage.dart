import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class PushStorage {
  static const _store = FlutterSecureStorage();

  static Future<String> installationId() async {
    final saved = await _store.read(key: 'push_installation_id');
    if (saved != null) return saved;
    final id = const Uuid().v4();
    await _store.write(key: 'push_installation_id', value: id);
    return id;
  }

  static Future<String?> deviceId() => _store.read(key: 'push_device_id');
  static Future<void> save(String id) =>
      _store.write(key: 'push_device_id', value: id);
  static Future<void> clearDevice() => _store.delete(key: 'push_device_id');
}
