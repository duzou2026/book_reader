import 'dart:convert';

import 'package:book_reader/services/app_update/app_update_checker.dart';
import 'package:book_reader/services/app_update/app_update_info.dart';
import 'package:book_reader/services/app_update/app_update_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppUpdateChecker', () {
    late Dio dio;
    late MockAdapter adapter;

    setUp(() {
      dio = Dio();
      adapter = MockAdapter();
      dio.httpClientAdapter = adapter;
    });

    test('parses a standard GitHub release payload', () async {
      adapter.response = _sampleReleasePayload();
      final checker = AppUpdateChecker(
        giteeOwner: 'duzou2026',
        giteeRepo: 'book_reader',
        githubOwner: 'duzou2026',
        githubRepo: 'book_reader',
        dio: dio,
      );
      final info = await checker.fetchLatestRelease();

      expect(info.tagName, 'v0.3.0');
      expect(info.version, '0.3.0');
      expect(info.name, 'Release 0.3.0');
      expect(info.body, contains('fix'));
      expect(info.htmlUrl, startsWith('https://'));
      expect(info.publishedAt, '2026-07-25T10:00:00Z');
      // 只保留 .apk 后缀的 assets
      expect(info.assets.length, 3);
      expect(info.assets.every((a) => a.name.endsWith('.apk')), isTrue);
      expect(info.assets.every((a) => a.browserDownloadUrl.isNotEmpty), isTrue);
    });

    test('throws FormatException when tag_name missing', () async {
      adapter.response = {'name': 'no tag'};
      final checker = AppUpdateChecker(
        giteeOwner: 'x',
        giteeRepo: 'y',
        githubOwner: 'x',
        githubRepo: 'y',
        dio: dio,
      );
      expect(checker.fetchLatestRelease(),
          throwsA(isA<FormatException>()));
    });

    test('ignores non-APK assets', () async {
      adapter.response = _sampleReleasePayload(extraAssets: [
        {
          'name': 'sources.tar.gz',
          'browser_download_url':
              'https://github.com/x/y/releases/download/v0.3.0/src.tar.gz',
          'size': 100,
          'content_type': 'application/gzip',
        },
        {
          'name': 'checksums.txt',
          'browser_download_url':
              'https://github.com/x/y/releases/download/v0.3.0/checksums.txt',
          'size': 200,
          'content_type': 'text/plain',
        },
      ]);
      final checker = AppUpdateChecker(giteeOwner: 'x', giteeRepo: 'y', githubOwner: 'x', githubRepo: 'y', dio: dio);
      final info = await checker.fetchLatestRelease();
      expect(info.assets.length, 3);
      expect(info.assets.every((a) => a.name.endsWith('.apk')), isTrue);
    });

    test('handles empty assets list', () async {
      adapter.response = {
        'tag_name': 'v0.0.1',
        'name': 'empty',
        'body': '',
        'published_at': '',
        'html_url': '',
        'assets': [],
      };
      final checker = AppUpdateChecker(giteeOwner: 'x', giteeRepo: 'y', githubOwner: 'x', githubRepo: 'y', dio: dio);
      final info = await checker.fetchLatestRelease();
      expect(info.assets, isEmpty);
    });

    test('handles missing assets field', () async {
      adapter.response = {
        'tag_name': 'v0.0.1',
        'name': 'no assets field',
      };
      final checker = AppUpdateChecker(giteeOwner: 'x', giteeRepo: 'y', githubOwner: 'x', githubRepo: 'y', dio: dio);
      final info = await checker.fetchLatestRelease();
      expect(info.assets, isEmpty);
    });
  });

  group('CheckForUpdate use case', () {
    test('returns AppUpdateInfo when remote is newer', () async {
      final dio = Dio();
      final adapter = MockAdapter();
      adapter.response = _sampleReleasePayload(tagName: 'v0.9.9');
      dio.httpClientAdapter = adapter;
      final checker = AppUpdateChecker(giteeOwner: 'x', giteeRepo: 'y', githubOwner: 'x', githubRepo: 'y', dio: dio);
      final useCase = CheckForUpdate(checker: checker, currentVersion: '0.2.2');
      final result = await useCase();
      expect(result, isNotNull);
      expect(result!.version, '0.9.9');
    });

    test('returns null when already up-to-date', () async {
      final dio = Dio();
      final adapter = MockAdapter();
      adapter.response = _sampleReleasePayload(tagName: 'v0.2.2');
      dio.httpClientAdapter = adapter;
      final checker = AppUpdateChecker(giteeOwner: 'x', giteeRepo: 'y', githubOwner: 'x', githubRepo: 'y', dio: dio);
      final useCase = CheckForUpdate(checker: checker, currentVersion: '0.2.2');
      final result = await useCase();
      expect(result, isNull);
    });

    test('returns null when remote is older', () async {
      final dio = Dio();
      final adapter = MockAdapter();
      adapter.response = _sampleReleasePayload(tagName: 'v0.1.0');
      dio.httpClientAdapter = adapter;
      final checker = AppUpdateChecker(giteeOwner: 'x', giteeRepo: 'y', githubOwner: 'x', githubRepo: 'y', dio: dio);
      final useCase = CheckForUpdate(checker: checker, currentVersion: '0.2.2');
      final result = await useCase();
      expect(result, isNull);
    });
  });
}

/// 简单的 dio httpClientAdapter mock：固定返回 [response]。
class MockAdapter implements HttpClientAdapter {
  dynamic response;
  int statusCode = 200;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    final body = response is String ? response as String : jsonEncode(response);
    return ResponseBody.fromString(body, statusCode, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }
}

Map<String, dynamic> _sampleReleasePayload({
  String tagName = 'v0.3.0',
  List<Map<String, dynamic>>? extraAssets,
}) {
  return {
    'tag_name': tagName,
    'name': 'Release 0.3.0',
    'body': '## What\'s new\n- fix bug A\n- add feature B',
    'published_at': '2026-07-25T10:00:00Z',
    // Gitee Releases API 用 created_at 字段；检查器优先走 Gitee，payload 需带上。
    'created_at': '2026-07-25T10:00:00Z',
    'html_url': 'https://github.com/duzou2026/book_reader/releases/tag/$tagName',
    'assets': <Map<String, dynamic>>[
      {
        'name': 'book_reader-$tagName-arm64-v8a.apk',
        'browser_download_url':
            'https://github.com/x/y/releases/download/$tagName/arm64.apk',
        'size': 31457280,
        'content_type': 'application/vnd.android.package-archive',
      },
      {
        'name': 'book_reader-$tagName-armeabi-v7a.apk',
        'browser_download_url':
            'https://github.com/x/y/releases/download/$tagName/armv7.apk',
        'size': 26214400,
        'content_type': 'application/vnd.android.package-archive',
      },
      {
        'name': 'book_reader-$tagName-x86_64.apk',
        'browser_download_url':
            'https://github.com/x/y/releases/download/$tagName/x64.apk',
        'size': 33554432,
        'content_type': 'application/vnd.android.package-archive',
      },
      if (extraAssets != null) ...extraAssets,
    ],
  };
}
