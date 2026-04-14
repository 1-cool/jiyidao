import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/code_item.dart';

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
      
      // 先删除旧渠道（如果存在），再创建新渠道
      // Android 通知渠道一旦创建，用户改设置后代码无法覆盖
      // 删掉旧渠道再用新 ID 创建，才能重置渠道设置
      await _deleteOldChannel();
      
      // 创建通知渠道
      await _createNotificationChannel();
    } catch (e) {
      print('NotificationService init failed: $e');
      // 不抛出异常，允许 App 继续运行
    }
  }

  /// 删除旧版本的通知渠道
  Future<void> _deleteOldChannel() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      // 删除旧版本的渠道 ID
      await androidPlugin.deleteNotificationChannel('pincode_channel');
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
          importance: Importance.max,
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
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      ongoing: true, // 常驻通知
      visibility: NotificationVisibility.public, // 锁屏可见
      styleInformation: BigTextStyleInformation(
        '取件码：${code.code}\n'
        '来源：${code.source}'
        '${code.location != null ? '\n地点：${code.location}' : ''}',
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
