# Validation Evidence

## Evidence policy

This repository publishes summarized, reproducible evidence instead of raw UE4SS logs.

Raw logs can contain:

- Local filesystem paths.
- Unrelated installed mods.
- Machine-specific addresses.
- Large quantities of engine output irrelevant to the finding.

The public record therefore includes the probe version, controlled action sequence, measured callback counts, teardown result, and the engineering decision produced by the test.

## Test Environment

- Game: Palworld PC.
- Runtime modification layer: UE4SS 3.0.1 Beta #0.
- Test world: a dedicated local world used for mod validation.
- NPC: the opening Scouting Party Survivor.
- Trigger policy: interaction only. Proximity alone must do nothing.

## Interaction Hook Probe v0.2.1

### Goal

Determine whether the two interaction-created dialogue widgets expose a stable class-scoped callback surface across:

1. Open conversation.
2. Close conversation.
3. Reopen page 1.
4. Advance to page 2.
5. Advance to page 3.
6. Close and immediately reopen.

### Safety constraints

- No hook during world loading.
- Manual arm only after page 1 is visible.
- Two target classes only.
- No PalCharacter construction listener.
- No property or save write.
- Manual teardown before returning to title.

### Function inventory result

High-value functions discovered on `WBP_TalkWindow_C`:

- `SetHide`
- `SetTextList`
- `SetupNextSplittedText`
- `SetupNextText`
- `OnProgressTextInput`
- `ProgressText`
- `SkipText`

High-value functions discovered on `WBP_Talk_C`:

- `AnmEvent_Open`
- `AnmEvent_Close_WithEventDispatcher`
- `SetMainText`
- `SetTalkerName`
- `SetNextArrowVisible`

### Controlled run result

| Signal | Count |
|---|---:|
| `talk-window` graph entry `15` | 19,731 |
| `talk-window` graph entry `241` | 5 |
| `talk-window` graph entry `256` | 8 |
| `talk-content` graph entry `302` | 3 |
| Total | 19,747 |

Additional results:

- Both hook registrations succeeded.
- All five manual phase markers were recorded.
- The same dialogue widget identities remained present across the labeled actions.
- Both hook unregistrations succeeded.
- Final cleanup reported zero failures.
- No crash or fatal signature was present in the test log.

### Interpretation

The two target widget classes are stable enough to continue narrow research.

The generated event graph is not a production-quality hook surface. Entry `15` accounted for approximately 99.92 percent of callbacks and behaved as Tick noise. The graph proved class residency and teardown, but it should not remain registered during normal gameplay.

### Decision

Replace both generated-event-graph hooks with exact named-function hooks.

## Dialogue Lifecycle Probe v0.3.0

### Goal

Map low-frequency named callbacks to six player actions and inspect callback parameters for subtitle and speaker data.

### Hooks

Eleven exact functions:

- 3 lifecycle signals.
- 4 content or identity signals.
- 2 input signals.
- 2 presentation or split-text signals.

### Acceptance criteria

- `ARM SUCCESS` reports 11 hooks.
- No `Tick` or `ExecuteUbergraph` hook exists.
- Each open, close, and page action produces a small callback group.
- At least one hook provides stable page identity or text.
- Immediate reopen reproduces the opening pattern.
- F10 removes all 11 hooks with zero failures.
- The player can return to title without a crash.

### Status

Source complete and syntax-validated. In-game trace pending.

## Next Validation Gate

After the named callback is selected:

1. Trigger one temporary spoken slate.
2. Close the conversation while it plays.
3. Verify immediate stop or short fade.
4. Reopen immediately.
5. Verify a single fresh start with no overlap.
6. Repeat ten times.

That result will determine whether the first original voice performance can be implemented safely.

