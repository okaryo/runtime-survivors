# Runtime Survivors

プログラミング言語を育て、押し寄せるタスクを処理するローグライト・アクションゲーム。

プレイヤーは、生まれたばかりのプログラミング言語です。コードを書く代わりに、レベルアップごとに言語機能や基盤強化を選択します。ガベージコレクション、並行処理、オブジェクト指向、関数型の組み合わせで、自分だけの戦い方を作りましょう。

- 移動と自動攻撃で、5分間のタスク処理を生き残る
- ランダムな3択から能力を選び、効果とトレードオフを組み合わせる
- 遭遇した敵と取得した能力を「ランタイム図鑑」に記録する
- 日本語・英語の切り替え、BGM・効果音、音量設定に対応

Flutter + Flameで開発しているPCブラウザ向けゲームです。キーボード操作を前提とし、1280×640以上の表示領域を目安にしています。

## 操作

| 操作 | キー |
| --- | --- |
| 移動 | WASD / HJKL / 矢印キー |
| 能力の取得 | 1 / 2 / 3、またはTabで移動してEnter |
| 一時停止・再開 | Esc / P |

攻撃は自動です。敵を倒すと落ちる ◆ を集めてレベルアップし、メモリが尽きる前に5分間生き残ればクリアです。能力カードはクリックでも選択できます。

## ローカルで遊ぶ

Flutter **3.47.8** / Dart **3.13.7** を使用します。Flutterのバージョン指定は `pubspec.yaml` の `environment.flutter` にあります。

```sh
flutter pub get --enforce-lockfile
flutter run -d chrome
```

Chromeを自動起動せず、任意のPCブラウザで開く場合：

```sh
flutter run -d web-server --web-port 8080
```

表示されたURLを開き、「ランタイムを起動」を選択します。

## 開発

```sh
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
```

Webビルドの出力先は `build/web` です。GitHub ActionsではPRと `main` の更新時に検証し、`main` の検証成功後にGitHub Pagesへ公開します。

## ドキュメント

- [ゲーム仕様](docs/gameplay.md)：能力、敵、成長、設定・図鑑のルール
- [開発ガイド](docs/development.md)：コード構成、アセット生成、CI、GitHub Pagesの設定
