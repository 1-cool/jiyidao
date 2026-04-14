import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题管理器
/// 
/// 管理应用的主题模式（跟随系统/亮色/暗黑）
class ThemeManager extends ChangeNotifier {
  static const String _keyThemeMode = 'theme_mode';
  
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeMode get themeMode => _themeMode;
  
  /// 是否是暗黑模式
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  
  /// 是否跟随系统
  bool get isSystemMode => _themeMode == ThemeMode.system;

  /// 初始化，从本地存储加载主题设置
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_keyThemeMode) ?? 0;
    _themeMode = ThemeMode.values[modeIndex];
    notifyListeners();
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeMode, mode.index);
  }

  /// 切换主题模式
  /// 
  /// 循环切换：system -> light -> dark -> system
  Future<void> toggleThemeMode() async {
    final modes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
    final currentIndex = modes.indexOf(_themeMode);
    final nextIndex = (currentIndex + 1) % modes.length;
    await setThemeMode(modes[nextIndex]);
  }

  /// 获取主题模式名称
  String getThemeModeName() {
    switch (_themeMode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '亮色模式';
      case ThemeMode.dark:
        return '暗黑模式';
    }
  }

  /// 获取主题模式图标
  IconData getThemeModeIcon() {
    switch (_themeMode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
    }
  }
}
