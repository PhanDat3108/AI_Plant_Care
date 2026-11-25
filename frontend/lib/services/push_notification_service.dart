import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'dio_client.dart';
import 'push_storage.dart';
import 'token_storage.dart';

class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();
  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final received = StreamController<String>.broadcast();
  final opened = StreamController<void>.broadcast();
  bool _active = false;
  bool _listening = false;
  bool _pendingOpen = false;
  final _receivedIds = <String>{};
  final _openedIds = <String>{};
  Future<void> _tail = Future.value();

  bool takeOpen() {
    final pending = _pendingOpen;
    _pendingOpen = false;
    return pending;
  }

  bool _accept(RemoteMessage message, Set<String> seen) {
    final id = message.data['notification_id'];
    if (!_active ||
        message.data['screen'] != 'notifications' ||
        id is! String ||
        seen.contains(id)) {
      return false;
    }
    if (seen.length >= 100) seen.remove(seen.first);
    seen.add(id);
    return true;
  }

  void _onOpen(RemoteMessage message) {
    if (!_accept(message, _openedIds)) return;
    _pendingOpen = true;
    opened.add(null);
  }

  Future<void> _queue(Future<void> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.catchError((Object _) {});
    return result;
  }

  void beginSession() {
    if (!_supported) return;
    _active = true;
    sync(requestPermission: true);
  }

  void sync({bool requestPermission = false}) {
    if (!_active) return;
    unawaited(
      _queue(() async {
        if (!_active || await TokenStorage.readAccess() == null) return;
        await Firebase.initializeApp();
        final messaging = FirebaseMessaging.instance;
        if (!_listening) {
          FirebaseMessaging.onMessage.listen((message) {
            if (_accept(message, _receivedIds)) {
              received.add(
                message.notification?.title ?? 'Có lời nhắc chăm sóc mới',
              );
            }
          });
          FirebaseMessaging.onMessageOpenedApp.listen(_onOpen);
          // Our API currently targets FCM registration tokens, not installation IDs.
          // ignore: deprecated_member_use
          messaging.onTokenRefresh.listen(
            (_) => sync(),
            onError: (Object _) {},
          );
          _listening = true;
          final initial = await messaging.getInitialMessage();
          if (initial != null) _onOpen(initial);
        }
        final settings = requestPermission
            ? await messaging.requestPermission()
            : await messaging.getNotificationSettings();
        if (!_active) return;
        if (settings.authorizationStatus != AuthorizationStatus.authorized) {
          await _removeBinding();
          return;
        }
        // This matches the backend Firebase Admin Message.token contract.
        // ignore: deprecated_member_use
        final token = await messaging.getToken();
        if (!_active || token == null) return;
        final data = await DioClient.instance.post(
          '/notifications/devices',
          body: {
            'installation_id': await PushStorage.installationId(),
            'token': token,
            'platform': 'android',
          },
        );
        if (data is! Map || data['id'] is! String) {
          throw const FormatException('device id');
        }
        await PushStorage.save(data['id'] as String);
      }).catchError((Object _) {
        debugPrint('Đăng ký push chưa thành công. Sẽ thử lại khi mở app.');
      }),
    );
  }

  Future<void> _removeBinding() async {
    final id = await PushStorage.deviceId();
    if (id == null) return;
    await DioClient.instance.delete('/notifications/devices/$id');
    await PushStorage.clearDevice();
  }

  Future<bool> endSession() async {
    _active = false;
    _pendingOpen = false;
    _openedIds.clear();
    _receivedIds.clear();
    if (!_supported) return true;
    try {
      await _queue(_removeBinding);
      return true;
    } catch (_) {
      return false;
    }
  }
}
