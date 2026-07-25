// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_chapter.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AudioChapterImpl _$$AudioChapterImplFromJson(Map<String, dynamic> json) =>
    _$AudioChapterImpl(
      name: json['name'] as String,
      url: json['url'] as String,
      audioUrl: json['audioUrl'] as String,
      isVolume: json['isVolume'] as bool? ?? false,
      isVip: json['isVip'] as bool? ?? false,
      updateTime: json['updateTime'] as String?,
      index: (json['index'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$AudioChapterImplToJson(_$AudioChapterImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'url': instance.url,
      'audioUrl': instance.audioUrl,
      'isVolume': instance.isVolume,
      'isVip': instance.isVip,
      'updateTime': instance.updateTime,
      'index': instance.index,
    };
