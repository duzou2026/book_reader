// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio_chapter.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AudioChapter _$AudioChapterFromJson(Map<String, dynamic> json) {
  return _AudioChapter.fromJson(json);
}

/// @nodoc
mixin _$AudioChapter {
  String get name => throw _privateConstructorUsedError;
  String get url => throw _privateConstructorUsedError;
  String get audioUrl => throw _privateConstructorUsedError;
  bool get isVolume => throw _privateConstructorUsedError;
  bool get isVip => throw _privateConstructorUsedError;
  String? get updateTime => throw _privateConstructorUsedError;
  int get index => throw _privateConstructorUsedError;

  /// Serializes this AudioChapter to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AudioChapter
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AudioChapterCopyWith<AudioChapter> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AudioChapterCopyWith<$Res> {
  factory $AudioChapterCopyWith(
          AudioChapter value, $Res Function(AudioChapter) then) =
      _$AudioChapterCopyWithImpl<$Res, AudioChapter>;
  @useResult
  $Res call(
      {String name,
      String url,
      String audioUrl,
      bool isVolume,
      bool isVip,
      String? updateTime,
      int index});
}

/// @nodoc
class _$AudioChapterCopyWithImpl<$Res, $Val extends AudioChapter>
    implements $AudioChapterCopyWith<$Res> {
  _$AudioChapterCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AudioChapter
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? url = null,
    Object? audioUrl = null,
    Object? isVolume = null,
    Object? isVip = null,
    Object? updateTime = freezed,
    Object? index = null,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      audioUrl: null == audioUrl
          ? _value.audioUrl
          : audioUrl // ignore: cast_nullable_to_non_nullable
              as String,
      isVolume: null == isVolume
          ? _value.isVolume
          : isVolume // ignore: cast_nullable_to_non_nullable
              as bool,
      isVip: null == isVip
          ? _value.isVip
          : isVip // ignore: cast_nullable_to_non_nullable
              as bool,
      updateTime: freezed == updateTime
          ? _value.updateTime
          : updateTime // ignore: cast_nullable_to_non_nullable
              as String?,
      index: null == index
          ? _value.index
          : index // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AudioChapterImplCopyWith<$Res>
    implements $AudioChapterCopyWith<$Res> {
  factory _$$AudioChapterImplCopyWith(
          _$AudioChapterImpl value, $Res Function(_$AudioChapterImpl) then) =
      __$$AudioChapterImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String name,
      String url,
      String audioUrl,
      bool isVolume,
      bool isVip,
      String? updateTime,
      int index});
}

/// @nodoc
class __$$AudioChapterImplCopyWithImpl<$Res>
    extends _$AudioChapterCopyWithImpl<$Res, _$AudioChapterImpl>
    implements _$$AudioChapterImplCopyWith<$Res> {
  __$$AudioChapterImplCopyWithImpl(
      _$AudioChapterImpl _value, $Res Function(_$AudioChapterImpl) _then)
      : super(_value, _then);

  /// Create a copy of AudioChapter
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? url = null,
    Object? audioUrl = null,
    Object? isVolume = null,
    Object? isVip = null,
    Object? updateTime = freezed,
    Object? index = null,
  }) {
    return _then(_$AudioChapterImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      audioUrl: null == audioUrl
          ? _value.audioUrl
          : audioUrl // ignore: cast_nullable_to_non_nullable
              as String,
      isVolume: null == isVolume
          ? _value.isVolume
          : isVolume // ignore: cast_nullable_to_non_nullable
              as bool,
      isVip: null == isVip
          ? _value.isVip
          : isVip // ignore: cast_nullable_to_non_nullable
              as bool,
      updateTime: freezed == updateTime
          ? _value.updateTime
          : updateTime // ignore: cast_nullable_to_non_nullable
              as String?,
      index: null == index
          ? _value.index
          : index // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AudioChapterImpl implements _AudioChapter {
  const _$AudioChapterImpl(
      {required this.name,
      required this.url,
      required this.audioUrl,
      this.isVolume = false,
      this.isVip = false,
      this.updateTime,
      this.index = 0});

  factory _$AudioChapterImpl.fromJson(Map<String, dynamic> json) =>
      _$$AudioChapterImplFromJson(json);

  @override
  final String name;
  @override
  final String url;
  @override
  final String audioUrl;
  @override
  @JsonKey()
  final bool isVolume;
  @override
  @JsonKey()
  final bool isVip;
  @override
  final String? updateTime;
  @override
  @JsonKey()
  final int index;

  @override
  String toString() {
    return 'AudioChapter(name: $name, url: $url, audioUrl: $audioUrl, isVolume: $isVolume, isVip: $isVip, updateTime: $updateTime, index: $index)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AudioChapterImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.audioUrl, audioUrl) ||
                other.audioUrl == audioUrl) &&
            (identical(other.isVolume, isVolume) ||
                other.isVolume == isVolume) &&
            (identical(other.isVip, isVip) || other.isVip == isVip) &&
            (identical(other.updateTime, updateTime) ||
                other.updateTime == updateTime) &&
            (identical(other.index, index) || other.index == index));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, name, url, audioUrl, isVolume, isVip, updateTime, index);

  /// Create a copy of AudioChapter
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AudioChapterImplCopyWith<_$AudioChapterImpl> get copyWith =>
      __$$AudioChapterImplCopyWithImpl<_$AudioChapterImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AudioChapterImplToJson(
      this,
    );
  }
}

abstract class _AudioChapter implements AudioChapter {
  const factory _AudioChapter(
      {required final String name,
      required final String url,
      required final String audioUrl,
      final bool isVolume,
      final bool isVip,
      final String? updateTime,
      final int index}) = _$AudioChapterImpl;

  factory _AudioChapter.fromJson(Map<String, dynamic> json) =
      _$AudioChapterImpl.fromJson;

  @override
  String get name;
  @override
  String get url;
  @override
  String get audioUrl;
  @override
  bool get isVolume;
  @override
  bool get isVip;
  @override
  String? get updateTime;
  @override
  int get index;

  /// Create a copy of AudioChapter
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AudioChapterImplCopyWith<_$AudioChapterImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
