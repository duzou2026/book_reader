/// 书源校验相关异常与函数。
class BookSourceValidationException implements Exception {
  final String message;
  BookSourceValidationException(this.message);

  @override
  String toString() => 'BookSourceValidationException: $message';
}

/// 校验单个书源 JSON 对象的必填字段。
/// 缺失或为空时抛出 [BookSourceValidationException]。
void validateBookSource(Map<String, dynamic> json) {
  final name = json['bookSourceName'];
  if (name == null || (name is String && name.trim().isEmpty)) {
    throw BookSourceValidationException('bookSourceName 缺失或为空');
  }
  final url = json['bookSourceUrl'];
  if (url == null || (url is String && url.trim().isEmpty)) {
    throw BookSourceValidationException('bookSourceUrl 缺失或为空');
  }
}
