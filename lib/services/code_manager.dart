import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/code_item.dart';
import 'database_service.dart';
import 'pattern_matcher.dart';
import 'notification_service.dart';
import 'oppo_island_service.dart';

/// 取件码管理器
/// 
/// 负责取件码的数据管理和通知协调
class CodeManager extends ChangeNotifier {
  final DatabaseService _database = DatabaseService();
  final NotificationService _notification;
  final OppoIslandService _oppoIsland = OppoIslandService();
  
  /// 取件码列表
  List<CodeItem> _codes = [];
  List<CodeItem> get codes => _codes;
  
  CodeManager({NotificationService? notificationService}) 
      : _notification = notificationService ?? NotificationService();

  /// 初始化
  Future<void> init() async {
    try {
      await _loadCodes();
    } catch (e) {
      debugPrint('Failed to load codes: $e');
      _codes = [];
    }

    // 初始化 OPPO 灵动岛服务
    try {
      final supported = await _oppoIsland.init();
      debugPrint('OPPO 灵动岛支持: $supported');
    } catch (e) {
      debugPrint('OPPO 灵动岛初始化失败: $e');
    }

    // 恢复通知和定时提醒
    await _restoreNotifications();
    await _restoreDailyReminder();
  }
  
  /// 恢复所有取件码的通知
  Future<void> _restoreNotifications() async {
    for (final code in _codes) {
      try {
        await _oppoIsland.showCode(code);
      } catch (e) {
        debugPrint('恢复灵动岛通知失败: ${code.code}, $e');
        // 降级使用 Flutter 端通知
        try {
          await _notification.showCodeNotification(code);
        } catch (e2) {
          debugPrint('恢复 Flutter 端通知也失败: ${code.code}, $e2');
        }
      }
    }
    debugPrint('已恢复 ${_codes.length} 个取件码的通知');
  }
  
  /// 恢复定时提醒设置
  Future<void> _restoreDailyReminder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeIndex = prefs.getInt('reminder_mode');
      
      if (modeIndex == null || modeIndex == 2) return; // 未设置或已关闭
      
      final hour = prefs.getInt('reminder_hour') ?? 18;
      final minute = prefs.getInt('reminder_minute') ?? 30;
      final workdayOnly = modeIndex == 1;
      
      // 检查是否有快递类型的取件码
      final hasExpress = _codes.any((code) => code.type == CodeType.express);
      
      if (hasExpress) {
        debugPrint('恢复定时提醒: $hour:$minute, 工作日: $workdayOnly');
        await _notification.scheduleDailyReminder(
          hour: hour,
          minute: minute,
          workdayOnly: workdayOnly,
        );
      }
    } catch (e) {
      debugPrint('恢复定时提醒失败: $e');
    }
  }

  /// 加载取件码列表
  Future<void> _loadCodes() async {
    _codes = await _database.getActiveCodes();
    notifyListeners();
  }

  /// 处理短信内容
  Future<CodeItem?> processSms(String smsContent) async {
    final result = PatternMatcher.match(smsContent);
    if (result == null) return null;
    
    if (await _database.codeExists(result.code)) return null;
    
    final codeItem = result.toCodeItem();
    await addCode(codeItem);
    return codeItem;
  }

  /// 添加取件码
  Future<void> addCode(CodeItem code) async {
    await _database.insertCode(code);
    _codes.insert(0, code);
    notifyListeners();

    // 显示通知
    await _showNotification(code);

    // 如果是快递类型，更新定时提醒
    if (code.type == CodeType.express) {
      await _updateExpressReminder();
    }
  }
  
  /// 显示通知（灵动岛优先，降级到普通通知）
  Future<void> _showNotification(CodeItem code) async {
    try {
      await _oppoIsland.showCode(code);
    } catch (e) {
      debugPrint('OPPO 灵动岛显示失败: $e');
      try {
        await _notification.showCodeNotification(code);
      } catch (e2) {
        debugPrint('Flutter 端通知也失败: $e2');
      }
    }
  }

  /// 手动添加取件码
  Future<CodeItem?> addManualCode({
    required String code,
    required CodeType type,
    required String source,
    String? location,
  }) async {
    if (await _database.codeExists(code)) return null;

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
    final index = _codes.indexWhere((c) => c.id == id);
    if (index == -1) return;
    
    final code = _codes[index];
    final wasExpress = code.type == CodeType.express;
    
    await _database.markAsUsed(id);
    _codes.removeAt(index);
    notifyListeners();
    
    await _hideNotification(id);
    
    if (wasExpress) await _updateExpressReminder();
  }
  
  /// 隐藏通知
  Future<void> _hideNotification(String id) async {
    await _notification.cancelNotification(id);
    try {
      await _oppoIsland.hideCode(id);
    } catch (e) {
      debugPrint('OPPO 灵动岛隐藏失败: $e');
    }
  }

  /// 删除取件码
  Future<void> deleteCode(String id) async {
    final index = _codes.indexWhere((c) => c.id == id);
    if (index == -1) return;
    
    final code = _codes[index];
    final wasExpress = code.type == CodeType.express;
    
    await _database.deleteCode(id);
    _codes.removeAt(index);
    notifyListeners();
    
    await _hideNotification(id);
    
    if (wasExpress) await _updateExpressReminder();
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

  /// 更新取快递提醒
  Future<void> _updateExpressReminder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeIndex = prefs.getInt('reminder_mode') ?? 1;
      
      if (modeIndex == 2) return; // 已关闭
      
      final hour = prefs.getInt('reminder_hour') ?? 18;
      final minute = prefs.getInt('reminder_minute') ?? 30;
      final workdayOnly = modeIndex == 1;
      final hasExpress = _codes.any((code) => code.type == CodeType.express);

      if (hasExpress) {
        await _notification.scheduleDailyReminder(
          hour: hour,
          minute: minute,
          workdayOnly: workdayOnly,
        );
      } else {
        await _notification.cancelDailyReminder(workdayOnly: true);
        await _notification.cancelDailyReminder(workdayOnly: false);
      }
    } catch (e) {
      debugPrint('更新取快递提醒失败: $e');
    }
  }
}
