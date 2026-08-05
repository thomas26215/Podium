import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../repositories/users_repository.dart';

/// Wires up push notifications: asks for permission, registers this
/// device's FCM token against the signed-in user, and shows a system
/// notification for messages that arrive while the app is in the
/// foreground (FCM only does that automatically in background/terminated).
///
/// The actual "someone started/finished a match" pushes are sent by a
/// Cloud Function (see functions/index.js) reacting to Firestore writes —
/// this class only handles the receiving side.
///
/// Mobile-only: web push needs its own setup (service worker, VAPID key)
/// that this app doesn't provide, so every method here is a no-op when
/// running on web — the rest of the app (live sessions, in-app history,
/// etc.) works the same regardless.
class NotificationsService {
  final UsersRepository usersRepo;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin   _local = FlutterLocalNotificationsPlugin();

  String? _registeredToken;
  String? _registeredUid;

  NotificationsService({required this.usersRepo});

  static const _channel = AndroidNotificationChannel(
    'podium_matches',
    'Parties',
    description: 'Débuts et fins de partie dans vos groupes',
    importance: Importance.high,
  );

  // Membership pushes (see functions/index.js's onGroupMemberAdded) — kept
  // separate from _channel since they're not about a match, so a player can
  // mute one without muting the other.
  static const _groupsChannel = AndroidNotificationChannel(
    'podium_groups',
    'Groupes',
    description: 'Quand vous êtes ajouté à un nouveau groupe',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (kIsWeb) return;
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    final androidPlugin = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.createNotificationChannel(_groupsChannel);

    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _messaging.setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: false);

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    _messaging.onTokenRefresh.listen((token) {
      if (_registeredUid != null) unawaited(_register(_registeredUid!, token));
    });
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    // The server picks the Android channel per notification type (see
    // functions/index.js) — match it here too instead of always showing
    // under _channel, now that there's more than one.
    final channel = notification.android?.channelId == _groupsChannel.id ? _groupsChannel : _channel;
    _local.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(channel.id, channel.name, channelDescription: channel.description, importance: Importance.high, priority: Priority.high),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Call once a user is signed in: fetches this device's token and links
  /// it to their account. Safe to call repeatedly (e.g. on every app start).
  Future<void> registerForUser(String uid) async {
    if (kIsWeb) return;
    _registeredUid = uid;
    try {
      final token = await _messaging.getToken();
      if (token != null) await _register(uid, token);
    } catch (_) {
      // Notifications are a nice-to-have — never block sign-in on this.
    }
  }

  Future<void> _register(String uid, String token) async {
    if (_registeredToken == token && _registeredUid == uid) return;
    await usersRepo.registerFcmToken(uid: uid, token: token);
    _registeredToken = token;
  }

  /// Call on sign-out so a shared device stops receiving this account's
  /// notifications.
  Future<void> unregister() async {
    if (kIsWeb) return;
    final uid = _registeredUid;
    final token = _registeredToken;
    _registeredUid = null;
    _registeredToken = null;
    if (uid == null || token == null) return;
    try {
      await usersRepo.unregisterFcmToken(uid: uid, token: token);
    } catch (_) {}
  }
}
