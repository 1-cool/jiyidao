import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

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
    final notificationService = NotificationService();
    await notificationService.init();
    
    final success = await notificationService.scheduleDailyReminder(
      hour: _reminderTime.hour,
      minute: _reminderTime.minute,
      workdayOnly: _reminderMode == ReminderMode.workday,
    );
    
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
          
          // 下班提醒
          _buildSectionHeader('下班提醒'),
          
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
                            ? '将在周一至周五的 ${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')} 提醒你拿快递'
                            : '将在每天的 ${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')} 提醒你拿快递',
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
            subtitle: Text('1.0.0'),
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
}
