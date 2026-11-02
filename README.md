# Runtime Survivors

プログラミング言語そのものを設計する、Vampire Survivors風のローグライト・アクションゲーム。Flutter + FlameによるPCブラウザ向けプロトタイプです。

## 起動

Flutter **3.47.8** / Dart **3.13.7** を使用します。FVMを利用する場合は `fvm install` 後、各コマンドを `fvm flutter` / `fvm dart` に置き換えてください。

```sh
flutter pub get
flutter run -d chrome
```

ブラウザを自動起動しない場合：

```sh
flutter run -d web-server --web-port 8080
```

表示されたローカルURLをPCブラウザで開き、「ランタイムを起動」をクリックします。

## 遊び方

- **WASD / 矢印キー**：移動（斜め移動も同じ速度）
- **自動攻撃**：攻撃範囲内の最も近いタスクを処理
- **◆**：倒したタスクが落とす経験値。近づくと吸い寄せて回収
- **レベルアップ**：ランダムな3択からクリック、または **1 / 2 / 3** キーで実装
- **ESC / P**：一時停止・再開。タブが非アクティブになった場合も自動停止
- **メモリ（HP）が0**：ラン終了。**5分生存**：言語完成

能力選択中は戦闘と時間を停止します。終了画面で獲得能力を確認でき、最初から遊び直せます。ランの保存や外部送信は行いません。

## 実装した能力

| 能力 | 効果（ランクごと） | トレードオフ |
| --- | --- | --- |
| Garbage Collection | 3秒ごとの範囲攻撃。範囲・威力も増加 | 通常攻撃の間隔 +0.08秒 |
| Concurrency | 通常攻撃の対象 +1 | 通常攻撃の単発威力 ×0.88 |
| Memory Expansion | 最大HP +25、現在HP +35（上限まで） | なし |
| Clock Speed | 移動速度 ×1.12 | なし |
| Cache Locality | 経験値回収範囲 +35、攻撃範囲 +20 | なし |
| Compiler Optimization | 通常攻撃の威力 ×1.25 | なし |

GCとConcurrencyは共存可能で、各4ランクまで。基盤強化は繰り返し取得できます。最大ランクの機能は3択に出現しません。

タスクは通常型・高速型・高耐久型の3種類。時間経過で出現頻度と耐久力が上がります。数値と勝利条件はゲーム性を検証するための仮設定です。

## 構成

- `lib/game/run_state.dart`：戦闘、スポーン、経験値、能力、ラン状態のシミュレーション
- `lib/game/runtime_game.dart`：Flameの更新・図形描画・キーボード入力
- `lib/main.dart`：FlutterのHUD、能力選択、開始・一時停止・結果画面
- `test/`：戦闘・成長のロジックテストとUIの操作テスト

仮の図形と色を利用しています。OOP、Functional Programming、Ownership、Null Safety、シナジー、言語命名、ビルド共有は今後の検討対象です。

## 検証・ビルド

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
```

`build/web` が成果物です。`--no-web-resources-cdn` によりCanvasKitも成果物に含めます。

## GitHub Pages

`.github/workflows/web.yml` で、PR時に書式・解析・テスト・Webビルドを実行し、`main` へのpush時にはGitHub Pagesへ配信します。手動実行も可能です。

初回配信前に、リポジトリの **Settings → Pages → Build and deployment → Source** を **GitHub Actions** に設定してください。

Pages用ビルドは `--base-href /runtime-survivors/` を指定しています。リポジトリ名や配信パスを変更する場合は、ワークフロー内のこの値も変更してください。

想定配信先：<https://okaryo.github.io/runtime-survivors/>（この実装作業ではpush・公開していません）
