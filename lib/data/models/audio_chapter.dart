import 'package:freezed_annotation/freezed_annotation.dart';

part 'audio_chapter.freezed.dart';
part 'audio_chapter.g.dart';

/// 有声书章节。
///
/// 在文本 [Chapter] 基础上增加 [audioUrl]（音频文件直链）。
/// legado 有声书源通常把音频 URL 放在 `ruleContent.content` 里，
/// 故 [audioUrl] 即对章节页应用 ruleContent.content 的求值结果。
@freezed
class AudioChapter with _$AudioChapter {
  const factory AudioChapter({
    required String name,
    required String url,
    required String audioUrl,
    @Default(false) bool isVolume,
    @Default(false) bool isVip,
    String? updateTime,
    @Default(0) int index,
  }) = _AudioChapter;

  factory AudioChapter.fromJson(Map<String, dynamic> json) =>
      _$AudioChapterFromJson(json);
}
