import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/code_item.dart';
import 'database_service.dart';

/// 通知服务
/// 
/// 负责在通知栏显示取件码
class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  // 通知渠道 ID 带版本号，删除旧渠道后递增版本即可重建
  static const String _channelId = 'pincode_channel_v2';
  static const String _channelName = '取件码通知';
  static const String _channelDescription = '显示取件码、取餐码等信息';

  /// 初始化通知服务（非阻塞）
  Future<void> init() async {
    // 使用 try-catch 防止初始化失败导致卡住
    try {
      // 初始化时区数据库
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

      // Android 初始化设置
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS 初始化设置
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false, // 不自动请求权限
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // 创建通知渠道（同步等待，确保渠道创建成功）
      await _createNotificationChannel();
    } catch (e) {
      print('NotificationService init failed: $e');
      // 不抛出异常，允许 App 继续运行
    }
  }

  /// 创建通知渠道（Android 8.0+）
  Future<void> _createNotificationChannel() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // 先尝试删除旧渠道（如果存在）
      try {
        await androidPlugin.deleteNotificationChannel('pincode_channel');
      } catch (e) {
        // 渠道不存在，忽略错误
      }

      // 创建新渠道
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.max,
          showBadge: true,
        ),
      );
    }
  }

  /// 显示取件码通知
  Future<void> showCodeNotification(CodeItem code) async {
    // Android 13+ 检查通知权限
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      final enabled = await androidPlugin.areNotificationsEnabled();
      final hasPermission = granted ?? enabled ?? false;

      if (!hasPermission) {
        print('通知权限未授予，无法显示通知');
        return;
      }
    }

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      ongoing: true, // 常驻通知
      autoCancel: false, // 点击后不自动取消
      visibility: NotificationVisibility.public, // 锁屏可见
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // 使用时间戳作为通知ID，确保每个码都有独立通知
    final notificationId = code.id.hashCode;

    await _notifications.show(
      notificationId,
      '${code.type.emoji} 取件码',
      code.code,
      notificationDetails,
      payload: code.id,
    );
  }

  /// 更新通知
  Future<void> updateNotification(CodeItem code) async {
    await showCodeNotification(code);
  }

  /// 取消通知
  Future<void> cancelNotification(String codeId) async {
    final notificationId = codeId.hashCode;
    await _notifications.cancel(notificationId);
  }

  /// 取消所有通知
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// 通知点击回调
  void _onNotificationTapped(NotificationResponse response) {
    // TODO: 处理通知点击事件
    // 可以跳转到详情页或复制取件码
    final payload = response.payload;
    if (payload != null) {
      // 这里可以发送事件到 UI 层
      print('Notification tapped: $payload');
    }
  }

  /// 请求通知权限
  Future<bool> requestPermission() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      return await androidPlugin.requestNotificationsPermission() ?? false;
    }
    
    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    
    if (iosPlugin != null) {
      return await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: false,
      ) ?? false;
    }
    
    return true;
  }

  /// 设置每日定时提醒
  /// 
  /// [hour] 小时 (0-23)
  /// [minute] 分钟 (0-59)
  /// [workdayOnly] 是否仅工作日提醒
  /// 
  /// 注意：只有存在快递类型的取件码时才会提醒
  Future<bool> scheduleDailyReminder({
    required int hour,
    required int minute,
    bool workdayOnly = true,
  }) async {
    try {
      // 先取消已有的定时提醒
      await _notifications.cancel(0); // 使用固定 ID 0 作为提醒通知

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        visibility: NotificationVisibility.public,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      if (workdayOnly) {
        // 工作日提醒：周一至周五
        // 由于 flutter_local_notifications 不直接支持"工作日"，
        // 我们需要为每一天分别设置
        for (int day in [1, 2, 3, 4, 5]) {
          // DateTime.monday = 1, ..., DateTime.friday = 5
          await _notifications.zonedSchedule(
            day, // 使用星期几作为 ID
            '📦 取快递提醒',
            '你有快递待取，别忘了哦！',
            _nextInstanceOfWeekdayTime(day, hour, minute),
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
      } else {
        // 每天提醒
        await _notifications.zonedSchedule(
          0,
          '📦 取快递提醒',
          '你有快递待取，别忘了哦！',
          _nextInstanceOfTime(hour, minute),
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }

      return true;
    } catch (e) {
      print('设置定时提醒失败: $e');
      return false;
    }
  }

  /// 取消定时提醒
  Future<void> cancelDailyReminder({bool workdayOnly = true}) async {
    if (workdayOnly) {
      // 取消工作日提醒 (ID 1-5)
      for (int day in [1, 2, 3, 4, 5]) {
        await _notifications.cancel(day);
      }
    } else {
      // 取消每天提醒 (ID 0)
      await _notifications.cancel(0);
    }
  }

  /// 获取下一个指定时间的 DateTime
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// 获取下一个指定星期几和时间的 DateTime
  tz.TZDateTime _nextInstanceOfWeekdayTime(int day, int hour, int minute) {
    var scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != day) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
