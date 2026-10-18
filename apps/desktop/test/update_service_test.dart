import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_forge_companion/app/update_service.dart';

void main() {
  group('AppReleaseVersion', () {
    test('orders numeric alpha sequences and blocks downgrades', () {
      final alpha9 = AppReleaseVersion.tryParse('v0.1.0-alpha.9')!;
      final alpha10 = AppReleaseVersion.tryParse('v0.1.0-alpha.10')!;
      final beta1 = AppReleaseVersion.tryParse('v0.1.0-beta.1')!;

      expect(alpha10.compareTo(alpha9), greaterThan(0));
      expect(beta1.compareTo(alpha10), greaterThan(0));
      expect(alpha9.compareTo(alpha10), lessThan(0));
      expect(AppReleaseVersion.tryParse('latest'), isNull);
    });
  });

  group('release selection', () {
    test('uses only newer prereleases with expected portable assets', () {
      final currentCommit = _commit('a');
      final releases = [
        _release('v0.1.0-alpha.10', commit: _commit('b')),
        _release('v0.1.0-alpha.2', commit: _commit('c')),
        _release('v0.1.0-alpha.11', commit: _commit('d'), draft: true),
        _release('v0.1.0-alpha.12', commit: _commit('e'), prerelease: false),
        _release(
          'v0.1.0-alpha.13',
          commit: _commit('f'),
          zipName: 'some-other-build.zip',
        ),
        _release(
          'v0.1.0-alpha.14',
          commit: _commit('1'),
          includeManifest: false,
        ),
        _release('v0.1.0-alpha.8', commit: currentCommit),
        _release('v0.1.0-alpha.9', commit: _commit('9')),
      ];

      final candidates = selectCompatibleAppReleases(
        releases,
        currentCommit: currentCommit,
        currentVersion: '0.1.0-alpha.9',
      );

      expect(candidates.map((item) => item.version.toString()), [
        '0.1.0-alpha.10',
      ]);
      expect(candidates.single.commit, _commit('b'));
    });

    test('returns candidates by semantic version rather than release order', () {
      final candidates = selectCompatibleAppReleases(
        [
          _release('v0.1.0-alpha.10', commit: _commit('b')),
          _release('v0.1.0-alpha.12', commit: _commit('c')),
          _release('v0.1.0-alpha.11', commit: _commit('d')),
        ],
        currentCommit: _commit('a'),
        currentVersion: '0.1.0-alpha.9',
      );
      expect(candidates.map((item) => item.version.sequence), [12, 11, 10]);
    });

    test('ignores assets hosted outside the configured repository', () {
      final release = _release('v0.1.0-alpha.10', commit: _commit('b'));
      (release['assets'] as List).first['browser_download_url'] =
          'https://github.com/other/project/releases/download/v0.1.0-alpha.10/the-forge-companion-windows-alpha.zip';
      expect(
        selectCompatibleAppReleases(
          [release],
          currentCommit: _commit('a'),
          currentVersion: '0.1.0-alpha.9',
        ),
        isEmpty,
      );
    });

    test('same version and lower versions are never update candidates', () {
      final candidates = selectCompatibleAppReleases(
        [
          _release('v0.1.0-alpha.9', commit: _commit('b')),
          _release('v0.1.0-alpha.8', commit: _commit('c')),
        ],
        currentCommit: _commit('a'),
        currentVersion: '0.1.0-alpha.9',
      );
      expect(candidates, isEmpty);
    });

    test('rejects release assets attached to a different tag', () {
      final release = _release('v0.1.0-alpha.10', commit: _commit('b'));
      (release['assets'] as List).first['browser_download_url'] =
          'https://github.com/LoliCatis/the-forge-companion/releases/download/v0.1.0-alpha.9/the-forge-companion-windows-alpha.zip';
      expect(
        selectCompatibleAppReleases(
          [release],
          currentCommit: _commit('a'),
          currentVersion: '0.1.0-alpha.9',
        ),
        isEmpty,
      );
    });

    test('rejects a release page URL that does not match its tag', () {
      final release = _release('v0.1.0-alpha.10', commit: _commit('b'));
      release['html_url'] =
          'https://github.com/LoliCatis/the-forge-companion/releases/tag/v0.1.0-alpha.9';
      expect(
        selectCompatibleAppReleases(
          [release],
          currentCommit: _commit('a'),
          currentVersion: '0.1.0-alpha.9',
        ),
        isEmpty,
      );
    });
  });

  test('public release feed accepts only newer tags from configured repo', () {
    final currentCommit = _commit('a');
    final nextCommit = _commit('b');
    final feed = '''
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <title>v0.1.0-alpha.10</title>
    <link rel="alternate" href="https://github.com/LoliCatis/the-forge-companion/releases/tag/v0.1.0-alpha.10" />
    <content type="html">&lt;p&gt;Commit SHA: &lt;a href=&quot;https://github.com/LoliCatis/the-forge-companion/commit/$nextCommit&quot;&gt;$nextCommit&lt;/a&gt;&lt;/p&gt;</content>
  </entry>
  <entry>
    <title>v0.1.0-alpha.11</title>
    <link rel="alternate" href="https://github.com/other/project/releases/tag/v0.1.0-alpha.11" />
    <content type="html">&lt;p&gt;Commit SHA: &lt;a href=&quot;https://github.com/other/project/commit/${_commit('c')}&quot;&gt;commit&lt;/a&gt;&lt;/p&gt;</content>
  </entry>
  <entry>
    <title>v0.1.0-alpha.8</title>
    <link rel="alternate" href="https://github.com/LoliCatis/the-forge-companion/releases/tag/v0.1.0-alpha.8" />
    <content type="html">&lt;p&gt;Commit SHA: &lt;a href=&quot;https://github.com/LoliCatis/the-forge-companion/commit/$currentCommit&quot;&gt;$currentCommit&lt;/a&gt;&lt;/p&gt;</content>
  </entry>
</feed>
''';

    final releases = parsePublicReleaseFeed(
      feed,
      currentVersion: '0.1.0-alpha.9',
    );

    expect(releases, hasLength(1));
    expect(releases.single['tag_name'], 'v0.1.0-alpha.10');
    expect(releases.single['body'], contains('Commit SHA: $nextCommit'));
  });

  test('safe ZIP staging path rejects traversal and absolute paths', () {
    final root = Directory.systemTemp.path;
    expect(
      safeArchiveDestination(root, 'data/flutter_assets/AssetManifest.bin'),
      isA<String>(),
    );
    for (final bad in [
      '../outside.txt',
      r'..\outside.txt',
      r'C:\outside.txt',
      r'\\server\share\outside.txt',
      'folder/../../outside.txt',
    ]) {
      expect(
        () => safeArchiveDestination(root, bad),
        throwsFormatException,
        reason: bad,
      );
    }
  });
}

Map<String, dynamic> _release(
  String tag, {
  required String commit,
  bool draft = false,
  bool prerelease = true,
  String zipName = 'the-forge-companion-windows-alpha.zip',
  bool includeManifest = true,
}) => {
  'tag_name': tag,
  'html_url':
      'https://github.com/LoliCatis/the-forge-companion/releases/tag/$tag',
  'draft': draft,
  'prerelease': prerelease,
  'body': 'Commit SHA: $commit',
  'assets': [
    {
      'name': zipName,
      'browser_download_url':
          'https://github.com/LoliCatis/the-forge-companion/releases/download/$tag/$zipName',
      'digest': 'sha256:${_repeat('a', 64)}',
      'size': 100,
    },
    if (includeManifest)
      {
        'name': 'windows-alpha-manifest.json',
        'browser_download_url':
            'https://github.com/LoliCatis/the-forge-companion/releases/download/$tag/windows-alpha-manifest.json',
        'digest': 'sha256:${_repeat('b', 64)}',
        'size': 200,
      },
  ],
};

String _commit(String value) => List.filled(40, value).join();

String _repeat(String value, int count) => List.filled(count, value).join();
