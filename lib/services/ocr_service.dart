import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:fast_paddle_ocr/fast_paddle_ocr.dart'; // 暂时移除，插件有问题

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

  // NCNN 模型文件名
  static const String _detBin = 'det.ncnn.bin';
  static const String _detParam = 'det.ncnn.param';
  static const String _recBin = 'rec.ncnn.bin';
  static const String _recParam = 'rec.ncnn.param';

  // 模型本地存储路径
  String? _modelPath;
  bool _initialized = false;

  /// 初始化 OCR 服务
  /// 
  /// 步骤：
  /// 1. 获取本地存储目录
  /// 2. 从 assets 复制模型文件到本地
  /// 3. 初始化 NCNN OCR 引擎
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      // 获取本地存储目录
      final appDir = await getApplicationSupportDirectory();
      _modelPath = '${appDir.path}/ocr_models';

      // 创建模型目录
      final modelDir = Directory(_modelPath!);
      if (!modelDir.existsSync()) {
        modelDir.createSync(recursive: true);
      }

      // 复制模型文件
      await _copyModelFiles();

      // 初始化 NCNN OCR（如果插件支持）
      // 注意：fast_paddle_ocr 可能需要特定的初始化方式
      // 这里先预留接口，实际调用需要查看插件文档
      
      _initialized = true;
      return true;
    } catch (e) {
      print('OCR 初始化失败: $e');
      return false;
    }
  }

  /// 从 assets 复制模型文件到本地存储
  Future<void> _copyModelFiles() async {
    final modelFiles = [_detBin, _detParam, _recBin, _recParam];

    for (final fileName in modelFiles) {
      final localPath = '$_modelPath/$fileName';
      final localFile = File(localPath);

      // 如果本地文件已存在且大小正确，跳过复制
      if (localFile.existsSync()) {
        final assetData = await rootBundle.load('assets/ocr/$fileName');
        final assetSize = assetData.lengthInBytes;
        final localSize = localFile.lengthSync();
        if (localSize == assetSize) continue;
      }

      // 从 assets 复制
      final assetData = await rootBundle.load('assets/ocr/$fileName');
      final bytes = assetData.buffer.asUint8List();
      await localFile.writeAsBytes(bytes);
      print('模型文件已复制: $fileName (${bytes.length} bytes)');
    }
  }

  /// 识别图片中的文字
  /// 
  /// 参数：
  /// - imagePath: 图片文件路径
  /// 
  /// 返回：
  /// - 识别出的文字列表
  Future<List<String>> recognizeText(String imagePath) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // 调用 fast_paddle_ocr 进行识别
      // 注意：具体 API 需要查看插件文档
      // 这里先预留接口
      
      // 示例调用（需要根据实际插件 API 调整）
      // final result = await FastPaddleOcr.recognize(imagePath);
      // return result;
      
      // 临时返回空列表，等待插件集成后完善
      print('OCR 识别: $imagePath (待实现)');
      return [];
    } catch (e) {
      print('OCR 识别失败: $e');
      return [];
    }
  }

  /// 检查模型文件是否已准备好
  bool isModelsReady() {
    if (_modelPath == null) return false;
    
    final modelFiles = [_detBin, _detParam, _recBin, _recParam];
    for (final fileName in modelFiles) {
      final file = File('$_modelPath/$fileName');
      if (!file.existsSync()) return false;
    }
    return true;
  }

  /// 获取模型文件总大小（用于显示）
  Future<int> getModelsSize() async {
    if (_modelPath == null) return 0;
    
    int totalSize = 0;
    final modelFiles = [_detBin, _detParam, _recBin, _recParam];
    for (final fileName in modelFiles) {
      final file = File('$_modelPath/$fileName');
      if (file.existsSync()) {
        totalSize += file.lengthSync();
      }
    }
    return totalSize;
  }

  /// 清理模型文件（释放存储空间）
  Future<void> clearModels() async {
    if (_modelPath == null) return;
    
    final modelDir = Directory(_modelPath!);
    if (modelDir.existsSync()) {
      modelDir.deleteSync(recursive: true);
    }
    _initialized = false;
  }
}