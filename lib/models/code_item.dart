/// 取件码数据模型
/// 
/// 用于存储取件码、取餐码、登机口等临时信息
class CodeItem {
  /// 唯一标识
  final String id;
  
  /// 取件码内容，如 "12-3-4567"
  final String code;
  
  /// 类型：快递、外卖、出行、其他
  final CodeType type;
  
  /// 来源，如 "菜鸟驿站"、"美团外卖"
  final String source;
  
  /// 地点，如 "东门快递柜"
  final String? location;
  
  /// 创建时间
  final DateTime createTime;
  
  /// 原始短信内容
  final String? rawMessage;
  
  /// 是否已使用
  final bool isUsed;

  CodeItem({
    required this.id,
    required this.code,
    required this.type,
    required this.source,
    this.location,
    required this.createTime,
    this.rawMessage,
    this.isUsed = false,
  });

  /// 从 JSON 创建
  factory CodeItem.fromJson(Map<String, dynamic> json) {
    return CodeItem(
      id: json['id'] as String,
      code: json['code'] as String,
      type: CodeType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CodeType.other,
      ),
      source: json['source'] as String,
      location: (json['location'] as String?)?.isNotEmpty == true ? json['location'] as String : null,
      createTime: DateTime.parse(json['createTime'] as String),
      rawMessage: json['rawMessage'] as String?,
      isUsed: (json['isUsed'] is int) ? (json['isUsed'] as int) == 1 : (json['isUsed'] as bool?) ?? false,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'type': type.name,
      'source': source,
      'location': location,
      'createTime': createTime.toIso8601String(),
      'rawMessage': rawMessage,
      'isUsed': isUsed,
    };
  }

  /// 复制并修改
  CodeItem copyWith({
    String? id,
    String? code,
    CodeType? type,
    String? source,
    String? location,
    DateTime? createTime,
    String? rawMessage,
    bool? isUsed,
  }) {
    return CodeItem(
      id: id ?? this.id,
      code: code ?? this.code,
      type: type ?? this.type,
      source: source ?? this.source,
      location: location ?? this.location,
      createTime: createTime ?? this.createTime,
      rawMessage: rawMessage ?? this.rawMessage,
      isUsed: isUsed ?? this.isUsed,
    );
  }

  @override
  String toString() {
    return 'CodeItem(id: $id, code: $code, type: $type, source: $source)';
  }
}

/// 取件码类型枚举
enum CodeType {
  /// 快递
  express('快递', '📦'),
  
  /// 外卖
  food('外卖', '🍔'),
  
  /// 出行
  travel('出行', '✈️'),
  
  /// 其他
  other('其他', '📋');

  final String label;
  final String emoji;

  const CodeType(this.label, this.emoji);
}
