// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SearchResult _$SearchResultFromJson(Map<String, dynamic> json) {
  return _SearchResult.fromJson(json);
}

/// @nodoc
mixin _$SearchResult {
  String get bookName => throw _privateConstructorUsedError;
  String get author => throw _privateConstructorUsedError;
  String? get coverUrl => throw _privateConstructorUsedError;
  String? get intro => throw _privateConstructorUsedError;
  String? get kind => throw _privateConstructorUsedError;
  String? get wordCount => throw _privateConstructorUsedError;
  String? get lastChapter => throw _privateConstructorUsedError;
  List<SearchSource> get sources => throw _privateConstructorUsedError;

  /// Serializes this SearchResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SearchResultCopyWith<SearchResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SearchResultCopyWith<$Res> {
  factory $SearchResultCopyWith(
          SearchResult value, $Res Function(SearchResult) then) =
      _$SearchResultCopyWithImpl<$Res, SearchResult>;
  @useResult
  $Res call(
      {String bookName,
      String author,
      String? coverUrl,
      String? intro,
      String? kind,
      String? wordCount,
      String? lastChapter,
      List<SearchSource> sources});
}

/// @nodoc
class _$SearchResultCopyWithImpl<$Res, $Val extends SearchResult>
    implements $SearchResultCopyWith<$Res> {
  _$SearchResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bookName = null,
    Object? author = null,
    Object? coverUrl = freezed,
    Object? intro = freezed,
    Object? kind = freezed,
    Object? wordCount = freezed,
    Object? lastChapter = freezed,
    Object? sources = null,
  }) {
    return _then(_value.copyWith(
      bookName: null == bookName
          ? _value.bookName
          : bookName // ignore: cast_nullable_to_non_nullable
              as String,
      author: null == author
          ? _value.author
          : author // ignore: cast_nullable_to_non_nullable
              as String,
      coverUrl: freezed == coverUrl
          ? _value.coverUrl
          : coverUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      intro: freezed == intro
          ? _value.intro
          : intro // ignore: cast_nullable_to_non_nullable
              as String?,
      kind: freezed == kind
          ? _value.kind
          : kind // ignore: cast_nullable_to_non_nullable
              as String?,
      wordCount: freezed == wordCount
          ? _value.wordCount
          : wordCount // ignore: cast_nullable_to_non_nullable
              as String?,
      lastChapter: freezed == lastChapter
          ? _value.lastChapter
          : lastChapter // ignore: cast_nullable_to_non_nullable
              as String?,
      sources: null == sources
          ? _value.sources
          : sources // ignore: cast_nullable_to_non_nullable
              as List<SearchSource>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SearchResultImplCopyWith<$Res>
    implements $SearchResultCopyWith<$Res> {
  factory _$$SearchResultImplCopyWith(
          _$SearchResultImpl value, $Res Function(_$SearchResultImpl) then) =
      __$$SearchResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String bookName,
      String author,
      String? coverUrl,
      String? intro,
      String? kind,
      String? wordCount,
      String? lastChapter,
      List<SearchSource> sources});
}

/// @nodoc
class __$$SearchResultImplCopyWithImpl<$Res>
    extends _$SearchResultCopyWithImpl<$Res, _$SearchResultImpl>
    implements _$$SearchResultImplCopyWith<$Res> {
  __$$SearchResultImplCopyWithImpl(
      _$SearchResultImpl _value, $Res Function(_$SearchResultImpl) _then)
      : super(_value, _then);

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bookName = null,
    Object? author = null,
    Object? coverUrl = freezed,
    Object? intro = freezed,
    Object? kind = freezed,
    Object? wordCount = freezed,
    Object? lastChapter = freezed,
    Object? sources = null,
  }) {
    return _then(_$SearchResultImpl(
      bookName: null == bookName
          ? _value.bookName
          : bookName // ignore: cast_nullable_to_non_nullable
              as String,
      author: null == author
          ? _value.author
          : author // ignore: cast_nullable_to_non_nullable
              as String,
      coverUrl: freezed == coverUrl
          ? _value.coverUrl
          : coverUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      intro: freezed == intro
          ? _value.intro
          : intro // ignore: cast_nullable_to_non_nullable
              as String?,
      kind: freezed == kind
          ? _value.kind
          : kind // ignore: cast_nullable_to_non_nullable
              as String?,
      wordCount: freezed == wordCount
          ? _value.wordCount
          : wordCount // ignore: cast_nullable_to_non_nullable
              as String?,
      lastChapter: freezed == lastChapter
          ? _value.lastChapter
          : lastChapter // ignore: cast_nullable_to_non_nullable
              as String?,
      sources: null == sources
          ? _value._sources
          : sources // ignore: cast_nullable_to_non_nullable
              as List<SearchSource>,
    ));
  }
}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _$SearchResultImpl implements _SearchResult {
  const _$SearchResultImpl(
      {required this.bookName,
      required this.author,
      this.coverUrl,
      this.intro,
      this.kind,
      this.wordCount,
      this.lastChapter,
      final List<SearchSource> sources = const []})
      : _sources = sources;

  factory _$SearchResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$SearchResultImplFromJson(json);

  @override
  final String bookName;
  @override
  final String author;
  @override
  final String? coverUrl;
  @override
  final String? intro;
  @override
  final String? kind;
  @override
  final String? wordCount;
  @override
  final String? lastChapter;
  final List<SearchSource> _sources;
  @override
  @JsonKey()
  List<SearchSource> get sources {
    if (_sources is EqualUnmodifiableListView) return _sources;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sources);
  }

  @override
  String toString() {
    return 'SearchResult(bookName: $bookName, author: $author, coverUrl: $coverUrl, intro: $intro, kind: $kind, wordCount: $wordCount, lastChapter: $lastChapter, sources: $sources)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SearchResultImpl &&
            (identical(other.bookName, bookName) ||
                other.bookName == bookName) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.coverUrl, coverUrl) ||
                other.coverUrl == coverUrl) &&
            (identical(other.intro, intro) || other.intro == intro) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.wordCount, wordCount) ||
                other.wordCount == wordCount) &&
            (identical(other.lastChapter, lastChapter) ||
                other.lastChapter == lastChapter) &&
            const DeepCollectionEquality().equals(other._sources, _sources));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      bookName,
      author,
      coverUrl,
      intro,
      kind,
      wordCount,
      lastChapter,
      const DeepCollectionEquality().hash(_sources));

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SearchResultImplCopyWith<_$SearchResultImpl> get copyWith =>
      __$$SearchResultImplCopyWithImpl<_$SearchResultImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SearchResultImplToJson(
      this,
    );
  }
}

abstract class _SearchResult implements SearchResult {
  const factory _SearchResult(
      {required final String bookName,
      required final String author,
      final String? coverUrl,
      final String? intro,
      final String? kind,
      final String? wordCount,
      final String? lastChapter,
      final List<SearchSource> sources}) = _$SearchResultImpl;

  factory _SearchResult.fromJson(Map<String, dynamic> json) =
      _$SearchResultImpl.fromJson;

  @override
  String get bookName;
  @override
  String get author;
  @override
  String? get coverUrl;
  @override
  String? get intro;
  @override
  String? get kind;
  @override
  String? get wordCount;
  @override
  String? get lastChapter;
  @override
  List<SearchSource> get sources;

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SearchResultImplCopyWith<_$SearchResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SearchSource _$SearchSourceFromJson(Map<String, dynamic> json) {
  return _SearchSource.fromJson(json);
}

/// @nodoc
mixin _$SearchSource {
  String get sourceName => throw _privateConstructorUsedError;
  String get sourceUrl => throw _privateConstructorUsedError;
  String get bookUrl => throw _privateConstructorUsedError;

  /// Serializes this SearchSource to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SearchSource
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SearchSourceCopyWith<SearchSource> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SearchSourceCopyWith<$Res> {
  factory $SearchSourceCopyWith(
          SearchSource value, $Res Function(SearchSource) then) =
      _$SearchSourceCopyWithImpl<$Res, SearchSource>;
  @useResult
  $Res call({String sourceName, String sourceUrl, String bookUrl});
}

/// @nodoc
class _$SearchSourceCopyWithImpl<$Res, $Val extends SearchSource>
    implements $SearchSourceCopyWith<$Res> {
  _$SearchSourceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SearchSource
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sourceName = null,
    Object? sourceUrl = null,
    Object? bookUrl = null,
  }) {
    return _then(_value.copyWith(
      sourceName: null == sourceName
          ? _value.sourceName
          : sourceName // ignore: cast_nullable_to_non_nullable
              as String,
      sourceUrl: null == sourceUrl
          ? _value.sourceUrl
          : sourceUrl // ignore: cast_nullable_to_non_nullable
              as String,
      bookUrl: null == bookUrl
          ? _value.bookUrl
          : bookUrl // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SearchSourceImplCopyWith<$Res>
    implements $SearchSourceCopyWith<$Res> {
  factory _$$SearchSourceImplCopyWith(
          _$SearchSourceImpl value, $Res Function(_$SearchSourceImpl) then) =
      __$$SearchSourceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String sourceName, String sourceUrl, String bookUrl});
}

/// @nodoc
class __$$SearchSourceImplCopyWithImpl<$Res>
    extends _$SearchSourceCopyWithImpl<$Res, _$SearchSourceImpl>
    implements _$$SearchSourceImplCopyWith<$Res> {
  __$$SearchSourceImplCopyWithImpl(
      _$SearchSourceImpl _value, $Res Function(_$SearchSourceImpl) _then)
      : super(_value, _then);

  /// Create a copy of SearchSource
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sourceName = null,
    Object? sourceUrl = null,
    Object? bookUrl = null,
  }) {
    return _then(_$SearchSourceImpl(
      sourceName: null == sourceName
          ? _value.sourceName
          : sourceName // ignore: cast_nullable_to_non_nullable
              as String,
      sourceUrl: null == sourceUrl
          ? _value.sourceUrl
          : sourceUrl // ignore: cast_nullable_to_non_nullable
              as String,
      bookUrl: null == bookUrl
          ? _value.bookUrl
          : bookUrl // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SearchSourceImpl implements _SearchSource {
  const _$SearchSourceImpl(
      {required this.sourceName,
      required this.sourceUrl,
      required this.bookUrl});

  factory _$SearchSourceImpl.fromJson(Map<String, dynamic> json) =>
      _$$SearchSourceImplFromJson(json);

  @override
  final String sourceName;
  @override
  final String sourceUrl;
  @override
  final String bookUrl;

  @override
  String toString() {
    return 'SearchSource(sourceName: $sourceName, sourceUrl: $sourceUrl, bookUrl: $bookUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SearchSourceImpl &&
            (identical(other.sourceName, sourceName) ||
                other.sourceName == sourceName) &&
            (identical(other.sourceUrl, sourceUrl) ||
                other.sourceUrl == sourceUrl) &&
            (identical(other.bookUrl, bookUrl) || other.bookUrl == bookUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, sourceName, sourceUrl, bookUrl);

  /// Create a copy of SearchSource
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SearchSourceImplCopyWith<_$SearchSourceImpl> get copyWith =>
      __$$SearchSourceImplCopyWithImpl<_$SearchSourceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SearchSourceImplToJson(
      this,
    );
  }
}

abstract class _SearchSource implements SearchSource {
  const factory _SearchSource(
      {required final String sourceName,
      required final String sourceUrl,
      required final String bookUrl}) = _$SearchSourceImpl;

  factory _SearchSource.fromJson(Map<String, dynamic> json) =
      _$SearchSourceImpl.fromJson;

  @override
  String get sourceName;
  @override
  String get sourceUrl;
  @override
  String get bookUrl;

  /// Create a copy of SearchSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SearchSourceImplCopyWith<_$SearchSourceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
