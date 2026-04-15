import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../services/sms_listener_service.dart';
import '../theme/theme_manager.dart';

/// 提醒模式
enum ReminderMode {
  everyday('每天', '每天提醒'),
  workday('工作日', '周一至周五提醒'),
  disabled('关闭', '不提醒');

  final String label;
  final String description;
  const ReminderMode(this.label, this.description);
}

/// 设置页面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 下班提醒时间
  TimeOfDay _reminderTime = const TimeOfDay(hour: 18, minute: 30);
  // 提醒模式
  ReminderMode _reminderMode = ReminderMode.workday;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final hour = prefs.getInt('reminder_hour') ?? 18;
    final minute = prefs.getInt('reminder_minute') ?? 30;
    final modeIndex = prefs.getInt('reminder_mode') ?? 1; // 默认工作日
    
    // 边界检查，防止数组越界
    final safeModeIndex = (modeIndex >= 0 && modeIndex < ReminderMode.values.length) 
        ? modeIndex 
        : 1;
    
    setState(() {
      _reminderTime = TimeOfDay(hour: hour, minute: minute);
      _reminderMode = ReminderMode.values[safeModeIndex];
    });
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setInt('reminder_hour', _reminderTime.hour);
    await prefs.setInt('reminder_minute', _reminderTime.minute);
    await prefs.setInt('reminder_mode', _reminderMode.index);
    
    if (_reminderMode != ReminderMode.disabled) {
      _scheduleReminder();
    } else {
      // 关闭提醒时取消定时通知
      _cancelReminder();
    }
  }

  /// 取消定时提醒
  Future<void> _cancelReminder() async {
    final notificationService = NotificationService();
    await notificationService.init();
    await notificationService.cancelDailyReminder(workdayOnly: true);
    await notificationService.cancelDailyReminder(workdayOnly: false);
  }

  /// 设置定时提醒
  Future<void> _scheduleReminder() async {
    // 使用全局 NotificationService 实例
    final notificationService = context.read<NotificationService>();
    
    debugPrint('开始设置定时提醒: ${_reminderTime.hour}:${_reminderTime.minute}, 模式: $_reminderMode');
    
    final success = await notificationService.scheduleDailyReminder(
      hour: _reminderTime.hour,
      minute: _reminderTime.minute,
      workdayOnly: _reminderMode == ReminderMode.workday,
    );
    
    debugPrint('设置定时提醒结果: $success');
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _reminderMode == ReminderMode.workday
                  ? '已设置工作日 ${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')} 提醒'
                  : '已设置每天 ${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')} 提醒',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置提醒失败，请检查通知权限')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // 外观设置
          _buildSectionHeader('外观'),
          
          // 主题模式
          Consumer<ThemeManager>(
            builder: (context, themeManager, child) {
              return ListTile(
                leading: Icon(themeManager.getThemeModeIcon()),
                title: const Text('主题模式'),
                subtitle: Text(themeManager.getThemeModeName()),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectThemeMode(context, themeManager),
              );
            },
          ),
          
          const Divider(),
          
          // 短信识别设置
          _buildSectionHeader('短信识别'),
          
          Consumer<SmsListenerService>(
            builder: (context, smsListener, child) {
              return ListTile(
                leading: const Icon(Icons.sms_outlined),
                title: const Text('短信自动识别'),
                subtitle: Text(smsListener.isEnabled ? '已开启' : '已关闭'),
                trailing: Switch(
                  value: smsListener.isEnabled,
                  onChanged: (value) async {
                    if (value) {
                      // 开启前检查短信权限
                      final status = await Permission.sms.status;
                      if (!status.isGranted) {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('需要短信权限'),
                            content: const Text('开启短信识别需要授予短信读取权限。是否继续？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('授权'),
                              ),
                            ],
                          ),
                        );
                        
                        if (result != true) return;
                        
                        final granted = await Permission.sms.request();
                        if (!granted.isGranted) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('短信权限未授予')),
                            );
                          }
                          return;
                        }
                      }
                      await smsListener.enable();
                    } else {
                      await smsListener.disable();
                    }
                    // 触发 UI 更新
                    setState(() {});
                  },
                ),
              );
            },
          ),
          
          // 短信识别说明
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '开启后，收到取件短信时会自动识别并添加到列表。关闭后将不再读取短信。',
                      style: TextStyle(color: Colors.orange[700], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const Divider(),
          
          // 通知设置
          _buildSectionHeader('通知设置'),
          
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('通知权限'),
            subtitle: const Text('点击检查通知权限状态'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _checkNotificationPermission,
          ),
          
          const Divider(),
          
          // 取快递提醒
          _buildSectionHeader('取快递提醒'),
          
          // 提醒模式选择
          ListTile(
            leading: const Icon(Icons.alarm),
            title: const Text('提醒模式'),
            subtitle: Text(_reminderMode.description),
            trailing: const Icon(Icons.chevron_right),
            onTap: _selectReminderMode,
          ),
          
          // 提醒时间
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('提醒时间'),
            subtitle: Text(
              '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            enabled: _reminderMode != ReminderMode.disabled,
            trailing: const Icon(Icons.chevron_right),
            onTap: _selectReminderTime,
          ),
          
          // 提示信息
          if (_reminderMode != ReminderMode.disabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _reminderMode == ReminderMode.workday
                            ? '将在周一至周五的 ${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')} 提醒你取快递（仅当有待取快递时）'
                            : '将在每天的 ${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')} 提醒你取快递（仅当有待取快递时）',
                        style: TextStyle(color: Colors.blue[700], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          const Divider(),
          
          // 关于
          _buildSectionHeader('关于'),
          
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('版本'),
            subtitle: Text('v1.0.5'),
          ),
          

        ],
      ),
    );
  }

  /// 构建分组标题
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  /// 检查通知权限
  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    
    if (!mounted) return;
    
    if (status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('通知权限已开启')),
      );
    } else {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('通知权限未开启'),
          content: const Text('是否前往系统设置开启通知权限？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('去设置'),
            ),
          ],
        ),
      );
      
      if (result == true) {
        await openAppSettings();
      }
    }
  }

  /// 选择提醒模式
  Future<void> _selectReminderMode() async {
    final result = await showDialog<ReminderMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择提醒模式'),
        children: ReminderMode.values.map((mode) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, mode),
            child: ListTile(
              leading: Radio<ReminderMode>(
                value: mode,
                groupValue: _reminderMode,
                onChanged: (_) {}, // 不需要处理，点击整行即可
              ),
              title: Text(mode.label),
              subtitle: Text(mode.description),
            ),
          );
        }).toList(),
      ),
    );
    
    if (result != null && result != _reminderMode) {
      setState(() => _reminderMode = result);
      _saveSettings();
    }
  }

  /// 选择提醒时间
  Future<void> _selectReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      helpText: '选择提醒时间',
      confirmText: '确定',
      cancelText: '取消',
    );
    
    if (picked != null && picked != _reminderTime) {
      setState(() => _reminderTime = picked);
      _saveSettings();
    }
  }

  /// 选择主题模式
  Future<void> _selectThemeMode(BuildContext context, ThemeManager themeManager) async {
    final result = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择主题模式'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ThemeMode.system),
            child: ListTile(
              leading: Radio<ThemeMode>(
                value: ThemeMode.system,
                groupValue: themeManager.themeMode,
                onChanged: (_) {},
              ),
              leadingAndTrailingTextStyle: const TextStyle(fontSize: 20),
              title: const Text('跟随系统'),
              subtitle: const Text('自动跟随系统设置'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ThemeMode.light),
            child: ListTile(
              leading: Radio<ThemeMode>(
                value: ThemeMode.light,
                groupValue: themeManager.themeMode,
                onChanged: (_) {},
              ),
              title: const Text('亮色模式'),
              subtitle: const Text('始终使用亮色主题'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ThemeMode.dark),
            child: ListTile(
              leading: Radio<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: themeManager.themeMode,
                onChanged: (_) {},
              ),
              title: const Text('暗黑模式'),
              subtitle: const Text('始终使用深蓝黑主题'),
            ),
          ),
        ],
      ),
    );
    
    if (result != null) {
      await themeManager.setThemeMode(result);
    }
  }
}
