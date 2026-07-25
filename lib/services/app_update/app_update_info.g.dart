// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_update_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReleaseAssetImpl _$$ReleaseAssetImplFromJson(Map<String, dynamic> json) =>
    _$ReleaseAssetImpl(
      name: json['name'] as String,
      browserDownloadUrl: json['browserDownloadUrl'] as String,
      size: (json['size'] as num).toInt(),
      contentType: json['contentType'] as String? ?? '',
    );

Map<String, dynamic> _$$ReleaseAssetImplToJson(_$ReleaseAssetImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'browserDownloadUrl': instance.browserDownloadUrl,
      'size': instance.size,
      'contentType': instance.contentType,
    };

_$AppUpdateInfoImpl _$$AppUpdateInfoImplFromJson(Map<String, dynamic> json) =>
    _$AppUpdateInfoImpl(
      tagName: json['tagName'] as String,
      version: json['version'] as String,
      name: json['name'] as String,
      body: json['body'] as String? ?? '',
      publishedAt: json['publishedAt'] as String? ?? '',
      htmlUrl: json['htmlUrl'] as String? ?? '',
      assets: (json['assets'] as List<dynamic>?)
              ?.map((e) => ReleaseAsset.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$AppUpdateInfoImplToJson(_$AppUpdateInfoImpl instance) =>
    <String, dynamic>{
      'tagName': instance.tagName,
      'version': instance.version,
      'name': instance.name,
      'body': instance.body,
      'publishedAt': instance.publishedAt,
      'htmlUrl': instance.htmlUrl,
      'assets': instance.assets,
    };
