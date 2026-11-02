# 開発ガイド

[READMEに戻る](../README.md)

## 環境

- Flutter 3.47.8 / Dart 3.13.7
- ゲームエンジン：Flame
- 対象：PCブラウザ
- 配信：GitHub Pages

Flutterのバージョンは [pubspec.yaml](../pubspec.yaml) の `environment.flutter` で指定し、CIもこのファイルを参照します。Actionの仕様に合わせ、範囲指定ではなく `3.47.8` のように完全なバージョンを指定します。

```sh
flutter pub get --enforce-lockfile
flutter run -d chrome
```

SDKを更新する際は、`pubspec.yaml` の指定とローカルのFlutterを揃えてください。

## コード構成

| パス | 役割 |
| --- | --- |
| `lib/main.dart` | アプリの起動とロケール設定 |
| `lib/game/run_state.dart` | 戦闘・能力の実行、経験値、ラン状態のシミュレーション |
| `lib/game/build.dart` | 能力・設計方針の定義と、戦闘・カードで共有するステータス計算 |
| `lib/game/ability_runtime.dart` | 減速領域・再攻撃・集中・回復予算のラン内状態 |
| `lib/game/combat_rules.dart` | 方向防御と範囲・側背面攻撃の共通判定 |
| `lib/game/combat_entities.dart` | 敵、弾、オブジェクト、軌道の衝突判定 |
| `lib/game/spawn_director.dart` | 時間帯と出現コストによる編成管理 |
| `lib/game/language_profile.dart` | 戦闘バランスから独立した言語傾向の判定 |
| `lib/game/runtime_game.dart` | Flameの更新・描画・キーボード入力 |
| `lib/game/character_painter.dart` | キャラクターの図形描画 |
| `lib/ui/` | HUD、能力選択、開始・一時停止・結果・設定・図鑑 |
| `lib/l10n/game_text.dart` | 日本語・英語の文言と能力説明 |
| `lib/audio/` | Web AudioによるBGM・効果音 |
| `lib/settings.dart` | 設定と発見記録のローカル保存 |
| `assets/` | BGM音源と能力アイコン |
| `test/` | 戦闘・成長・音声状態・入力・UIのテスト |
| `tool/` | オリジナルアセットの生成処理 |

## 検証

CIと同じ検証コマンドです。

```sh
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
flutter build web --release --base-href /runtime-survivors/ --no-web-resources-cdn
```

`build/web` にPages用の成果物を出力します。`--no-web-resources-cdn` によりCanvasKitも成果物に含めます。ルートパスでホストする場合は `--base-href /runtime-survivors/` を省略できます。

UIの表示テストではFlutter SDKに同梱されたRobotoと、HUDで使う同梱のRoboto Monoを読み込み、PCブラウザの英文に近い文字幅でレイアウトを検証します。音声のネイティブテストでは無音のバックエンドを使用します。

5分間の統合テストでは両設計方針に加え、範囲・減速・回復、OOP・防壁・集中、同時攻撃・再攻撃・集中・貫通の組み合わせを実行します。生存時間全体を検証するため、このテストではメモリを補充します。難易度評価や実プレイの代替ではありません。

新しい敵のIDは列挙型の末尾に追加し、既存の発見記録との互換性を維持します。出現時期・比率・上限・コストは `SpawnDirector.rules`、Infraの前提とランク上限は `UpgradeInfo`、言語判定の重みは `language_profile.dart` にあります。

## アセットの生成

### HUDの等幅フォント

[Roboto Monoの公式配布](https://github.com/google/fonts/tree/main/ofl/robotomono)から取得した可変フォントを `assets/fonts/roboto_mono/RobotoMono.ttf` に同梱しています。原文のライセンス `OFL.txt` もWeb成果物に含めます。HUDとキーキャップに使用し、表示テストでも同じフォントを読み込みます。

### BGM

```sh
python3 tool/generate_bgm.py
```

Pythonの標準ライブラリだけで `assets/audio/runtime_loop.wav` を生成します。「Runtime Loop」は112 BPM・16小節（約34秒）のチップチューンで、メロディ・ベース・アルペジオ・ドラムを重ねています。BGM音源はビルド成果物に同梱し、効果音はWeb Audio APIで合成します。

### 能力アイコン

```sh
flutter test tool/generate_upgrade_icons.dart
```

ベクター描画のソースから `assets/icons/upgrades/` に19種類の256×256 PNGを生成します。カード・サイドバー・図鑑は共通の `UpgradeIcon` ウィジェットで同じアセットを参照します。

## CIとGitHub Pages

[ci.yaml](../.github/workflows/ci.yaml) が、PR、`main` へのpush、手動実行を受け付けます。

1. 依存関係をロックファイルに従って取得する。
2. 書式・静的解析・テストを検証する。
3. Pages用のWebビルドを作成する。
4. `main` のpushまたは `main` に対する手動実行では、成果物をアップロードする。
5. 検証とビルドが成功した後、再利用可能な [pages.yaml](../.github/workflows/pages.yaml) を呼び出して公開する。

PRや `main` 以外の手動実行では公開しません。PRの古い実行はキャンセルし、公開を含む `main` の実行は途中でキャンセルしない構成です。

初回の公開前に、リポジトリの **Settings → Pages → Build and deployment → Source** を **GitHub Actions** に設定してください。

公開先は `https://okaryo.github.io/runtime-survivors/` です。リポジトリ名や配信パスを変更する場合は、`ci.yaml` の `--base-href` も変更してください。

### Actionsの更新

外部ActionはコミットSHAで固定し、コメントに対応するバージョンを残します。更新には [pinact](https://github.com/suzuki-shunsuke/pinact) を使用します。

```sh
pinact run -u
pinact run --check --verify
```

更新後はワークフローとバージョンコメントの差分を確認してください。
