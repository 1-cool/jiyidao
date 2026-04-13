import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// 设置页面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 下班提醒时间
  TimeOfDay _reminderTime = const TimeOfDay(hour: 18, minute: 30);
  bool _reminderEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    // TODO: 从 SharedPreferences 加载设置
    // 这里暂时使用默认值
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    // TODO: 保存到 SharedPreferences
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
          
          SwitchListTile(
            secondary: const Icon(Icons.alarm),
            title: const Text('启用下班提醒'),
            subtitle: const Text('每天下班时间提醒拿快递'),
            value: _reminderEnabled,
            onChanged: (value) {
              setState(() => _reminderEnabled = value);
              _saveSettings();
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('提醒时间'),
            subtitle: Text(
              '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            enabled: _reminderEnabled,
            trailing: const Icon(Icons.chevron_right),
            onTap: _selectReminderTime,
          ),
          
          const Divider(),
          
          // 关于
          _buildSectionHeader('关于'),
          
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('版本'),
            subtitle: Text('1.0.0'),
          ),
          
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('开源地址'),
            subtitle: const Text('github.com/1-cool/jiyidao'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              // TODO: 打开浏览器
            },
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

  /// 选择提醒时间
  Future<void> _selectReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      locale: const Locale('zh', 'CN'),
      helpText: '选择提醒时间',
      confirmText: '确定',
      cancelText: '取消',
    );
    
    if (picked != null) {
      setState(() => _reminderTime = picked);
      _saveSettings();
    }
  }
}
