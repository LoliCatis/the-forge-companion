import 'package:calculation_engine/calculation_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Forge calculator', () {
    const calc = ForgeCalculator();
    test('weighted multiplier and composition percentages', () {
      const a = OreDefinition(id: 'a', name: 'A', multiplier: 0.2);
      const b = OreDefinition(id: 'b', name: 'B', multiplier: 0.4);
      final result = calc.calculate(const [
        OreAmount(ore: a, quantity: 2),
        OreAmount(ore: b, quantity: 2),
      ]);
      expect(result.totalOres, 4);
      expect(result.weightedMultiplier, closeTo(0.3, 1e-9));
      expect(result.composition['a'], 0.5);
      expect(result.composition['b'], 0.5);
    });

    test('unknown multiplier stays unknown', () {
      const unknown = OreDefinition(id: 'unknown', name: 'Unknown Ore');
      final result = calc.calculate(const [
        OreAmount(ore: unknown, quantity: 4),
      ]);
      expect(result.weightedMultiplier, isNull);
      expect(result.weaponClassProbabilities, isNull);
      expect(result.qualityMultiplier, isNull);
    });

    test('trait activation and full threshold boundaries', () {
      const trait = OreTrait(
        id: 'trait',
        name: 'Trait',
        activationThreshold: 0.1,
        fullThreshold: 0.3,
        scalingRule: TraitScalingRule.linearBetweenThresholds,
      );
      const ore = OreDefinition(id: 'ore', name: 'Ore', traits: [trait]);
      final inactive = calc.calculate(const [
        OreAmount(ore: ore, quantity: 1),
        OreAmount(
          ore: OreDefinition(id: 'filler', name: 'Filler'),
          quantity: 10,
        ),
      ]);
      final partial = calc.calculate(const [
        OreAmount(ore: ore, quantity: 18),
        OreAmount(
          ore: OreDefinition(id: 'filler', name: 'Filler'),
          quantity: 82,
        ),
      ]);
      final full = calc.calculate(const [
        OreAmount(ore: ore, quantity: 3),
        OreAmount(
          ore: OreDefinition(id: 'filler', name: 'Filler'),
          quantity: 7,
        ),
      ]);
      final overallocated = calc.calculate(const [
        OreAmount(ore: ore, quantity: 4),
        OreAmount(
          ore: OreDefinition(id: 'filler', name: 'Filler'),
          quantity: 6,
        ),
      ]);
      expect(inactive.traits.single.activation, TraitActivation.inactive);
      expect(partial.traits.single.activation, TraitActivation.partial);
      expect(partial.traits.single.strength, closeTo(0.4, 1e-9));
      expect(full.traits.single.activation, TraitActivation.full);
      expect(full.traits.single.strength, 1.0);
      expect(
        overallocated.traits.single.activation,
        TraitActivation.overallocated,
      );
      expect(overallocated.traits.single.strength, 1.0);
    });

    test('formula selection preserves alternative scaling hypotheses', () {
      const trait = OreTrait(
        id: 'trait',
        name: 'Trait',
        activationThreshold: 0.1,
        fullThreshold: 0.3,
      );
      const ore = OreDefinition(id: 'ore', name: 'Ore', traits: [trait]);
      const filler = OreDefinition(id: 'filler', name: 'Filler');
      const linear = TraitFormulaPolicy(
        formula: FormulaDefinition(
          id: 'traitScaling.linear.v1',
          name: 'Linear',
          version: '1',
          source: 'ForgeOre community description',
          verificationStatus: VerificationStatus.community,
          description: 'Linear from activation to full threshold.',
        ),
      );
      const selection = [
        OreAmount(ore: ore, quantity: 2),
        OreAmount(ore: filler, quantity: 8),
      ];
      final unresolved = calc.calculate(selection);
      final selected = calc.calculate(
        selection,
        traitFormulaPolicy: linear,
      );
      expect(unresolved.traits.single.strength, isNull);
      expect(selected.traits.single.strength, closeTo(0.5, 1e-9));
    });
  });

  group('Probability table validator', () {
    const validator = ProbabilityTableValidator();
    test('sum one is valid', () {
      final result = validator.validate(const [
        ProbabilityEntry('a', .4),
        ProbabilityEntry('b', .6),
      ]);
      expect(result.status, ProbabilityTableStatus.valid);
      expect(result.sourceSum, 1);
    });
    test(
      'underflow is retained and only explicitly normalized for estimate',
      () {
        final validation = validator.validate(const [
          ProbabilityEntry('a', .55),
          ProbabilityEntry('b', .42),
        ]);
        expect(validation.sourceSum, closeTo(.97, 1e-9));
        expect(validation.status, ProbabilityTableStatus.underflow);
        final source = validator.estimate(validation);
        expect(source.normalized, isFalse);
        expect(source.probabilities['a'], .55);
        final estimate = validator.estimate(
          validation,
          policy: ProbabilityNormalizationPolicy.normalizedEstimate,
        );
        expect(estimate.normalized, isTrue);
        expect(estimate.sourceSum, closeTo(.97, 1e-9));
        expect(
          estimate.probabilities.values.reduce((a, b) => a + b),
          closeTo(1, 1e-9),
        );
      },
    );
    test('overflow is retained', () {
      final result = validator.validate(const [
        ProbabilityEntry('a', .61),
        ProbabilityEntry('b', .60),
      ]);
      expect(result.sourceSum, closeTo(1.21, 1e-9));
      expect(result.status, ProbabilityTableStatus.overflow);
    });
    test('negative, duplicate, missing and impossible entries are invalid', () {
      final result = validator.validate(
        const [
          ProbabilityEntry('a', -.1),
          ProbabilityEntry('a', .4),
          ProbabilityEntry('impossible', .1),
        ],
        expectedResults: {'a', 'b'},
        impossibleResults: {'impossible'},
      );
      expect(result.status, ProbabilityTableStatus.invalid);
      expect(result.missingResults, ['b']);
      expect(result.issues.join(' '), contains('Duplicate'));
      expect(result.issues.join(' '), contains('Impossible'));
    });
    test('small sum difference is marked rounding suspected', () {
      final result = validator.validate(const [
        ProbabilityEntry('a', .499),
        ProbabilityEntry('b', .5),
      ]);
      expect(result.status, ProbabilityTableStatus.roundingSuspected);
    });
  });

  group('DPS calculation', () {
    const calculator = DpsCalculator();
    test('breakdown accounts for interval, multiplier, crit and proc', () {
      final result = calculator.calculate(
        const DpsInput(
          weapon: WeaponVariant(
            id: 'w',
            name: 'Weapon',
            baseDamage: 100,
            attackIntervalSeconds: .5,
            dataConfidence: .8,
          ),
          oreMultiplier: 2,
          criticalChance: .2,
          criticalDamageExtra: 1,
          expectedProcDps: 30,
          procDataKnown: true,
          inputDataConfidence: .7,
          formulaConfidence: .9,
        ),
      );
      expect(result.attacksPerSecond, 2);
      expect(result.rawDps, 400);
      expect(result.criticalContribution, 80);
      expect(result.expectedProcContribution, 30);
      expect(result.estimatedTotalDps, 510);
      expect(result.finalConfidence, closeTo(.63, 1e-9));
    });
    test('unknown proc is not silently treated as zero', () {
      final result = calculator.calculate(
        const DpsInput(
          weapon: WeaponVariant(
            id: 'w',
            name: 'Weapon',
            baseDamage: 100,
            attackIntervalSeconds: 1,
          ),
          oreMultiplier: 1,
          criticalChance: 0,
          criticalDamageExtra: 1,
        ),
      );
      expect(result.rawDps, 100);
      expect(result.knownContributionDps, 100);
      expect(result.estimatedTotalDps, isNull);
      expect(result.unknownContributions, contains('trait proc contribution'));
    });
  });

  group('Basic optimizer constraints', () {
    const optimizer = BasicOptimizer();
    const stock = [
      OptimizerOre(
        id: 'a',
        name: 'A',
        available: 6,
        protectedQuantity: 2,
        multiplier: 2,
        dataConfidence: .8,
      ),
      OptimizerOre(
        id: 'b',
        name: 'B',
        available: 4,
        protectedQuantity: 0,
        multiplier: 3,
        dataConfidence: .9,
      ),
      OptimizerOre(
        id: 'c',
        name: 'C',
        available: 20,
        protectedQuantity: 0,
        multiplier: 10,
        dataConfidence: .2,
      ),
      OptimizerOre(
        id: 'd',
        name: 'D',
        available: 8,
        protectedQuantity: 0,
        multiplier: 4,
        dataConfidence: .7,
      ),
      OptimizerOre(
        id: 'e',
        name: 'E',
        available: 8,
        protectedQuantity: 0,
        multiplier: 5,
        dataConfidence: .7,
      ),
    ];
    test('respects protected quantity, required and forbidden ores', () {
      final results = optimizer.optimize(
        stock,
        constraints: const OptimizerConstraints(
          requiredOres: {'a'},
          forbiddenOres: {'c'},
          minTotalOres: 3,
          maxTotalOres: 4,
          maxOreTypes: 2,
        ),
      );
      expect(results, isNotEmpty);
      for (final result in results) {
        expect(result.recipe, contains('a'));
        expect(result.recipe, isNot(contains('c')));
        expect(result.recipe['a'] ?? 0, lessThanOrEqualTo(4));
        expect(result.remainingInventory['a'], 6 - (result.recipe['a'] ?? 0));
      }
    });
    test('caps recipe at four ore types', () {
      final results = optimizer.optimize(
        stock,
        constraints: const OptimizerConstraints(
          minTotalOres: 5,
          maxTotalOres: 5,
          maxOreTypes: 4,
        ),
      );
      expect(results, isNotEmpty);
      expect(results.every((r) => r.recipe.length <= 4), isTrue);
    });
    test('propagates certainty dimensions and rankability', () {
      final result = optimizer
          .optimize(
            stock,
            constraints: const OptimizerConstraints(
              minTotalOres: 3,
              maxTotalOres: 3,
            ),
          )
          .first;
      expect(result.dataCertainty, result.confidence);
      expect(result.formulaCertainty, 1);
      expect(result.probabilityCertainty, 0);
      expect(result.rankable, isTrue);
      expect(result.snapshotId, isNull);
    });
    test('does not rank unknown expected DPS inputs', () {
      final result = optimizer.optimize(
        stock,
        objective: OptimizerObjective.maxExpectedDps,
        constraints: const OptimizerConstraints(
          minTotalOres: 3,
          maxTotalOres: 3,
        ),
        dpsTemplate: const DpsInput(
          weapon: WeaponVariant(id: 'w', name: 'Unknown weapon'),
        ),
      );
      expect(result, isEmpty);
    });
    test(
      'scores selected effects only when known share thresholds are met',
      () {
        final results = optimizer.optimize(
          const [
            OptimizerOre(
              id: 'flame',
              name: 'Flame Ore',
              available: 4,
              protectedQuantity: 0,
              effectTags: {'burn'},
              effectActivationThresholds: {'burn': .5},
            ),
            OptimizerOre(
              id: 'plain',
              name: 'Plain Ore',
              available: 4,
              protectedQuantity: 0,
            ),
          ],
          objective: OptimizerObjective.maxEffects,
          constraints: const OptimizerConstraints(
            minTotalOres: 4,
            maxTotalOres: 4,
            maxOreTypes: 2,
            targetEffects: {'burn'},
          ),
        );
        expect(results, isNotEmpty);
        expect(results.first.score, 1);
        expect(results.first.recipe['flame']! / 4, greaterThanOrEqualTo(.5));
      },
    );
  });
}
