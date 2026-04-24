import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/code_item.dart';
import 'code_manager.dart';
import 'pattern_matcher.dart';

/// 短信监听服务
/// 
/// 通过 EventChannel 接收原生层的短信事件
/// 所有正则匹配统一在 Flutter 端的 PatternMatcher 处理
class SmsListenerService {
  static const String _eventChannelName = 'com.pincode.app/sms_receiver';
  static const String _methodChannelName = 'com.pincode.app/method';
  static const String _prefKey = 'sms_listener_enabled';
  
  static const EventChannel _eventChannel = EventChannel(_eventChannelName);
  static const MethodChannel _methodChannel = MethodChannel(_methodChannelName);
  
  StreamSubscription? _subscription;
  CodeManager? _codeManager;
  
  /// 单例模式 - 状态变量必须是 static 的
  static bool _isEnabled = false;
  static final SmsListenerService _instance = SmsListenerService._internal();
  
  factory SmsListenerService() => _instance;
  SmsListenerService._internal();
  
  bool get isEnabled => _isEnabled;
  
  /// 初始化服务
  Future<void> init(CodeManager codeManager) async {
    _codeManager = codeManager;
    
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_prefKey) ?? false;
    
    await _methodChannel.invokeMethod('setSmsListenerEnabled', _isEnabled);
    
    if (_isEnabled) _startListening();
  }
  
  /// 启用短信监听
  Future<void> enable() async {
    if (_isEnabled) return;
    
    _isEnabled = true;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
    
    await _methodChannel.invokeMethod('setSmsListenerEnabled', true);
    _startListening();
  }
  
  /// 禁用短信监听
  Future<void> disable() async {
    if (!_isEnabled) return;
    
    _isEnabled = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, false);
    
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
      (dynamic event) => _handleSmsEvent(event as Map),
      onError: (dynamic error) => debugPrint('SmsListenerService 错误: $error'),
      onDone: () => debugPrint('SmsListenerService 流结束'),
    );
    
    debugPrint('SmsListenerService 已启动');
  }
  
  /// 停止监听
  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
    debugPrint('SmsListenerService 已停止');
  }
  
  /// 处理短信事件
  Future<void> _handleSmsEvent(Map event) async {
    final body = event['body'] as String?;
    final sender = event['sender'] as String?;
    
    if (_codeManager == null || body == null || body.isEmpty) return;
    
    debugPrint('收到短信: sender=$sender, body=${body.take(50)}...');
    
    // 统一使用 PatternMatcher 进行正则匹配
    final result = PatternMatcher.match(body);
    if (result == null) {
      debugPrint('未能识别取件码');
      return;
    }
    
    // 检查是否已存在
    if (await _codeManager!.codeExists(result.code)) {
      debugPrint('取件码已存在: ${result.code}');
      return;
    }
    
    // 添加取件码
    await _codeManager!.addCode(result.toCodeItem());
    debugPrint('已自动添加取件码: ${result.code}');
  }
  
  /// 释放资源
  void dispose() {
    _stopListening();
  }
}
