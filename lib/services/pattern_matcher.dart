import '../models/code_item.dart';

/// 正则匹配规则
class PatternRule {
  /// 正则表达式
  final RegExp pattern;

  /// 码类型
  final CodeType type;

  /// 来源名称提取组(正则中的分组索引)
  final int? sourceGroup;

  /// 码提取组(正则中的分组索引,默认为1)
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
  /// 规则按优先级排序,越靠前的优先匹配
  static final List<PatternRule> _rules = [
    // ============ 快递类 ============

    // 申通快递格式:请凭0706-0331到XX领取
    PatternRule(
      pattern: RegExp(r'请凭\s*(\d{4}-\d{4})\s*到'),
      type: CodeType.express,
    ),

    // 菜鸟驿站格式:取件码:12-3-4567 或 取件码4-3-3020
    PatternRule(
      pattern: RegExp(r'取件码[::]?\s*(\d{1,2}-\d{1,2}-\d{3,4})'),
      type: CodeType.express,
      sourceGroup: null, // 从上下文提取
    ),

    // 丰巢快递柜:取件码 123456
    PatternRule(
      pattern: RegExp(r'(?:丰巢|快递柜).*?取件码[::]?\s*(\d{6,8})'),
      type: CodeType.express,
    ),

    // 通用取件码:取件码:123456 或 取件码123456
    PatternRule(
      pattern: RegExp(r'取件码[::]?\s*(\d{4,8})'),
      type: CodeType.express,
    ),

    // 快递通知:您的快递已到...取件码123456
    PatternRule(
      pattern: RegExp(r'(?:快递|包裹).*?(?:取件码|取货码)[::]?\s*(\d{4,8})'),
      type: CodeType.express,
    ),

    // 驿站格式:请到XX驿站取件,码:12-3-4567
    PatternRule(
      pattern: RegExp(r'(?:驿站|快递点).*?(?:码|取件码)[::]?\s*(\d{1,2}-\d{1,2}-\d{3,4})'),
      type: CodeType.express,
    ),

    // 凭码取件:凭码123456取件
    PatternRule(
      pattern: RegExp(r'凭[码号]\s*(\d{4,8})\s*(?:取件|领取)'),
      type: CodeType.express,
    ),

    // 取货码:取货码123456
    PatternRule(
      pattern: RegExp(r'取货码[::]?\s*(\d{4,8})'),
      type: CodeType.express,
    ),

    // ============ 外卖类 ============

    // 美团取餐码:取餐码:123
    PatternRule(
      pattern: RegExp(r'(?:美团|外卖).*?取餐码[::]\s*(\d{2,4})'),
      type: CodeType.food,
    ),

    // 通用取餐码
    PatternRule(
      pattern: RegExp(r'取餐码[::]\s*(\d{2,4})'),
      type: CodeType.food,
    ),

    // 饿了么取餐码
    PatternRule(
      pattern: RegExp(r'(?:饿了么|蜂鸟).*?(?:取餐码|取货码)[::]?\s*(\d{2,4})'),
      type: CodeType.food,
    ),

    // ============ 出行类 ============

    // 登机口
    PatternRule(
      pattern: RegExp(r'登机口[::]\s*([A-Z]\d{1,3})'),
      type: CodeType.travel,
    ),

    // 座位号
    PatternRule(
      pattern: RegExp(r'座位[::]\s*(\d{1,2}[A-F])'),
      type: CodeType.travel,
    ),

    // 航班号
    PatternRule(
      pattern: RegExp(r'航班[::]\s*([A-Z]{2}\d{3,4})'),
      type: CodeType.travel,
    ),

    // ============ 其他 ============

    // 验证码(作为备选)
    PatternRule(
      pattern: RegExp(r'验证码[::]\s*(\d{4,6})'),
      type: CodeType.other,
    ),
  ];

  /// 匹配结果
  static const int _maxSourceLength = 20;

  /// 从文本中提取取件码（单个）
  ///
  /// 返回匹配结果,如果没有匹配则返回 null
  static MatchResult? match(String text) {
    final results = matchAll(text);
    return results.isNotEmpty ? results.first : null;
  }

  /// 从文本中提取所有取件码
  ///
  /// 返回所有匹配结果列表,如果没有匹配则返回空列表
  static List<MatchResult> matchAll(String text) {
    final List<MatchResult> results = [];
    final Set<String> foundCodes = {}; // 防止重复

    for (final rule in _rules) {
      // 使用 allMatches 获取所有匹配
      for (final match in rule.pattern.allMatches(text)) {
        final code = match.group(rule.codeGroup) ?? '';
        if (code.isEmpty || foundCodes.contains(code)) continue;

        foundCodes.add(code);

        // 提取来源（基于匹配位置附近的上下文）
        String source = _extractSourceNearMatch(text, match);

        // 提取地点（基于匹配位置附近的上下文）
        String? location = _extractLocationNearMatch(text, match);

        results.add(MatchResult(
          code: code,
          type: rule.type,
          source: source,
          location: location,
          rawMessage: text,
        ));
      }

      // 如果已经找到结果，不再尝试低优先级的规则
      // 但继续用同一规则匹配其他取件码
    }

    return results;
  }

  /// 从匹配位置附近提取来源
  ///
  /// 向前搜索 100 个字符，查找快递公司名称
  static String _extractSourceNearMatch(String text, RegExpMatch match) {
    // 获取匹配位置前 100 个字符的上下文
    final startPos = match.start;
    final contextStart = startPos > 100 ? startPos - 100 : 0;
    final context = text.substring(contextStart, startPos);

    // 常见来源关键词（按优先级排序）
    final sourcePatterns = [
      (RegExp(r'(菜鸟驿站|驿站|快递点)'), '菜鸟驿站'),
      (RegExp(r'(丰巢|快递柜)'), '丰巢快递柜'),
      (RegExp(r'(韵达|韵达快递)'), '韵达快递'),
      (RegExp(r'(中通|中通快递)'), '中通快递'),
      (RegExp(r'(圆通|圆通快递)'), '圆通快递'),
      (RegExp(r'(申通|申通快递)'), '申通快递'),
      (RegExp(r'(顺丰|顺丰快递)'), '顺丰快递'),
      (RegExp(r'(京东|京东快递)'), '京东快递'),
      (RegExp(r'(美团|美团外卖)'), '美团外卖'),
      (RegExp(r'(饿了么|蜂鸟)'), '饿了么'),
    ];

    for (final (pattern, name) in sourcePatterns) {
      if (pattern.hasMatch(context)) {
        return name;
      }
    }

    // 如果上下文没找到，尝试在整个文本中查找
    for (final (pattern, name) in sourcePatterns) {
      if (pattern.hasMatch(text)) {
        return name;
      }
    }

    return '未知来源';
  }

  /// 从匹配位置附近提取地点
  ///
  /// 向后搜索 50 个字符，查找地点信息
  static String? _extractLocationNearMatch(String text, RegExpMatch match) {
    // 获取匹配位置后 50 个字符的上下文
    final endPos = match.end;
    final contextEnd = endPos + 50 < text.length ? endPos + 50 : text.length;
    final context = text.substring(endPos, contextEnd);

    // 优先匹配“菜鸟驿站|XXX店”格式
    final cainiaoPattern = RegExp(r'菜鸟驿站[|｜]([^
]{2,20})');
    final cainiaoMatch = cainiaoPattern.firstMatch(context);
    if (cainiaoMatch != null) {
      return cainiaoMatch.group(1)?.trim();
    }

    // 匹配“请到XX取件”、“前往XX取件”等
    final locationPattern = RegExp(r'(?:请到|前往|到)([^，。！？\n]{2,10})(?:取件|取货|领取)');
    final locationMatch = locationPattern.firstMatch(context);
    if (locationMatch != null) {
      return locationMatch.group(1)?.trim();
    }

    // 如果上下文没找到，尝试在整个文本中查找
    return _extractLocation(text);
  }

  /// 从文本中提取来源（旧方法，保留兼容）
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

  /// 从文本中提取地点
  static String? _extractLocation(String text) {
    // 优先匹配“菜鸟驿站|XXX店”格式
    final cainiaoPattern = RegExp(r'菜鸟驿站[|｜]([^\n]{2,20})');
    final cainiaoMatch = cainiaoPattern.firstMatch(text);
    if (cainiaoMatch != null) {
      return cainiaoMatch.group(1)?.trim();
    }
    
    // 匹配“请到XX取件”、“前往XX取件”等
    final locationPattern = RegExp(r'(?:请到|前往|到)([^，。！？\n]{2,10})(?:取件|取货|领取)');
    final match = locationPattern.firstMatch(text);
    if (match != null) {
      return match.group(1)?.trim();
    }
    
    return null;
  }

  /// 添加自定义规则
  static void addRule(PatternRule rule) {
    _rules.insert(0, rule); // 插入到最前面,优先级最高
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

  /// 原始消息
  final String rawMessage;

  MatchResult({
    required this.code,
    required this.type,
    required this.source,
    this.location,
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
      createTime: DateTime.now(),
      rawMessage: rawMessage,
    );
  }
}
