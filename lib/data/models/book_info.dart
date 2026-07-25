import 'package:freezed_annotation/freezed_annotation.dart';

part 'book_info.freezed.dart';
part 'book_info.g.dart';

/// 书籍详情。
///
/// 来自对书源书籍详情页应用 `RuleBookInfo` 的解析结果。
/// 与 [SearchResult] 区别：搜索结果是聚合视图，本类是单源详情。
@freezed
class BookInfo with _$BookInfo {
  const factory BookInfo({
    required String url,
    required String sourceName,
    required String sourceUrl,
    String? name,
    String? author,
    String? intro,
    String? coverUrl,
    String? kind,
    String? wordCount,
    String? lastChapter,
    /// 目录页 URL。若为空表示详情页本身就是目录页。
    String? tocUrl,
  }) = _BookInfo;

  factory BookInfo.fromJson(Map<String, dynamic> json) =>
      _$BookInfoFromJson(json);
}

/// 章节信息。
@freezed
class Chapter with _$Chapter {
  const factory Chapter({
    required String name,
    required String url,
    /// 是否卷标（不可点击的分组标题）。
    @Default(false) bool isVolume,
    /// 是否 VIP 章节。
    @Default(false) bool isVip,
    /// 章节更新时间（书源返回的原始字符串）。
    String? updateTime,
    /// 章节序号（从 1 开始，按目录顺序）。
    @Default(0) int index,
  }) = _Chapter;

  factory Chapter.fromJson(Map<String, dynamic> json) =>
      _$ChapterFromJson(json);
}
