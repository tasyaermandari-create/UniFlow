import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // INISIALISASI NOTIFIKASI
  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    final timezoneInfo = await FlutterTimezone.getLocalTimezone();

    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(settings: initializationSettings);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;

      if (notification != null) {
        showNotification(
          id: message.hashCode,
          title: notification.title ?? 'Notifikasi UniFlow',
          body: notification.body ?? 'Kamu memiliki notifikasi baru.',
        );
      }
    });

    _initialized = true;
  }

  // MEMINTA IZIN ALARM TEPAT WAKTU ANDROID
  Future<bool> requestExactAlarmPermission() async {
    await initialize();

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin == null) return true;

    final canSchedule = await androidPlugin.canScheduleExactNotifications();

    if (canSchedule == true) return true;

    final granted = await androidPlugin.requestExactAlarmsPermission();

    return granted ?? false;
  }

  // MEMINTA IZIN NOTIFIKASI
  Future<bool> requestPermission() async {
    await initialize();

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final status = settings.authorizationStatus;

    final notificationGranted =
        status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;

    if (!notificationGranted) return false;

    await requestExactAlarmPermission();

    return true;
  }

  // TOKEN FCM

  // MENGAMBIL TOKEN FCM PERANGKAT
  Future<String?> getFcmToken() async {
    await initialize();

    final messaging = FirebaseMessaging.instance;

    final tokenFuture = messaging.onRegistered.first;

    await messaging.register();

    return await tokenFuture;
  }

  // MENDENGARKAN TOKEN FCM TERBARU
  Stream<String> get onTokenRefresh {
    return FirebaseMessaging.instance.onRegistered;
  }

  // TAMPILAN NOTIFIKASI
  NotificationDetails get _notificationDetails => const NotificationDetails(
    android: AndroidNotificationDetails(
      'uniflow_reminders',
      'UniFlow Reminders',
      channelDescription: 'Pengingat tugas dan rutinitas UniFlow',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    ),
  );

  // NOTIFIKASI LANGSUNG
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _notificationDetails,
    );
  }

  // NOTIFIKASI TERJADWAL DENGAN ALARM TEPAT WAKTU
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await initialize();

    if (!scheduledDate.isAfter(DateTime.now())) {
      return;
    }

    final permissionGranted = await requestExactAlarmPermission();

    if (!permissionGranted) {
      throw Exception(
        'Izin alarm tepat waktu belum diberikan. '
        'Aktifkan izin alarm UniFlow di pengaturan Android.',
      );
    }

    final scheduledTime = tz.TZDateTime.from(scheduledDate, tz.local);

    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledTime,
      notificationDetails: _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // PENGINGAT TUGAS
  Future<void> scheduleTaskReminder({
    required int taskId,
    required String taskTitle,
    required DateTime deadline,
  }) async {
    final reminderTime = deadline.subtract(const Duration(hours: 1));

    await scheduleNotification(
      id: taskId,
      title: 'Pengingat Tugas',
      body: 'Tugas "$taskTitle" akan segera berakhir.',
      scheduledDate: reminderTime,
    );
  }

  // PENGINGAT RUTINITAS
  Future<void> scheduleRoutineReminder({
    required int routineId,
    required String routineTitle,
    required DateTime startTime,
  }) async {
    await scheduleNotification(
      id: routineId,
      title: 'Waktunya Beraktivitas',
      body: 'Jadwal "$routineTitle" akan segera dimulai.',
      scheduledDate: startTime,
    );
  }

  // MEMBATALKAN NOTIFIKASI
  Future<void> cancelNotification(int id) async {
    await initialize();

    await _notifications.cancel(id: id);
  }

  // MEMBATALKAN SEMUA NOTIFIKASI
  Future<void> cancelAllNotifications() async {
    await initialize();

    await _notifications.cancelAll();
  }

  // MELIHAT NOTIFIKASI TERJADWAL
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    await initialize();

    return _notifications.pendingNotificationRequests();
  }
}
