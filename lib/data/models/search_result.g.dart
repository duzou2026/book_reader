// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SearchResultImpl _$$SearchResultImplFromJson(Map<String, dynamic> json) =>
    _$SearchResultImpl(
      bookName: json['bookName'] as String,
      author: json['author'] as String,
      coverUrl: json['coverUrl'] as String?,
      intro: json['intro'] as String?,
      kind: json['kind'] as String?,
      wordCount: json['wordCount'] as String?,
      lastChapter: json['lastChapter'] as String?,
      sources: (json['sources'] as List<dynamic>?)
              ?.map((e) => SearchSource.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$SearchResultImplToJson(_$SearchResultImpl instance) =>
    <String, dynamic>{
      'bookName': instance.bookName,
      'author': instance.author,
      'coverUrl': instance.coverUrl,
      'intro': instance.intro,
      'kind': instance.kind,
      'wordCount': instance.wordCount,
      'lastChapter': instance.lastChapter,
      'sources': instance.sources.map((e) => e.toJson()).toList(),
    };

_$SearchSourceImpl _$$SearchSourceImplFromJson(Map<String, dynamic> json) =>
    _$SearchSourceImpl(
      sourceName: json['sourceName'] as String,
      sourceUrl: json['sourceUrl'] as String,
      bookUrl: json['bookUrl'] as String,
    );

Map<String, dynamic> _$$SearchSourceImplToJson(_$SearchSourceImpl instance) =>
    <String, dynamic>{
      'sourceName': instance.sourceName,
      'sourceUrl': instance.sourceUrl,
      'bookUrl': instance.bookUrl,
    };
