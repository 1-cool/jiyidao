import 'package:flutter/foundation.dart';
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
    _notification.init().catchError((e) {
      print('NotificationService init failed: $e');
    });
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
    await _database.markAsUsed(id);
    _codes.removeWhere((code) => code.id == id);
    notifyListeners();
    
    // 取消通知
    await _notification.cancelNotification(id);
  }

  /// 删除取件码
  Future<void> deleteCode(String id) async {
    await _database.deleteCode(id);
    _codes.removeWhere((code) => code.id == id);
    notifyListeners();
    
    // 取消通知
    await _notification.cancelNotification(id);
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

  /// 释放资源
  @override
  void dispose() {
    super.dispose();
  }
}
