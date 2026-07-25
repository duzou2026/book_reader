import 'dart:convert';
import 'dart:io';

import 'package:book_reader/data/bookmarks_repository.dart';
import 'package:book_reader/data/bookshelf_repository.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/data/notes_repository.dart';
import 'package:book_reader/data/reading_history_repository.dart';
import 'package:book_reader/data/reading_stats_repository.dart';
import 'package:book_reader/domain/usecases/search_books.dart' show BookSourceRepository;
import 'package:book_reader/services/preferences/reading_progress_repository.dart';
import 'package:book_reader/services/preferences/reading_prefs_repository.dart';
import 'package:path_provider/path_provider.dart';

/// 备份文件格式版本。
const kBackupFormatVersion = 1;

/// 备份元数据 + 数据。
class BookshelfBackupData {
  /// 格式版本号。
  final int version;

  /// 创建时间（毫秒时间戳）。
  final int createdAt;

  /// 备份来源设备标识（如「Pixel 7」），可选。
  final String? deviceLabel;

  /// 书架条目。
  final List<Map<String, dynamic>> bookshelf;

  /// 阅读进度。
  final List<Map<String, dynamic>> readingProgress;

  /// 笔记。
  final List<Map<String, dynamic>> notes;

  /// 书签。
  final List<Map<String, dynamic>> bookmarks;

  /// 阅读统计。
  final List<Map<String, dynamic>> readingStats;

  /// 阅读历史。
  final List<Map<String, dynamic>> readingHistory;

  /// 书源。
  final List<Map<String, dynamic>> bookSources;

  /// 阅读偏好（全局）。
  final Map<String, dynamic>? readingPrefs;

  const BookshelfBackupData({
    required this.version,
    required this.createdAt,
    this.deviceLabel,
    required this.bookshelf,
    required this.readingProgress,
    required this.notes,
    required this.bookmarks,
    required this.readingStats,
    required this.readingHistory,
    required this.bookSources,
    this.readingPrefs,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'createdAt': createdAt,
        if (deviceLabel != null) 'deviceLabel': deviceLabel,
        'bookshelf': bookshelf,
        'readingProgress': readingProgress,
        'notes': notes,
        'bookmarks': bookmarks,
        'readingStats': readingStats,
        'readingHistory': readingHistory,
        'bookSources': bookSources,
        if (readingPrefs != null) 'readingPrefs': readingPrefs,
      };

  factory BookshelfBackupData.fromJson(Map<String, dynamic> json) {
    return BookshelfBackupData(
      version: (json['version'] as num?)?.toInt() ?? kBackupFormatVersion,
      createdAt: (json['createdAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      deviceLabel: json['deviceLabel'] as String?,
      bookshelf: ((json['bookshelf'] as List?) ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      readingProgress: ((json['readingProgress'] as List?) ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      notes: ((json['notes'] as List?) ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      bookmarks: ((json['bookmarks'] as List?) ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      readingStats: ((json['readingStats'] as List?) ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      readingHistory: ((json['readingHistory'] as List?) ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      bookSources: ((json['bookSources'] as List?) ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      readingPrefs: json['readingPrefs'] as Map<String, dynamic>?,
    );
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  static BookshelfBackupData fromJsonString(String s) =>
      BookshelfBackupData.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

/// 导入策略。
enum RestoreStrategy {
  /// 跳过已存在的记录（保留本地）。
  skip,

  /// 覆盖已存在的记录。
  overwrite,

  /// 全部覆盖（先清空本地，再写入）。
  replaceAll,
}

/// 导入结果摘要。
class RestoreSummary {
  final int bookshelfAdded;
  final int bookshelfSkipped;
  final int bookshelfOverwritten;

  final int progressAdded;
  final int progressSkipped;
  final int progressOverwritten;

  final int notesAdded;
  final int notesSkipped;
  final int notesOverwritten;

  final int bookmarksAdded;
  final int bookmarksSkipped;
  final int bookmarksOverwritten;

  final int statsAdded;
  final int statsOverwritten;

  final int historyAdded;

  final int sourcesAdded;
  final int sourcesOverwritten;

  final bool readingPrefsRestored;

  const RestoreSummary({
    required this.bookshelfAdded,
    required this.bookshelfSkipped,
    required this.bookshelfOverwritten,
    required this.progressAdded,
    required this.progressSkipped,
    required this.progressOverwritten,
    required this.notesAdded,
    required this.notesSkipped,
    required this.notesOverwritten,
    required this.bookmarksAdded,
    required this.bookmarksSkipped,
    required this.bookmarksOverwritten,
    required this.statsAdded,
    required this.statsOverwritten,
    required this.historyAdded,
    required this.sourcesAdded,
    required this.sourcesOverwritten,
    required this.readingPrefsRestored,
  });

  int get totalEntries =>
      bookshelfAdded +
      progressAdded +
      notesAdded +
      bookmarksAdded +
      statsAdded +
      historyAdded +
      sourcesAdded;

  int get totalOverwritten =>
      bookshelfOverwritten +
      progressOverwritten +
      notesOverwritten +
      bookmarksOverwritten +
      statsOverwritten +
      sourcesOverwritten;

  int get totalSkipped =>
      bookshelfSkipped + progressSkipped + notesSkipped + bookmarksSkipped;

  @override
  String toString() =>
      'RestoreSummary(added=$totalEntries, overwritten=$totalOverwritten, skipped=$totalSkipped, sources=$sourcesAdded, prefs=$readingPrefsRestored)';
}

/// 「导出书架备份」用例。
class ExportBookshelfBackup {
  final BookshelfRepository _bookshelfRepo;
  final ReadingProgressRepository _progressRepo;
  final NoteRepository _noteRepo;
  final BookmarkRepository _bookmarkRepo;
  final ReadingStatsRepository _statsRepo;
  final ReadingHistoryRepository _historyRepo;
  final BookSourceRepository _sourceRepo;
  final ReadingPrefsRepository _prefsRepo;

  ExportBookshelfBackup({
    required BookshelfRepository bookshelfRepo,
    required ReadingProgressRepository progressRepo,
    required NoteRepository noteRepo,
    required BookmarkRepository bookmarkRepo,
    required ReadingStatsRepository statsRepo,
    required ReadingHistoryRepository historyRepo,
    required BookSourceRepository sourceRepo,
    required ReadingPrefsRepository prefsRepo,
  })  : _bookshelfRepo = bookshelfRepo,
        _progressRepo = progressRepo,
        _noteRepo = noteRepo,
        _bookmarkRepo = bookmarkRepo,
        _statsRepo = statsRepo,
        _historyRepo = historyRepo,
        _sourceRepo = sourceRepo,
        _prefsRepo = prefsRepo;

  /// 导出全部数据为 [BookshelfBackupData]。
  Future<BookshelfBackupData> export({
    String? deviceLabel,
  }) async {
    final bookshelf = await _bookshelfRepo.getAll();
    final notes = await _noteRepo.getAll();
    final stats = await _statsRepo.getAll();
    final history = await _historyRepo.getAll();
    final sources = await _sourceRepo.getAll();
    final progress = await _progressRepo.getAll();
    final bookmarks = await _bookmarkRepo.getAll();
    final prefs = await _prefsRepo.get();

    return BookshelfBackupData(
      version: kBackupFormatVersion,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      deviceLabel: deviceLabel,
      bookshelf: bookshelf.map((e) => e.toJson()).toList(),
      readingProgress: progress.map((e) => e.toJson()).toList(),
      notes: notes.map((e) => e.toJson()).toList(),
      bookmarks: bookmarks.map((e) => e.toJson()).toList(),
      readingStats: stats.map((e) => e.toJson()).toList(),
      readingHistory: history.map((e) => e.toJson()).toList(),
      bookSources: sources.map((e) => e.toJson()).toList(),
      readingPrefs: prefs.toJson(),
    );
  }

  /// 导出并写入文件到 `documents/book_reader_backups/` 目录。
  ///
  /// 返回写入的文件。
  Future<File> exportToFile({String? deviceLabel}) async {
    final data = await export(deviceLabel: deviceLabel);
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${dir.path}/book_reader_backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    final now = DateTime.now();
    final stamp =
        '${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
    final file = File('${backupDir.path}/bookreader_backup_$stamp.json');
    await file.writeAsString(data.toJsonString());
    return file;
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  /// 列出所有已存在的备份文件（按修改时间倒序）。
  Future<List<FileSystemEntity>> listBackupFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${dir.path}/book_reader_backups');
    if (!await backupDir.exists()) return const [];
    final list = backupDir.listSync();
    list.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return list.whereType<File>().toList();
  }

  /// 读取并解析备份文件。
  Future<BookshelfBackupData> readFile(File file) async {
    final s = await file.readAsString();
    return BookshelfBackupData.fromJsonString(s);
  }

  /// 删除备份文件。
  Future<void> deleteFile(File file) async {
    if (await file.exists()) await file.delete();
  }
}

/// 「从备份恢复」用例。
class RestoreBookshelfBackup {
  final BookshelfRepository _bookshelfRepo;
  final ReadingProgressRepository _progressRepo;
  final NoteRepository _noteRepo;
  final BookmarkRepository _bookmarkRepo;
  final ReadingStatsRepository _statsRepo;
  final ReadingHistoryRepository _historyRepo;
  final BookSourceRepository _sourceRepo;
  final ReadingPrefsRepository _prefsRepo;

  RestoreBookshelfBackup({
    required BookshelfRepository bookshelfRepo,
    required ReadingProgressRepository progressRepo,
    required NoteRepository noteRepo,
    required BookmarkRepository bookmarkRepo,
    required ReadingStatsRepository statsRepo,
    required ReadingHistoryRepository historyRepo,
    required BookSourceRepository sourceRepo,
    required ReadingPrefsRepository prefsRepo,
  })  : _bookshelfRepo = bookshelfRepo,
        _progressRepo = progressRepo,
        _noteRepo = noteRepo,
        _bookmarkRepo = bookmarkRepo,
        _statsRepo = statsRepo,
        _historyRepo = historyRepo,
        _sourceRepo = sourceRepo,
        _prefsRepo = prefsRepo;

  /// 从 [data] 恢复。
  ///
  /// [strategy] 控制冲突处理：
  /// - [RestoreStrategy.skip]：本地已存在则跳过
  /// - [RestoreStrategy.overwrite]：本地已存在则覆盖
  /// - [RestoreStrategy.replaceAll]：先清空本地所有数据，再写入（危险）
  Future<RestoreSummary> restore(
    BookshelfBackupData data, {
    RestoreStrategy strategy = RestoreStrategy.overwrite,
    bool restoreSources = true,
    bool restorePrefs = true,
  }) async {
    if (strategy == RestoreStrategy.replaceAll) {
      await _clearAll();
    }

    var bsAdded = 0, bsSkipped = 0, bsOverwritten = 0;
    for (final json in data.bookshelf) {
      final entry = BookshelfEntry.fromJson(json);
      final exists = await _bookshelfRepo.contains(entry.id);
      if (exists && strategy == RestoreStrategy.skip) {
        bsSkipped++;
        continue;
      }
      if (exists) {
        bsOverwritten++;
      } else {
        bsAdded++;
      }
      await _bookshelfRepo.upsert(entry);
    }

    var pAdded = 0, pSkipped = 0, pOverwritten = 0;
    for (final json in data.readingProgress) {
      final p = ReadingProgress.fromJson(json);
      final exists = (await _progressRepo.get(p.id)) != null;
      if (exists && strategy == RestoreStrategy.skip) {
        pSkipped++;
        continue;
      }
      if (exists) {
        pOverwritten++;
      } else {
        pAdded++;
      }
      await _progressRepo.upsert(p);
    }

    var nAdded = 0, nSkipped = 0, nOverwritten = 0;
    for (final json in data.notes) {
      final note = Note.fromJson(json);
      final exists = await _noteRepo.exists(note.id);
      if (exists && strategy == RestoreStrategy.skip) {
        nSkipped++;
        continue;
      }
      if (exists) {
        nOverwritten++;
      } else {
        nAdded++;
      }
      await _noteRepo.add(note);
    }

    var bmAdded = 0, bmSkipped = 0, bmOverwritten = 0;
    for (final json in data.bookmarks) {
      final bm = Bookmark.fromJson(json);
      final exists = await _bookmarkRepo.exists(bm.id);
      if (exists && strategy == RestoreStrategy.skip) {
        bmSkipped++;
        continue;
      }
      if (exists) {
        bmOverwritten++;
      } else {
        bmAdded++;
      }
      await _bookmarkRepo.add(bm);
    }

    var statsAdded = 0, statsOverwritten = 0;
    for (final json in data.readingStats) {
      final s = DailyReadingStat.fromJson(json);
      final existing = await _statsRepo.get(s.date);
      final exists =
          existing.durationSeconds > 0 || existing.wordCount > 0;
      if (exists) {
        statsOverwritten++;
      } else {
        statsAdded++;
      }
      // 直接写入（覆盖）
      await _statsRepo.upsertRaw(s);
    }

    var historyAdded = 0;
    for (final json in data.readingHistory) {
      final h = ReadingHistoryEntry.fromJson(json);
      await _historyRepo.add(h);
      historyAdded++;
    }

    var sourcesAdded = 0, sourcesOverwritten = 0;
    if (restoreSources) {
      for (final json in data.bookSources) {
        try {
          final src = BookSource.fromJson(json);
          final exists = await _sourceRepo.contains(src.bookSourceUrl);
          if (exists) {
            sourcesOverwritten++;
          } else {
            sourcesAdded++;
          }
          await _sourceRepo.upsert(src);
        } catch (_) {
          // 跳过无法解析的书源
        }
      }
    }

    var prefsRestored = false;
    if (restorePrefs && data.readingPrefs != null) {
      final prefs = ReadingPrefs.fromJson(data.readingPrefs!);
      await _prefsRepo.save(prefs);
      prefsRestored = true;
    }

    return RestoreSummary(
      bookshelfAdded: bsAdded,
      bookshelfSkipped: bsSkipped,
      bookshelfOverwritten: bsOverwritten,
      progressAdded: pAdded,
      progressSkipped: pSkipped,
      progressOverwritten: pOverwritten,
      notesAdded: nAdded,
      notesSkipped: nSkipped,
      notesOverwritten: nOverwritten,
      bookmarksAdded: bmAdded,
      bookmarksSkipped: bmSkipped,
      bookmarksOverwritten: bmOverwritten,
      statsAdded: statsAdded,
      statsOverwritten: statsOverwritten,
      historyAdded: historyAdded,
      sourcesAdded: sourcesAdded,
      sourcesOverwritten: sourcesOverwritten,
      readingPrefsRestored: prefsRestored,
    );
  }

  Future<void> _clearAll() async {
    final all = await _bookshelfRepo.getAll();
    for (final e in all) {
      await _bookshelfRepo.delete(e.id);
    }
    // 进度 / 书签 / 笔记 / 历史 / 统计 直接清空对应 box
    // 通过 deleteByBook 间接清空
    for (final e in all) {
      await _progressRepo.delete(e.id);
      await _bookmarkRepo.deleteByBook(e.id);
      await _noteRepo.deleteByBook(e.id);
    }
    await _historyRepo.clear();
    await _statsRepo.clear();
    await _sourceRepo.clear();
  }
}
