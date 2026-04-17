import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/code_item.dart';

/// OPPO 灵动岛服务
/// 
/// 通过 OPPO Push SDK 的实时活动通知 API 实现
/// 文档：https://open.oppomobile.com/documentation/page/info?id=12658
class OppoIslandService {
  static const MethodChannel _channel = MethodChannel('com.pincode.app/oppo_island');
  
  bool _isInitialized = false;
  bool _isSupported = false;
  
  /// 单例模式
  static final OppoIslandService _instance = OppoIslandService._internal();
  factory OppoIslandService() => _instance;
  OppoIslandService._internal();
  
  /// 初始化服务
  Future<bool> init() async {
    if (_isInitialized) return _isSupported;
    
    try {
      // 检查是否是 OPPO 设备
      if (!await isOppoDevice()) {
        print('不是 OPPO 设备，跳过初始化');
        _isSupported = false;
        _isInitialized = true;
        return false;
      }
      
      // 调用原生初始化
      final result = await _channel.invokeMethod<bool>('init');
      _isSupported = result ?? false;
      _isInitialized = true;
      
      print('OPPO 灵动岛服务初始化: $_isSupported');
      return _isSupported;
    } catch (e) {
      print('OPPO 灵动岛服务初始化失败: $e');
      _isInitialized = true;
      _isSupported = false;
      return false;
    }
  }
  
  /// 检查是否是 OPPO 设备
  Future<bool> isOppoDevice() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    
    try {
      // 通过原生方法检测设备信息（比 Process.run 更可靠）
      final result = await _channel.invokeMethod<Map<String, dynamic>>('getDeviceInfo');
      
      if (result != null) {
        final manufacturer = (result['manufacturer'] as String?)?.toLowerCase() ?? '';
        final colorOsVersion = result['colorOsVersion'] as String? ?? '';
        
        // OPPO 系设备（OPPO、OnePlus、realme 都使用 ColorOS）
        if (manufacturer == 'oppo' || manufacturer == 'oneplus' || manufacturer == 'realme') {
          print('检测到 $manufacturer 设备, ColorOS: $colorOsVersion');
          return true;
        }
        
        // 有 ColorOS 版本号也认为是 OPPO 设备
        if (colorOsVersion.isNotEmpty) {
          print('检测到 ColorOS 版本: $colorOsVersion');
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('检测 OPPO 设备失败: $e');
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
    if (!_isInitialized) await init();
    if (!_isSupported) {
      print('OPPO 灵动岛不支持，跳过');
      return false;
    }
    
    try {
      final result = await _channel.invokeMethod<bool>('showCode', {
        'id': code.id,
        'title': '${code.type.emoji} ${code.location}',
        'code': code.code,
        'type': code.type.name,
      });
      
      print('OPPO 灵动岛显示取件码: ${code.id}, 结果: $result');
      return result ?? false;
    } catch (e) {
      print('OPPO 灵动岛显示取件码失败: $e');
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
        'title': '${code.type.emoji} ${code.location}',
        'code': code.code,
        'type': code.type.name,
      });
      
      return result ?? false;
    } catch (e) {
      print('OPPO 灵动岛更新失败: $e');
      return false;
    }
  }
  
  /// 隐藏灵动岛
  Future<bool> hideCode(String codeId) async {
    if (!_isInitialized) await init();
    if (!_isSupported) return false;
    
    try {
      final result = await _channel.invokeMethod<bool>('hideCode', {
        'id': codeId,
      });
      
      return result ?? false;
    } catch (e) {
      print('OPPO 灵动岛隐藏失败: $e');
      return false;
    }
  }
  
  /// 隐藏所有灵动岛
  Future<bool> hideAll() async {
    if (!_isInitialized) await init();
    if (!_isSupported) return false;
    
    try {
      final result = await _channel.invokeMethod<bool>('hideAll');
      return result ?? false;
    } catch (e) {
      print('OPPO 灵动岛隐藏所有失败: $e');
      return false;
    }
  }
}
