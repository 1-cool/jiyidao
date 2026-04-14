import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/code_item.dart';
import '../services/code_manager.dart';
import '../services/pattern_matcher.dart';

/// 添加取件码页面
class AddCodeScreen extends StatefulWidget {
  const AddCodeScreen({super.key});

  @override
  State<AddCodeScreen> createState() => _AddCodeScreenState();
}

class _AddCodeScreenState extends State<AddCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _sourceController = TextEditingController();
  final _locationController = TextEditingController();
  final _recognizeController = TextEditingController(); // 识别输入框
  
  CodeType _selectedType = CodeType.express;
  
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // 监听剪贴板
    _checkClipboard();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _sourceController.dispose();
    _locationController.dispose();
    _recognizeController.dispose();
    super.dispose();
  }

  /// 检查剪贴板是否有取件码
  Future<void> _checkClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    
    if (text != null && text.isNotEmpty) {
      final result = PatternMatcher.match(text);
      if (result != null && mounted) {
        // 自动填充
        setState(() {
          _codeController.text = result.code;
          _sourceController.text = result.source;
          _selectedType = result.type;
          if (result.location != null) {
            _locationController.text = result.location!;
          }
        });
        
        // 提示用户
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已从剪贴板识别取件码')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加'),
        actions: [
          TextButton.icon(
            onPressed: _isProcessing ? null : _save,
            icon: const Icon(Icons.check),
            label: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 取件码输入
            TextFormField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: _selectedType == CodeType.food ? '取餐码 *' : '取件码 *',
                hintText: '如：12-3-4567 或 0706-0331',
                prefixIcon: const Icon(Icons.qr_code),
              ),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z\-]')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return _selectedType == CodeType.food ? '请输入取餐码' : '请输入取件码';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // 类型选择
            DropdownButtonFormField<CodeType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: '类型',
                prefixIcon: Icon(Icons.category),
              ),
              items: CodeType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text('${type.emoji} ${type.label}'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            // 来源输入
            TextFormField(
              controller: _sourceController,
              decoration: const InputDecoration(
                labelText: '来源 *',
                hintText: '如：菜鸟驿站、申通快递',
                prefixIcon: Icon(Icons.store),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入来源';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // 地点输入
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: '地点（可选）',
                hintText: '如：东门快递柜、水岸明珠世纪华联',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            
            const Divider(height: 32),
            
            // 快捷操作
            const Text(
              '快捷操作',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 从剪贴板粘贴
            OutlinedButton.icon(
              onPressed: _pasteFromClipboard,
              icon: const Icon(Icons.content_paste),
              label: const Text('从剪贴板识别'),
            ),
            
            const SizedBox(height: 12),
            
            // 手动输入识别
            TextField(
              controller: _recognizeController,
              decoration: InputDecoration(
                labelText: '粘贴内容识别',
                hintText: '粘贴短信内容，自动识别取件码',
                prefixIcon: const Icon(Icons.text_fields),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: '识别',
                  onPressed: () => _recognizeText(_recognizeController.text),
                ),
              ),
              maxLines: 3,
              onSubmitted: _recognizeText,
            ),
            
            const SizedBox(height: 24),
            
            // 提示
            Container(
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
                      '收到取件短信后会自动识别并添加，无需手动输入',
                      style: TextStyle(color: Colors.blue[700], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 从剪贴板粘贴
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    
    if (text == null || text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('剪贴板为空')),
        );
      }
      return;
    }
    
    _recognizeText(text);
  }

  /// 识别文本内容
  void _recognizeText(String text) {
    if (text.isEmpty) return;
    
    final result = PatternMatcher.match(text);
    
    if (result != null) {
      setState(() {
        _codeController.text = result.code;
        _sourceController.text = result.source;
        _selectedType = result.type;
        if (result.location != null) {
          _locationController.text = result.location!;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('识别成功！')),
        );
      }
    } else {
      // 没识别到，清空识别框并提示用户手动输入
      _recognizeController.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未能自动识别，请手动填写取件码')),
        );
      }
    }
  }

  /// 保存
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isProcessing = true);
    
    try {
      final code = await context.read<CodeManager>().addManualCode(
        code: _codeController.text.trim(),
        type: _selectedType,
        source: _sourceController.text.trim(),
        location: _locationController.text.trim().isNotEmpty 
            ? _locationController.text.trim() 
            : null,
      );
      
      if (code != null && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('添加成功')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该取件码已存在')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}
