import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/code_item.dart';

/// 通知服务
/// 
/// 负责在通知栏显示取件码
class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  static const String _channelId = 'pincode_channel';
  static const String _channelName = '取件码通知';
  static const String _channelDescription = '显示取件码、取餐码等信息';

  /// 初始化通知服务（非阻塞）
  Future<void> init() async {
    // 使用 try-catch 防止初始化失败导致卡住
    try {
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
      
      // 创建通知渠道（异步，不等待）
      _createNotificationChannel().catchError((e) {
        print('Failed to create notification channel: $e');
      });
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
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
          showBadge: true,
        ),
      );
    }
  }

  /// 显示取件码通知
  Future<void> showCodeNotification(CodeItem code) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      ongoing: true, // 常驻通知
      styleInformation: BigTextStyleInformation(
        '取件码：${code.code}\n'
        '来源：${code.source}\n'
        '${code.location != null ? '地点：${code.location}\n' : ''}'
        '${code.remainingTimeDesc}',
        contentTitle: '${code.type.emoji} ${code.source}',
        summaryText: '点击复制取件码',
      ),
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
      '${code.type.emoji} ${code.source}',
      '取件码：${code.code}',
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
}
