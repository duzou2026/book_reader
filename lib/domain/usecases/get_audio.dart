import 'package:book_reader/data/models/audio_chapter.dart';
import 'package:book_reader/data/models/book_info.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/services/audio/audio_toc_fetcher.dart';
import 'package:book_reader/services/audio/audio_url_fetcher.dart';

/// 「获取有声书目录」用例。
class GetAudioToc {
  final AudioTocFetcher fetcher;
  final Future<List<BookSource>> Function() _getEnabledSources;

  GetAudioToc({
    required this.fetcher,
    required Future<List<BookSource>> Function() getEnabledSources,
  }) : _getEnabledSources = getEnabledSources;

  Future<List<AudioChapter>> call(BookInfo info) async {
    final sources = await _getEnabledSources();
    final byUrl = {for (final s in sources) s.bookSourceUrl: s};
    final source = byUrl[info.sourceUrl];
    if (source == null) return const [];
    final tocUrl = info.tocUrl ?? info.url;
    return fetcher.fetch(tocUrl, source);
  }
}

/// 「获取单章音频 URL」用例。
class GetAudioUrl {
  final AudioUrlFetcher fetcher;
  final Future<List<BookSource>> Function() _getEnabledSources;

  GetAudioUrl({
    required this.fetcher,
    required Future<List<BookSource>> Function() getEnabledSources,
  }) : _getEnabledSources = getEnabledSources;

  Future<String> call(BookInfo info, AudioChapter chapter) async {
    final sources = await _getEnabledSources();
    final byUrl = {for (final s in sources) s.bookSourceUrl: s};
    final source = byUrl[info.sourceUrl];
    if (source == null) return '';
    return fetcher.fetch(chapter.url, source);
  }
}
