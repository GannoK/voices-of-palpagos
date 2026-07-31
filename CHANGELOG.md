# Changelog

Version numbers identify diagnostic prototypes until the first gameplay release.

## [0.3.0] - 2026-07-30

### Added

- Eleven exact named-function targets across `WBP_TalkWindow_C` and `WBP_Talk_C`.
- Controlled action labels for close, open, page changes, and immediate reopen.
- Protected callback-parameter inspection for subtitle and speaker extraction.
- Per-hook counts, callback limits, summary output, and explicit teardown.

### Changed

- Replaced generated-event-graph tracing with named lifecycle, content, input, and presentation functions.

### Runtime constraints

- No `NotifyOnNewObject`.
- No timer, polling loop, Tick, or `ExecuteUbergraph` hook.
- No map, player, actor, or character hook.
- No audio playback.
- No game-property or save-data writes.
- Partial registration rolls back registered hooks.

## [0.2.1] - 2026-07-30

### Validated

- Both target dialogue widget classes accepted class-scoped hooks.
- Controlled dialogue actions produced traceable callback groups.
- Widget identities remained stable through close and immediate reopen.
- Both hooks unregistered with zero failures.

### Finding

The generated event graph produced 19,731 Tick-associated callbacks out of 19,747 total callbacks. This measurement established the requirement for exact named-function hooks.

