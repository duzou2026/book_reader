// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_source.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BookSourceImpl _$$BookSourceImplFromJson(Map<String, dynamic> json) =>
    _$BookSourceImpl(
      bookSourceName: json['bookSourceName'] as String,
      bookSourceUrl: json['bookSourceUrl'] as String,
      bookSourceType: $enumDecodeNullable(
              _$BookSourceTypeEnumMap, json['bookSourceType']) ??
          BookSourceType.text,
      enabled: json['enabled'] as bool? ?? true,
      bookSourceGroup: json['bookSourceGroup'] as String?,
      searchUrl: json['searchUrl'] as String?,
      loginUrl: json['loginUrl'] as String?,
      ruleSearch: json['ruleSearch'] == null
          ? null
          : RuleSearch.fromJson(json['ruleSearch'] as Map<String, dynamic>),
      ruleBookInfo: json['ruleBookInfo'] == null
          ? null
          : RuleBookInfo.fromJson(json['ruleBookInfo'] as Map<String, dynamic>),
      ruleToc: json['ruleToc'] == null
          ? null
          : RuleToc.fromJson(json['ruleToc'] as Map<String, dynamic>),
      ruleContent: json['ruleContent'] == null
          ? null
          : RuleContent.fromJson(json['ruleContent'] as Map<String, dynamic>),
      header: json['header'] as String?,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      weight: (json['weight'] as num?)?.toInt() ?? 0,
      lastUpdateTime: _asObject(json['lastUpdateTime']),
      respondTime: _asObject(json['respondTime']),
      weightValue: json['weightValue'] as String?,
    );

Map<String, dynamic> _$$BookSourceImplToJson(_$BookSourceImpl instance) =>
    <String, dynamic>{
      'bookSourceName': instance.bookSourceName,
      'bookSourceUrl': instance.bookSourceUrl,
      'bookSourceType': _$BookSourceTypeEnumMap[instance.bookSourceType]!,
      'enabled': instance.enabled,
      'bookSourceGroup': instance.bookSourceGroup,
      'searchUrl': instance.searchUrl,
      'loginUrl': instance.loginUrl,
      'ruleSearch': instance.ruleSearch,
      'ruleBookInfo': instance.ruleBookInfo,
      'ruleToc': instance.ruleToc,
      'ruleContent': instance.ruleContent,
      'header': instance.header,
      'priority': instance.priority,
      'weight': instance.weight,
      'lastUpdateTime': instance.lastUpdateTime,
      'respondTime': instance.respondTime,
      'weightValue': instance.weightValue,
    };

const _$BookSourceTypeEnumMap = {
  BookSourceType.text: 0,
  BookSourceType.audio: 1,
};

_$RuleSearchImpl _$$RuleSearchImplFromJson(Map<String, dynamic> json) =>
    _$RuleSearchImpl(
      bookList: json['bookList'] as String?,
      name: json['name'] as String?,
      author: json['author'] as String?,
      kind: json['kind'] as String?,
      wordCount: json['wordCount'] as String?,
      lastChapter: json['lastChapter'] as String?,
      intro: json['intro'] as String?,
      coverUrl: json['coverUrl'] as String?,
      bookUrl: json['bookUrl'] as String?,
    );

Map<String, dynamic> _$$RuleSearchImplToJson(_$RuleSearchImpl instance) =>
    <String, dynamic>{
      'bookList': instance.bookList,
      'name': instance.name,
      'author': instance.author,
      'kind': instance.kind,
      'wordCount': instance.wordCount,
      'lastChapter': instance.lastChapter,
      'intro': instance.intro,
      'coverUrl': instance.coverUrl,
      'bookUrl': instance.bookUrl,
    };

_$RuleBookInfoImpl _$$RuleBookInfoImplFromJson(Map<String, dynamic> json) =>
    _$RuleBookInfoImpl(
      name: json['name'] as String?,
      author: json['author'] as String?,
      intro: json['intro'] as String?,
      coverUrl: json['coverUrl'] as String?,
      kind: json['kind'] as String?,
      lastChapter: json['lastChapter'] as String?,
      tocUrl: json['tocUrl'] as String?,
      wordCount: json['wordCount'] as String?,
    );

Map<String, dynamic> _$$RuleBookInfoImplToJson(_$RuleBookInfoImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'author': instance.author,
      'intro': instance.intro,
      'coverUrl': instance.coverUrl,
      'kind': instance.kind,
      'lastChapter': instance.lastChapter,
      'tocUrl': instance.tocUrl,
      'wordCount': instance.wordCount,
    };

_$RuleTocImpl _$$RuleTocImplFromJson(Map<String, dynamic> json) =>
    _$RuleTocImpl(
      chapterList: json['chapterList'] as String?,
      chapterName: json['chapterName'] as String?,
      chapterUrl: json['chapterUrl'] as String?,
      nextTocUrl: json['nextTocUrl'] as String?,
      isVolume: json['isVolume'] as String?,
      isVip: json['isVip'] as String?,
      updateTime: json['updateTime'] as String?,
    );

Map<String, dynamic> _$$RuleTocImplToJson(_$RuleTocImpl instance) =>
    <String, dynamic>{
      'chapterList': instance.chapterList,
      'chapterName': instance.chapterName,
      'chapterUrl': instance.chapterUrl,
      'nextTocUrl': instance.nextTocUrl,
      'isVolume': instance.isVolume,
      'isVip': instance.isVip,
      'updateTime': instance.updateTime,
    };

_$RuleContentImpl _$$RuleContentImplFromJson(Map<String, dynamic> json) =>
    _$RuleContentImpl(
      content: json['content'] as String?,
      nextContentUrl: json['nextContentUrl'] as String?,
      replaceRegex: json['replaceRegex'] as String?,
      imageStyle: json['imageStyle'] as String?,
    );

Map<String, dynamic> _$$RuleContentImplToJson(_$RuleContentImpl instance) =>
    <String, dynamic>{
      'content': instance.content,
      'nextContentUrl': instance.nextContentUrl,
      'replaceRegex': instance.replaceRegex,
      'imageStyle': instance.imageStyle,
    };
