import 'dart:math' as math;

import 'models.dart';

class BasicOptimizer {
  const BasicOptimizer();

  List<OptimizerRecipe> optimize(
    List<OptimizerOre> inventory, {
    OptimizerConstraints constraints = const OptimizerConstraints(),
    OptimizerObjective objective = OptimizerObjective.maxMultiplier,
    DpsInput? dpsTemplate,
  }) {
    if (constraints.maxOreTypes < 1 || constraints.maxOreTypes > 4) {
      throw ArgumentError.value(
        constraints.maxOreTypes,
        'maxOreTypes',
        'Must be 1..4',
      );
    }
    if (constraints.minTotalOres < 1 ||
        constraints.maxTotalOres < constraints.minTotalOres) {
      throw ArgumentError('Invalid total ore bounds');
    }
    final byId = {for (final ore in inventory) ore.id: ore};
    if (constraints.requiredOres.any(
      (id) => !byId.containsKey(id) || byId[id]!.craftable == 0,
    ))
      return const [];

    final candidates = inventory
        .where(
          (ore) =>
              ore.craftable > 0 && !constraints.forbiddenOres.contains(ore.id),
        )
        .toList();
    final results = <OptimizerRecipe>[];
    var evaluations = 0;

    void evaluate(Map<String, int> recipe) {
      if (evaluations >= constraints.maxEvaluations) return;
      final total = recipe.values.fold<int>(0, (a, b) => a + b);
      if (total < constraints.minTotalOres ||
          total > constraints.maxTotalOres ||
          recipe.length > constraints.maxOreTypes ||
          !constraints.requiredOres.every(recipe.containsKey))
        return;
      evaluations++;
      final chosen = recipe.keys.map((id) => byId[id]!).toList();
      final known = chosen.every((ore) => ore.multiplier != null);
      final multiplier = known
          ? recipe.entries.fold<double>(
                  0,
                  (sum, e) => sum + byId[e.key]!.multiplier! * e.value,
                ) /
                total
          : null;
      var score = multiplier ?? double.negativeInfinity;
      var reason = 'Highest known weighted multiplier';
      final warnings = <String>[];
      if (objective == OptimizerObjective.maxEffects) {
        final effects = <String>{};
        var unknownThreshold = false;
        for (final entry in recipe.entries) {
          final ore = byId[entry.key]!;
          final share = entry.value / total;
          for (final effect in ore.effectTags.intersection(
            constraints.targetEffects,
          )) {
            final threshold = ore.effectActivationThresholds[effect];
            if (threshold == null) {
              unknownThreshold = true;
            } else if (share >= threshold) {
              effects.add(effect);
            }
          }
        }
        score = effects.length.toDouble();
        reason =
            'Meets activation thresholds for ${effects.length} selected effects';
        if (unknownThreshold) {
          warnings.add(
            'Some selected effect activation thresholds are unknown and were not scored.',
          );
        }
      } else if (objective == OptimizerObjective.maxRawDps ||
          objective == OptimizerObjective.maxExpectedDps) {
        if (dpsTemplate == null ||
            dpsTemplate.weapon.baseDamage == null ||
            dpsTemplate.weapon.attackIntervalSeconds == null ||
            multiplier == null) {
          score = double.negativeInfinity;
          warnings.add(
            'Required weapon damage, attack interval, or multiplier is unknown.',
          );
          reason = 'Not ranked because DPS inputs are incomplete';
        } else {
          final raw =
              dpsTemplate.weapon.baseDamage! *
              multiplier /
              dpsTemplate.weapon.attackIntervalSeconds!;
          if (objective == OptimizerObjective.maxRawDps) {
            score = raw;
            reason = 'Highest raw DPS from known weapon inputs';
          } else if (dpsTemplate.criticalChance == null ||
              dpsTemplate.criticalDamageExtra == null ||
              !dpsTemplate.procDataKnown ||
              dpsTemplate.expectedProcDps == null) {
            score = double.negativeInfinity;
            warnings.add(
              'Expected DPS is not ranked because critical or trait inputs are unknown.',
            );
            reason = 'Not ranked because expected DPS inputs are incomplete';
          } else {
            score =
                raw *
                    (1 +
                        dpsTemplate.criticalChance! *
                            dpsTemplate.criticalDamageExtra!) +
                dpsTemplate.expectedProcDps!;
            reason = 'Highest expected DPS from fully supplied inputs';
          }
        }
      }
      if (chosen.any((ore) => ore.dataConfidence < 0.6)) {
        warnings.add('One or more input values have low data confidence.');
      }
      final consumed = Map<String, int>.unmodifiable(recipe);
      final dataCertainty = chosen.fold<double>(
        1,
        (v, ore) => math.min(v, ore.dataConfidence.clamp(0.0, 1.0)),
      );
      final rankable = score.isFinite;
      results.add(
        OptimizerRecipe(
          recipe: consumed,
          score: score,
          multiplier: multiplier,
          consumedInventory: consumed,
          remainingInventory: Map.unmodifiable({
            for (final ore in inventory)
              ore.id: ore.available - (recipe[ore.id] ?? 0),
          }),
          warnings: List.unmodifiable(warnings),
          confidence: dataCertainty,
          whyThisResult: reason,
          dataCertainty: dataCertainty,
          formulaCertainty: rankable ? 1 : 0,
          probabilityCertainty: 0,
          rankable: rankable,
        ),
      );
    }

    void generateCounts(
      List<OptimizerOre> selected,
      int index,
      int remaining,
      Map<String, int> recipe,
    ) {
      if (evaluations >= constraints.maxEvaluations) return;
      if (index == selected.length) {
        if (remaining == 0) evaluate(recipe);
        return;
      }
      final ore = selected[index];
      final maxCount = math.min(ore.craftable, remaining);
      final minCount = constraints.requiredOres.contains(ore.id) ? 1 : 0;
      for (var count = minCount; count <= maxCount; count++) {
        if (count > 0) recipe[ore.id] = count;
        generateCounts(selected, index + 1, remaining - count, recipe);
        recipe.remove(ore.id);
        if (evaluations >= constraints.maxEvaluations) break;
      }
    }

    void chooseTypes(int start, List<OptimizerOre> selected) {
      if (evaluations >= constraints.maxEvaluations) return;
      if (selected.isNotEmpty &&
          constraints.requiredOres.every(
            (id) => selected.any((ore) => ore.id == id),
          )) {
        final upper = math.min(
          constraints.maxTotalOres,
          selected.fold<int>(0, (sum, ore) => sum + ore.craftable),
        );
        for (var total = constraints.minTotalOres; total <= upper; total++) {
          generateCounts(selected, 0, total, {});
          if (evaluations >= constraints.maxEvaluations) break;
        }
      }
      if (selected.length == constraints.maxOreTypes) return;
      for (var i = start; i < candidates.length; i++) {
        chooseTypes(i + 1, [...selected, candidates[i]]);
        if (evaluations >= constraints.maxEvaluations) break;
      }
    }

    chooseTypes(0, []);
    results.removeWhere((r) => !r.score.isFinite);
    results.sort((a, b) => b.score.compareTo(a.score));
    final unique = <String, OptimizerRecipe>{};
    for (final result in results) {
      final entries = result.recipe.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final key = entries.map((e) => '${e.key}:${e.value}').join('|');
      unique.putIfAbsent(key, () => result);
    }
    return unique.values.take(10).toList(growable: false);
  }
}
