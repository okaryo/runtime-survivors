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

### FVM（任意）

FVMを使う場合は、`pubspec.yaml` に指定されたバージョンをローカルに設定します。

```sh
fvm use 3.47.8
fvm flutter pub get --enforce-lockfile
fvm flutter run -d chrome
```

作成される `.fvmrc` とSDKキャッシュの `.fvm/` はGit管理対象外です。以降の `flutter` / `dart` コマンドは `fvm flutter` / `fvm dart` に読み替えて実行できます。

## コード構成

| パス | 役割 |
| --- | --- |
| `lib/main.dart` | アプリの起動とロケール設定 |
| `lib/game/run_state.dart` | 戦闘、スポーン、経験値、能力、ラン状態のシミュレーション |
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

UIの表示テストではFlutter SDKに同梱されたRobotoフォントを読み込み、PCブラウザの英文に近い文字幅でレイアウトを検証します。音声のネイティブテストでは無音のバックエンドを使用します。

## アセットの生成

### BGM

```sh
python3 tool/generate_bgm.py
```

Pythonの標準ライブラリだけで `assets/audio/runtime_loop.wav` を生成します。「Runtime Loop」は112 BPM・16小節（約34秒）のチップチューンで、メロディ・ベース・アルペジオ・ドラムを重ねています。BGM音源はビルド成果物に同梱し、効果音はWeb Audio APIで合成します。

### 能力アイコン

```sh
flutter test tool/generate_upgrade_icons.dart
```

ベクター描画のソースから `assets/icons/upgrades/` に8種類の256×256 PNGを生成します。カード・サイドバー・図鑑は共通の `UpgradeIcon` ウィジェットで同じアセットを参照します。

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
