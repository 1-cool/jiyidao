import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fast_paddle_ocr/ocr.dart';

/// OCR 服务类 - 使用 NCNN 进行图片文字识别
/// 
/// 功能：
/// - 初始化时从 assets 复制 NCNN 模型到本地存储
/// - 提供图片识别接口
/// - 管理模型生命周期
class OcrService {
  static final OcrService _instance = OcrService._internal();
  factory OcrService() => _instance;
  OcrService._internal();

  // OCR 插件实例
  final Ocr _ocr = Ocr();
  
  // NCNN 模型文件名
  static const String _detParam = 'det.ncnn.param';
  static const String _detBin = 'det.ncnn.bin';
  static const String _recParam = 'rec.ncnn.param';
  static const String _recBin = 'rec.ncnn.bin';

  // 模型本地存储路径
  String? _modelPath;
  bool _initialized = false;

  /// 初始化 OCR 服务
  /// 
  /// 步骤：
  /// 1. 获取本地存储目录
  /// 2. 从 assets 复制模型文件到本地
  /// 3. 加载 NCNN OCR 模型
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      // 获取本地存储目录
      final appDir = await getApplicationDocumentsDirectory();
      _modelPath = appDir.path;

      // 复制模型文件
      final detParamPath = await _copyAssetToFile(_detParam);
      final detBinPath = await _copyAssetToFile(_detBin);
      final recParamPath = await _copyAssetToFile(_recParam);
      final recBinPath = await _copyAssetToFile(_recBin);

      // 加载模型
      await _ocr.loadModel(
        detParam: detParamPath,
        detModel: detBinPath,
        recParam: recParamPath,
        recModel: recBinPath,
        sizeid: 0,  // 模型大小 ID
        cpugpu: 0,  // 0 = CPU, 1 = GPU
      );

      _initialized = true;
      print('OCR 服务初始化成功');
      return true;
    } catch (e) {
      print('OCR 初始化失败: $e');
      return false;
    }
  }

  /// 从 assets 复制模型文件到本地存储
  Future<String> _copyAssetToFile(String assetName) async {
    final file = File('$_modelPath/$assetName');
    
    // 如果文件已存在，直接返回路径
    if (await file.exists()) {
      return file.path;
    }

    // 从 assets 复制
    final data = await rootBundle.load('assets/ocr/$assetName');
    await file.writeAsBytes(data.buffer.asUint8List());
    print('模型文件已复制: $assetName');
    
    return file.path;
  }

  /// 识别图片中的文字
  /// 
  /// 参数：
  /// - imagePath: 图片文件路径
  /// 
  /// 返回：
  /// - 识别出的文字
  Future<String> recognizeText(String imagePath) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // 调用 OCR 插件识别图片
      final text = await _ocr.ocrFromImage(imagePath);
      print('OCR 识别结果: $text');
      return text ?? '';
    } catch (e) {
      print('OCR 识别失败: $e');
      return '';
    }
  }

  /// 检查服务是否已初始化
  bool isInitialized() => _initialized;

  /// 清理模型文件（释放存储空间）
  Future<void> clearModels() async {
    if (_modelPath == null) return;
    
    final modelFiles = [_detParam, _detBin, _recParam, _recBin];
    for (final fileName in modelFiles) {
      final file = File('$_modelPath/$fileName');
      if (await file.exists()) {
        await file.delete();
      }
    }
    _initialized = false;
    print('OCR 模型文件已清理');
  }
}
