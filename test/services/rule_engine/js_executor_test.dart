import 'package:flutter_test/flutter_test.dart';
import 'package:book_reader/services/rule_engine/js_executor.dart';

/// JsExecutor 依赖 flutter_js，而 flutter_js 通过 FFI 加载 native 库
/// `libquickjs_c_bridge_plugin.so`。该库只在 Flutter 应用上下文（含平台插件
/// 注册）中可用，纯 `flutter test` 单元测试跑不动。
///
/// 这些测试需在 integration_test 或真机/模拟器上跑。本地 `flutter test` 时
/// 自动跳过。
bool _canRunJs() {
  try {
    final executor = JsExecutor();
    // 真正调用一次 eval 才会触发 FFI 加载 native 库
    executor.eval('"ok"', 'js:result');
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  final canRun = _canRunJs();
  final skipReason = canRun
      ? null
      : 'flutter_js native lib 不可用，需在 integration_test 中运行';

  group('JsExecutor.eval', () {
    test('parses JSON via JSON.parse(result)', () {
      final executor = JsExecutor();
      final result = executor.eval(
        '{"title":"三体"}',
        r'js:JSON.parse(result).title',
      );
      expect(result, '三体');
    }, skip: skipReason);

    test('accesses array elements', () {
      final executor = JsExecutor();
      final result = executor.eval(
        '{"items":["a","b","c"]}',
        r'js:JSON.parse(result).items[1]',
      );
      expect(result, 'b');
    }, skip: skipReason);

    test('strips <js>...</js> form', () {
      final executor = JsExecutor();
      final result = executor.eval(
        '{"x":42}',
        '<js>JSON.parse(result).x</js>',
      );
      expect(result, '42');
    }, skip: skipReason);

    test('handles string input (non-JSON)', () {
      final executor = JsExecutor();
      final result = executor.eval(
        'hello world',
        'js:result.split(" ").length',
      );
      expect(result, '2');
    }, skip: skipReason);

    test('uses baseUrl variable when provided', () {
      final executor = JsExecutor();
      final result = executor.eval(
        '{"path":"/book/1"}',
        'js:baseUrl + JSON.parse(result).path',
        baseUrl: 'https://example.com',
      );
      expect(result, 'https://example.com/book/1');
    }, skip: skipReason);
  });
}
