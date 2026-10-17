import 'package:game_data/game_data.dart';
import 'package:test/test.dart';

void main() {
  test('prefers in-game observation but preserves conflicting values', () {
    final community = FieldObservation(
      id: 'community',
      entityType: 'ORE',
      entityId: 'ore',
      fieldName: 'multiplier',
      value: 2.0,
      sourceId: 'wiki',
      observedAt: DateTime.utc(2026, 10, 1),
      verificationStatus: 'COMMUNITY',
      confidence: .8,
    );
    final inGame = FieldObservation(
      id: 'capture',
      entityType: 'ORE',
      entityId: 'ore',
      fieldName: 'multiplier',
      value: 2.25,
      sourceId: 'capture',
      observedAt: DateTime.utc(2026, 9, 1),
      verificationStatus: 'IN_GAME_VERIFIED',
      confidence: .7,
    );
    final result = const DataResolver().resolve([community, inGame]);
    expect(result.preferred?.id, 'capture');
    expect(result.alternatives.single.value, 2.0);
    expect(result.conflicting, isFalse);
  });

  test('a confirmed capture outranks community but not in-game verified', () {
    final community = FieldObservation(
      id: 'community',
      entityType: 'ORE',
      entityId: 'ore',
      fieldName: 'multiplier',
      value: 0.42,
      sourceId: 'wiki',
      observedAt: DateTime.utc(2026, 10, 17),
      verificationStatus: 'COMMUNITY',
      confidence: 1,
    );
    final capture = FieldObservation(
      id: 'capture',
      entityType: 'ORE',
      entityId: 'ore',
      fieldName: 'multiplier',
      value: 2.75,
      sourceId: 'manual',
      observedAt: DateTime.utc(2026, 10, 15),
      verificationStatus: 'USER_CONFIRMED_CAPTURE',
      confidence: .7,
    );
    final resolved = const DataResolver().resolve([community, capture]);
    expect(resolved.preferred?.id, 'capture');
    expect(resolved.conflicting, isTrue);
  });

  test(
    'verified policies select only in-game observations and mark fallback',
    () {
      final community = FieldObservation(
        id: 'community',
        entityType: 'ORE',
        entityId: 'ore',
        fieldName: 'multiplier',
        value: 2.0,
        sourceId: 'wiki',
        observedAt: DateTime.utc(2026, 10, 1),
        verificationStatus: 'COMMUNITY',
      );
      final verified = FieldObservation(
        id: 'verified',
        entityType: 'ORE',
        entityId: 'ore',
        fieldName: 'multiplier',
        value: 2.25,
        sourceId: 'capture',
        observedAt: DateTime.utc(2026, 10, 2),
        verificationStatus: 'IN_GAME_VERIFIED',
      );
      final preferred = const DataResolver().resolve([
        community,
      ], policy: DataPolicy.verifiedPreferred);
      expect(preferred.preferred?.id, 'community');
      expect(preferred.usedFallback, isTrue);
      expect(preferred.incomplete, isFalse);
      final strictMissing = const DataResolver().resolve([
        community,
      ], policy: DataPolicy.verifiedOnly);
      expect(strictMissing.preferred, isNull);
      expect(strictMissing.incomplete, isTrue);
      final strictAvailable = const DataResolver().resolve([
        community,
        verified,
      ], policy: DataPolicy.verifiedOnly);
      expect(strictAvailable.preferred?.id, 'verified');
      expect(strictAvailable.alternatives.single.id, 'community');
    },
  );
}
