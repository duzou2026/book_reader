import 'package:freezed_annotation/freezed_annotation.dart';

part 'book_source.freezed.dart';
part 'book_source.g.dart';

/// legado 书源 JSON 里 lastUpdateTime / respondTime 字段类型不固定：
/// 有的书源用 int（毫秒时间戳），有的用 String。
/// 这两个辅助函数用 Object? 兼容两种类型，避免 `as String?` 在 int 时崩溃。
Object? _asObject(Object? v) => v;
Object? _objectToJson(Object? v) => v;

/// 书源类型：0=文本小说，1=有声书
enum BookSourceType {
  @JsonValue(0) text,
  @JsonValue(1) audio,
}

/// 书源模型，兼容 legado（阅读 App）的 JSON 格式。
/// 用户可导入 legado 生态的现有书源 JSON。
@freezed
class BookSource with _$BookSource {
  const factory BookSource({
    required String bookSourceName,
    required String bookSourceUrl,
    @Default(BookSourceType.text) BookSourceType bookSourceType,
    @Default(true) bool enabled,
    String? bookSourceGroup,
    String? searchUrl,
    String? loginUrl,
    RuleSearch? ruleSearch,
    RuleBookInfo? ruleBookInfo,
    RuleToc? ruleToc,
    RuleContent? ruleContent,
    @Default(0) int priority,
    @Default(0) int weight,
    /// legado 书源里这两个字段有时是 int（毫秒时间戳），有时是 String。
    /// 用 Object? 兼容两种类型，避免 `as String?` 在 int 时崩溃。
    @JsonKey(fromJson: _asObject, toJson: _objectToJson) Object? lastUpdateTime,
    @JsonKey(fromJson: _asObject, toJson: _objectToJson) Object? respondTime,
    String? weightValue,
  }) = _BookSource;

  factory BookSource.fromJson(Map<String, dynamic> json) =>
      _$BookSourceFromJson(json);
}

@freezed
class RuleSearch with _$RuleSearch {
  const factory RuleSearch({
    String? bookList,
    String? name,
    String? author,
    String? kind,
    String? wordCount,
    String? lastChapter,
    String? intro,
    String? coverUrl,
    String? bookUrl,
  }) = _RuleSearch;

  factory RuleSearch.fromJson(Map<String, dynamic> json) =>
      _$RuleSearchFromJson(json);
}

@freezed
class RuleBookInfo with _$RuleBookInfo {
  const factory RuleBookInfo({
    String? name,
    String? author,
    String? intro,
    String? coverUrl,
    String? kind,
    String? lastChapter,
    String? tocUrl,
    String? wordCount,
  }) = _RuleBookInfo;

  factory RuleBookInfo.fromJson(Map<String, dynamic> json) =>
      _$RuleBookInfoFromJson(json);
}

@freezed
class RuleToc with _$RuleToc {
  const factory RuleToc({
    String? chapterList,
    String? chapterName,
    String? chapterUrl,
    String? nextTocUrl,
    String? isVolume,
    String? isVip,
    String? updateTime,
  }) = _RuleToc;

  factory RuleToc.fromJson(Map<String, dynamic> json) =>
      _$RuleTocFromJson(json);
}

@freezed
class RuleContent with _$RuleContent {
  const factory RuleContent({
    String? content,
    String? nextContentUrl,
    String? replaceRegex,
    String? imageStyle,
  }) = _RuleContent;

  factory RuleContent.fromJson(Map<String, dynamic> json) =>
      _$RuleContentFromJson(json);
}
