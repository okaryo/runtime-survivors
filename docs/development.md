# 開発ガイド

[READMEに戻る](../README.md)

## 環境

- Flutter 3.47.8 / Dart 3.13.7
- ゲームエンジン：Flame
- 外部リンク：Flutter公式の `url_launcher` の `Link`（Webでは実際のリンクとして描画）
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
| `lib/game/build.dart` | 能力とトレードオフの定義と、戦闘・カードで共有するステータス計算 |
| `lib/game/ability_runtime.dart` | 設置攻撃・例外処理の再準備・JITゲージ・ストリーム接続・回復予算のラン内状態 |
| `lib/game/deadlock_encounter.dart` | ロックノード・障壁・解除時間・再構成の管理 |
| `lib/game/workload_hazards.dart` | メモリリークのセル形状と寿命、タイマーパルスの移動と衝突 |
| `lib/game/workload_painter.dart` | 漏出領域・タイマーパルス・ストリームの描画 |
| `lib/game/combat_entities.dart` | 敵、弾、オブジェクト、軌道の衝突判定、実回復量を持つ表示エフェクト |
| `lib/game/spawn_director.dart` | 時間別耐久・高負荷個体・ラッシュテーマ・出現コストによる編成管理 |
| `lib/game/language_profile.dart` | 戦闘バランスから独立した言語傾向の判定 |
| `lib/game/runtime_game.dart` | Flameの更新・描画・キーボード入力 |
| `lib/game/character_painter.dart` | キャラクターの図形描画 |
| `lib/ui/` | HUD、能力選択、開始・一時停止・結果・設定・図鑑 |
| `lib/l10n/game_text.dart` | 日本語・英語の文言と能力説明 |
| `lib/audio/` | Web AudioによるBGM・効果音 |
| `lib/settings.dart` | 設定と発見記録のローカル保存 |
| `assets/` | BGM音源・能力アイコン・同梱フォントとライセンス |
| `web/` | Webの起動HTML、共有メタ情報、OGP画像、アプリアイコン |
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

UIの表示テストではFlutter SDKに同梱されたRobotoと、キーキャップで使う同梱のRoboto Monoを読み込み、PCブラウザの英文に近い文字幅でレイアウトを検証します。日本語は同梱のRuntimeSansJPも読み込み、実際の日本語の文字幅で確認します。音声のネイティブテストでは無音のバックエンドを使用します。

クリア音の譜面は `lib/audio/victory_fanfare.dart` にあります。通常SEの音程下降を適用せず、固定音程の三角波を重ねます。5分間のプレイなしで確認したい場合は、`dart run tool/preview_victory_fanfare.dart /tmp/runtime-victory.wav` で同じ譜面・振幅エンベロープのWAVプレビューを生成できます。Web Audioの波形を近似する確認用で、ゲームはWeb Audioで合成します。

ゲームオーバー音の譜面は `lib/audio/game_over_theme.dart` にあります。低いAマイナーの和音へ下降する約2.23秒のフレーズで、クリア音と同じ固定音程の三角波と余韻を使います。`dart run tool/preview_victory_fanfare.dart --game-over /tmp/runtime-game-over.wav` で同じ生成ツールからプレビューできます。敗北への遷移で一度だけ再生し、ミュート・音量設定を共有します。

5分間の統合テストでは範囲・設置・回復、OOP・連鎖・JIT、同時攻撃・入力再利用・貫通、ストリーム接続と範囲攻撃の組み合わせを実行します。生存時間全体を検証するため、このテストではメモリを補充します。難易度評価や実プレイの代替ではありません。

特殊敵の行動機会・優先処理を比較する固定条件のテストもあります。

```sh
RUNTIME_BALANCE_REPORT=1 flutter test test/specialist_pressure_test.dart
RUNTIME_CAPTURE=1 flutter test test/reinforced_render_test.dart
```

前者は4分時点の耐久と、ストリーム・OOP・連鎖・JITおよび関連Infraを強化した構成で、通常個体・高負荷個体の初動と処理時間、接近した場合の処理時間を比較します。メモリを補充し、無関係な出現を除くため、勝率は測りません。後者は日英の比較画像を `/tmp/runtime-high-load-ja.png` と `/tmp/runtime-high-load-en.png` へ出力します。表示比較のため4種類を並べる固定シーンで、実際の同時出現上限は1〜2体です。

新しい敵のIDは列挙型の末尾に追加し、既存の発見記録との互換性を維持します。出現時期・比率・上限・コストは `SpawnDirector.rules`、出現・図鑑対象の切り替えは `EnemyAvailability`、Infraのランク上限は `UpgradeInfo`、言語判定の重みは `language_profile.dart` にあります。

## アセットの生成

### キーキャップの等幅フォント

[Roboto Monoの公式配布](https://github.com/google/fonts/tree/main/ofl/robotomono)から取得した可変フォントを `assets/fonts/roboto_mono/RobotoMono.ttf` に同梱しています。原文のライセンス `OFL.txt` もWeb成果物に含めます。カードのキーキャップに使用し、表示テストでも同じフォントを読み込みます。

### 日本語フォント

[公式Noto Sans JP](https://github.com/google/fonts/tree/main/ofl/notosansjp)を使用し、UIの日本語フォールバックとゲーム内テキストに `RuntimeSansJP` を指定しています。日本語用の句読点を使用し、言語未指定の代替字体に依存しません。英数字は既存のRoboto / Roboto Monoを継続します。

約9.1MBの元フォントを使用文字・仮名・句読点・共通記号へ絞り、約711KBの可変フォントを同梱。Webのindex.htmlから同一オリジンのアセットを先読みし、日本語表示のための外部フォントの追加取得を減らします。元のOFLライセンスも成果物へ含めます。ビルド時のフォント取得やFontToolsのインストールは不要です。

新しい漢字を文言へ追加した場合、`test/japanese_font_test.dart` が同梱範囲を確認します。必要なら公式の `NotoSansJP[wght].ttf` を取得し、FontToolsを一時環境へ入れて再生成します。

```sh
python3 -m venv /tmp/runtime-font-tools
/tmp/runtime-font-tools/bin/pip install fonttools==4.68.0
/tmp/runtime-font-tools/bin/python tool/subset_japanese_font.py /path/to/NotoSansJP.ttf
```

生成されたTTFとcodepoints.txtを一緒にコミットしてください。句読点を含む日本語の実画面も確認します。

### BGM

```sh
python3 tool/generate_bgm.py
```

Pythonの標準ライブラリだけで `assets/audio/runtime_loop.wav` を生成します。「Runtime Loop」は112 BPM・16小節（約34秒）のチップチューンで、メロディ・ベース・アルペジオ・ドラムを重ねています。BGM音源はビルド成果物に同梱し、効果音はWeb Audio APIで合成します。

### 能力アイコン

```sh
flutter test tool/generate_upgrade_icons.dart
```

ベクター描画のソースから `assets/icons/upgrades/` に21種類の256×256 PNGを生成します（現役17種類と、取得候補から外したNull Safety・補助プロセッサ・命令パイプライン・メモ化）。カード・サイドバー・図鑑は共通の `UpgradeIcon` ウィジェットで同じアセットを参照します。

### OGPとREADMEのヘッダ画像

`web/ogp.png` は1200×630のPNGで、READMEと[Open Graph](https://ogp.me/)の両方から参照します。ゲーム内の `CharacterPainter` と既存の能力アイコンを使ったオリジナルの描画で、画像の再生成は次のコマンドです。

```sh
flutter test tool/generate_social_image.dart
```

キャラクターはゲーム本体と同じ半径で描画した後、Canvas全体を拡大します。体の半径だけを増やすと目・口・手足との比率が変わるため、顔・輪郭・付属物を含めて拡大します。プレイヤーの半径は16、敵は `TaskEnemy.radius` を参照します。

タイトル・キャラ・能力を小さいプレビューでも見分けられるように構成しています。`web/index.html` にOGPと大きな画像のTwitter Cardメタ情報、画像サイズ・代替テキスト・canonical URLを設定。Flutter起動前に読み取れる静的HTMLです。`web/` の画像はビルド時にWeb成果物のルートへコピーされます。

共有先のURLは現在のGitHub Pages（`https://okaryo.github.io/runtime-survivors/`）です。ホスト先を変える場合はcanonical・og:url・og:image・twitter:imageとREADMEのリンクを更新してください。画像やメタ情報の公開には通常のpush・CI配信が必要です。GitHubリポジトリ自体のSocial preview設定は別で、ここでは変更しません。

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
