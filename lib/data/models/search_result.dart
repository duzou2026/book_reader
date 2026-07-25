import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_result.freezed.dart';
part 'search_result.g.dart';

/// 单条搜索结果。
///
/// 表示「一本书」的聚合信息。同一本书可能在多个书源里都能搜到，
/// 此时 `sources` 列表会有多条记录，每条对应一个书源的 URL。
@freezed
class SearchResult with _$SearchResult {
  @JsonSerializable(explicitToJson: true)
  const factory SearchResult({
    required String bookName,
    required String author,
    String? coverUrl,
    String? intro,
    String? kind,
    String? wordCount,
    String? lastChapter,
    @Default([]) List<SearchSource> sources,
  }) = _SearchResult;

  factory SearchResult.fromJson(Map<String, dynamic> json) =>
      _$SearchResultFromJson(json);
}

/// 「在哪个书源找到这本书」的记录。
@freezed
class SearchSource with _$SearchSource {
  const factory SearchSource({
    required String sourceName,
    required String sourceUrl,
    required String bookUrl,
  }) = _SearchSource;

  factory SearchSource.fromJson(Map<String, dynamic> json) =>
      _$SearchSourceFromJson(json);
}

extension SearchResultX on SearchResult {
  /// 用于去重的归一化 key。
  ///
  /// 规则：
  ///   - name 和 author 都 toLowerCase()
  ///   - 去前后空白
  ///   - 内部连续空白合并为单个空格
  ///
  /// 这样「三体」/「  三体 」/「三  体」都会归一化到相同的 key。
  String get dedupKey {
    final n = _normalize(bookName);
    final a = _normalize(author);
    return '$n|$a';
  }

  /// 合并另一个相同 dedupKey 的结果：拼接 sources，补充缺失的可选字段。
  SearchResult mergeWith(SearchResult other) {
    return copyWith(
      coverUrl: coverUrl ?? other.coverUrl,
      intro: intro ?? other.intro,
      kind: kind ?? other.kind,
      wordCount: wordCount ?? other.wordCount,
      lastChapter: lastChapter ?? other.lastChapter,
      sources: [...sources, ...other.sources],
    );
  }

  static String _normalize(String s) {
    return s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
