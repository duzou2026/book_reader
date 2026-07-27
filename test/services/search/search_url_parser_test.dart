import 'package:book_reader/services/search/search_url_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchUrlParser.parse - 纯 URL', () {
    test('GET URL with {{key}} substitution (关键字编码)', () {
      final config = SearchUrlParser.parse(
        'https://example.com/search?q={{key}}',
        keyword: '三体',
        page: 1,
      );
      expect(config, isNotNull);
      // URL 上下文下 {{key}} 会被 URL 编码
      expect(config!.url, 'https://example.com/search?q=%E4%B8%89%E4%BD%93');
      expect(config.method, 'GET');
      expect(config.body, isNull);
    });

    test('substitutes {{page}}', () {
      final config = SearchUrlParser.parse(
        'https://example.com/search?page={{page}}&q={{key}}',
        keyword: 'abc',
        page: 3,
      );
      expect(config!.url, 'https://example.com/search?page=3&q=abc');
    });

    test('returns null for empty input', () {
      expect(SearchUrlParser.parse('', keyword: 'x'), isNull);
      expect(SearchUrlParser.parse('   ', keyword: 'x'), isNull);
    });

    test('相对 URL + baseUrl → 拼接为绝对 URL', () {
      // 铅笔小说风格：searchUrl 是相对路径
      final config = SearchUrlParser.parse(
        '/search.html?searchkey={{key}}',
        keyword: '三体',
        page: 1,
        baseUrl: 'https://www.23qb.com',
      );
      expect(config, isNotNull);
      expect(config!.url,
          'https://www.23qb.com/search.html?searchkey=%E4%B8%89%E4%BD%93');
      expect(config.method, 'GET');
    });

    test('相对 URL 无 baseUrl → 保持相对', () {
      final config = SearchUrlParser.parse(
        '/search?q={{key}}',
        keyword: 'test',
        page: 1,
      );
      expect(config, isNotNull);
      // 无 baseUrl 无法拼接，保持原样（关键字仍编码）
      expect(config!.url, '/search?q=test');
    });

    test('协议相对 URL (//host/path) + baseUrl → 补 https:', () {
      final config = SearchUrlParser.parse(
        '//api.example.com/search?q={{key}}',
        keyword: '三体',
        page: 1,
        baseUrl: 'https://www.23qb.com',
      );
      expect(config, isNotNull);
      expect(config!.url,
          'https://api.example.com/search?q=%E4%B8%89%E4%BD%93');
    });
  });

  group('SearchUrlParser.parse - URL + JSON 配置段', () {
    test('parses POST body and charset', () {
      final raw =
          "https://example.com/search,{'method':'POST','body':'key={{key}}','charset':'gbk'}";
      final config = SearchUrlParser.parse(raw, keyword: '三体');
      expect(config!.url, 'https://example.com/search');
      expect(config.method, 'POST');
      expect(config.body, 'key=三体');
      expect(config.charset, 'gbk');
    });

    test('parses custom headers', () {
      final raw =
          "https://example.com/search,{'method':'POST','body':'q={{key}}','headers':{'Referer':'https://example.com/'}}";
      final config = SearchUrlParser.parse(raw, keyword: 'x');
      expect(config!.headers, isNotNull);
      expect(config.headers!['Referer'], 'https://example.com/');
    });

    test('falls back to GET when JSON malformed', () {
      final raw = "https://example.com/search,{not json}";
      final config = SearchUrlParser.parse(raw, keyword: 'x');
      // 退化为整串当 URL（含 ,{not json}）
      expect(config!.method, 'GET');
    });
  });

  group('SearchUrlParser.parse - @js: 静态提取', () {
    test('模式 B: @js:url="<full_url_with_config>";...', () {
      // 模拟「大文学无错小说网」/「思路客」等源：url="https://...,{...}";if(java.ajax...)
      final raw = """@js:url="https://m.example.com/search.php,{'body':'keyword={{key}}','method':'POST'}";if(java.ajax(url).match(/foo/)){java.toast('x');}""";
      final config = SearchUrlParser.parse(raw, keyword: '三体');
      expect(config, isNotNull);
      expect(config!.url, 'https://m.example.com/search.php');
      expect(config.method, 'POST');
      // body 中的 {{key}} 不编码（非 URL 上下文，是 POST body）
      expect(config.body, 'keyword=三体');
    });

    test('模式 B 支持 single quotes (URL 中的 {{key}} 编码)', () {
      final raw = """@js:url='https://m.example.com/search?q={{key}}';result=url;""";
      final config = SearchUrlParser.parse(raw, keyword: '三体');
      expect(config!.url, 'https://m.example.com/search?q=%E4%B8%89%E4%BD%93');
      expect(config.method, 'GET');
    });

    test('模式 C: @js:url=baseUrl+"<path_with_config>";...', () {
      // 模拟「起点中文」：url=baseUrl+"/so/{{key}}.html,{...}";java.put('url',url);result=url;
      final raw = """@js:url=baseUrl+"/so/{{key}}.html,{'method':'GET','headers':{'Referer':'https://www.example.com/'}}";java.put('url',url);result=url;""";
      final config = SearchUrlParser.parse(
        raw,
        keyword: '三体',
        baseUrl: 'https://www.example.com',
      );
      expect(config, isNotNull);
      expect(config!.url, 'https://www.example.com/so/%E4%B8%89%E4%BD%93.html');
      expect(config.method, 'GET');
      expect(config.headers, isNotNull);
      expect(config.headers!['Referer'], 'https://www.example.com/');
    });

    test('模式 C 无 baseUrl 时仍能提取 path', () {
      final raw = """@js:url=baseUrl+"/so/{{key}}.html";result=url;""";
      final config = SearchUrlParser.parse(raw, keyword: '三体');
      // 没有 baseUrl，path 本身不是绝对 URL，但 method 默认 GET
      expect(config, isNotNull);
      expect(config!.method, 'GET');
    });

    test('复杂 @js (含 function/try) 返回 null', () {
      final raw = """@js:
function getUrl(key) {
  return \`https://api.example.com/search?q=\${key}\`;
}
result = getUrl(key);
""";
      final config = SearchUrlParser.parse(raw, keyword: '三体');
      expect(config, isNull);
    });
  });

  group('SearchUrlParser.parse - <js>...</js> 后接 URL', () {
    test('模式 A: <js>side-effect</js>URL', () {
      // 模拟「69书吧2」/「和图书」：<js>verification</js>/search/{key}/1.html
      final raw =
          """<js>if(java.ajax(baseUrl).match(/foo/)){java.toast('verify');}</js>/search/{{key}}/1.html""";
      final config = SearchUrlParser.parse(
        raw,
        keyword: '三体',
        baseUrl: 'https://www.example.com',
      );
      expect(config, isNotNull);
      expect(config!.url, 'https://www.example.com/search/%E4%B8%89%E4%BD%93/1.html');
      expect(config.method, 'GET');
    });

    test('模式 A 后接带 JSON 配置的 URL', () {
      final raw =
          """<js>java.toast('check');</js>/search,{'method':'POST','body':'q={{key}}'}""";
      final config = SearchUrlParser.parse(
        raw,
        keyword: '三体',
        baseUrl: 'https://www.example.com',
      );
      expect(config!.url, 'https://www.example.com/search');
      expect(config.method, 'POST');
      // body 中的 {{key}} 不编码（POST body 上下文）
      expect(config.body, 'q=三体');
    });

    test('<js> 无后续内容 → 返回 null', () {
      final raw = """<js>result='';result;</js>""";
      expect(SearchUrlParser.parse(raw, keyword: 'x'), isNull);
    });
  });
}
