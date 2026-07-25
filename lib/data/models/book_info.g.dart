// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BookInfoImpl _$$BookInfoImplFromJson(Map<String, dynamic> json) =>
    _$BookInfoImpl(
      url: json['url'] as String,
      sourceName: json['sourceName'] as String,
      sourceUrl: json['sourceUrl'] as String,
      name: json['name'] as String?,
      author: json['author'] as String?,
      intro: json['intro'] as String?,
      coverUrl: json['coverUrl'] as String?,
      kind: json['kind'] as String?,
      wordCount: json['wordCount'] as String?,
      lastChapter: json['lastChapter'] as String?,
      tocUrl: json['tocUrl'] as String?,
    );

Map<String, dynamic> _$$BookInfoImplToJson(_$BookInfoImpl instance) =>
    <String, dynamic>{
      'url': instance.url,
      'sourceName': instance.sourceName,
      'sourceUrl': instance.sourceUrl,
      'name': instance.name,
      'author': instance.author,
      'intro': instance.intro,
      'coverUrl': instance.coverUrl,
      'kind': instance.kind,
      'wordCount': instance.wordCount,
      'lastChapter': instance.lastChapter,
      'tocUrl': instance.tocUrl,
    };

_$ChapterImpl _$$ChapterImplFromJson(Map<String, dynamic> json) =>
    _$ChapterImpl(
      name: json['name'] as String,
      url: json['url'] as String,
      isVolume: json['isVolume'] as bool? ?? false,
      isVip: json['isVip'] as bool? ?? false,
      updateTime: json['updateTime'] as String?,
      index: (json['index'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$ChapterImplToJson(_$ChapterImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'url': instance.url,
      'isVolume': instance.isVolume,
      'isVip': instance.isVip,
      'updateTime': instance.updateTime,
      'index': instance.index,
    };
