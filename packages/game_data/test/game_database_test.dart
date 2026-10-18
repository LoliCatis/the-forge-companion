import 'dart:io';

import 'package:game_data/game_data.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  test('new database has no bundled game catalog or inventory table', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp('forge-empty-db-');
    final path = '${directory.path}${Platform.pathSeparator}empty.sqlite';
    final db = await GameDatabase.open(path);
    expect(await db.getActiveDataVersion(), isNull);
    expect(await db.countAllOres(), 0);
    expect(await db.searchOres(''), isEmpty);
    expect(await db.getVerificationSessions(), isEmpty);
    await db.close();

    final inspected = await databaseFactoryFfi.openDatabase(path);
    final tables = await inspected.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    expect(tables.map((row) => row['name']), isNot(contains('inventory')));
    await inspected.close();
    await directory.delete(recursive: true);
  });

  test('schema upgrade preserves legacy inventory and saved builds', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp('forge-legacy-db-');
    final path = '${directory.path}${Platform.pathSeparator}legacy.sqlite';
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 7,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE inventory (
              ore_id TEXT PRIMARY KEY,
              quantity INTEGER NOT NULL,
              protected_quantity INTEGER NOT NULL
            )
          ''');
          await database.insert('inventory', {
            'ore_id': 'legacy-ore',
            'quantity': 6,
            'protected_quantity': 2,
          });
          await database.execute('''
            CREATE TABLE saved_builds (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              recipe_json TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          await database.insert('saved_builds', {
            'id': 'saved-build',
            'name': 'Saved build',
            'recipe_json': '{"legacy-ore":3}',
            'created_at': '2026-10-18T00:00:00.000Z',
          });
        },
      ),
    );
    await legacy.close();

    final upgraded = await GameDatabase.open(path);
    final builds = await upgraded.getSavedBuilds();
    expect(builds.single.id, 'saved-build');
    expect(builds.single.recipe, {'legacy-ore': 3});
    expect(builds.single.craftGoal, isNull);
    await upgraded.close();

    final inspected = await databaseFactoryFfi.openDatabase(path);
    final inventory = await inspected.query('inventory');
    expect(inventory.single['quantity'], 6);
    expect(inventory.single['protected_quantity'], 2);
    await inspected.close();
    await directory.delete(recursive: true);
  });
}
