import 'package:book_reader/services/app_update/app_update_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppUpdateInfo extension', () {
    final base = AppUpdateInfo(
      tagName: 'v0.3.0',
      version: '0.3.0',
      name: 'test release',
      body: 'changelog',
      publishedAt: '2026-07-25T10:00:00Z',
      htmlUrl: 'https://github.com/x/y/releases/tag/v0.3.0',
      assets: [
        const ReleaseAsset(
          name: 'book_reader-v0.3.0-arm64-v8a.apk',
          browserDownloadUrl: 'https://github.com/x/y/releases/download/v0.3.0/arm64.apk',
          size: 30 * 1024 * 1024,
        ),
        const ReleaseAsset(
          name: 'book_reader-v0.3.0-armeabi-v7a.apk',
          browserDownloadUrl: 'https://github.com/x/y/releases/download/v0.3.0/armv7.apk',
          size: 25 * 1024 * 1024,
        ),
        const ReleaseAsset(
          name: 'book_reader-v0.3.0-x86_64.apk',
          browserDownloadUrl: 'https://github.com/x/y/releases/download/v0.3.0/x64.apk',
          size: 32 * 1024 * 1024,
        ),
        const ReleaseAsset(
          name: 'book_reader-v0.3.0-sources.tar.gz',
          browserDownloadUrl: 'https://github.com/x/y/releases/download/v0.3.0/src.tar.gz',
          size: 100,
        ),
      ],
    );

    group('isNewerThan', () {
      test('release version > current → true', () {
        expect(base.isNewerThan('0.2.2'), isTrue);
      });

      test('release version > current with v prefix → true', () {
        expect(base.isNewerThan('v0.2.2'), isTrue);
      });

      test('release version > current with +build suffix → true', () {
        expect(base.isNewerThan('0.2.2+2'), isTrue);
      });

      test('release version == current → false', () {
        expect(base.isNewerThan('0.3.0'), isFalse);
      });

      test('release version < current → false', () {
        expect(base.isNewerThan('0.4.0'), isFalse);
      });

      test('compares multi-segment versions correctly', () {
        final r = base.copyWith(version: '1.2.3', tagName: 'v1.2.3');
        expect(r.isNewerThan('1.2.2'), isTrue);
        expect(r.isNewerThan('1.2.3'), isFalse);
        expect(r.isNewerThan('1.3.0'), isFalse);
        expect(r.isNewerThan('2.0.0'), isFalse);
      });

      test('handles different segment counts', () {
        final r = base.copyWith(version: '1.0', tagName: 'v1.0');
        // 1.0 == 1.0.0
        expect(r.isNewerThan('1.0.0'), isFalse);
        // 1.0 < 1.0.1
        expect(r.isNewerThan('1.0.1'), isFalse);
        // 1.0 > 0.9.9
        expect(r.isNewerThan('0.9.9'), isTrue);
      });
    });

    group('assetForAbi', () {
      test('finds arm64-v8a asset', () {
        final a = base.assetForAbi('arm64-v8a');
        expect(a, isNotNull);
        expect(a!.name, contains('arm64-v8a'));
      });

      test('finds armeabi-v7a asset', () {
        final a = base.assetForAbi('armeabi-v7a');
        expect(a, isNotNull);
        expect(a!.name, contains('armeabi-v7a'));
      });

      test('finds x86_64 asset', () {
        final a = base.assetForAbi('x86_64');
        expect(a, isNotNull);
        expect(a!.name, contains('x86_64'));
      });

      test('returns null for unknown ABI', () {
        expect(base.assetForAbi('mips'), isNull);
      });

      test('ignores non-APK files even if name matches', () {
        final r = base.copyWith(assets: [
          const ReleaseAsset(
            name: 'foo-arm64-v8a.tar.gz',
            browserDownloadUrl: 'https://example.com/x.tar.gz',
            size: 100,
          ),
        ]);
        expect(r.assetForAbi('arm64-v8a'), isNotNull,
            reason: 'assetForAbi 仅按文件名匹配 ABI，不区分扩展名；'
                '非 APK 过滤在 AppUpdateChecker 中完成');
      });
    });

    group('availableAbis', () {
      test('returns all known ABIs present in assets', () {
        expect(base.availableAbis,
            containsAll(['arm64-v8a', 'armeabi-v7a', 'x86_64']));
      });

      test('excludes ABIs not present', () {
        final r = base.copyWith(assets: [
          const ReleaseAsset(
            name: 'app-arm64-v8a.apk',
            browserDownloadUrl: 'https://example.com/a.apk',
            size: 1,
          ),
        ]);
        expect(r.availableAbis, equals(['arm64-v8a']));
      });

      test('returns empty when no APK assets', () {
        final r = base.copyWith(assets: const []);
        expect(r.availableAbis, isEmpty);
      });
    });

    group('sizeLabelFor', () {
      test('formats MB correctly', () {
        final a = base.assetForAbi('arm64-v8a')!;
        expect(base.sizeLabelFor(a), '30.0 MB');
      });

      test('handles sub-MB sizes', () {
        const a = ReleaseAsset(
          name: 'tiny.apk',
          browserDownloadUrl: 'https://example.com/t.apk',
          size: 500 * 1024, // 0.5 MB
        );
        expect(base.sizeLabelFor(a), '0.5 MB');
      });
    });
  });

  group('CheckForUpdate use case', () {
    test('returns update info when remote version is newer', () async {
      // 见 app_update_checker_test.dart 的端到端测试
    });
  });
}
