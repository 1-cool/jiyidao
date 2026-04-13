import '../models/code_item.dart';

/// 正则匹配规则
class PatternRule {
  /// 正则表达式
  final RegExp pattern;
  
  /// 码类型
  final CodeType type;
  
  /// 来源名称提取组（正则中的分组索引）
  final int? sourceGroup;
  
  /// 码提取组（正则中的分组索引，默认为1）
  final int codeGroup;

  const PatternRule({
    required this.pattern,
    required this.type,
    this.sourceGroup,
    this.codeGroup = 1,
  });
}

/// 取件码识别引擎
/// 
/// 使用正则表达式匹配短信中的取件码、取餐码等信息
class PatternMatcher {
  /// 匹配规则库
  /// 
  /// 规则按优先级排序，越靠前的优先匹配
  static final List<PatternRule> _rules = [
    // ============ 快递类 ============
    
    // 申通快递格式：请凭0706-0331到XX领取
    PatternRule(
      pattern: RegExp(r'请凭\s*(\d{4}-\d{4})\s*到'),
      type: CodeType.express,
    ),
    
    // 菜鸟驿站格式：取件码：12-3-4567
    PatternRule(
      pattern: RegExp(r'取件码[：:]\s*(\d{1,2}-\d{1,2}-\d{3,4})'),
      type: CodeType.express,
      sourceGroup: null, // 从上下文提取
    ),
    
    // 丰巢快递柜：取件码 123456
    PatternRule(
      pattern: RegExp(r'(?:丰巢|快递柜).*?取件码[：:]?\s*(\d{6,8})'),
      type: CodeType.express,
    ),
    
    // 通用取件码：取件码：123456
    PatternRule(
      pattern: RegExp(r'取件码[：:]\s*(\d{4,8})'),
      type: CodeType.express,
    ),
    
    // 快递通知：您的快递已到...取件码123456
    PatternRule(
      pattern: RegExp(r'(?:快递|包裹).*?(?:取件码|取货码)[：:]?\s*(\d{4,8})'),
      type: CodeType.express,
    ),
    
    // 驿站格式：请到XX驿站取件，码：12-3-4567
    PatternRule(
      pattern: RegExp(r'(?:驿站|快递点).*?(?:码|取件码)[：:]?\s*(\d{1,2}-\d{1,2}-\d{3,4})'),
      type: CodeType.express,
    ),
    
    // 凭码取件：凭码123456取件
    PatternRule(
      pattern: RegExp(r'凭[码号]\s*(\d{4,8})\s*(?:取件|领取)'),
      type: CodeType.express,
    ),
    
    // 取货码：取货码123456
    PatternRule(
      pattern: RegExp(r'取货码[：:]?\s*(\d{4,8})'),
      type: CodeType.express,
    ),
    
    // ============ 外卖类 ============
    
    // 美团取餐码：取餐码：123
    PatternRule(
      pattern: RegExp(r'(?:美团|外卖).*?取餐码[：:]\s*(\d{2,4})'),
      type: CodeType.food,
    ),
    
    // 通用取餐码
    PatternRule(
      pattern: RegExp(r'取餐码[：:]\s*(\d{2,4})'),
      type: CodeType.food,
    ),
    
    // 饿了么取餐码
    PatternRule(
      pattern: RegExp(r'(?:饿了么|蜂鸟).*?(?:取餐码|取货码)[：:]?\s*(\d{2,4})'),
      type: CodeType.food,
    ),
    
    // ============ 出行类 ============
    
    // 登机口
    PatternRule(
      pattern: RegExp(r'登机口[：:]\s*([A-Z]\d{1,3})'),
      type: CodeType.travel,
    ),
    
    // 座位号
    PatternRule(
      pattern: RegExp(r'座位[：:]\s*(\d{1,2}[A-F])'),
      type: CodeType.travel,
    ),
    
    // 航班号
    PatternRule(
      pattern: RegExp(r'航班[：:]\s*([A-Z]{2}\d{3,4})'),
      type: CodeType.travel,
    ),
    
    // ============ 其他 ============
    
    // 验证码（作为备选）
    PatternRule(
      pattern: RegExp(r'验证码[：:]\s*(\d{4,6})'),
      type: CodeType.other,
    ),
  ];

  /// 匹配结果
  static const int _maxSourceLength = 20;

  /// 从文本中提取取件码
  /// 
  /// 返回匹配结果，如果没有匹配则返回 null
  static MatchResult? match(String text) {
    for (final rule in _rules) {
      final match = rule.pattern.firstMatch(text);
      if (match != null) {
        final code = match.group(rule.codeGroup) ?? '';
        if (code.isEmpty) continue;
        
        // 提取来源
        String source = _extractSource(text, match);
        
        // 提取过期时间
        DateTime? expireTime = _extractExpireTime(text);
        
        // 提取地点
        String? location = _extractLocation(text);
        
        return MatchResult(
          code: code,
          type: rule.type,
          source: source,
          location: location,
          expireTime: expireTime,
          rawMessage: text,
        );
      }
    }
    return null;
  }

  /// 从文本中提取来源
  static String _extractSource(String text, RegExpMatch match) {
    // 常见来源关键词
    final sourcePatterns = [
      (RegExp(r'(菜鸟驿站|驿站|快递点)'), '菜鸟驿站'),
      (RegExp(r'(丰巢|快递柜)'), '丰巢快递柜'),
      (RegExp(r'(美团|美团外卖)'), '美团外卖'),
      (RegExp(r'(饿了么|蜂鸟)'), '饿了么'),
      (RegExp(r'(顺丰|顺丰快递)'), '顺丰快递'),
      (RegExp(r'(京东|京东快递)'), '京东快递'),
      (RegExp(r'(中通|中通快递)'), '中通快递'),
      (RegExp(r'(圆通|圆通快递)'), '圆通快递'),
      (RegExp(r'(韵达|韵达快递)'), '韵达快递'),
      (RegExp(r'(申通|申通快递)'), '申通快递'),
    ];
    
    for (final (pattern, name) in sourcePatterns) {
      if (pattern.hasMatch(text)) {
        return name;
      }
    }
    
    // 默认来源
    return '未知来源';
  }

  /// 从文本中提取过期时间
  static DateTime? _extractExpireTime(String text) {
    // 匹配"X天内取件"、"X小时后过期"等
    final dayPattern = RegExp(r'(\d+)\s*天[内后]');
    final hourPattern = RegExp(r'(\d+)\s*小时[内后]');
    
    final dayMatch = dayPattern.firstMatch(text);
    if (dayMatch != null) {
      final days = int.tryParse(dayMatch.group(1) ?? '0') ?? 0;
      return DateTime.now().add(Duration(days: days));
    }
    
    final hourMatch = hourPattern.firstMatch(text);
    if (hourMatch != null) {
      final hours = int.tryParse(hourMatch.group(1) ?? '0') ?? 0;
      return DateTime.now().add(Duration(hours: hours));
    }
    
    // 默认3天后过期
    return DateTime.now().add(const Duration(days: 3));
  }

  /// 从文本中提取地点
  static String? _extractLocation(String text) {
    // 匹配"请到XX取件"、"XX驿站"等
    final locationPattern = RegExp(r'(?:请到|前往|到)([^，。！？\n]{2,10})(?:取件|取货|领取)');
    final match = locationPattern.firstMatch(text);
    if (match != null) {
      return match.group(1)?.trim();
    }
    return null;
  }

  /// 添加自定义规则
  static void addRule(PatternRule rule) {
    _rules.insert(0, rule); // 插入到最前面，优先级最高
  }

  /// 获取所有规则
  static List<PatternRule> get rules => List.unmodifiable(_rules);
}

/// 匹配结果
class MatchResult {
  /// 提取的码
  final String code;
  
  /// 码类型
  final CodeType type;
  
  /// 来源
  final String source;
  
  /// 地点
  final String? location;
  
  /// 过期时间
  final DateTime? expireTime;
  
  /// 原始消息
  final String rawMessage;

  MatchResult({
    required this.code,
    required this.type,
    required this.source,
    this.location,
    this.expireTime,
    required this.rawMessage,
  });

  /// 转换为 CodeItem
  CodeItem toCodeItem() {
    return CodeItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      code: code,
      type: type,
      source: source,
      location: location,
      expireTime: expireTime ?? DateTime.now().add(const Duration(days: 3)),
      createTime: DateTime.now(),
      rawMessage: rawMessage,
    );
  }
}
