# Voices of Palpagos

**An interaction-driven voice runtime for Palworld human NPCs**

Voices of Palpagos is an unofficial technical prototype by **Kyle Gannon**. The project is establishing a reliable path from Palworld's existing human-NPC dialogue interface to authored, spatialized voice playback.

The current build is a UE4SS diagnostic probe. It maps conversation open, page progression, speaker identity, subtitle content, close, and immediate reopen without changing save data or triggering from proximity.

> This is an independent fan project. It is not endorsed by or affiliated with Pocketpair, Inc. Palworld and related names and assets belong to their respective owners.

## Current Engineering Result

Runtime investigation identified two stable dialogue widget classes:

- `WBP_TalkWindow_C` — conversation state, text progression, input, and visibility.
- `WBP_Talk_C` — speaker name, displayed text, next-page indicator, and open/close animation events.

A controlled trace proved that both classes can be hooked and cleanly released across page changes, conversation close, and immediate reopen. It also showed why generated event graphs are unsuitable for production:

| Measurement | Result |
|---|---:|
| Registered hooks | 2 |
| Total callbacks | 19,747 |
| Tick-associated callbacks | 19,731 |
| Non-Tick callbacks | 16 |
| Hooks removed | 2 |
| Removal failures | 0 |

Because 99.92% of the callback traffic was Tick noise, the broad graph strategy was rejected. The current `v0.3.0` probe targets 11 explicit, low-frequency dialogue functions instead.

## Current Validation Gate

The active test is selecting the smallest reliable signal set for:

```text
open -> page 1 -> page 2 -> page 3 -> close -> immediate reopen
```

The gate passes when:

- Named callbacks remain low frequency.
- A stable speaker and page identity can be resolved.
- All hooks are removed deterministically.
- Returning to the title screen remains stable.

The next gate is one interruption-safe voice line: play once, stop on close, and restart without overlap on immediate reopen.

## Runtime Design Goals

- Speech begins only after deliberate player interaction.
- Each subtitle page resolves to one stable line identity.
- Closing a conversation stops or briefly fades its current line.
- Immediate reopen cannot inherit stale playback.
- Audio remains owned by and spatialized from the correct NPC.
- Per-speaker priority, concurrency, and cooldown rules prevent chatter.
- Original performances and runtime assets retain traceable rights and revision metadata.
- Disabling the runtime leaves existing saves unchanged.

## Repository

```text
voices-of-palpagos/
├── src/
│   └── VoPDialogueLifecycleProbe/
│       ├── enabled.txt
│       └── Scripts/main.lua
├── docs/
│   ├── ARCHITECTURE.md
│   └── VALIDATION.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── ROADMAP.md
└── LICENSE.md
```

- [Architecture](docs/ARCHITECTURE.md) documents the current runtime boundary and planned playback state model.
- [Validation](docs/VALIDATION.md) records controlled results and acceptance criteria.
- [Roadmap](ROADMAP.md) defines the progression from lifecycle proof to a production-ready vertical slice.

Raw logs, crash dumps, local paths, and unrelated runtime data are excluded from the public repository. Published findings are reduced to reproducible test conditions, measurements, and engineering decisions.

## Current Source

`src/VoPDialogueLifecycleProbe/Scripts/main.lua`

The probe:

- Arms manually with `F8` after a conversation is visible.
- Uses `F9` to label controlled dialogue actions.
- Uses `F10` to summarize and remove registered hooks.
- Hooks only named functions on the two identified dialogue classes.
- Plays no audio and writes no game or save properties.

This source is a diagnostic tool, not a gameplay release.

## Creator

**Kyle Gannon**  
Audio engineer and implementation developer
