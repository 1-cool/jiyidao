import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

/// 定时提醒服务
/// 
/// 使用 Timer 实现精确的定时提醒
/// - App 在前台时：精确到秒
/// - App 在后台时：依赖前台服务保活
class ReminderService extends ChangeNotifier {
  static const String _keyReminderHour = 'reminder_hour';
  static const String _keyReminderMinute = 'reminder_minute';
  static const String _keyReminderMode = 'reminder_mode';
  
  final NotificationService _notificationService;
  
  Timer? _timer;
  int _reminderHour = 18;
  int _reminderMinute = 30;
  ReminderMode _reminderMode = ReminderMode.workday;
  bool _isRunning = false;
  
  ReminderService({required NotificationService notificationService})
      : _notificationService = notificationService;
  
  // Getters
  int get reminderHour => _reminderHour;
  int get reminderMinute => _reminderMinute;
  ReminderMode get reminderMode => _reminderMode;
  bool get isRunning => _isRunning;
  
  /// 初始化服务
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    _reminderHour = prefs.getInt(_keyReminderHour) ?? 18;
    _reminderMinute = prefs.getInt(_keyReminderMinute) ?? 30;
    final modeIndex = prefs.getInt(_keyReminderMode) ?? 1;
    _reminderMode = ReminderMode.values[modeIndex.clamp(0, ReminderMode.values.length - 1)];
    
    // 如果提醒模式不是关闭，启动定时器
    if (_reminderMode != ReminderMode.disabled) {
      _startTimer();
    }
    
    notifyListeners();
  }
  
  /// 设置提醒时间
  Future<void> setReminderTime(int hour, int minute) async {
    _reminderHour = hour.clamp(0, 23);
    _reminderMinute = minute.clamp(0, 59);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReminderHour, _reminderHour);
    await prefs.setInt(_keyReminderMinute, _reminderMinute);
    
    // 重启定时器
    if (_reminderMode != ReminderMode.disabled) {
      _restartTimer();
    }
    
    notifyListeners();
  }
  
  /// 设置提醒模式
  Future<void> setReminderMode(ReminderMode mode) async {
    _reminderMode = mode;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReminderMode, mode.index);
    
    if (mode == ReminderMode.disabled) {
      _stopTimer();
    } else {
      _startTimer();
    }
    
    notifyListeners();
  }
  
  /// 启动定时器
  void _startTimer() {
    if (_isRunning) return;
    
    _isRunning = true;
    _scheduleNextCheck();
    
    debugPrint('定时提醒服务已启动: $_reminderHour:$_reminderMinute, 模式: $_reminderMode');
  }
  
  /// 停止定时器
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    
    debugPrint('定时提醒服务已停止');
  }
  
  /// 重启定时器
  void _restartTimer() {
    _stopTimer();
    _startTimer();
  }
  
  /// 调度下一次检查
  void _scheduleNextCheck() {
    if (!_isRunning || _reminderMode == ReminderMode.disabled) return;
    
    final now = DateTime.now();
    final nextReminder = _getNextReminderTime();
    
    if (nextReminder == null) {
      debugPrint('没有下一个提醒时间');
      return;
    }
    
    final delay = nextReminder.difference(now);
    
    debugPrint('下一次提醒时间: $nextReminder, 延迟: ${delay.inMinutes} 分钟');
    
    // 每分钟检查一次（避免 Timer 时间过长导致精度问题）
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkAndNotify();
    });
  }
  
  /// 检查并发送提醒
  void _checkAndNotify() {
    if (!_isRunning || _reminderMode == ReminderMode.disabled) return;
    
    final now = DateTime.now();
    
    // 检查是否到达提醒时间（允许 1 分钟误差）
    if (now.hour == _reminderHour && 
        (now.minute - _reminderMinute).abs() <= 1) {
      
      // 检查是否是工作日模式
      if (_reminderMode == ReminderMode.workday) {
        final weekday = now.weekday;
        if (weekday == 6 || weekday == 7) {
          debugPrint('今天是周末，跳过提醒');
          return;
        }
      }
      
      // 发送提醒通知
      _sendReminderNotification();
    }
  }
  
  /// 发送提醒通知
  Future<void> _sendReminderNotification() async {
    debugPrint('发送定时提醒通知...');
    
    await _notificationService.showReminderNotification(
      title: '📦 取快递提醒',
      body: '你有快递待取，别忘了哦！',
    );
  }
  
  /// 获取下一个提醒时间
  DateTime? _getNextReminderTime() {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, _reminderHour, _reminderMinute);
    
    // 如果今天的时间已过，从明天开始
    if (next.isBefore(now)) {
      next = next.add(const Duration(days: 1));
    }
    
    // 如果是工作日模式，跳过周末
    if (_reminderMode == ReminderMode.workday) {
      while (next.weekday == 6 || next.weekday == 7) {
        next = next.add(const Duration(days: 1));
      }
    }
    
    return next;
  }
  
  /// 测试提醒（几秒后触发）
  Future<void> testReminder({int seconds = 10}) async {
    debugPrint('测试提醒: $seconds 秒后触发');
    
    _timer?.cancel();
    
    _timer = Timer(Duration(seconds: seconds), () {
      _sendReminderNotification();
      // 测试完成后恢复正常的定时器
      if (_reminderMode != ReminderMode.disabled) {
        _scheduleNextCheck();
      }
    });
  }
  
  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}

/// 提醒模式
enum ReminderMode {
  disabled('关闭', '不提醒'),
  everyday('每天', '每天提醒'),
  workday('工作日', '周一至周五提醒');
  
  final String label;
  final String description;
  const ReminderMode(this.label, this.description);
}
