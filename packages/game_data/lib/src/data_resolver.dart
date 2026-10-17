import 'models.dart';

class DataResolver {
  const DataResolver();

  ResolvedField resolve(
    List<FieldObservation> observations, {
    DataPolicy policy = DataPolicy.bestAvailable,
  }) {
    if (observations.isEmpty) {
      return const ResolvedField(
        preferred: null,
        alternatives: [],
        conflicting: false,
        incomplete: true,
      );
    }
    final ordered = [...observations]
      ..sort((a, b) {
        final statusOrder = _priority(
          b.verificationStatus,
        ).compareTo(_priority(a.verificationStatus));
        if (statusOrder != 0) return statusOrder;
        final confidenceOrder = (b.confidence ?? 0).compareTo(
          a.confidence ?? 0,
        );
        if (confidenceOrder != 0) return confidenceOrder;
        final recency = b.observedAt.compareTo(a.observedAt);
        if (recency != 0) return recency;
        // Give equal-ranked candidates a stable, reproducible ordering while
        // preserving the conflict state and every alternative for review.
        final sourceOrder = a.sourceId.compareTo(b.sourceId);
        return sourceOrder != 0 ? sourceOrder : a.id.compareTo(b.id);
      });
    final distinctValues = ordered
        .map((o) => jsonEncodeStable(o.value))
        .toSet();
    final verified = ordered
        .where((o) => o.verificationStatus.toUpperCase() == 'IN_GAME_VERIFIED')
        .toList();
    final chosen = switch (policy) {
      DataPolicy.bestAvailable => ordered.first,
      DataPolicy.verifiedPreferred =>
        verified.isNotEmpty ? verified.first : ordered.first,
      DataPolicy.verifiedOnly => verified.firstOrNull,
    };
    return ResolvedField(
      preferred: chosen,
      alternatives: List.unmodifiable(ordered.where((o) => o.id != chosen?.id)),
      conflicting: verified.isNotEmpty
          ? verified.map((o) => jsonEncodeStable(o.value)).toSet().length > 1
          : distinctValues.length > 1,
      policy: policy,
      incomplete: chosen == null,
      usedFallback: policy == DataPolicy.verifiedPreferred && verified.isEmpty,
    );
  }

  int _priority(String status) => switch (status.toUpperCase()) {
    'IN_GAME_VERIFIED' => 6,
    'USER_CONFIRMED_CAPTURE' => 5,
    'STALE_VERIFIED' => 0,
    'MULTI_SOURCE_VERIFIED' => 4,
    'COMMUNITY' => 3,
    'GUIDE_BASED' => 2,
    'GUIDE_LISTED' => 2,
    'CONFLICTING' => 1,
    'OUTDATED' => 0,
    _ => 0,
  };
}

String jsonEncodeStable(Object? value) =>
    value is Map || value is List ? value.toString() : '$value';
