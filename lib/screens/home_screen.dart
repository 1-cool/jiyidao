import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/code_item.dart';
import '../services/code_manager.dart';
import '../widgets/code_card.dart';
import 'add_code_screen.dart';
import 'settings_screen.dart';

/// 主界面
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasCheckedPermission = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationPermission();
  }

  /// 检查通知权限
  Future<void> _checkNotificationPermission() async {
    if (_hasCheckedPermission) return;
    _hasCheckedPermission = true;

    final status = await Permission.notification.status;
    if (!status.isGranted && mounted) {
      // 延迟显示，等页面加载完成
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showPermissionDialog();
        }
      });
    }
  }

  /// 显示权限请求对话框
  Future<void> _showPermissionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.orange),
            SizedBox(width: 8),
            Text('开启通知权限'),
          ],
        ),
        content: const Text('为了在收到取件短信时及时提醒您，需要开启通知权限。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('稍后再说'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('去设置'),
          ),
        ],
      ),
    );

    if (result == true) {
      await Permission.notification.request();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('记忆岛'),
        centerTitle: true,
        actions: [
          // 设置按钮
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      body: Consumer<CodeManager>(
        builder: (context, manager, child) {
          final codes = manager.codes;
          
          if (codes.isEmpty) {
            return _buildEmptyState(context);
          }
          
          return RefreshIndicator(
            onRefresh: () => manager.refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: codes.length,
              itemBuilder: (context, index) {
                final code = codes[index];
                return CodeCard(
                  code: code,
                  onUsed: () => _markAsUsed(context, code),
                  onDelete: () => _deleteCode(context, code),
                  onTap: () => _showCodeDetail(context, code),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addCode(context),
        icon: const Icon(Icons.add),
        label: const Text('添加'),
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无取件码',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮添加，或复制短信后自动识别',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _addCode(context),
            icon: const Icon(Icons.add),
            label: const Text('手动添加'),
          ),
        ],
      ),
    );
  }

  /// 添加取件码
  void _addCode(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddCodeScreen(),
      ),
    );
  }

  /// 标记为已使用
  Future<void> _markAsUsed(BuildContext context, CodeItem code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认使用'),
        content: Text('已取件？将移除「${code.code}」'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && context.mounted) {
      await context.read<CodeManager>().markAsUsed(code.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已标记为使用')),
        );
      }
    }
  }

  /// 删除取件码
  Future<void> _deleteCode(BuildContext context, CodeItem code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除「${code.code}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && context.mounted) {
      await context.read<CodeManager>().deleteCode(code.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除')),
        );
      }
    }
  }

  /// 显示取件码详情
  void _showCodeDetail(BuildContext context, CodeItem code) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              // 标题
              Row(
                children: [
                  Text(code.type.emoji, style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          code.source,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          code.type.label,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const Divider(height: 32),
              
              // 取件码（大字）
              Center(
                child: SelectableText(
                  code.code,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 地点信息
              if (code.location != null)
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: '地点',
                  value: code.location!,
                ),
              
              // 创建时间
              _InfoRow(
                icon: Icons.schedule_outlined,
                label: '添加时间',
                value: '${code.createTime.month}月${code.createTime.day}日 ${code.createTime.hour}:${code.createTime.minute.toString().padLeft(2, '0')}',
              ),
              
              if (code.rawMessage != null) ...[
                const SizedBox(height: 16),
                const Text(
                  '原始短信',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    code.rawMessage!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // 操作按钮
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _markAsUsed(context, code);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('已取件'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteCode(context, code);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('删除'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 打开设置
  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }
}

/// 信息行组件
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
