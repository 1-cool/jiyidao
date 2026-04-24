import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/code_item.dart';

/// OPPO 灵动岛服务
///
/// 通过 OPPO Push SDK 的实时活动通知 API 实现
/// 文档：https://open.oppomobile.com/documentation/page/info?id=12658
class OppoIslandService {
  static const MethodChannel _channel = MethodChannel('com.pincode.app/oppo_island');

  /// 单例模式 - 状态变量必须是 static 的
  static bool _isInitialized = false;
  static bool _isSupported = false;

  /// 单例实例
  static final OppoIslandService _instance = OppoIslandService._internal();
  factory OppoIslandService() => _instance;
  OppoIslandService._internal();

  /// 初始化服务
  Future<bool> init() async {
    if (_isInitialized) return _isSupported;

    if (defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('不是 Android 平台，跳过灵动岛初始化');
      _isInitialized = true;
      return false;
    }

    try {
      final deviceInfo = await _channel.invokeMethod<Map<String, dynamic>>('getDeviceInfo');
      if (deviceInfo != null) {
        debugPrint('设备信息: $deviceInfo');
      }

      final result = await _channel.invokeMethod<bool>('init');
      _isSupported = result ?? false;
      _isInitialized = true;

      debugPrint('OPPO 灵动岛服务初始化完成, 支持状态: $_isSupported');
      return _isSupported;
    } catch (e) {
      debugPrint('OPPO 灵动岛服务初始化失败: $e');
      _isInitialized = true;
      _isSupported = false;
      return false;
    }
  }

  /// 检查是否支持灵动岛
  Future<bool> isSupported() async {
    if (!_isInitialized) await init();
    return _isSupported;
  }

  /// 显示取件码到灵动岛
  Future<bool> showCode(CodeItem code) async {
    debugPrint('showCode: ${code.id}, ${code.code}');
    
    if (!_isInitialized) await init();
    
    try {
      final result = await _channel.invokeMethod<bool>('showCode', {
        'id': code.id,
        'title': '${code.type.emoji} ${code.location ?? ""}',
        'code': code.code,
        'type': code.type.name,
        'location': code.location ?? '',
      });
      return result ?? false;
    } catch (e) {
      debugPrint('OPPO 灵动岛显示失败: $e');
      return false;
    }
  }

  /// 更新灵动岛内容
  Future<bool> updateCode(CodeItem code) async {
    if (!_isInitialized) await init();
    if (!_isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>('updateCode', {
        'id': code.id,
        'title': '${code.type.emoji} ${code.location ?? ""}',
        'code': code.code,
        'type': code.type.name,
        'location': code.location ?? '',
      });
      return result ?? false;
    } catch (e) {
      debugPrint('OPPO 灵动岛更新失败: $e');
      return false;
    }
  }

  /// 隐藏灵动岛
  Future<bool> hideCode(String codeId) async {
    debugPrint('hideCode: $codeId');
    
    if (!_isInitialized) await init();
    
    try {
      final result = await _channel.invokeMethod<bool>('hideCode', {'id': codeId});
      return result ?? false;
    } catch (e) {
      debugPrint('OPPO 灵动岛隐藏失败: $e');
      return false;
    }
  }

  /// 隐藏所有灵动岛
  Future<bool> hideAll() async {
    debugPrint('hideAll');
    
    if (!_isInitialized) await init();
    
    try {
      final result = await _channel.invokeMethod<bool>('hideAll');
      return result ?? false;
    } catch (e) {
      debugPrint('OPPO 灵动岛隐藏所有失败: $e');
      return false;
    }
  }
}
