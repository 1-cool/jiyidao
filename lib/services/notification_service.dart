import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:permission_handler/permission_handler.dart';
import '../models/code_item.dart';

/// 通知服务
/// 
/// 负责在通知栏显示取件码
class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  // 常驻通知渠道（用于显示取件码等常驻信息）
  static const String _channelId = 'pincode_channel_v2';
  static const String _channelName = '常驻通知';
  static const String _channelDescription = '显示取件码、取餐码等常驻信息';
  
  // 定时提醒通知渠道（独立渠道，方便用户管理）
  static const String _reminderChannelId = 'reminder_channel_v1';
  static const String _reminderChannelName = '定时提醒';
  static const String _reminderChannelDescription = '取快递定时提醒通知';

  /// 初始化通知服务（非阻塞）
  Future<void> init() async {
    // 使用 try-catch 防止初始化失败导致卡住
    try {
      // 初始化时区数据库
      tz_data.initializeTimeZones();
      final location = tz.getLocation('Asia/Shanghai');
      tz.setLocalLocation(location);
      print('时区初始化成功: ${tz.local.name}');

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

      // flutter_local_notifications 21.x: 所有参数改为命名参数
      await _notifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      print('通知服务初始化成功');

      // 创建通知渠道（同步等待，确保渠道创建成功）
      await _createNotificationChannel();
    } catch (e, stackTrace) {
      print('NotificationService init failed: $e');
      print('堆栈: $stackTrace');
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
        await androidPlugin.deleteNotificationChannel(channelId: 'pincode_channel');
      } catch (e) {
        // 渠道不存在，忽略错误
      }

      // 创建取件码通知渠道
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.max,
          showBadge: true,
        ),
      );
      
      // 创建定时提醒通知渠道（独立渠道）
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _reminderChannelId,
          _reminderChannelName,
          description: _reminderChannelDescription,
          importance: Importance.max,
          showBadge: true,
          playSound: true,
          enableVibration: true,
        ),
      );
      
      print('通知渠道创建成功: $_channelId, $_reminderChannelId');
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

    // flutter_local_notifications 21.x: 所有参数改为命名参数
    await _notifications.show(
      id: notificationId,
      title: '${code.type.emoji} 取件码',
      body: code.code,
      notificationDetails: notificationDetails,
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
    // flutter_local_notifications 21.x: cancel 也需要命名参数
    await _notifications.cancel(id: notificationId);
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
      print('开始设置定时提醒: $hour:$minute, 工作日: $workdayOnly');
      
      // Android 12+ 检查精确闹钟权限
      if (await Permission.scheduleExactAlarm.isDenied) {
        print('请求精确闹钟权限...');
        final granted = await Permission.scheduleExactAlarm.request();
        if (!granted.isGranted) {
          print('精确闹钟权限未授予');
          return false;
        }
      }
      
      // 确保时区已初始化
      try {
        tz_data.initializeTimeZones();
        tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
        print('时区已设置: ${tz.local}');
      } catch (e) {
        print('时区设置失败: $e');
      }
      
      // 先取消已有的定时提醒
      await _notifications.cancel(id: 0);
      for (int day in [1, 2, 3, 4, 5]) {
        await _notifications.cancel(id: day);
      }

      // 使用独立的定时提醒渠道
      final androidDetails = AndroidNotificationDetails(
        _reminderChannelId,
        _reminderChannelName,
        channelDescription: _reminderChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
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
        for (int day in [1, 2, 3, 4, 5]) {
          final scheduledDate = _nextInstanceOfWeekdayTime(day, hour, minute);
          print('设置周${day}提醒: $scheduledDate');
          
          await _notifications.zonedSchedule(
            id: day,
            title: '📦 取快递提醒',
            body: '你有快递待取，别忘了哦！',
            scheduledDate: scheduledDate,
            notificationDetails: notificationDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
      } else {
        // 每天提醒
        final scheduledDate = _nextInstanceOfTime(hour, minute);
        print('设置每天提醒: $scheduledDate');
        
        await _notifications.zonedSchedule(
          id: 0,
          title: '📦 取快递提醒',
          body: '你有快递待取，别忘了哦！',
          scheduledDate: scheduledDate,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }

      print('定时提醒设置成功');
      return true;
    } catch (e, stackTrace) {
      print('设置定时提醒失败: $e');
      print('堆栈: $stackTrace');
      return false;
    }
  }

  /// 取消定时提醒
  Future<void> cancelDailyReminder({bool workdayOnly = true}) async {
    if (workdayOnly) {
      // 取消工作日提醒 (ID 1-5)
      for (int day in [1, 2, 3, 4, 5]) {
        await _notifications.cancel(id: day);
      }
    } else {
      // 取消每天提醒 (ID 0)
      await _notifications.cancel(id: 0);
    }
  }
  
  /// 发送提醒通知（直接发送，不依赖 AlarmManager）
  Future<void> showReminderNotification({
    required String title,
    required String body,
  }) async {
    try {
      print('发送提醒通知: $title');
      
      final androidDetails = AndroidNotificationDetails(
        _reminderChannelId,
        _reminderChannelName,
        channelDescription: _reminderChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
        // 强制弹出横幅
        channelShowBadge: true,
        // 设置 ticker，触发状态栏提示
        ticker: '取快递提醒',
        // 设置分类为提醒，提高优先级
        category: AndroidNotificationCategory.reminder,
        // 不设置 ongoing，让它是一个普通通知
        ongoing: false,
        autoCancel: true,
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

      await _notifications.show(
        id: 999997,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
      );
      
      print('提醒通知发送成功');
    } catch (e) {
      print('发送提醒通知失败: $e');
    }
  }
  
  /// 发送测试通知（用于调试）
  Future<void> sendTestNotification() async {
    try {
      print('发送测试通知...');
      
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

      await _notifications.show(
        id: 999999,
        title: '📦 测试通知',
        body: '如果你看到这条通知，说明通知功能正常！',
        notificationDetails: notificationDetails,
      );
      
      print('测试通知发送成功');
    } catch (e) {
      print('发送测试通知失败: $e');
    }
  }
  
  /// 测试定时提醒（几秒后触发）
  /// 
  /// [seconds] 多少秒后触发提醒
  Future<bool> testScheduledReminder({int seconds = 10}) async {
    try {
      print('测试定时提醒: $seconds 秒后触发');
      
      // Android 12+ 检查精确闹钟权限
      if (await Permission.scheduleExactAlarm.isDenied) {
        print('请求精确闹钟权限...');
        final granted = await Permission.scheduleExactAlarm.request();
        if (!granted.isGranted) {
          print('精确闹钟权限未授予，尝试使用非精确模式');
          // 权限未授予时，使用非精确模式
          return await _testScheduledReminderInexact(seconds);
        }
      }
      
      // 确保时区已初始化
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
      
      // 计算触发时间
      final now = tz.TZDateTime.now(tz.local);
      final scheduledDate = now.add(Duration(seconds: seconds));
      
      print('当前时间: $now');
      print('计划时间: $scheduledDate');
      
      // 先取消已有的测试提醒
      await _notifications.cancel(id: 999998);
      
      // 使用独立的定时提醒渠道
      final androidDetails = AndroidNotificationDetails(
        _reminderChannelId,
        _reminderChannelName,
        channelDescription: _reminderChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
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
      
      await _notifications.zonedSchedule(
        id: 999998,
        title: '📦 定时提醒测试',
        body: '如果你看到这条通知，说明定时提醒功能正常！',
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      
      print('定时提醒已设置，将在 $seconds 秒后触发');
      return true;
    } catch (e, stackTrace) {
      print('测试定时提醒失败: $e');
      print('堆栈: $stackTrace');
      return false;
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
  
  /// 使用非精确模式测试定时提醒（精确闹钟权限未授予时的备用方案）
  Future<bool> _testScheduledReminderInexact(int seconds) async {
    try {
      print('使用非精确模式测试定时提醒');
      
      // 确保时区已初始化
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
      
      final now = tz.TZDateTime.now(tz.local);
      final scheduledDate = now.add(Duration(seconds: seconds));
      
      await _notifications.cancel(id: 999998);
      
      final androidDetails = AndroidNotificationDetails(
        _reminderChannelId,
        _reminderChannelName,
        channelDescription: _reminderChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
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
      
      // 使用 inexactAllowWhileIdle 模式（不需要精确闹钟权限）
      await _notifications.zonedSchedule(
        id: 999998,
        title: '📦 定时提醒测试（非精确）',
        body: '如果你看到这条通知，说明定时提醒功能正常！',
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      
      print('非精确定时提醒已设置');
      return true;
    } catch (e, stackTrace) {
      print('非精确定时提醒失败: $e');
      print('堆栈: $stackTrace');
      return false;
    }
  }
}
