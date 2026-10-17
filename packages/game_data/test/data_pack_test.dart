import 'dart:convert';
import 'dart:io';

import 'package:game_data/game_data.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'data_pack_test_utils.dart';

void main() {
  test('empty first-party bootstrap pack validates and imports', () async {
    final cwd = Directory.current;
    final root = cwd.path.endsWith(p.join('packages', 'game_data')) ? cwd.parent.parent : cwd;
    final directory = Directory(p.join(root.path, 'data', 'packs', '2026.10.17-bootstrap.1'));
    const names = ['manifest.json','sources.json','ores.json','weapons.json','traits.json','probabilities.json','evidence.json','observations.json'];
    final pack = DataPackBundle({for (final name in names) name: await File(p.join(directory.path, name)).readAsString()}).validate();
    expect(pack.manifest.schemaVersion, 1);
    expect(pack.manifest.dataVersion, '2026.10.17-bootstrap.1');
    expect(pack.sources, isEmpty);
    expect(pack.ores, isEmpty);
    expect(pack.weapons, isEmpty);
    expect(pack.observations, isEmpty);
    final db = await GameDatabase.open(':memory:');
    try {
      await db.importDataPack(pack);
      expect(await db.getActiveDataVersion(), '2026.10.17-bootstrap.1');
      expect(await db.countAllOres(), 0);
      expect(await db.getWeaponVariants(), isEmpty);
    } finally { await db.close(); }
  });

  test('rejects unsupported schema and content hash mismatch', () {
    final pack = makePack(id: 'p1', version: 'v1', multiplier: 2);
    final changedManifest = Map<String, Object?>.from(jsonDecode(pack.rawFiles['manifest.json']!) as Map)..['schemaVersion'] = 99;
    expect(() => DataPackBundle({...pack.rawFiles, 'manifest.json': '${jsonEncode(changedManifest)}\n'}).validate(), throwsUnsupportedError);
    expect(() => DataPackBundle({...pack.rawFiles, 'ores.json': '[]\n'}).validate(), throwsFormatException);
  });
}
