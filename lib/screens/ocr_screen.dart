import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/code_item.dart';
import '../services/code_manager.dart';
import '../services/ocr_service.dart';
import '../services/pattern_matcher.dart';

/// 图片识别页面
/// 
/// 功能：
/// - 从相册选择图片识别
/// - 拍照识别
/// - 显示识别结果
/// - 一键添加到码列表
class OcrScreen extends StatefulWidget {
  final bool initialCamera; // 是否直接打开相机

  const OcrScreen({super.key, this.initialCamera = false});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final _ocrService = OcrService();
  final _imagePicker = ImagePicker();
  
  File? _selectedImage;
  List<String> _recognizedTexts = [];
  List<MatchResult> _matchResults = [];
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeOcr();
    
    // 如果 initialCamera 为 true，延迟打开相机
    if (widget.initialCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _takePhoto();
      });
    }
  }

  /// 初始化 OCR 服务
  Future<void> _initializeOcr() async {
    await _ocrService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('图片识别'),
        actions: [
          if (_matchResults.isNotEmpty)
            TextButton.icon(
              onPressed: _isProcessing ? null : _addAllCodes,
              icon: const Icon(Icons.add_circle),
              label: const Text('全部添加'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 图片预览
          if (_selectedImage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _selectedImage!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // 操作按钮
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('从相册选择'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _takePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('拍照'),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // 处理状态
          if (_isProcessing) ...[
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在识别...'),
                ],
              ),
            ),
          ],
          
          // 错误信息
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // 识别结果
          if (_matchResults.isNotEmpty) ...[
            const Text(
              '识别结果',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            ...List.generate(_matchResults.length, (index) {
              final result = _matchResults[index];
              return Card(
                child: ListTile(
                  leading: Text(
                    result.type.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(
                    result.code,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  subtitle: Text('${result.source}${result.location != null ? ' · ${result.location}' : ''}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle),
                    onPressed: () => _addCode(result),
                  ),
                ),
              );
            }),
          ],
          
          // 原始识别文本（调试用）
          if (_recognizedTexts.isNotEmpty) ...[
            const SizedBox(height: 24),
            ExpansionTile(
              title: const Text('原始识别文本'),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],  // 深色背景，方便看白色字
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(  // 可选择复制
                    _recognizedTexts.join('\n'),
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 从相册选择图片
  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _recognizedTexts = [];
          _matchResults = [];
          _errorMessage = null;
        });
        await _recognizeImage();
      }
    } catch (e) {
      setState(() {
        _errorMessage = '选择图片失败: $e';
      });
    }
  }

  /// 拍照
  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _recognizedTexts = [];
          _matchResults = [];
          _errorMessage = null;
        });
        await _recognizeImage();
      }
    } catch (e) {
      setState(() {
        _errorMessage = '拍照失败: $e';
      });
    }
  }

  /// 识别图片
  Future<void> _recognizeImage() async {
    if (_selectedImage == null) return;
    
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    
    try {
      // 调用 OCR 识别
      final text = await _ocrService.recognizeText(_selectedImage!.path);
      
      // 用 PatternMatcher 匹配取件码
      final results = <MatchResult>[];
      final result = PatternMatcher.match(text);
      if (result != null) {
        results.add(result);
      }
      
      // 按行分割文本，用于显示
      final textLines = text.isEmpty ? <String>[] : text.split('\n');
      
      setState(() {
        _recognizedTexts = textLines;
        _matchResults = results;
        _isProcessing = false;
      });
      
      // 显示结果
      if (results.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未识别到取件码，请尝试其他图片')),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = '识别失败: $e';
      });
    }
  }

  /// 添加单个取件码
  Future<void> _addCode(MatchResult result) async {
    final code = await context.read<CodeManager>().addManualCode(
      code: result.code,
      type: result.type,
      source: result.source,
      location: result.location,
    );
    
    if (code != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.code} 添加成功')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该取件码已存在')),
      );
    }
  }

  /// 添加所有识别到的取件码
  Future<void> _addAllCodes() async {
    int addedCount = 0;
    int duplicateCount = 0;
    
    for (final result in _matchResults) {
      final code = await context.read<CodeManager>().addManualCode(
        code: result.code,
        type: result.type,
        source: result.source,
        location: result.location,
      );
      
      if (code != null) {
        addedCount++;
      } else {
        duplicateCount++;
      }
    }
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 $addedCount 个取件码${duplicateCount > 0 ? '，$duplicateCount 个重复' : ''}')),
      );
    }
  }
}