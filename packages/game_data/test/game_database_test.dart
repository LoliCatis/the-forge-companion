import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

void main() {
  test('new database has no bundled game catalog', () async {
    final db = await GameDatabase.open(':memory:');
    try {
      expect(await db.getActiveDataVersion(), isNull);
      expect(await db.countAllOres(), 0);
      expect(await db.searchOres(''), isEmpty);
      expect(await db.getVerificationSessions(), isEmpty);
    } finally { await db.close(); }
  });

  test('manual inventory rows support protected quantity', () async {
    final db = await GameDatabase.open(':memory:');
    try {
      await db.upsertOre(const OreRecord(id: 'test-ore', name: 'Test Ore', source: 'manual entry', verificationStatus: 'UNKNOWN'));
      await db.setInventoryQuantity('test-ore', 8, protectedQuantity: 3);
      final inventory = await db.getInventory();
      expect(inventory.single.quantity, 8);
      expect(inventory.single.protectedQuantity, 3);
    } finally { await db.close(); }
  });
}
