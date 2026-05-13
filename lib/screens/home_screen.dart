import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/code_item.dart';
import '../services/code_manager.dart';
import '../widgets/code_card.dart';
import 'add_code_screen.dart';
import 'ocr_screen.dart';
import 'settings_screen.dart';

/// 主界面
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _hasCheckedPermission = false;
  bool _isFabExpanded = false; // 展开状态
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _checkNotificationPermission();
    
    // 初始化动画控制器
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
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
      floatingActionButton: _buildExpandableFab(),
    );
  }

  /// 构建展开式 FAB
  Widget _buildExpandableFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 展开的选项（从下到上）
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _isFabExpanded
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 文本添加
                    _FabOption(
                      icon: Icons.edit,
                      label: '文本添加',
                      onPressed: () {
                        _toggleFab();
                        _addCode(context);
                      },
                    ),
                    const SizedBox(height: 12),
                    // 图片识别
                    _FabOption(
                      icon: Icons.photo_library,
                      label: '图片识别',
                      onPressed: () {
                        _toggleFab();
                        _openOcrScreen();
                      },
                    ),
                    const SizedBox(height: 12),
                    // 拍照识别
                    _FabOption(
                      icon: Icons.camera_alt,
                      label: '拍照识别',
                      onPressed: () {
                        _toggleFab();
                        _openOcrScreen(camera: true);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        
        // 主按钮
        FloatingActionButton(
          onPressed: _toggleFab,
          child: AnimatedRotation(
            turns: _isFabExpanded ? 0.125 : 0, // 旋转 45 度
            duration: const Duration(milliseconds: 200),
            child: Icon(_isFabExpanded ? Icons.close : Icons.add),
          ),
        ),
      ],
    );
  }

  /// 切换 FAB 展开状态
  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _fabAnimationController.forward();
      } else {
        _fabAnimationController.reverse();
      }
    });
  }

  /// 打开 OCR 页面
  void _openOcrScreen({bool camera = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OcrScreen(initialCamera: camera),
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
            '点击右下角按钮添加，或复制短信后自动识别',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
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
    // 保存外部 context 引用，避免 bottomSheet 内部 context 失效
    final homeContext = context;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
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
                        Navigator.pop(sheetContext);
                        _markAsUsed(homeContext, code);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('已取件'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _deleteCode(homeContext, code);
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

/// FAB 选项组件
class _FabOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _FabOption({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 12),
        FloatingActionButton.small(
          heroTag: label,
          onPressed: onPressed,
          child: Icon(icon),
        ),
      ],
    );
  }
}
