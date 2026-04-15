import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/code_item.dart';
import 'database_service.dart';
import 'pattern_matcher.dart';
import 'notification_service.dart';

/// 取件码管理器
/// 
/// 负责取件码的业务逻辑处理
class CodeManager extends ChangeNotifier {
  final DatabaseService _database = DatabaseService();
  final NotificationService _notification = NotificationService();
  
  /// 取件码列表（用于UI展示）
  List<CodeItem> _codes = [];
  
  List<CodeItem> get codes => _codes;

  /// 初始化
  Future<void> init() async {
    try {
      await _loadCodes();
    } catch (e) {
      print('Failed to load codes: $e');
      // 加载失败时使用空列表
      _codes = [];
    }

    // 通知服务初始化（不阻塞主流程）
    _notification.init().then((_) async {
      // 初始化成功后，重新显示所有取件码的通知
      await _restoreNotifications();
      // 恢复定时提醒设置
      await _restoreDailyReminder();
    }).catchError((e) {
      print('NotificationService init failed: $e');
    });
  }
  
  /// 恢复所有取件码的通知
  Future<void> _restoreNotifications() async {
    for (final code in _codes) {
      try {
        await _notification.showCodeNotification(code);
      } catch (e) {
        print('恢复通知失败: ${code.code}, $e');
      }
    }
    print('已恢复 ${_codes.length} 个取件码的通知');
  }
  
  /// 恢复定时提醒设置
  Future<void> _restoreDailyReminder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeIndex = prefs.getInt('reminder_mode');
      
      // 如果没有设置或已关闭，不恢复
      if (modeIndex == null || modeIndex == 2) {
        print('定时提醒未设置或已关闭');
        return;
      }
      
      final hour = prefs.getInt('reminder_hour') ?? 18;
      final minute = prefs.getInt('reminder_minute') ?? 30;
      final workdayOnly = modeIndex == 1;
      
      print('恢复定时提醒: $hour:$minute, 工作日: $workdayOnly');
      
      await _notification.scheduleDailyReminder(
        hour: hour,
        minute: minute,
        workdayOnly: workdayOnly,
      );
    } catch (e) {
      print('恢复定时提醒失败: $e');
    }
  }

  /// 加载取件码列表
  Future<void> _loadCodes() async {
    _codes = await _database.getActiveCodes();
    notifyListeners();
  }

  /// 处理短信内容
  /// 
  /// 自动识别短信中的取件码并保存
  Future<CodeItem?> processSms(String smsContent) async {
    final result = PatternMatcher.match(smsContent);
    if (result == null) return null;
    
    // 检查是否已存在
    if (await _database.codeExists(result.code)) {
      return null; // 已存在，不重复添加
    }
    
    final codeItem = result.toCodeItem();
    await addCode(codeItem);
    return codeItem;
  }

  /// 添加取件码
  Future<void> addCode(CodeItem code) async {
    await _database.insertCode(code);
    _codes.insert(0, code);
    notifyListeners();

    // 发送通知
    try {
      await _notification.showCodeNotification(code);
    } catch (e) {
      print('发送通知失败: $e');
      // 通知失败不阻塞主流程，但可以提示用户
    }

    // 如果是快递类型，更新取快递提醒
    if (code.type == CodeType.express) {
      _updateExpressReminder();
    }
  }

  /// 手动添加取件码
  Future<CodeItem?> addManualCode({
    required String code,
    required CodeType type,
    required String source,
    String? location,
  }) async {
    // 检查是否已存在
    if (await _database.codeExists(code)) {
      return null;
    }

    final codeItem = CodeItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      code: code,
      type: type,
      source: source,
      location: location,
      createTime: DateTime.now(),
    );

    await addCode(codeItem);
    return codeItem;
  }

  /// 标记为已使用
  Future<void> markAsUsed(String id) async {
    final code = _codes.firstWhere((c) => c.id == id);
    final wasExpress = code.type == CodeType.express;
    
    await _database.markAsUsed(id);
    _codes.removeWhere((code) => code.id == id);
    notifyListeners();
    
    // 取消通知
    await _notification.cancelNotification(id);

    // 如果是快递类型，更新取快递提醒
    if (wasExpress) {
      _updateExpressReminder();
    }
  }

  /// 删除取件码
  Future<void> deleteCode(String id) async {
    final code = _codes.firstWhere((c) => c.id == id);
    final wasExpress = code.type == CodeType.express;
    
    await _database.deleteCode(id);
    _codes.removeWhere((code) => code.id == id);
    notifyListeners();
    
    // 取消通知
    await _notification.cancelNotification(id);

    // 如果是快递类型，更新取快递提醒
    if (wasExpress) {
      _updateExpressReminder();
    }
  }

  /// 清理所有已使用的取件码
  Future<int> cleanUsedCodes() async {
    final count = await _database.cleanUsedCodes();
    await _loadCodes();
    return count;
  }

  /// 刷新列表
  Future<void> refresh() async {
    await _loadCodes();
  }
  
  /// 检查取件码是否已存在
  Future<bool> codeExists(String code) async {
    return await _database.codeExists(code);
  }

  /// 释放资源
  @override
  void dispose() {
    super.dispose();
  }

  /// 更新取快递提醒
  /// 
  /// 根据当前快递数量和设置决定是否启用提醒
  Future<void> _updateExpressReminder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeIndex = prefs.getInt('reminder_mode') ?? 1;
      
      // 如果提醒已关闭，不做任何操作
      if (modeIndex == 2) return; // ReminderMode.disabled.index = 2
      
      final hour = prefs.getInt('reminder_hour') ?? 18;
      final minute = prefs.getInt('reminder_minute') ?? 30;
      final workdayOnly = modeIndex == 1; // ReminderMode.workday.index = 1

      // 检查是否有快递类型的取件码
      final hasExpress = _codes.any((code) => code.type == CodeType.express);

      if (hasExpress) {
        // 有快递，设置提醒
        await _notification.scheduleDailyReminder(
          hour: hour,
          minute: minute,
          workdayOnly: workdayOnly,
        );
      } else {
        // 没有快递，取消提醒
        await _notification.cancelDailyReminder(workdayOnly: true);
        await _notification.cancelDailyReminder(workdayOnly: false);
      }
    } catch (e) {
      print('更新取快递提醒失败: $e');
    }
  }
}
