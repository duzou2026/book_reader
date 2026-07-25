import 'package:book_reader/app/providers.dart';
import 'package:book_reader/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  Hive.init(dir.path);
  final bookSourceBox = await Hive.openBox<String>('book_sources');
  final bookshelfBox =
      await Hive.openBox<String>('bookshelf');
  final readingProgressBox =
      await Hive.openBox<String>('reading_progress');
  final readingPrefsBox =
      await Hive.openBox<String>('reading_prefs');
  runApp(
    ProviderScope(
      overrides: [
        bookSourceBoxProvider.overrideWithValue(bookSourceBox),
        bookshelfBoxProvider.overrideWithValue(bookshelfBox),
        readingProgressBoxProvider.overrideWithValue(readingProgressBox),
        readingPrefsBoxProvider.overrideWithValue(readingPrefsBox),
      ],
      child: const BookReaderApp(),
    ),
  );
}

class BookReaderApp extends StatelessWidget {
  const BookReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Book Reader',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      routerConfig: appRouter,
    );
  }
}
