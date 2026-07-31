# Roadmap

Development is organized around evidence gates. A later stage begins only after the previous stage produces repeatable behavior and deterministic cleanup.

## 1. Dialogue Lifecycle

**Current**

- [x] Isolate the two human-NPC dialogue widget classes.
- [x] Prove class-scoped hook registration after interaction.
- [x] Prove deterministic teardown before world exit.
- [x] Reject the high-frequency generated-event-graph strategy.
- [ ] Map named callbacks to open, close, and page progression.
- [ ] Resolve stable speaker and subtitle-page identity.

**Exit criterion**

One controlled test produces the same low-frequency sequence for:

`open -> page 1 -> page 2 -> page 3 -> close -> immediate reopen`

## 2. Interruption-Safe Playback

- [ ] Trigger one temporary spoken slate from one resolved page.
- [ ] Bind playback to the correct dialogue session and speaker.
- [ ] Stop or briefly fade when the conversation closes.
- [ ] Restart without overlap on immediate reopen.
- [ ] Reject duplicate starts for the same session and line.
- [ ] Verify that disabling the runtime leaves the save unaffected.

**Exit criterion**

Ten consecutive open, interrupt, close, and immediate-reopen cycles complete without duplicate playback, overlap, stale state, hook accumulation, or a crash.

## 3. Authored Character Vertical Proof

- [ ] Create a concise voice and performance brief.
- [ ] Record original, rights-cleared performances.
- [ ] Edit dry masters and runtime assets.
- [ ] Implement stable line IDs, subtitles, priority, cooldown, and variation.
- [ ] Add spatialization and mix behavior.
- [ ] Capture matched before-and-after gameplay.

**Exit criterion**

One human character has a complete, rights-cleared, mixed, documented, and repeatably tested interaction set.

## 4. Gameplay Vertical Slice

- [ ] Expand to three contrasting human archetypes.
- [ ] Add interaction and combat-state coverage.
- [ ] Validate concurrency during multi-NPC and Pal combat.
- [ ] Test single-player, listen-host, and dedicated-server behavior.
- [ ] Produce an installation package, compatibility notes, and feature reel.

**Exit criterion**

The slice demonstrates reliable runtime behavior, clear faction identity, controlled repetition, intelligible mixing, and documented asset provenance.

## 5. Production Readiness

- [ ] Build the authoritative human roster from current game data.
- [ ] Establish versioned line, localization, rights, and QA databases.
- [ ] Add regression tests for game updates and world transitions.
- [ ] Validate removal, upgrade, and compatibility workflows.
- [ ] Select the appropriate supported distribution path.

Context-aware or generated dialogue remains deferred until authored playback, multiplayer authority, validation, and moderation boundaries are proven.

