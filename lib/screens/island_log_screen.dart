import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 灵动岛日志查看页面
class IslandLogScreen extends StatefulWidget {
  const IslandLogScreen({super.key});

  @override
  State<IslandLogScreen> createState() => _IslandLogScreenState();
}

class _IslandLogScreenState extends State<IslandLogScreen> {
  static const platform = MethodChannel('com.pincode.app/oppo_island');
  
  List<String> _logs = [];
  bool _loading = true;
  
  @override
  void initState() {
    super.initState();
    _loadLogs();
  }
  
  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    
    try {
      final List<dynamic>? logs = await platform.invokeMethod('getLogs');
      setState(() {
        _logs = logs?.cast<String>() ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _logs = ['获取日志失败: $e'];
        _loading = false;
      });
    }
  }
  
  Future<void> _clearLogs() async {
    try {
      await platform.invokeMethod('clearLogs');
      await _loadLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日志已清空')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清空失败: $e')),
        );
      }
    }
  }
  
  void _copyLogs() {
    if (_logs.isEmpty) return;
    
    final text = _logs.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('日志已复制到剪贴板')),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('灵动岛日志'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: '刷新',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'copy':
                  _copyLogs();
                  break;
                case 'clear':
                  _showClearConfirm();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'copy',
                child: ListTile(
                  leading: Icon(Icons.copy),
                  title: Text('复制全部'),
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('清空日志'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        '暂无日志',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '添加一个取件码后日志会显示在这里',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final isError = log.contains('❌');
                    final isWarning = log.contains('⚠️');
                    final isSuccess = log.contains('✅');
                    final isHeader = log.contains('===');
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isError
                            ? Colors.red[50]
                            : isWarning
                                ? Colors.orange[50]
                                : isSuccess
                                    ? Colors.green[50]
                                    : isHeader
                                        ? Colors.blue[50]
                                        : Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isError
                              ? Colors.red[200]!
                              : isWarning
                                  ? Colors.orange[200]!
                                  : isSuccess
                                      ? Colors.green[200]!
                                      : isHeader
                                          ? Colors.blue[200]!
                                          : Colors.grey[300]!,
                        ),
                      ),
                      child: Text(
                        log,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: isError
                              ? Colors.red[700]
                              : isWarning
                                  ? Colors.orange[700]
                                  : isSuccess
                                      ? Colors.green[700]
                                      : isHeader
                                          ? Colors.blue[700]
                                          : Colors.grey[800],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadLogs,
        child: const Icon(Icons.refresh),
        tooltip: '刷新日志',
      ),
    );
  }
  
  void _showClearConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空日志'),
        content: const Text('确定要清空所有日志吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _clearLogs();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
