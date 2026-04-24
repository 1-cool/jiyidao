import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:permission_handler/permission_handler.dart';
import '../models/code_item.dart';

/// 通知服务
/// 
/// 负责在通知栏显示取件码和定时提醒
class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  // ==================== 通知渠道 ====================
  static const String _codeChannelId = 'pincode_channel_v2';
  static const String _codeChannelName = '常驻通知';
  static const String _reminderChannelId = 'reminder_channel_v1';
  static const String _reminderChannelName = '定时提醒';
  
  // ==================== 通知 ID 常量 ====================
  static const int _reminderIdEveryday = 0;
  static const int _reminderIdWorkdayStart = 1;  // 周一到周五: 1-5
  static const int _testReminderId = 999998;
  static const int _baseCodeId = 10000;  // 取件码通知 ID 基数

  /// 初始化通知服务
  Future<void> init() async {
    try {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
      debugPrint('时区初始化成功: ${tz.local.name}');

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await _notifications.initialize(
        settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      await _createNotificationChannels();
      debugPrint('通知服务初始化成功');
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
    }
  }

  /// 创建通知渠道
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // 删除旧渠道（如果存在）
    try {
      await androidPlugin.deleteNotificationChannel(channelId: 'pincode_channel');
    } catch (_) {}

    // 创建取件码通知渠道
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _codeChannelId,
        _codeChannelName,
        importance: Importance.max,
        showBadge: true,
      ),
    );
    
    // 创建定时提醒通知渠道
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _reminderChannelId,
        _reminderChannelName,
        importance: Importance.max,
        showBadge: true,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  // ==================== 取件码通知 ====================

  /// 显示取件码通知
  Future<void> showCodeNotification(CodeItem code) async {
    if (!await _checkNotificationPermission()) return;

    final androidDetails = AndroidNotificationDetails(
      _codeChannelId,
      _codeChannelName,
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      ongoing: true,
      autoCancel: false,
      visibility: NotificationVisibility.public,
    );

    await _notifications.show(
      id: _getCodeNotificationId(code.id),
      title: '${code.type.emoji} 取件码',
      body: code.code,
      notificationDetails: NotificationDetails(android: androidDetails, iOS: const DarwinNotificationDetails()),
      payload: code.id,
    );
  }

  /// 取消取件码通知
  Future<void> cancelNotification(String codeId) async {
    await _notifications.cancel(id: _getCodeNotificationId(codeId));
  }

  /// 生成取件码通知 ID（简单且足够）
  int _getCodeNotificationId(String id) {
    return _baseCodeId + (id.hashCode & 0xFFFF);
  }

  // ==================== 定时提醒 ====================

  /// 设置每日定时提醒
  Future<bool> scheduleDailyReminder({
    required int hour,
    required int minute,
    bool workdayOnly = true,
  }) async {
    try {
      debugPrint('设置定时提醒: $hour:$minute, 工作日: $workdayOnly');
      
      // 检查精确闹钟权限
      if (await Permission.scheduleExactAlarm.isDenied) {
        final granted = await Permission.scheduleExactAlarm.request();
        if (!granted.isGranted) {
          debugPrint('精确闹钟权限未授予');
          return false;
        }
      }

      // 先取消所有定时提醒
      await cancelDailyReminder(workdayOnly: true);
      await cancelDailyReminder(workdayOnly: false);

      final androidDetails = AndroidNotificationDetails(
        _reminderChannelId,
        _reminderChannelName,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
      );

      if (workdayOnly) {
        // 工作日提醒：周一至周五 (ID 1-5)
        for (int day in [1, 2, 3, 4, 5]) {
          await _notifications.zonedSchedule(
            id: _reminderIdWorkdayStart + day - 1,
            title: '📦 取快递提醒',
            body: '你有快递待取，别忘了哦！',
            scheduledDate: _nextWeekdayTime(day, hour, minute),
            notificationDetails: NotificationDetails(android: androidDetails, iOS: const DarwinNotificationDetails()),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
      } else {
        // 每天提醒 (ID 0)
        await _notifications.zonedSchedule(
          id: _reminderIdEveryday,
          title: '📦 取快递提醒',
          body: '你有快递待取，别忘了哦！',
          scheduledDate: _nextTime(hour, minute),
          notificationDetails: NotificationDetails(android: androidDetails, iOS: const DarwinNotificationDetails()),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }

      debugPrint('定时提醒设置成功');
      return true;
    } catch (e) {
      debugPrint('设置定时提醒失败: $e');
      return false;
    }
  }

  /// 取消定时提醒
  Future<void> cancelDailyReminder({bool workdayOnly = true}) async {
    if (workdayOnly) {
      for (int i = 0; i < 5; i++) {
        await _notifications.cancel(id: _reminderIdWorkdayStart + i);
      }
    } else {
      await _notifications.cancel(id: _reminderIdEveryday);
    }
  }

  /// 发送即时提醒通知（用于测试）
  Future<void> showReminderNotification() async {
    final androidDetails = AndroidNotificationDetails(
      _reminderChannelId,
      _reminderChannelName,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
    );

    await _notifications.show(
      id: _testReminderId,
      title: '📦 取快递提醒',
      body: '你有快递待取，别忘了哦！',
      notificationDetails: NotificationDetails(android: androidDetails, iOS: const DarwinNotificationDetails()),
    );
  }

  /// 测试定时提醒（几秒后触发）
  Future<bool> testScheduledReminder(int seconds) async {
    try {
      final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
      
      await _notifications.cancel(id: _testReminderId);
      
      await _notifications.zonedSchedule(
        id: _testReminderId,
        title: '📦 定时提醒测试',
        body: '如果你看到这条通知，说明定时提醒功能正常！',
        scheduledDate: scheduledDate,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(_reminderChannelId, _reminderChannelName, importance: Importance.max),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      
      debugPrint('测试提醒已设置，$seconds 秒后触发');
      return true;
    } catch (e) {
      debugPrint('测试定时提醒失败: $e');
      return false;
    }
  }

  // ==================== 辅助方法 ====================

  /// 检查通知权限
  Future<bool> _checkNotificationPermission() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin == null) return true;
    
    final granted = await androidPlugin.requestNotificationsPermission();
    final enabled = await androidPlugin.areNotificationsEnabled();
    return granted ?? enabled ?? false;
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
      return await iosPlugin.requestPermissions(alert: true, badge: true) ?? false;
    }
    
    return true;
  }

  /// 通知点击回调
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// 获取下一个指定时间
  tz.TZDateTime _nextTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// 获取下一个指定星期几和时间
  tz.TZDateTime _nextWeekdayTime(int weekday, int hour, int minute) {
    var scheduled = _nextTime(hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// 取消所有通知
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}