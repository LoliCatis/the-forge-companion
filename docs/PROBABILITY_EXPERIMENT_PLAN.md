# Forge probability experiment plan (planning only)

This document does not promote any probability to verified status. Existing community/guide values remain attributed as such until direct evidence or a sufficiently powered experiment supports a change.

## Candidate paths

1. **Official or in-game dataset:** prefer a published dataset or a game screen that directly exposes the complete table, with version/context and provenance.
2. **Reliable game-data extraction:** only a documented, reproducible, read-only data source with provenance and permission; no Roblox memory reading, DLL/injection, or hidden client interfaces.
3. **Craft outcome experiment:** estimate the distribution from repeated real crafts under a fixed recipe and game update. This supports or challenges a hypothesis; it does not prove an exact hidden table.

## Protocol for path 3

- Freeze one recipe: craft type, exact ore IDs and quantities, weapon/class selection, and all other in-game options. Do not pool different recipes.
- Record game/update label, session/date, recipe, and any visible settings. Record each craft outcome as one result category, including an explicit `OTHER/UNKNOWN` when the result cannot be classified. Do not omit failed/ambiguous attempts; annotate and report them separately.
- Record the cumulative sample size `n` and outcome counts `xᵢ`; observed frequency is `xᵢ/n` for each outcome.
- Pre-register the community probability `p₀` being evaluated and a practical discrepancy threshold before collecting outcomes. Keep exploratory batches separate from the confirmation batch.
- Initial screening: at least 200 independent crafts for a common outcome is a useful first batch, not a universal proof threshold. Rare outcomes need far larger samples; choose a target sample based on the smallest probability and discrepancy worth detecting. For example, seeing zero occurrences only becomes informative when the upper confidence bound is below the claimed probability.
- Report a 95% Wilson interval for each binomial outcome, and a multinomial interval or simultaneous-adjusted intervals when evaluating a full table. For zero counts, use an exact binomial interval rather than treating the estimated frequency as exactly zero.
- Support criterion: the pre-registered `p₀` lies inside the interval and the interval is narrow enough to exclude the pre-registered practically meaningful difference. This is evidence consistent with `p₀`, not proof of exact equality.
- Refutation criterion: the pre-registered `p₀` falls outside the pre-registered confidence interval after the confirmation sample, or a pre-registered multinomial goodness-of-fit test rejects the full table at α=0.05 with the chosen multiple-testing handling. Investigate recipe/update drift before changing the source status.
- Otherwise report **inconclusive** and keep the community value and experiment estimate side by side.

Do not use “100 crafts = exact probability.” Publish counts, frequencies, intervals, recipe, update context, and exclusions together. The existing Experiment model should hold experiment/run/outcome records; this milestone adds no large experiment UI.
