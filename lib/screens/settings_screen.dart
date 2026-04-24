import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/sms_listener_service.dart';
import '../theme/theme_manager.dart';
import 'island_log_screen.dart';

/// 设置页面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 定时提醒设置
  int _reminderHour = 18;
  int _reminderMinute = 30;
  int _reminderMode = 1; // 0: 每天, 1: 工作日, 2: 关闭
  
  @override
  void initState() {
    super.initState();
    _loadReminderSettings();
  }
  
  /// 加载定时提醒设置
  Future<void> _loadReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _reminderHour = prefs.getInt('reminder_hour') ?? 18;
      _reminderMinute = prefs.getInt('reminder_minute') ?? 30;
      _reminderMode = prefs.getInt('reminder_mode') ?? 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // 外观设置
          _buildSectionHeader('外观'),
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
                  onChanged: (value) => _toggleSmsListener(smsListener, value),
                ),
              );
            },
          ),
          _buildInfoBox(
            '开启后，收到取件短信时会自动识别并添加到列表。',
            Colors.orange,
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
          ListTile(
            leading: const Icon(Icons.alarm),
            title: const Text('提醒模式'),
            subtitle: Text(_getReminderModeName()),
            trailing: const Icon(Icons.chevron_right),
            onTap: _selectReminderMode,
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('提醒时间'),
            subtitle: Text(
              '${_reminderHour.toString().padLeft(2, '0')}:${_reminderMinute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            enabled: _reminderMode != 2,
            trailing: const Icon(Icons.chevron_right),
            onTap: _selectReminderTime,
          ),
          if (_reminderMode != 2)
            _buildInfoBox(
              _reminderMode == 1
                  ? '将在周一至周五的 ${_reminderHour.toString().padLeft(2, '0')}:${_reminderMinute.toString().padLeft(2, '0')} 提醒你取快递'
                  : '将在每天的 ${_reminderHour.toString().padLeft(2, '0')}:${_reminderMinute.toString().padLeft(2, '0')} 提醒你取快递',
              Colors.blue,
            ),
          
          const Divider(),
          
          // 开发调试
          _buildSectionHeader('开发调试'),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('灵动岛日志'),
            subtitle: const Text('查看流体云/灵动岛调试日志'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const IslandLogScreen()),
            ),
          ),
          
          const Divider(),
          
          // 关于
          _buildSectionHeader('关于'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('版本'),
            subtitle: Text('v1.0.49-beta'),
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
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600]),
      ),
    );
  }

  /// 构建提示框
  Widget _buildInfoBox(String text, MaterialColor color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: color[700], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: TextStyle(color: color[700], fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  /// 切换短信监听
  Future<void> _toggleSmsListener(SmsListenerService smsListener, bool value) async {
    if (value) {
      final status = await Permission.sms.status;
      if (!status.isGranted) {
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('需要短信权限'),
            content: const Text('开启短信识别需要授予短信读取权限。是否继续？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('授权')),
            ],
          ),
        );
        
        if (result != true) return;
        
        final granted = await Permission.sms.request();
        if (!granted.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('短信权限未授予')));
          }
          return;
        }
      }
      await smsListener.enable();
    } else {
      await smsListener.disable();
    }
    setState(() {});
  }

  /// 检查通知权限
  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    
    if (!mounted) return;
    
    if (status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('通知权限已开启')));
    } else {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('通知权限未开启'),
          content: const Text('是否前往系统设置开启通知权限？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('去设置')),
          ],
        ),
      );
      
      if (result == true) await openAppSettings();
    }
  }

  /// 获取提醒模式名称
  String _getReminderModeName() {
    switch (_reminderMode) {
      case 0: return '每天提醒';
      case 1: return '工作日提醒';
      default: return '关闭';
    }
  }

  /// 选择提醒模式
  Future<void> _selectReminderMode() async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择提醒模式'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 0),
            child: ListTile(
              leading: Radio<int>(value: 0, groupValue: _reminderMode, onChanged: (_) {}),
              title: const Text('每天'),
              subtitle: const Text('每天提醒'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 1),
            child: ListTile(
              leading: Radio<int>(value: 1, groupValue: _reminderMode, onChanged: (_) {}),
              title: const Text('工作日'),
              subtitle: const Text('周一至周五提醒'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 2),
            child: ListTile(
              leading: Radio<int>(value: 2, groupValue: _reminderMode, onChanged: (_) {}),
              title: const Text('关闭'),
              subtitle: const Text('不提醒'),
            ),
          ),
        ],
      ),
    );
    
    if (result != null && result != _reminderMode) {
      setState(() => _reminderMode = result);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('reminder_mode', result);
      
      // 更新定时提醒
      final notificationService = context.read<NotificationService>();
      if (result == 2) {
        await notificationService.cancelDailyReminder(workdayOnly: true);
        await notificationService.cancelDailyReminder(workdayOnly: false);
      } else {
        await notificationService.scheduleDailyReminder(
          hour: _reminderHour,
          minute: _reminderMinute,
          workdayOnly: result == 1,
        );
      }
    }
  }

  /// 选择提醒时间
  Future<void> _selectReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
      helpText: '选择提醒时间',
      confirmText: '确定',
      cancelText: '取消',
    );
    
    if (picked != null) {
      setState(() {
        _reminderHour = picked.hour;
        _reminderMinute = picked.minute;
      });
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('reminder_hour', picked.hour);
      await prefs.setInt('reminder_minute', picked.minute);
      
      // 更新定时提醒
      if (_reminderMode != 2) {
        final notificationService = context.read<NotificationService>();
        await notificationService.scheduleDailyReminder(
          hour: picked.hour,
          minute: picked.minute,
          workdayOnly: _reminderMode == 1,
        );
      }
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
              leading: Radio<ThemeMode>(value: ThemeMode.system, groupValue: themeManager.themeMode, onChanged: (_) {}),
              title: const Text('跟随系统'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ThemeMode.light),
            child: ListTile(
              leading: Radio<ThemeMode>(value: ThemeMode.light, groupValue: themeManager.themeMode, onChanged: (_) {}),
              title: const Text('亮色模式'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ThemeMode.dark),
            child: ListTile(
              leading: Radio<ThemeMode>(value: ThemeMode.dark, groupValue: themeManager.themeMode, onChanged: (_) {}),
              title: const Text('暗黑模式'),
            ),
          ),
        ],
      ),
    );
    
    if (result != null) await themeManager.setThemeMode(result);
  }
}
