import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:io' show Platform;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 初始化通知服務
  Future<void> initialize() async {
    if (_initialized) return;

    // 初始化時區資料
    tz.initializeTimeZones();

    // Android 初始化設定
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 初始化設定
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // 初始化設定
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // 初始化通知插件
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 請求通知權限
    await requestPermissions();

    // 創建 Android 通知通道
    if (Platform.isAndroid) {
      await _createNotificationChannel();
    }

    _initialized = true;
  }

  /// 請求通知權限
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      // Android 13+ 需要請求通知權限
      final status = await Permission.notification.request();
      return status.isGranted;
    } else if (Platform.isIOS) {
      // iOS 權限在初始化時自動請求
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }

  /// 創建 Android 通知通道
  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'high_importance_channel', // 通道 ID
      '重要通知', // 通道名稱
      description: '用於接收重要通知訊息', // 通道描述
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// 顯示通知
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Android 通知詳細設定
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel', // 通道 ID
      '重要通知', // 通道名稱
      channelDescription: '用於接收重要通知訊息',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    // iOS 通知詳細設定
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // 通知詳細設定
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // 顯示通知
    await _notifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// 顯示排程通知（在指定時間後顯示）
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    // Android 通知詳細設定
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      '重要通知',
      channelDescription: '用於接收重要通知訊息',
      importance: Importance.high,
      priority: Priority.high,
    );

    // iOS 通知詳細設定
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // 排程通知
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      _convertToTZDateTime(scheduledDate),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// 取消通知
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// 取消所有通知
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// 通知點擊回調
  void _onNotificationTapped(NotificationResponse response) {
    // 處理通知點擊事件
    // 可以在這裡導航到特定頁面
    print('通知被點擊: ${response.payload}');
  }

  /// 將 DateTime 轉換為 TZDateTime（用於排程通知）
  tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, tz.local);
  }

  /// 檢查通知權限狀態
  Future<bool> isPermissionGranted() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }
}

