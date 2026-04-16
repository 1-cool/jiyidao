import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/code_item.dart';
import 'code_manager.dart';
import 'pattern_matcher.dart';

/// 短信监听服务
/// 
/// 通过 EventChannel 接收原生层的短信取件码事件
class SmsListenerService {
  static const String _eventChannelName = 'com.pincode.app/sms_receiver';
  static const String _methodChannelName = 'com.pincode.app/method';
  
  static const EventChannel _eventChannel = EventChannel(_eventChannelName);
  static const MethodChannel _methodChannel = MethodChannel(_methodChannelName);
  
  static const String _prefKey = 'sms_listener_enabled';
  
  StreamSubscription? _subscription;
  CodeManager? _codeManager;
  
  /// 单例模式
  static final SmsListenerService _instance = SmsListenerService._internal();
  factory SmsListenerService() => _instance;
  SmsListenerService._internal();
  
  /// 是否已启用
  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;
  
  /// 初始化服务
  /// 
  /// [codeManager] 取件码管理器，用于自动添加识别到的取件码
  Future<void> init(CodeManager codeManager) async {
    _codeManager = codeManager;
    
    // 读取设置（默认关闭，需要用户主动开启）
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_prefKey) ?? false;
    
    // 同步到原生层
    await _methodChannel.invokeMethod('setSmsListenerEnabled', _isEnabled);
    
    if (_isEnabled) {
      _startListening();
    }
  }
  
  /// 启用短信监听
  Future<void> enable() async {
    if (_isEnabled) return;
    
    _isEnabled = true;
    
    // 保存设置
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
    
    // 同步到原生层
    await _methodChannel.invokeMethod('setSmsListenerEnabled', true);
    
    _startListening();
  }
  
  /// 禁用短信监听
  Future<void> disable() async {
    if (!_isEnabled) return;
    
    _isEnabled = false;
    
    // 保存设置
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, false);
    
    // 同步到原生层
    await _methodChannel.invokeMethod('setSmsListenerEnabled', false);
    
    _stopListening();
  }
  
  /// 切换开关
  Future<void> toggle() async {
    if (_isEnabled) {
      await disable();
    } else {
      await enable();
    }
  }
  
  /// 开始监听
  void _startListening() {
    _subscription?.cancel();
    
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        _handleSmsEvent(event as Map);
      },
      onError: (dynamic error) {
        print('SmsListenerService 错误: $error');
      },
      onDone: () {
        print('SmsListenerService 流结束');
      },
    );
    
    print('SmsListenerService 已启动');
  }
  
  /// 停止监听
  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
    print('SmsListenerService 已停止');
  }
  
  /// 处理短信事件
  Future<void> _handleSmsEvent(Map event) async {
    final code = event['code'] as String?;
    final body = event['body'] as String?;
    final sender = event['sender'] as String?;
    
    if (_codeManager == null) return;
    
    print('收到短信取件码事件: code=$code, sender=$sender');
    
    // 优先使用 body 解析完整信息
    if (body != null && body.isNotEmpty) {
      final result = PatternMatcher.match(body);
      if (result != null) {
        // 创建取件码项
        final codeItem = result.toCodeItem();
        
        // 检查是否已存在
        if (!await _codeManager!.codeExists(codeItem.code)) {
          await _codeManager!.addCode(codeItem);
          print('已自动添加取件码: ${codeItem.code}');
        } else {
          print('取件码已存在，跳过: ${codeItem.code}');
        }
        return;
      }
    }
    
    // 如果 body 解析失败，但有 code，直接使用 code
    if (code != null && code.isNotEmpty) {
      // 检查是否已存在
      if (!await _codeManager!.codeExists(code)) {
        final codeItem = CodeItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          code: code,
          type: CodeType.express,
          source: sender ?? '未知来源',
          createTime: DateTime.now(),
          rawMessage: body,
        );
        await _codeManager!.addCode(codeItem);
        print('已自动添加取件码（简化模式）: $code');
      } else {
        print('取件码已存在，跳过: $code');
      }
    }
  }
  
  /// 释放资源
  void dispose() {
    _stopListening();
  }
}
