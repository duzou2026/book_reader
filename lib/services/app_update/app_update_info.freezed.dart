// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_update_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ReleaseAsset _$ReleaseAssetFromJson(Map<String, dynamic> json) {
  return _ReleaseAsset.fromJson(json);
}

/// @nodoc
mixin _$ReleaseAsset {
  String get name => throw _privateConstructorUsedError;
  String get browserDownloadUrl => throw _privateConstructorUsedError;
  int get size => throw _privateConstructorUsedError;
  String get contentType => throw _privateConstructorUsedError;

  /// Serializes this ReleaseAsset to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ReleaseAsset
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReleaseAssetCopyWith<ReleaseAsset> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReleaseAssetCopyWith<$Res> {
  factory $ReleaseAssetCopyWith(
          ReleaseAsset value, $Res Function(ReleaseAsset) then) =
      _$ReleaseAssetCopyWithImpl<$Res, ReleaseAsset>;
  @useResult
  $Res call(
      {String name, String browserDownloadUrl, int size, String contentType});
}

/// @nodoc
class _$ReleaseAssetCopyWithImpl<$Res, $Val extends ReleaseAsset>
    implements $ReleaseAssetCopyWith<$Res> {
  _$ReleaseAssetCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReleaseAsset
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? browserDownloadUrl = null,
    Object? size = null,
    Object? contentType = null,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      browserDownloadUrl: null == browserDownloadUrl
          ? _value.browserDownloadUrl
          : browserDownloadUrl // ignore: cast_nullable_to_non_nullable
              as String,
      size: null == size
          ? _value.size
          : size // ignore: cast_nullable_to_non_nullable
              as int,
      contentType: null == contentType
          ? _value.contentType
          : contentType // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ReleaseAssetImplCopyWith<$Res>
    implements $ReleaseAssetCopyWith<$Res> {
  factory _$$ReleaseAssetImplCopyWith(
          _$ReleaseAssetImpl value, $Res Function(_$ReleaseAssetImpl) then) =
      __$$ReleaseAssetImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String name, String browserDownloadUrl, int size, String contentType});
}

/// @nodoc
class __$$ReleaseAssetImplCopyWithImpl<$Res>
    extends _$ReleaseAssetCopyWithImpl<$Res, _$ReleaseAssetImpl>
    implements _$$ReleaseAssetImplCopyWith<$Res> {
  __$$ReleaseAssetImplCopyWithImpl(
      _$ReleaseAssetImpl _value, $Res Function(_$ReleaseAssetImpl) _then)
      : super(_value, _then);

  /// Create a copy of ReleaseAsset
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? browserDownloadUrl = null,
    Object? size = null,
    Object? contentType = null,
  }) {
    return _then(_$ReleaseAssetImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      browserDownloadUrl: null == browserDownloadUrl
          ? _value.browserDownloadUrl
          : browserDownloadUrl // ignore: cast_nullable_to_non_nullable
              as String,
      size: null == size
          ? _value.size
          : size // ignore: cast_nullable_to_non_nullable
              as int,
      contentType: null == contentType
          ? _value.contentType
          : contentType // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ReleaseAssetImpl implements _ReleaseAsset {
  const _$ReleaseAssetImpl(
      {required this.name,
      required this.browserDownloadUrl,
      required this.size,
      this.contentType = ''});

  factory _$ReleaseAssetImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReleaseAssetImplFromJson(json);

  @override
  final String name;
  @override
  final String browserDownloadUrl;
  @override
  final int size;
  @override
  @JsonKey()
  final String contentType;

  @override
  String toString() {
    return 'ReleaseAsset(name: $name, browserDownloadUrl: $browserDownloadUrl, size: $size, contentType: $contentType)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReleaseAssetImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.browserDownloadUrl, browserDownloadUrl) ||
                other.browserDownloadUrl == browserDownloadUrl) &&
            (identical(other.size, size) || other.size == size) &&
            (identical(other.contentType, contentType) ||
                other.contentType == contentType));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, name, browserDownloadUrl, size, contentType);

  /// Create a copy of ReleaseAsset
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReleaseAssetImplCopyWith<_$ReleaseAssetImpl> get copyWith =>
      __$$ReleaseAssetImplCopyWithImpl<_$ReleaseAssetImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReleaseAssetImplToJson(
      this,
    );
  }
}

abstract class _ReleaseAsset implements ReleaseAsset {
  const factory _ReleaseAsset(
      {required final String name,
      required final String browserDownloadUrl,
      required final int size,
      final String contentType}) = _$ReleaseAssetImpl;

  factory _ReleaseAsset.fromJson(Map<String, dynamic> json) =
      _$ReleaseAssetImpl.fromJson;

  @override
  String get name;
  @override
  String get browserDownloadUrl;
  @override
  int get size;
  @override
  String get contentType;

  /// Create a copy of ReleaseAsset
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReleaseAssetImplCopyWith<_$ReleaseAssetImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AppUpdateInfo _$AppUpdateInfoFromJson(Map<String, dynamic> json) {
  return _AppUpdateInfo.fromJson(json);
}

/// @nodoc
mixin _$AppUpdateInfo {
  /// Release tag，如 `v0.2.2`。
  String get tagName => throw _privateConstructorUsedError;

  /// 解析后的语义版本号（不含 `v` 前缀），如 `0.2.2`。
  String get version => throw _privateConstructorUsedError;

  /// Release 名称（通常是 commit message）。
  String get name => throw _privateConstructorUsedError;

  /// Release body（changelog / release notes）。
  String get body => throw _privateConstructorUsedError;

  /// Release 发布时间（ISO8601 字符串）。
  String get publishedAt => throw _privateConstructorUsedError;

  /// HTML 页面 URL（用户可在浏览器查看）。
  String get htmlUrl => throw _privateConstructorUsedError;

  /// 所有可下载的 asset（APK 文件）。
  List<ReleaseAsset> get assets => throw _privateConstructorUsedError;

  /// Serializes this AppUpdateInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AppUpdateInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppUpdateInfoCopyWith<AppUpdateInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppUpdateInfoCopyWith<$Res> {
  factory $AppUpdateInfoCopyWith(
          AppUpdateInfo value, $Res Function(AppUpdateInfo) then) =
      _$AppUpdateInfoCopyWithImpl<$Res, AppUpdateInfo>;
  @useResult
  $Res call(
      {String tagName,
      String version,
      String name,
      String body,
      String publishedAt,
      String htmlUrl,
      List<ReleaseAsset> assets});
}

/// @nodoc
class _$AppUpdateInfoCopyWithImpl<$Res, $Val extends AppUpdateInfo>
    implements $AppUpdateInfoCopyWith<$Res> {
  _$AppUpdateInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppUpdateInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tagName = null,
    Object? version = null,
    Object? name = null,
    Object? body = null,
    Object? publishedAt = null,
    Object? htmlUrl = null,
    Object? assets = null,
  }) {
    return _then(_value.copyWith(
      tagName: null == tagName
          ? _value.tagName
          : tagName // ignore: cast_nullable_to_non_nullable
              as String,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      body: null == body
          ? _value.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
      publishedAt: null == publishedAt
          ? _value.publishedAt
          : publishedAt // ignore: cast_nullable_to_non_nullable
              as String,
      htmlUrl: null == htmlUrl
          ? _value.htmlUrl
          : htmlUrl // ignore: cast_nullable_to_non_nullable
              as String,
      assets: null == assets
          ? _value.assets
          : assets // ignore: cast_nullable_to_non_nullable
              as List<ReleaseAsset>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AppUpdateInfoImplCopyWith<$Res>
    implements $AppUpdateInfoCopyWith<$Res> {
  factory _$$AppUpdateInfoImplCopyWith(
          _$AppUpdateInfoImpl value, $Res Function(_$AppUpdateInfoImpl) then) =
      __$$AppUpdateInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String tagName,
      String version,
      String name,
      String body,
      String publishedAt,
      String htmlUrl,
      List<ReleaseAsset> assets});
}

/// @nodoc
class __$$AppUpdateInfoImplCopyWithImpl<$Res>
    extends _$AppUpdateInfoCopyWithImpl<$Res, _$AppUpdateInfoImpl>
    implements _$$AppUpdateInfoImplCopyWith<$Res> {
  __$$AppUpdateInfoImplCopyWithImpl(
      _$AppUpdateInfoImpl _value, $Res Function(_$AppUpdateInfoImpl) _then)
      : super(_value, _then);

  /// Create a copy of AppUpdateInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tagName = null,
    Object? version = null,
    Object? name = null,
    Object? body = null,
    Object? publishedAt = null,
    Object? htmlUrl = null,
    Object? assets = null,
  }) {
    return _then(_$AppUpdateInfoImpl(
      tagName: null == tagName
          ? _value.tagName
          : tagName // ignore: cast_nullable_to_non_nullable
              as String,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      body: null == body
          ? _value.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
      publishedAt: null == publishedAt
          ? _value.publishedAt
          : publishedAt // ignore: cast_nullable_to_non_nullable
              as String,
      htmlUrl: null == htmlUrl
          ? _value.htmlUrl
          : htmlUrl // ignore: cast_nullable_to_non_nullable
              as String,
      assets: null == assets
          ? _value._assets
          : assets // ignore: cast_nullable_to_non_nullable
              as List<ReleaseAsset>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AppUpdateInfoImpl implements _AppUpdateInfo {
  const _$AppUpdateInfoImpl(
      {required this.tagName,
      required this.version,
      required this.name,
      this.body = '',
      this.publishedAt = '',
      this.htmlUrl = '',
      final List<ReleaseAsset> assets = const []})
      : _assets = assets;

  factory _$AppUpdateInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppUpdateInfoImplFromJson(json);

  /// Release tag，如 `v0.2.2`。
  @override
  final String tagName;

  /// 解析后的语义版本号（不含 `v` 前缀），如 `0.2.2`。
  @override
  final String version;

  /// Release 名称（通常是 commit message）。
  @override
  final String name;

  /// Release body（changelog / release notes）。
  @override
  @JsonKey()
  final String body;

  /// Release 发布时间（ISO8601 字符串）。
  @override
  @JsonKey()
  final String publishedAt;

  /// HTML 页面 URL（用户可在浏览器查看）。
  @override
  @JsonKey()
  final String htmlUrl;

  /// 所有可下载的 asset（APK 文件）。
  final List<ReleaseAsset> _assets;

  /// 所有可下载的 asset（APK 文件）。
  @override
  @JsonKey()
  List<ReleaseAsset> get assets {
    if (_assets is EqualUnmodifiableListView) return _assets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_assets);
  }

  @override
  String toString() {
    return 'AppUpdateInfo(tagName: $tagName, version: $version, name: $name, body: $body, publishedAt: $publishedAt, htmlUrl: $htmlUrl, assets: $assets)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppUpdateInfoImpl &&
            (identical(other.tagName, tagName) || other.tagName == tagName) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.body, body) || other.body == body) &&
            (identical(other.publishedAt, publishedAt) ||
                other.publishedAt == publishedAt) &&
            (identical(other.htmlUrl, htmlUrl) || other.htmlUrl == htmlUrl) &&
            const DeepCollectionEquality().equals(other._assets, _assets));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, tagName, version, name, body,
      publishedAt, htmlUrl, const DeepCollectionEquality().hash(_assets));

  /// Create a copy of AppUpdateInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppUpdateInfoImplCopyWith<_$AppUpdateInfoImpl> get copyWith =>
      __$$AppUpdateInfoImplCopyWithImpl<_$AppUpdateInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AppUpdateInfoImplToJson(
      this,
    );
  }
}

abstract class _AppUpdateInfo implements AppUpdateInfo {
  const factory _AppUpdateInfo(
      {required final String tagName,
      required final String version,
      required final String name,
      final String body,
      final String publishedAt,
      final String htmlUrl,
      final List<ReleaseAsset> assets}) = _$AppUpdateInfoImpl;

  factory _AppUpdateInfo.fromJson(Map<String, dynamic> json) =
      _$AppUpdateInfoImpl.fromJson;

  /// Release tag，如 `v0.2.2`。
  @override
  String get tagName;

  /// 解析后的语义版本号（不含 `v` 前缀），如 `0.2.2`。
  @override
  String get version;

  /// Release 名称（通常是 commit message）。
  @override
  String get name;

  /// Release body（changelog / release notes）。
  @override
  String get body;

  /// Release 发布时间（ISO8601 字符串）。
  @override
  String get publishedAt;

  /// HTML 页面 URL（用户可在浏览器查看）。
  @override
  String get htmlUrl;

  /// 所有可下载的 asset（APK 文件）。
  @override
  List<ReleaseAsset> get assets;

  /// Create a copy of AppUpdateInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppUpdateInfoImplCopyWith<_$AppUpdateInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
