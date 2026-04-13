import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/code_item.dart';

/// 取件码卡片组件
class CodeCard extends StatelessWidget {
  final CodeItem code;
  final VoidCallback? onUsed;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const CodeCard({
    super.key,
    required this.code,
    this.onUsed,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired = code.isExpired;
    
    return Slidable(
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onUsed?.call(),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            icon: Icons.check,
            label: '已取',
          ),
          SlidableAction(
            onPressed: (_) => onDelete?.call(),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: '删除',
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 类型图标
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getTypeColor(code.type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      code.type.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // 信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 来源
                      Text(
                        code.source,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // 取件码
                      Text(
                        code.code,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: isExpired ? Colors.grey : null,
                          decoration: isExpired 
                              ? TextDecoration.lineThrough 
                              : null,
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // 过期时间
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: isExpired ? Colors.red : Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            code.remainingTimeDesc,
                            style: TextStyle(
                              fontSize: 12,
                              color: isExpired ? Colors.red : Colors.grey[500],
                            ),
                          ),
                          if (code.location != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                code.location!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                // 复制按钮
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyCode(context),
                  tooltip: '复制',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 复制取件码
  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: code.code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制：${code.code}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// 获取类型颜色
  Color _getTypeColor(CodeType type) {
    switch (type) {
      case CodeType.express:
        return Colors.orange;
      case CodeType.food:
        return Colors.green;
      case CodeType.travel:
        return Colors.blue;
      case CodeType.other:
        return Colors.purple;
    }
  }
}
