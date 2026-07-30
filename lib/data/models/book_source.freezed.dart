// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book_source.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

BookSource _$BookSourceFromJson(Map<String, dynamic> json) {
  return _BookSource.fromJson(json);
}

/// @nodoc
mixin _$BookSource {
  String get bookSourceName => throw _privateConstructorUsedError;
  String get bookSourceUrl => throw _privateConstructorUsedError;
  BookSourceType get bookSourceType => throw _privateConstructorUsedError;
  bool get enabled => throw _privateConstructorUsedError;
  String? get bookSourceGroup => throw _privateConstructorUsedError;
  String? get searchUrl => throw _privateConstructorUsedError;
  String? get loginUrl => throw _privateConstructorUsedError;
  RuleSearch? get ruleSearch => throw _privateConstructorUsedError;
  RuleBookInfo? get ruleBookInfo => throw _privateConstructorUsedError;
  RuleToc? get ruleToc => throw _privateConstructorUsedError;
  RuleContent? get ruleContent => throw _privateConstructorUsedError;
  String? get header => throw _privateConstructorUsedError;
  int get priority => throw _privateConstructorUsedError;
  int get weight => throw _privateConstructorUsedError;
  Object? get lastUpdateTime => throw _privateConstructorUsedError;
  Object? get respondTime => throw _privateConstructorUsedError;
  String? get weightValue => throw _privateConstructorUsedError;
  String? get exploreUrl => throw _privateConstructorUsedError;
  RuleSearch? get ruleExplore => throw _privateConstructorUsedError;

  /// Serializes this BookSource to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BookSourceCopyWith<BookSource> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BookSourceCopyWith<$Res> {
  factory $BookSourceCopyWith(
          BookSource value, $Res Function(BookSource) then) =
      _$BookSourceCopyWithImpl<$Res, BookSource>;
  @useResult
  $Res call(
      {String bookSourceName,
      String bookSourceUrl,
      BookSourceType bookSourceType,
      bool enabled,
      String? bookSourceGroup,
      String? searchUrl,
      String? loginUrl,
      RuleSearch? ruleSearch,
      RuleBookInfo? ruleBookInfo,
      RuleToc? ruleToc,
      RuleContent? ruleContent,
      String? header,
      int priority,
      int weight,
      Object? lastUpdateTime,
      Object? respondTime,
      String? weightValue,
      String? exploreUrl,
      RuleSearch? ruleExplore});

  $RuleSearchCopyWith<$Res>? get ruleSearch;
  $RuleBookInfoCopyWith<$Res>? get ruleBookInfo;
  $RuleTocCopyWith<$Res>? get ruleToc;
  $RuleContentCopyWith<$Res>? get ruleContent;
  $RuleSearchCopyWith<$Res>? get ruleExplore;
}

/// @nodoc
class _$BookSourceCopyWithImpl<$Res, $Val extends BookSource>
    implements $BookSourceCopyWith<$Res> {
  _$BookSourceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bookSourceName = null,
    Object? bookSourceUrl = null,
    Object? bookSourceType = null,
    Object? enabled = null,
    Object? bookSourceGroup = freezed,
    Object? searchUrl = freezed,
    Object? loginUrl = freezed,
    Object? ruleSearch = freezed,
    Object? ruleBookInfo = freezed,
    Object? ruleToc = freezed,
    Object? ruleContent = freezed,
    Object? header = freezed,
    Object? priority = null,
    Object? weight = null,
    Object? lastUpdateTime = freezed,
    Object? respondTime = freezed,
    Object? weightValue = freezed,
    Object? exploreUrl = freezed,
    Object? ruleExplore = freezed,
  }) {
    return _then(_value.copyWith(
      bookSourceName: null == bookSourceName
          ? _value.bookSourceName
          : bookSourceName // ignore: cast_nullable_to_non_nullable
              as String,
      bookSourceUrl: null == bookSourceUrl
          ? _value.bookSourceUrl
          : bookSourceUrl // ignore: cast_nullable_to_non_nullable
              as String,
      bookSourceType: null == bookSourceType
          ? _value.bookSourceType
          : bookSourceType // ignore: cast_nullable_to_non_nullable
              as BookSourceType,
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      bookSourceGroup: freezed == bookSourceGroup
          ? _value.bookSourceGroup
          : bookSourceGroup // ignore: cast_nullable_to_non_nullable
              as String?,
      searchUrl: freezed == searchUrl
          ? _value.searchUrl
          : searchUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      loginUrl: freezed == loginUrl
          ? _value.loginUrl
          : loginUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      ruleSearch: freezed == ruleSearch
          ? _value.ruleSearch
          : ruleSearch // ignore: cast_nullable_to_non_nullable
              as RuleSearch?,
      ruleBookInfo: freezed == ruleBookInfo
          ? _value.ruleBookInfo
          : ruleBookInfo // ignore: cast_nullable_to_non_nullable
              as RuleBookInfo?,
      ruleToc: freezed == ruleToc
          ? _value.ruleToc
          : ruleToc // ignore: cast_nullable_to_non_nullable
              as RuleToc?,
      ruleContent: freezed == ruleContent
          ? _value.ruleContent
          : ruleContent // ignore: cast_nullable_to_non_nullable
              as RuleContent?,
      header: freezed == header
          ? _value.header
          : header // ignore: cast_nullable_to_non_nullable
              as String?,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as int,
      weight: null == weight
          ? _value.weight
          : weight // ignore: cast_nullable_to_non_nullable
              as int,
      lastUpdateTime: freezed == lastUpdateTime
          ? _value.lastUpdateTime
          : lastUpdateTime // ignore: cast_nullable_to_non_nullable
              as String?,
      respondTime: freezed == respondTime
          ? _value.respondTime
          : respondTime // ignore: cast_nullable_to_non_nullable
              as String?,
      weightValue: freezed == weightValue
          ? _value.weightValue
          : weightValue // ignore: cast_nullable_to_non_nullable
              as String?,
      exploreUrl: freezed == exploreUrl
          ? _value.exploreUrl
          : exploreUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      ruleExplore: freezed == ruleExplore
          ? _value.ruleExplore
          : ruleExplore // ignore: cast_nullable_to_non_nullable
              as RuleSearch?,
    ) as $Val);
  }

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RuleSearchCopyWith<$Res>? get ruleSearch {
    if (_value.ruleSearch == null) {
      return null;
    }

    return $RuleSearchCopyWith<$Res>(_value.ruleSearch!, (value) {
      return _then(_value.copyWith(ruleSearch: value) as $Val);
    });
  }

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RuleBookInfoCopyWith<$Res>? get ruleBookInfo {
    if (_value.ruleBookInfo == null) {
      return null;
    }

    return $RuleBookInfoCopyWith<$Res>(_value.ruleBookInfo!, (value) {
      return _then(_value.copyWith(ruleBookInfo: value) as $Val);
    });
  }

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RuleTocCopyWith<$Res>? get ruleToc {
    if (_value.ruleToc == null) {
      return null;
    }

    return $RuleTocCopyWith<$Res>(_value.ruleToc!, (value) {
      return _then(_value.copyWith(ruleToc: value) as $Val);
    });
  }

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RuleContentCopyWith<$Res>? get ruleContent {
    if (_value.ruleContent == null) {
      return null;
    }

    return $RuleContentCopyWith<$Res>(_value.ruleContent!, (value) {
      return _then(_value.copyWith(ruleContent: value) as $Val);
    });
  }

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RuleSearchCopyWith<$Res>? get ruleExplore {
    if (_value.ruleExplore == null) {
      return null;
    }

    return $RuleSearchCopyWith<$Res>(_value.ruleExplore!, (value) {
      return _then(_value.copyWith(ruleExplore: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$BookSourceImplCopyWith<$Res>
    implements $BookSourceCopyWith<$Res> {
  factory _$$BookSourceImplCopyWith(
          _$BookSourceImpl value, $Res Function(_$BookSourceImpl) then) =
      __$$BookSourceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String bookSourceName,
      String bookSourceUrl,
      BookSourceType bookSourceType,
      bool enabled,
      String? bookSourceGroup,
      String? searchUrl,
      String? loginUrl,
      RuleSearch? ruleSearch,
      RuleBookInfo? ruleBookInfo,
      RuleToc? ruleToc,
      RuleContent? ruleContent,
      String? header,
      int priority,
      int weight,
      Object? lastUpdateTime,
      Object? respondTime,
      String? weightValue,
      String? exploreUrl,
      RuleSearch? ruleExplore});

  @override
  $RuleSearchCopyWith<$Res>? get ruleSearch;
  @override
  $RuleBookInfoCopyWith<$Res>? get ruleBookInfo;
  @override
  $RuleTocCopyWith<$Res>? get ruleToc;
  @override
  $RuleContentCopyWith<$Res>? get ruleContent;
  @override
  $RuleSearchCopyWith<$Res>? get ruleExplore;
}

/// @nodoc
class __$$BookSourceImplCopyWithImpl<$Res>
    extends _$BookSourceCopyWithImpl<$Res, _$BookSourceImpl>
    implements _$$BookSourceImplCopyWith<$Res> {
  __$$BookSourceImplCopyWithImpl(
      _$BookSourceImpl _value, $Res Function(_$BookSourceImpl) _then)
      : super(_value, _then);

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bookSourceName = null,
    Object? bookSourceUrl = null,
    Object? bookSourceType = null,
    Object? enabled = null,
    Object? bookSourceGroup = freezed,
    Object? searchUrl = freezed,
    Object? loginUrl = freezed,
    Object? ruleSearch = freezed,
    Object? ruleBookInfo = freezed,
    Object? ruleToc = freezed,
    Object? ruleContent = freezed,
    Object? header = freezed,
    Object? priority = null,
    Object? weight = null,
    Object? lastUpdateTime = freezed,
    Object? respondTime = freezed,
    Object? weightValue = freezed,
    Object? exploreUrl = freezed,
    Object? ruleExplore = freezed,
  }) {
    return _then(_$BookSourceImpl(
      bookSourceName: null == bookSourceName
          ? _value.bookSourceName
          : bookSourceName // ignore: cast_nullable_to_non_nullable
              as String,
      bookSourceUrl: null == bookSourceUrl
          ? _value.bookSourceUrl
          : bookSourceUrl // ignore: cast_nullable_to_non_nullable
              as String,
      bookSourceType: null == bookSourceType
          ? _value.bookSourceType
          : bookSourceType // ignore: cast_nullable_to_non_nullable
              as BookSourceType,
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      bookSourceGroup: freezed == bookSourceGroup
          ? _value.bookSourceGroup
          : bookSourceGroup // ignore: cast_nullable_to_non_nullable
              as String?,
      searchUrl: freezed == searchUrl
          ? _value.searchUrl
          : searchUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      loginUrl: freezed == loginUrl
          ? _value.loginUrl
          : loginUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      ruleSearch: freezed == ruleSearch
          ? _value.ruleSearch
          : ruleSearch // ignore: cast_nullable_to_non_nullable
              as RuleSearch?,
      ruleBookInfo: freezed == ruleBookInfo
          ? _value.ruleBookInfo
          : ruleBookInfo // ignore: cast_nullable_to_non_nullable
              as RuleBookInfo?,
      ruleToc: freezed == ruleToc
          ? _value.ruleToc
          : ruleToc // ignore: cast_nullable_to_non_nullable
              as RuleToc?,
      ruleContent: freezed == ruleContent
          ? _value.ruleContent
          : ruleContent // ignore: cast_nullable_to_non_nullable
              as RuleContent?,
      header: freezed == header
          ? _value.header
          : header // ignore: cast_nullable_to_non_nullable
              as String?,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as int,
      weight: null == weight
          ? _value.weight
          : weight // ignore: cast_nullable_to_non_nullable
              as int,
      lastUpdateTime: freezed == lastUpdateTime
          ? _value.lastUpdateTime
          : lastUpdateTime // ignore: cast_nullable_to_non_nullable
              as String?,
      respondTime: freezed == respondTime
          ? _value.respondTime
          : respondTime // ignore: cast_nullable_to_non_nullable
              as String?,
      weightValue: freezed == weightValue
          ? _value.weightValue
          : weightValue // ignore: cast_nullable_to_non_nullable
              as String?,
      exploreUrl: freezed == exploreUrl
          ? _value.exploreUrl
          : exploreUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      ruleExplore: freezed == ruleExplore
          ? _value.ruleExplore
          : ruleExplore // ignore: cast_nullable_to_non_nullable
              as RuleSearch?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BookSourceImpl implements _BookSource {
  const _$BookSourceImpl(
      {required this.bookSourceName,
      required this.bookSourceUrl,
      this.bookSourceType = BookSourceType.text,
      this.enabled = true,
      this.bookSourceGroup,
      this.searchUrl,
      this.loginUrl,
      this.ruleSearch,
      this.ruleBookInfo,
      this.ruleToc,
      this.ruleContent,
      this.header,
      this.priority = 0,
      this.weight = 0,
      this.lastUpdateTime,
      this.respondTime,
      this.weightValue,
      this.exploreUrl,
      this.ruleExplore});

  factory _$BookSourceImpl.fromJson(Map<String, dynamic> json) =>
      _$$BookSourceImplFromJson(json);

  @override
  final String bookSourceName;
  @override
  final String bookSourceUrl;
  @override
  @JsonKey()
  final BookSourceType bookSourceType;
  @override
  @JsonKey()
  final bool enabled;
  @override
  final String? bookSourceGroup;
  @override
  final String? searchUrl;
  @override
  final String? loginUrl;
  @override
  final RuleSearch? ruleSearch;
  @override
  final RuleBookInfo? ruleBookInfo;
  @override
  final RuleToc? ruleToc;
  @override
  final RuleContent? ruleContent;
  final String? header;
  @override
  @JsonKey()
  final int priority;
  @override
  @JsonKey()
  final int weight;
  @override
  final Object? lastUpdateTime;
  @override
  final Object? respondTime;
  @override
  final String? weightValue;
  @override
  final String? exploreUrl;
  @override
  final RuleSearch? ruleExplore;

  @override
  String toString() {
    return 'BookSource(bookSourceName: $bookSourceName, bookSourceUrl: $bookSourceUrl, bookSourceType: $bookSourceType, enabled: $enabled, bookSourceGroup: $bookSourceGroup, searchUrl: $searchUrl, loginUrl: $loginUrl, ruleSearch: $ruleSearch, ruleBookInfo: $ruleBookInfo, ruleToc: $ruleToc, ruleContent: $ruleContent, header: $header, priority: $priority, weight: $weight, lastUpdateTime: $lastUpdateTime, respondTime: $respondTime, weightValue: $weightValue, exploreUrl: $exploreUrl, ruleExplore: $ruleExplore)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BookSourceImpl &&
            (identical(other.bookSourceName, bookSourceName) ||
                other.bookSourceName == bookSourceName) &&
            (identical(other.bookSourceUrl, bookSourceUrl) ||
                other.bookSourceUrl == bookSourceUrl) &&
            (identical(other.bookSourceType, bookSourceType) ||
                other.bookSourceType == bookSourceType) &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.bookSourceGroup, bookSourceGroup) ||
                other.bookSourceGroup == bookSourceGroup) &&
            (identical(other.searchUrl, searchUrl) ||
                other.searchUrl == searchUrl) &&
            (identical(other.loginUrl, loginUrl) ||
                other.loginUrl == loginUrl) &&
            (identical(other.ruleSearch, ruleSearch) ||
                other.ruleSearch == ruleSearch) &&
            (identical(other.ruleBookInfo, ruleBookInfo) ||
                other.ruleBookInfo == ruleBookInfo) &&
            (identical(other.ruleToc, ruleToc) || other.ruleToc == ruleToc) &&
            (identical(other.ruleContent, ruleContent) ||
                other.ruleContent == ruleContent) &&
            (identical(other.header, header) ||
                other.header == header) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.weight, weight) || other.weight == weight) &&
            (identical(other.lastUpdateTime, lastUpdateTime) ||
                other.lastUpdateTime == lastUpdateTime) &&
            (identical(other.respondTime, respondTime) ||
                other.respondTime == respondTime) &&
            (identical(other.weightValue, weightValue) ||
                other.weightValue == weightValue) &&
            (identical(other.exploreUrl, exploreUrl) ||
                other.exploreUrl == exploreUrl) &&
            (identical(other.ruleExplore, ruleExplore) ||
                other.ruleExplore == ruleExplore));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      bookSourceName,
      bookSourceUrl,
      bookSourceType,
      enabled,
      bookSourceGroup,
      searchUrl,
      loginUrl,
      ruleSearch,
      ruleBookInfo,
      ruleToc,
      ruleContent,
      header,
      priority,
      weight,
      lastUpdateTime,
      respondTime,
      weightValue,
      exploreUrl,
      ruleExplore);

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BookSourceImplCopyWith<_$BookSourceImpl> get copyWith =>
      __$$BookSourceImplCopyWithImpl<_$BookSourceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BookSourceImplToJson(
      this,
    );
  }
}

abstract class _BookSource implements BookSource {
  const factory _BookSource(
      {required final String bookSourceName,
      required final String bookSourceUrl,
      final BookSourceType bookSourceType,
      final bool enabled,
      final String? bookSourceGroup,
      final String? searchUrl,
      final String? loginUrl,
      final RuleSearch? ruleSearch,
      final RuleBookInfo? ruleBookInfo,
      final RuleToc? ruleToc,
      final RuleContent? ruleContent,
      final String? header,
      final int priority,
      final int weight,
      final Object? lastUpdateTime,
      final Object? respondTime,
      final String? weightValue,
      final String? exploreUrl,
      final RuleSearch? ruleExplore}) = _$BookSourceImpl;

  factory _BookSource.fromJson(Map<String, dynamic> json) =
      _$BookSourceImpl.fromJson;

  @override
  String get bookSourceName;
  @override
  String get bookSourceUrl;
  @override
  BookSourceType get bookSourceType;
  @override
  bool get enabled;
  @override
  String? get bookSourceGroup;
  @override
  String? get searchUrl;
  @override
  String? get loginUrl;
  @override
  RuleSearch? get ruleSearch;
  @override
  RuleBookInfo? get ruleBookInfo;
  @override
  RuleToc? get ruleToc;
  @override
  RuleContent? get ruleContent;
  @override
  int get priority;
  @override
  int get weight;
  @override
  Object? get lastUpdateTime;
  @override
  Object? get respondTime;
  @override
  String? get weightValue;
  @override
  String? get exploreUrl;
  @override
  RuleSearch? get ruleExplore;

  /// Create a copy of BookSource
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BookSourceImplCopyWith<_$BookSourceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RuleSearch _$RuleSearchFromJson(Map<String, dynamic> json) {
  return _RuleSearch.fromJson(json);
}

/// @nodoc
mixin _$RuleSearch {
  String? get bookList => throw _privateConstructorUsedError;
  String? get name => throw _privateConstructorUsedError;
  String? get author => throw _privateConstructorUsedError;
  String? get kind => throw _privateConstructorUsedError;
  String? get wordCount => throw _privateConstructorUsedError;
  String? get lastChapter => throw _privateConstructorUsedError;
  String? get intro => throw _privateConstructorUsedError;
  String? get coverUrl => throw _privateConstructorUsedError;
  String? get bookUrl => throw _privateConstructorUsedError;

  /// Serializes this RuleSearch to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RuleSearch
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RuleSearchCopyWith<RuleSearch> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RuleSearchCopyWith<$Res> {
  factory $RuleSearchCopyWith(
          RuleSearch value, $Res Function(RuleSearch) then) =
      _$RuleSearchCopyWithImpl<$Res, RuleSearch>;
  @useResult
  $Res call(
      {String? bookList,
      String? name,
      String? author,
      String? kind,
      String? wordCount,
      String? lastChapter,
      String? intro,
      String? coverUrl,
      String? bookUrl});
}

/// @nodoc
class _$RuleSearchCopyWithImpl<$Res, $Val extends RuleSearch>
    implements $RuleSearchCopyWith<$Res> {
  _$RuleSearchCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RuleSearch
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bookList = freezed,
    Object? name = freezed,
    Object? author = freezed,
    Object? kind = freezed,
    Object? wordCount = freezed,
    Object? lastChapter = freezed,
    Object? intro = freezed,
    Object? coverUrl = freezed,
    Object? bookUrl = freezed,
  }) {
    return _then(_value.copyWith(
      bookList: freezed == bookList
          ? _value.bookList
          : bookList // ignore: cast_nullable_to_non_nullable
              as String?,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      author: freezed == author
          ? _value.author
          : author // ignore: cast_nullable_to_non_nullable
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
      intro: freezed == intro
          ? _value.intro
          : intro // ignore: cast_nullable_to_non_nullable
              as String?,
      coverUrl: freezed == coverUrl
          ? _value.coverUrl
          : coverUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      bookUrl: freezed == bookUrl
          ? _value.bookUrl
          : bookUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RuleSearchImplCopyWith<$Res>
    implements $RuleSearchCopyWith<$Res> {
  factory _$$RuleSearchImplCopyWith(
          _$RuleSearchImpl value, $Res Function(_$RuleSearchImpl) then) =
      __$$RuleSearchImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? bookList,
      String? name,
      String? author,
      String? kind,
      String? wordCount,
      String? lastChapter,
      String? intro,
      String? coverUrl,
      String? bookUrl});
}

/// @nodoc
class __$$RuleSearchImplCopyWithImpl<$Res>
    extends _$RuleSearchCopyWithImpl<$Res, _$RuleSearchImpl>
    implements _$$RuleSearchImplCopyWith<$Res> {
  __$$RuleSearchImplCopyWithImpl(
      _$RuleSearchImpl _value, $Res Function(_$RuleSearchImpl) _then)
      : super(_value, _then);

  /// Create a copy of RuleSearch
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bookList = freezed,
    Object? name = freezed,
    Object? author = freezed,
    Object? kind = freezed,
    Object? wordCount = freezed,
    Object? lastChapter = freezed,
    Object? intro = freezed,
    Object? coverUrl = freezed,
    Object? bookUrl = freezed,
  }) {
    return _then(_$RuleSearchImpl(
      bookList: freezed == bookList
          ? _value.bookList
          : bookList // ignore: cast_nullable_to_non_nullable
              as String?,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      author: freezed == author
          ? _value.author
          : author // ignore: cast_nullable_to_non_nullable
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
      intro: freezed == intro
          ? _value.intro
          : intro // ignore: cast_nullable_to_non_nullable
              as String?,
      coverUrl: freezed == coverUrl
          ? _value.coverUrl
          : coverUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      bookUrl: freezed == bookUrl
          ? _value.bookUrl
          : bookUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RuleSearchImpl implements _RuleSearch {
  const _$RuleSearchImpl(
      {this.bookList,
      this.name,
      this.author,
      this.kind,
      this.wordCount,
      this.lastChapter,
      this.intro,
      this.coverUrl,
      this.bookUrl});

  factory _$RuleSearchImpl.fromJson(Map<String, dynamic> json) =>
      _$$RuleSearchImplFromJson(json);

  @override
  final String? bookList;
  @override
  final String? name;
  @override
  final String? author;
  @override
  final String? kind;
  @override
  final String? wordCount;
  @override
  final String? lastChapter;
  @override
  final String? intro;
  @override
  final String? coverUrl;
  @override
  final String? bookUrl;

  @override
  String toString() {
    return 'RuleSearch(bookList: $bookList, name: $name, author: $author, kind: $kind, wordCount: $wordCount, lastChapter: $lastChapter, intro: $intro, coverUrl: $coverUrl, bookUrl: $bookUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RuleSearchImpl &&
            (identical(other.bookList, bookList) ||
                other.bookList == bookList) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.wordCount, wordCount) ||
                other.wordCount == wordCount) &&
            (identical(other.lastChapter, lastChapter) ||
                other.lastChapter == lastChapter) &&
            (identical(other.intro, intro) || other.intro == intro) &&
            (identical(other.coverUrl, coverUrl) ||
                other.coverUrl == coverUrl) &&
            (identical(other.bookUrl, bookUrl) || other.bookUrl == bookUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, bookList, name, author, kind,
      wordCount, lastChapter, intro, coverUrl, bookUrl);

  /// Create a copy of RuleSearch
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RuleSearchImplCopyWith<_$RuleSearchImpl> get copyWith =>
      __$$RuleSearchImplCopyWithImpl<_$RuleSearchImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RuleSearchImplToJson(
      this,
    );
  }
}

abstract class _RuleSearch implements RuleSearch {
  const factory _RuleSearch(
      {final String? bookList,
      final String? name,
      final String? author,
      final String? kind,
      final String? wordCount,
      final String? lastChapter,
      final String? intro,
      final String? coverUrl,
      final String? bookUrl}) = _$RuleSearchImpl;

  factory _RuleSearch.fromJson(Map<String, dynamic> json) =
      _$RuleSearchImpl.fromJson;

  @override
  String? get bookList;
  @override
  String? get name;
  @override
  String? get author;
  @override
  String? get kind;
  @override
  String? get wordCount;
  @override
  String? get lastChapter;
  @override
  String? get intro;
  @override
  String? get coverUrl;
  @override
  String? get bookUrl;

  /// Create a copy of RuleSearch
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RuleSearchImplCopyWith<_$RuleSearchImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RuleBookInfo _$RuleBookInfoFromJson(Map<String, dynamic> json) {
  return _RuleBookInfo.fromJson(json);
}

/// @nodoc
mixin _$RuleBookInfo {
  String? get name => throw _privateConstructorUsedError;
  String? get author => throw _privateConstructorUsedError;
  String? get intro => throw _privateConstructorUsedError;
  String? get coverUrl => throw _privateConstructorUsedError;
  String? get kind => throw _privateConstructorUsedError;
  String? get lastChapter => throw _privateConstructorUsedError;
  String? get tocUrl => throw _privateConstructorUsedError;
  String? get wordCount => throw _privateConstructorUsedError;

  /// Serializes this RuleBookInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RuleBookInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RuleBookInfoCopyWith<RuleBookInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RuleBookInfoCopyWith<$Res> {
  factory $RuleBookInfoCopyWith(
          RuleBookInfo value, $Res Function(RuleBookInfo) then) =
      _$RuleBookInfoCopyWithImpl<$Res, RuleBookInfo>;
  @useResult
  $Res call(
      {String? name,
      String? author,
      String? intro,
      String? coverUrl,
      String? kind,
      String? lastChapter,
      String? tocUrl,
      String? wordCount});
}

/// @nodoc
class _$RuleBookInfoCopyWithImpl<$Res, $Val extends RuleBookInfo>
    implements $RuleBookInfoCopyWith<$Res> {
  _$RuleBookInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RuleBookInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = freezed,
    Object? author = freezed,
    Object? intro = freezed,
    Object? coverUrl = freezed,
    Object? kind = freezed,
    Object? lastChapter = freezed,
    Object? tocUrl = freezed,
    Object? wordCount = freezed,
  }) {
    return _then(_value.copyWith(
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      author: freezed == author
          ? _value.author
          : author // ignore: cast_nullable_to_non_nullable
              as String?,
      intro: freezed == intro
          ? _value.intro
          : intro // ignore: cast_nullable_to_non_nullable
              as String?,
      coverUrl: freezed == coverUrl
          ? _value.coverUrl
          : coverUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      kind: freezed == kind
          ? _value.kind
          : kind // ignore: cast_nullable_to_non_nullable
              as String?,
      lastChapter: freezed == lastChapter
          ? _value.lastChapter
          : lastChapter // ignore: cast_nullable_to_non_nullable
              as String?,
      tocUrl: freezed == tocUrl
          ? _value.tocUrl
          : tocUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      wordCount: freezed == wordCount
          ? _value.wordCount
          : wordCount // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RuleBookInfoImplCopyWith<$Res>
    implements $RuleBookInfoCopyWith<$Res> {
  factory _$$RuleBookInfoImplCopyWith(
          _$RuleBookInfoImpl value, $Res Function(_$RuleBookInfoImpl) then) =
      __$$RuleBookInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? name,
      String? author,
      String? intro,
      String? coverUrl,
      String? kind,
      String? lastChapter,
      String? tocUrl,
      String? wordCount});
}

/// @nodoc
class __$$RuleBookInfoImplCopyWithImpl<$Res>
    extends _$RuleBookInfoCopyWithImpl<$Res, _$RuleBookInfoImpl>
    implements _$$RuleBookInfoImplCopyWith<$Res> {
  __$$RuleBookInfoImplCopyWithImpl(
      _$RuleBookInfoImpl _value, $Res Function(_$RuleBookInfoImpl) _then)
      : super(_value, _then);

  /// Create a copy of RuleBookInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = freezed,
    Object? author = freezed,
    Object? intro = freezed,
    Object? coverUrl = freezed,
    Object? kind = freezed,
    Object? lastChapter = freezed,
    Object? tocUrl = freezed,
    Object? wordCount = freezed,
  }) {
    return _then(_$RuleBookInfoImpl(
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      author: freezed == author
          ? _value.author
          : author // ignore: cast_nullable_to_non_nullable
              as String?,
      intro: freezed == intro
          ? _value.intro
          : intro // ignore: cast_nullable_to_non_nullable
              as String?,
      coverUrl: freezed == coverUrl
          ? _value.coverUrl
          : coverUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      kind: freezed == kind
          ? _value.kind
          : kind // ignore: cast_nullable_to_non_nullable
              as String?,
      lastChapter: freezed == lastChapter
          ? _value.lastChapter
          : lastChapter // ignore: cast_nullable_to_non_nullable
              as String?,
      tocUrl: freezed == tocUrl
          ? _value.tocUrl
          : tocUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      wordCount: freezed == wordCount
          ? _value.wordCount
          : wordCount // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RuleBookInfoImpl implements _RuleBookInfo {
  const _$RuleBookInfoImpl(
      {this.name,
      this.author,
      this.intro,
      this.coverUrl,
      this.kind,
      this.lastChapter,
      this.tocUrl,
      this.wordCount});

  factory _$RuleBookInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$RuleBookInfoImplFromJson(json);

  @override
  final String? name;
  @override
  final String? author;
  @override
  final String? intro;
  @override
  final String? coverUrl;
  @override
  final String? kind;
  @override
  final String? lastChapter;
  @override
  final String? tocUrl;
  @override
  final String? wordCount;

  @override
  String toString() {
    return 'RuleBookInfo(name: $name, author: $author, intro: $intro, coverUrl: $coverUrl, kind: $kind, lastChapter: $lastChapter, tocUrl: $tocUrl, wordCount: $wordCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RuleBookInfoImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.intro, intro) || other.intro == intro) &&
            (identical(other.coverUrl, coverUrl) ||
                other.coverUrl == coverUrl) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.lastChapter, lastChapter) ||
                other.lastChapter == lastChapter) &&
            (identical(other.tocUrl, tocUrl) || other.tocUrl == tocUrl) &&
            (identical(other.wordCount, wordCount) ||
                other.wordCount == wordCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, author, intro, coverUrl,
      kind, lastChapter, tocUrl, wordCount);

  /// Create a copy of RuleBookInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RuleBookInfoImplCopyWith<_$RuleBookInfoImpl> get copyWith =>
      __$$RuleBookInfoImplCopyWithImpl<_$RuleBookInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RuleBookInfoImplToJson(
      this,
    );
  }
}

abstract class _RuleBookInfo implements RuleBookInfo {
  const factory _RuleBookInfo(
      {final String? name,
      final String? author,
      final String? intro,
      final String? coverUrl,
      final String? kind,
      final String? lastChapter,
      final String? tocUrl,
      final String? wordCount}) = _$RuleBookInfoImpl;

  factory _RuleBookInfo.fromJson(Map<String, dynamic> json) =
      _$RuleBookInfoImpl.fromJson;

  @override
  String? get name;
  @override
  String? get author;
  @override
  String? get intro;
  @override
  String? get coverUrl;
  @override
  String? get kind;
  @override
  String? get lastChapter;
  @override
  String? get tocUrl;
  @override
  String? get wordCount;

  /// Create a copy of RuleBookInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RuleBookInfoImplCopyWith<_$RuleBookInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RuleToc _$RuleTocFromJson(Map<String, dynamic> json) {
  return _RuleToc.fromJson(json);
}

/// @nodoc
mixin _$RuleToc {
  String? get chapterList => throw _privateConstructorUsedError;
  String? get chapterName => throw _privateConstructorUsedError;
  String? get chapterUrl => throw _privateConstructorUsedError;
  String? get nextTocUrl => throw _privateConstructorUsedError;
  String? get isVolume => throw _privateConstructorUsedError;
  String? get isVip => throw _privateConstructorUsedError;
  String? get updateTime => throw _privateConstructorUsedError;

  /// Serializes this RuleToc to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RuleToc
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RuleTocCopyWith<RuleToc> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RuleTocCopyWith<$Res> {
  factory $RuleTocCopyWith(RuleToc value, $Res Function(RuleToc) then) =
      _$RuleTocCopyWithImpl<$Res, RuleToc>;
  @useResult
  $Res call(
      {String? chapterList,
      String? chapterName,
      String? chapterUrl,
      String? nextTocUrl,
      String? isVolume,
      String? isVip,
      String? updateTime});
}

/// @nodoc
class _$RuleTocCopyWithImpl<$Res, $Val extends RuleToc>
    implements $RuleTocCopyWith<$Res> {
  _$RuleTocCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RuleToc
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chapterList = freezed,
    Object? chapterName = freezed,
    Object? chapterUrl = freezed,
    Object? nextTocUrl = freezed,
    Object? isVolume = freezed,
    Object? isVip = freezed,
    Object? updateTime = freezed,
  }) {
    return _then(_value.copyWith(
      chapterList: freezed == chapterList
          ? _value.chapterList
          : chapterList // ignore: cast_nullable_to_non_nullable
              as String?,
      chapterName: freezed == chapterName
          ? _value.chapterName
          : chapterName // ignore: cast_nullable_to_non_nullable
              as String?,
      chapterUrl: freezed == chapterUrl
          ? _value.chapterUrl
          : chapterUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      nextTocUrl: freezed == nextTocUrl
          ? _value.nextTocUrl
          : nextTocUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      isVolume: freezed == isVolume
          ? _value.isVolume
          : isVolume // ignore: cast_nullable_to_non_nullable
              as String?,
      isVip: freezed == isVip
          ? _value.isVip
          : isVip // ignore: cast_nullable_to_non_nullable
              as String?,
      updateTime: freezed == updateTime
          ? _value.updateTime
          : updateTime // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RuleTocImplCopyWith<$Res> implements $RuleTocCopyWith<$Res> {
  factory _$$RuleTocImplCopyWith(
          _$RuleTocImpl value, $Res Function(_$RuleTocImpl) then) =
      __$$RuleTocImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? chapterList,
      String? chapterName,
      String? chapterUrl,
      String? nextTocUrl,
      String? isVolume,
      String? isVip,
      String? updateTime});
}

/// @nodoc
class __$$RuleTocImplCopyWithImpl<$Res>
    extends _$RuleTocCopyWithImpl<$Res, _$RuleTocImpl>
    implements _$$RuleTocImplCopyWith<$Res> {
  __$$RuleTocImplCopyWithImpl(
      _$RuleTocImpl _value, $Res Function(_$RuleTocImpl) _then)
      : super(_value, _then);

  /// Create a copy of RuleToc
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chapterList = freezed,
    Object? chapterName = freezed,
    Object? chapterUrl = freezed,
    Object? nextTocUrl = freezed,
    Object? isVolume = freezed,
    Object? isVip = freezed,
    Object? updateTime = freezed,
  }) {
    return _then(_$RuleTocImpl(
      chapterList: freezed == chapterList
          ? _value.chapterList
          : chapterList // ignore: cast_nullable_to_non_nullable
              as String?,
      chapterName: freezed == chapterName
          ? _value.chapterName
          : chapterName // ignore: cast_nullable_to_non_nullable
              as String?,
      chapterUrl: freezed == chapterUrl
          ? _value.chapterUrl
          : chapterUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      nextTocUrl: freezed == nextTocUrl
          ? _value.nextTocUrl
          : nextTocUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      isVolume: freezed == isVolume
          ? _value.isVolume
          : isVolume // ignore: cast_nullable_to_non_nullable
              as String?,
      isVip: freezed == isVip
          ? _value.isVip
          : isVip // ignore: cast_nullable_to_non_nullable
              as String?,
      updateTime: freezed == updateTime
          ? _value.updateTime
          : updateTime // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RuleTocImpl implements _RuleToc {
  const _$RuleTocImpl(
      {this.chapterList,
      this.chapterName,
      this.chapterUrl,
      this.nextTocUrl,
      this.isVolume,
      this.isVip,
      this.updateTime});

  factory _$RuleTocImpl.fromJson(Map<String, dynamic> json) =>
      _$$RuleTocImplFromJson(json);

  @override
  final String? chapterList;
  @override
  final String? chapterName;
  @override
  final String? chapterUrl;
  @override
  final String? nextTocUrl;
  @override
  final String? isVolume;
  @override
  final String? isVip;
  @override
  final String? updateTime;

  @override
  String toString() {
    return 'RuleToc(chapterList: $chapterList, chapterName: $chapterName, chapterUrl: $chapterUrl, nextTocUrl: $nextTocUrl, isVolume: $isVolume, isVip: $isVip, updateTime: $updateTime)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RuleTocImpl &&
            (identical(other.chapterList, chapterList) ||
                other.chapterList == chapterList) &&
            (identical(other.chapterName, chapterName) ||
                other.chapterName == chapterName) &&
            (identical(other.chapterUrl, chapterUrl) ||
                other.chapterUrl == chapterUrl) &&
            (identical(other.nextTocUrl, nextTocUrl) ||
                other.nextTocUrl == nextTocUrl) &&
            (identical(other.isVolume, isVolume) ||
                other.isVolume == isVolume) &&
            (identical(other.isVip, isVip) || other.isVip == isVip) &&
            (identical(other.updateTime, updateTime) ||
                other.updateTime == updateTime));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, chapterList, chapterName,
      chapterUrl, nextTocUrl, isVolume, isVip, updateTime);

  /// Create a copy of RuleToc
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RuleTocImplCopyWith<_$RuleTocImpl> get copyWith =>
      __$$RuleTocImplCopyWithImpl<_$RuleTocImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RuleTocImplToJson(
      this,
    );
  }
}

abstract class _RuleToc implements RuleToc {
  const factory _RuleToc(
      {final String? chapterList,
      final String? chapterName,
      final String? chapterUrl,
      final String? nextTocUrl,
      final String? isVolume,
      final String? isVip,
      final String? updateTime}) = _$RuleTocImpl;

  factory _RuleToc.fromJson(Map<String, dynamic> json) = _$RuleTocImpl.fromJson;

  @override
  String? get chapterList;
  @override
  String? get chapterName;
  @override
  String? get chapterUrl;
  @override
  String? get nextTocUrl;
  @override
  String? get isVolume;
  @override
  String? get isVip;
  @override
  String? get updateTime;

  /// Create a copy of RuleToc
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RuleTocImplCopyWith<_$RuleTocImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RuleContent _$RuleContentFromJson(Map<String, dynamic> json) {
  return _RuleContent.fromJson(json);
}

/// @nodoc
mixin _$RuleContent {
  String? get content => throw _privateConstructorUsedError;
  String? get nextContentUrl => throw _privateConstructorUsedError;
  String? get replaceRegex => throw _privateConstructorUsedError;
  String? get imageStyle => throw _privateConstructorUsedError;

  /// Serializes this RuleContent to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RuleContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RuleContentCopyWith<RuleContent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RuleContentCopyWith<$Res> {
  factory $RuleContentCopyWith(
          RuleContent value, $Res Function(RuleContent) then) =
      _$RuleContentCopyWithImpl<$Res, RuleContent>;
  @useResult
  $Res call(
      {String? content,
      String? nextContentUrl,
      String? replaceRegex,
      String? imageStyle});
}

/// @nodoc
class _$RuleContentCopyWithImpl<$Res, $Val extends RuleContent>
    implements $RuleContentCopyWith<$Res> {
  _$RuleContentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RuleContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? content = freezed,
    Object? nextContentUrl = freezed,
    Object? replaceRegex = freezed,
    Object? imageStyle = freezed,
  }) {
    return _then(_value.copyWith(
      content: freezed == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String?,
      nextContentUrl: freezed == nextContentUrl
          ? _value.nextContentUrl
          : nextContentUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      replaceRegex: freezed == replaceRegex
          ? _value.replaceRegex
          : replaceRegex // ignore: cast_nullable_to_non_nullable
              as String?,
      imageStyle: freezed == imageStyle
          ? _value.imageStyle
          : imageStyle // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RuleContentImplCopyWith<$Res>
    implements $RuleContentCopyWith<$Res> {
  factory _$$RuleContentImplCopyWith(
          _$RuleContentImpl value, $Res Function(_$RuleContentImpl) then) =
      __$$RuleContentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? content,
      String? nextContentUrl,
      String? replaceRegex,
      String? imageStyle});
}

/// @nodoc
class __$$RuleContentImplCopyWithImpl<$Res>
    extends _$RuleContentCopyWithImpl<$Res, _$RuleContentImpl>
    implements _$$RuleContentImplCopyWith<$Res> {
  __$$RuleContentImplCopyWithImpl(
      _$RuleContentImpl _value, $Res Function(_$RuleContentImpl) _then)
      : super(_value, _then);

  /// Create a copy of RuleContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? content = freezed,
    Object? nextContentUrl = freezed,
    Object? replaceRegex = freezed,
    Object? imageStyle = freezed,
  }) {
    return _then(_$RuleContentImpl(
      content: freezed == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String?,
      nextContentUrl: freezed == nextContentUrl
          ? _value.nextContentUrl
          : nextContentUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      replaceRegex: freezed == replaceRegex
          ? _value.replaceRegex
          : replaceRegex // ignore: cast_nullable_to_non_nullable
              as String?,
      imageStyle: freezed == imageStyle
          ? _value.imageStyle
          : imageStyle // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RuleContentImpl implements _RuleContent {
  const _$RuleContentImpl(
      {this.content, this.nextContentUrl, this.replaceRegex, this.imageStyle});

  factory _$RuleContentImpl.fromJson(Map<String, dynamic> json) =>
      _$$RuleContentImplFromJson(json);

  @override
  final String? content;
  @override
  final String? nextContentUrl;
  @override
  final String? replaceRegex;
  @override
  final String? imageStyle;

  @override
  String toString() {
    return 'RuleContent(content: $content, nextContentUrl: $nextContentUrl, replaceRegex: $replaceRegex, imageStyle: $imageStyle)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RuleContentImpl &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.nextContentUrl, nextContentUrl) ||
                other.nextContentUrl == nextContentUrl) &&
            (identical(other.replaceRegex, replaceRegex) ||
                other.replaceRegex == replaceRegex) &&
            (identical(other.imageStyle, imageStyle) ||
                other.imageStyle == imageStyle));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, content, nextContentUrl, replaceRegex, imageStyle);

  /// Create a copy of RuleContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RuleContentImplCopyWith<_$RuleContentImpl> get copyWith =>
      __$$RuleContentImplCopyWithImpl<_$RuleContentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RuleContentImplToJson(
      this,
    );
  }
}

abstract class _RuleContent implements RuleContent {
  const factory _RuleContent(
      {final String? content,
      final String? nextContentUrl,
      final String? replaceRegex,
      final String? imageStyle}) = _$RuleContentImpl;

  factory _RuleContent.fromJson(Map<String, dynamic> json) =
      _$RuleContentImpl.fromJson;

  @override
  String? get content;
  @override
  String? get nextContentUrl;
  @override
  String? get replaceRegex;
  @override
  String? get imageStyle;

  /// Create a copy of RuleContent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RuleContentImplCopyWith<_$RuleContentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
