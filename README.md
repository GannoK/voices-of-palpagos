# Voices of Palpagos

**An interaction-driven voice runtime for Palworld human NPCs**  
**Palworldの人間NPC向け、インタラクション駆動型音声ランタイム**

Voices of Palpagos is an unofficial technical prototype by **Kyle Gannon**. The project is establishing a reliable path from Palworld's existing human-NPC dialogue interface to authored, spatialized voice playback.

Voices of Palpagosは、**Kyle Gannon**が開発する非公式の技術プロトタイプです。本プロジェクトは、Palworldに既存の人間NPC用会話インターフェースから、制作済み音声を空間化して再生するまでの、信頼性の高い実装経路を確立することを目的としています。

The current build is a UE4SS diagnostic probe. It maps conversation open, page progression, speaker identity, subtitle content, close, and immediate reopen without changing save data or triggering from proximity.

現在のビルドは、UE4SSを使用した診断用プローブです。セーブデータを変更せず、またNPCへの接近をトリガーとせずに、会話の開始、ページ進行、話者識別、字幕内容、終了、直後の再開を追跡します。

> This is an independent fan project. It is not endorsed by or affiliated with Pocketpair, Inc. Palworld and related names and assets belong to their respective owners.
>
> 本プロジェクトは独立したファンプロジェクトであり、株式会社ポケットペアによる承認・後援を受けたものではなく、同社との提携関係もありません。Palworldならびに関連する名称およびアセットの権利は、それぞれの権利所有者に帰属します。

## Current Engineering Result / 現在の技術成果

Runtime investigation identified two stable dialogue widget classes:

ランタイム調査により、安定して利用できる2つの会話ウィジェットクラスを特定しました。

- `WBP_TalkWindow_C` — conversation state, text progression, input, and visibility.  
  会話状態、テキスト進行、入力、および表示状態を管理します。
- `WBP_Talk_C` — speaker name, displayed text, next-page indicator, and open/close animation events.  
  話者名、表示テキスト、次ページ表示、および開閉アニメーションイベントを管理します。

A controlled trace proved that both classes can be hooked and cleanly released across page changes, conversation close, and immediate reopen. It also showed why generated event graphs are unsuitable for production:

制御されたトレース試験により、ページ変更、会話終了、直後の再開を通して、両クラスへのフックを登録し、安全に解除できることを確認しました。同時に、自動生成されたイベントグラフが本番環境に適さない理由も明らかになりました。

| Measurement / 計測項目 | Result / 結果 |
|---|---:|
| Registered hooks / 登録フック数 | 2 |
| Total callbacks / コールバック総数 | 19,747 |
| Tick-associated callbacks / Tick関連コールバック | 19,731 |
| Non-Tick callbacks / Tick以外のコールバック | 16 |
| Hooks removed / 解除済みフック数 | 2 |
| Removal failures / 解除失敗数 | 0 |

Because 99.92% of the callback traffic was Tick noise, the broad graph strategy was rejected. The current `v0.3.0` probe targets 11 explicit, low-frequency dialogue functions instead.

コールバックトラフィックの99.92%がTick由来のノイズであったため、広範なグラフを対象とする方式は採用しませんでした。現在の`v0.3.0`プローブでは、代わりに明示的に指定した11個の低頻度会話関数を対象としています。

## Current Validation Gate / 現在の検証ゲート

The active test is selecting the smallest reliable signal set for:

現在の試験では、次のライフサイクルを確実に検出できる最小限のシグナルセットを選定しています。

```text
open / 開始 -> page 1 / ページ1 -> page 2 / ページ2 -> page 3 / ページ3 -> close / 終了 -> immediate reopen / 直後の再開
```

The gate passes when:

以下の条件を満たした場合、この検証ゲートは合格となります。

- Named callbacks remain low frequency.  
  指定したコールバックが低頻度を維持すること。
- A stable speaker and page identity can be resolved.  
  話者とページを安定して識別できること。
- All hooks are removed deterministically.  
  すべてのフックを決定論的に解除できること。
- Returning to the title screen remains stable.  
  タイトル画面へ安定して戻れること。

The next gate is one interruption-safe voice line: play once, stop on close, and restart without overlap on immediate reopen.

次の検証ゲートでは、中断に対して安全な1本の音声を実装します。音声は一度だけ再生され、会話終了時に停止し、直後に会話を再開した場合も重複せず最初から再生される必要があります。

## Runtime Design Goals / ランタイム設計目標

- Speech begins only after deliberate player interaction.  
  音声は、プレイヤーが明示的に操作した場合のみ開始します。
- Each subtitle page resolves to one stable line identity.  
  各字幕ページを、一意で安定した音声ラインIDに対応させます。
- Closing a conversation stops or briefly fades its current line.  
  会話を終了すると、再生中の音声を停止するか、短くフェードアウトします。
- Immediate reopen cannot inherit stale playback.  
  会話を直後に再開しても、以前の再生状態を引き継がないようにします。
- Audio remains owned by and spatialized from the correct NPC.  
  音声の所有元と空間上の再生位置を、正しいNPCに維持します。
- Per-speaker priority, concurrency, and cooldown rules prevent chatter.  
  話者ごとの優先度、同時再生数、およびクールダウン規則により、過剰な発話を防止します。
- Original performances and runtime assets retain traceable rights and revision metadata.  
  オリジナルの演技音声とランタイムアセットについて、権利情報と改訂履歴を追跡可能な状態で保持します。
- Disabling the runtime leaves existing saves unchanged.  
  ランタイムを無効化しても、既存のセーブデータには変更を残しません。

## Repository / リポジトリ構成

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
  [Architecture](docs/ARCHITECTURE.md)では、現在のランタイム境界と、計画中の再生状態モデルを説明しています。
- [Validation](docs/VALIDATION.md) records controlled results and acceptance criteria.  
  [Validation](docs/VALIDATION.md)には、制御された試験結果と合格基準を記録しています。
- [Roadmap](ROADMAP.md) defines the progression from lifecycle proof to a production-ready vertical slice.  
  [Roadmap](ROADMAP.md)では、ライフサイクル検証から本番品質の垂直スライスへ進むための開発段階を定義しています。

Raw logs, crash dumps, local paths, and unrelated runtime data are excluded from the public repository. Published findings are reduced to reproducible test conditions, measurements, and engineering decisions.

生ログ、クラッシュダンプ、ローカル環境のパス、および無関係なランタイムデータは、公開リポジトリから除外しています。公開する調査結果は、再現可能な試験条件、計測値、および技術的判断に整理しています。

## Current Source / 現在のソース

`src/VoPDialogueLifecycleProbe/Scripts/main.lua`

The probe:

プローブの機能：

- Arms manually with `F8` after a conversation is visible.  
  会話が表示された後、`F8`キーで手動起動します。
- Uses `F9` to label controlled dialogue actions.  
  `F9`キーで、制御された会話操作にラベルを付けます。
- Uses `F10` to summarize and remove registered hooks.  
  `F10`キーで結果を集計し、登録済みフックを解除します。
- Hooks only named functions on the two identified dialogue classes.  
  特定済みの2つの会話クラスにある、明示的に指定した関数のみをフックします。
- Plays no audio and writes no game or save properties.  
  音声は再生せず、ゲームまたはセーブデータのプロパティにも書き込みません。

This source is a diagnostic tool, not a gameplay release.

このソースは診断用ツールであり、ゲームプレイ向けのリリースではありません。

## Creator / 制作者

**Kyle Gannon**  
Audio engineer and implementation developer  
オーディオエンジニア／実装開発者
