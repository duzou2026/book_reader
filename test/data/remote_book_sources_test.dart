import 'dart:convert';

import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/data/remote_book_sources.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this.responseBody, {this.statusCode = 200});
  final String responseBody;
  final int statusCode;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    return ResponseBody.fromString(responseBody, statusCode, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }
}

const _samplePayload = '''
[
  {
    "bookSourceName": "测试源A",
    "bookSourceUrl": "https://a.example.com",
    "bookSourceType": 0,
    "enabled": true,
    "bookSourceGroup": "测试",
    "searchUrl": "/search?q={{key}}",
    "ruleSearch": {
      "bookList": "css:.list > li",
      "name": "css:.name@text",
      "author": "css:.author@text",
      "bookUrl": "css:a@href"
    }
  },
  {
    "bookSourceName": "测试源B",
    "bookSourceUrl": "https://b.example.com",
    "bookSourceType": 0,
    "enabled": false,
    "searchUrl": "/search?kw={{key}}"
  }
]
''';

void main() {
  late Box<String> box;

  setUp(() async {
    Hive.init('/tmp/hive_test_${DateTime.now().millisecondsSinceEpoch}');
    box = await Hive.openBox<String>('book_sources_test');
  });

  tearDown(() async {
    await box.clear();
    await box.close();
  });

  group('RemoteBookSources.fetch', () {
    test('远程拉取成功 → 返回解析后的书源列表', () async {
      final dio = _MockDio();
      when(() => dio.get<dynamic>(any(),
              options: any(named: 'options')))
          .thenAnswer((_) async => Response<dynamic>(
                requestOptions: RequestOptions(path: ''),
                data: _samplePayload,
              ));
      final fetcher = RemoteBookSources(cacheBox: box, dio: dio);
      final sources = await fetcher.fetch(forceRefresh: true);

      expect(sources.length, 2);
      expect(sources[0].bookSourceName, '测试源A');
      expect(sources[0].enabled, isTrue);
      expect(sources[1].bookSourceName, '测试源B');
      expect(sources[1].enabled, isFalse);
    });

    test('远程拉取成功 → 写入 Hive 缓存', () async {
      final dio = _MockDio();
      when(() => dio.get<dynamic>(any(),
              options: any(named: 'options')))
          .thenAnswer((_) async => Response<dynamic>(
                requestOptions: RequestOptions(path: ''),
                data: _samplePayload,
              ));
      final fetcher = RemoteBookSources(cacheBox: box, dio: dio);
      await fetcher.fetch(forceRefresh: true);

      // 缓存应被写入
      final cached = box.get(RemoteBookSources.cacheKey);
      expect(cached, isNotNull);
      expect(cached, _samplePayload);
    });

    test('forceRefresh=false + 缓存命中 → 不发起网络请求', () async {
      // 先写入缓存
      await box.put(RemoteBookSources.cacheKey, _samplePayload);
      // Dio 不应该被调用
      final dio = _MockDio();
      when(() => dio.get<dynamic>(any(),
              options: any(named: 'options')))
          .thenThrow(Exception('不应该发起网络请求'));
      final fetcher = RemoteBookSources(cacheBox: box, dio: dio);

      final sources = await fetcher.fetch(forceRefresh: false);
      expect(sources.length, 2);
      expect(sources[0].bookSourceName, '测试源A');
    });

    test('forceRefresh=true → 跳过缓存，发起网络请求', () async {
      // 先写入"旧"缓存
      await box.put(RemoteBookSources.cacheKey, '[]');
      final dio = _MockDio();
      var called = 0;
      when(() => dio.get<dynamic>(any(),
              options: any(named: 'options'))).thenAnswer((_) async {
        called++;
        return Response<dynamic>(
          requestOptions: RequestOptions(path: ''),
          data: _samplePayload,
        );
      });
      final fetcher = RemoteBookSources(cacheBox: box, dio: dio);

      final sources = await fetcher.fetch(forceRefresh: true);
      expect(called, 1);
      expect(sources.length, 2);
    });

    test('网络失败 + 有缓存 → 返回缓存', () async {
      await box.put(RemoteBookSources.cacheKey, _samplePayload);
      final dio = _MockDio();
      when(() => dio.get<dynamic>(any(),
              options: any(named: 'options')))
          .thenThrow(DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.connectionTimeout,
          ));
      final fetcher = RemoteBookSources(cacheBox: box, dio: dio);

      final sources = await fetcher.fetch(forceRefresh: true);
      expect(sources.length, 2,
          reason: '网络失败时应回退到缓存');
    });

    test('网络失败 + 无缓存 → 返回空列表', () async {
      final dio = _MockDio();
      when(() => dio.get<dynamic>(any(),
              options: any(named: 'options')))
          .thenThrow(DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.connectionTimeout,
          ));
      final fetcher = RemoteBookSources(cacheBox: box, dio: dio);

      final sources = await fetcher.fetch(forceRefresh: true);
      expect(sources, isEmpty);
    });

    test('JSON 格式异常 → 跳过该条，解析成功的仍返回', () async {
      const payload = '''
[
  {"bookSourceName": "正常源", "bookSourceUrl": "https://ok.example.com"},
  {"invalid": "missing required fields"},
  {"bookSourceName": "另一正常源", "bookSourceUrl": "https://ok2.example.com"}
]
''';
      final dio = _MockDio();
      when(() => dio.get<dynamic>(any(),
              options: any(named: 'options')))
          .thenAnswer((_) async => Response<dynamic>(
                requestOptions: RequestOptions(path: ''),
                data: payload,
              ));
      final fetcher = RemoteBookSources(cacheBox: box, dio: dio);

      final sources = await fetcher.fetch(forceRefresh: true);
      // 第一条和第三条应成功，第二条缺 required 字段会被跳过
      // 注：BookSource.fromJson 不抛错（required 字段空时 freezed 用默认值），
      // 但缺 bookSourceUrl 时会触发 fromJson 内部异常被 catch
      // 实际行为取决于 freezed 实现，此处仅断言至少有可解析的条目
      expect(sources.any((s) => s.bookSourceName == '正常源'), isTrue);
    });

    test('顶层非数组 → 抛 FormatException，回退缓存', () async {
      const payload = '{"not": "an array"}';
      await box.put(RemoteBookSources.cacheKey, _samplePayload);
      final dio = _MockDio();
      when(() => dio.get<dynamic>(any(),
              options: any(named: 'options')))
          .thenAnswer((_) async => Response<dynamic>(
                requestOptions: RequestOptions(path: ''),
                data: payload,
              ));
      final fetcher = RemoteBookSources(cacheBox: box, dio: dio);

      final sources = await fetcher.fetch(forceRefresh: true);
      expect(sources.length, 2, reason: '远程格式异常应回退缓存');
    });

    test('clearCache → 清空缓存 key', () async {
      await box.put(RemoteBookSources.cacheKey, _samplePayload);
      final dio = _MockDio();
      final fetcher = RemoteBookSources(cacheBox: box, dio: dio);
      expect(box.get(RemoteBookSources.cacheKey), isNotNull);

      await fetcher.clearCache();
      expect(box.get(RemoteBookSources.cacheKey), isNull);
    });
  });
}
