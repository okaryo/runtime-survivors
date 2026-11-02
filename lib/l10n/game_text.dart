import '../game/run_state.dart';

/// All player-facing copy lives here; each entry is [Japanese, English].
class GameText {
  const GameText(this.language);
  final String language;
  bool get isJapanese => language == 'ja';
  String call(String key, [Map<String, Object> args = const {}]) {
    var value = copy[key]![isJapanese ? 0 : 1];
    for (final entry in args.entries) {
      value = value.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return value;
  }

  String title(Upgrade upgrade) => call('${upgrade.name}.title');
  String description(Upgrade upgrade) => call('${upgrade.name}.description');
  String tradeoff(Upgrade upgrade) => call('${upgrade.name}.tradeoff');
  String category(Upgrade upgrade) =>
      call(upgrade.isFeature ? 'feature' : 'infra');
  String change(Upgrade upgrade, RunState run) {
    final rank = run.rank(upgrade);
    return switch (upgrade) {
      Upgrade.garbageCollection => call('gc.change', {
        'radius': 115 + (rank + 1) * 18,
        'damage': 22 + (rank + 1) * 14,
      }),
      Upgrade.concurrency => call('concurrency.change', {
        'from': run.targetCount,
        'to': run.targetCount + 1,
      }),
      Upgrade.memory => call('memory.change', {
        'from': run.maxHealth.toInt(),
        'to': run.maxHealth.toInt() + 25,
      }),
      Upgrade.clock => call('clock.change', {
        'from': run.speed.round(),
        'to': (run.speed * 1.12).round(),
      }),
      Upgrade.cache => call('cache.change', {
        'from': run.pickupRadius.toInt(),
        'to': run.pickupRadius.toInt() + 35,
      }),
      Upgrade.compiler => call('compiler.change', {
        'from': run.attackDamage.toStringAsFixed(1),
        'to': (run.attackDamage * 1.25).toStringAsFixed(1),
      }),
    };
  }

  String event(RunLog event) => call(event.key, {
    ...event.args,
    if (event.upgrade != null) 'name': title(event.upgrade!),
  });

  static const copy = <String, List<String>>{
    'tagline': [
      'タスクを処理し、自分だけの言語を設計しよう。',
      'Survive the tasks. Design your language.',
    ],
    'memory': ['メモリ（HP）', 'Memory (HP)'],
    'uptime': ['稼働時間', 'Uptime'],
    'tasks': ['処理したタスク', 'Tasks processed'],
    'completed': ['完了', 'completed'],
    'level': ['言語レベル', 'Language level'],
    'help': ['遊び方', 'How to play'],
    'settings': ['設定', 'Settings'],
    'language': ['表示言語', 'Language'],
    'sound': ['効果音', 'Sound effects'],
    'volume': ['音量', 'Volume'],
    'mute': ['ミュート', 'Mute'],
    'soundOn': ['効果音をオン', 'Unmute sound'],
    'soundOff': ['効果音をミュート', 'Mute sound'],
    'soundTest': ['効果音を試す', 'Test sound'],
    'close': ['閉じる', 'Close'],
    'paused': ['一時停止中', 'Paused'],
    'pause': ['一時停止', 'Pause'],
    'resume': ['処理を再開', 'Resume runtime'],
    'standby': ['起動待ち', 'Standby'],
    'running': ['稼働中', 'Running'],
    'choosing': ['設計を選択中', 'Choosing an upgrade'],
    'terminated': ['終了', 'Terminated'],
    'controls': [
      'WASD / HJKL / 矢印キー：移動　 ESC / P：一時停止',
      'WASD / HJKL / Arrows: move   ESC / P: pause',
    ],
    'moveHint': [
      '移動して回避。攻撃は自動。◆ を集めて成長しよう。',
      'Keep moving. Attacks are automatic. Collect ◆ to grow.',
    ],
    'design': ['言語の設計', 'Language design'],
    'designHint': ['選んだ機能が、戦い方を変える。', 'Your choices shape the way you fight.'],
    'feature': ['言語機能 / FEATURE', 'LANGUAGE FEATURE'],
    'infra': ['基盤強化 / INFRA', 'INFRASTRUCTURE'],
    'featureShort': ['言語機能', 'Features'],
    'infraShort': ['基盤強化', 'Infrastructure'],
    'featureHint': ['攻撃方法や振る舞いを変える', 'Changes attacks and behavior'],
    'infraHint': ['基本性能を引き上げる', 'Improves your base stats'],
    'emptyFeatures': ['機能はまだありません', 'No features yet'],
    'emptyInfra': ['基盤は初期構成です', 'Running on base infrastructure'],
    'metrics': ['処理性能', 'Runtime metrics'],
    'targets': ['同時攻撃数', 'Attack targets'],
    'damage': ['通常攻撃の威力', 'Base attack damage'],
    'interval': ['通常攻撃の間隔', 'Attack interval'],
    'log': ['システムログ', 'System log'],
    'welcomeLabel': [
      'まだ名前のない、小さな言語のはじまり。',
      'A small language. A world of possibilities.',
    ],
    'welcomeBody': [
      'あなたは、生まれたばかりのプログラミング言語。\nタスクを処理し、機能を選び、5分間を生き残ろう。',
      'You are a programming language in the making.\nProcess tasks, choose features, and survive for five minutes.',
    ],
    'start': ['ランタイムを起動', 'Start runtime'],
    'pickupHint': [
      '倒したタスクが落とす ◆ を集めるとレベルアップ',
      'Collect ◆ from defeated tasks to level up',
    ],
    'choicesTitle': ['次の機能を選ぼう', 'Choose your next upgrade'],
    'choicesHint': [
      '選択中は一時停止。効果はこのランの間だけ続きます。',
      'Time is paused. Upgrades last for this run.',
    ],
    'choicesKeys': [
      'クリック、または 1 / 2 / 3 キーで選択',
      'Click a card or press 1 / 2 / 3',
    ],
    'nextRank': ['ランク {from} → {to}', 'Rank {from} → {to}'],
    'change': ['今回の強化', 'This upgrade'],
    'tradeoff': ['トレードオフ', 'Tradeoff'],
    'implement': ['実装する', 'Implement'],
    'noTradeoff': ['なし', 'None'],
    'pauseTitle': ['ひと息、つこう。', 'Take a breath.'],
    'pauseBody': ['時間の経過と戦闘を停止しています。', 'The timer and combat are paused.'],
    'pauseKeys': ['ESC / P でも再開できます', 'Press ESC / P to resume'],
    'wonLabel': ['ビルド成功', 'Build succeeded'],
    'lostLabel': ['メモリ不足', 'Out of memory'],
    'wonTitle': ['あなたの言語が完成！', 'Your language is complete!'],
    'lostTitle': ['この設計を、次のランへ。', 'A new design starts next run.'],
    'emptyResult': [
      '今回は初期構成。次は機能を実装してみよう。',
      'A minimal build. Try adding features next run.',
    ],
    'restart': ['新しいランタイムを起動', 'Start a new runtime'],
    'helpBody': [
      'WASD / 矢印キー / HJKLで移動します。Hは左、Jは下、Kは上、Lは右。最も近いタスクを自動攻撃します。\n\nタスクを倒すと ◆（経験値）を落とします。近づいて回収し、レベルアップ時に3択から機能を選びましょう。\n\n言語機能は攻撃方法や振る舞いを変え、基盤強化は基本性能を上げます。カードで今回の強化とトレードオフを確認できます。\n\nメモリ（HP）が0になると終了。5分生き残ればクリアです。ESC / Pで一時停止できます。',
      'Move with WASD, arrow keys, or HJKL (H left, J down, K up, L right). Your runtime attacks the nearest task automatically.\n\nDefeated tasks drop ◆ experience. Move close to collect it, then choose one of three upgrades at each level.\n\nFeatures change your attacks and behavior; infrastructure improves your stats. Each card shows its upgrade and tradeoff.\n\nSurvive five minutes to finish your language. Running out of memory (HP) ends the run. Press ESC / P to pause.',
    ],
    'savedLocally': [
      '設定と発見記録は、このブラウザに保存します。',
      'Settings and discoveries are saved in this browser.',
    ],
    'codex': ['ランタイム図鑑', 'Runtime codex'],
    'codexHint': [
      '遭遇したタスクと、取得した能力の記録。',
      'A record of encountered tasks and acquired upgrades.',
    ],
    'codexPaused': ['図鑑を開いている間は一時停止します。', 'Opening the codex pauses the run.'],
    'undiscovered': ['未発見', 'Undiscovered'],
    'unlockEnemy': [
      '遭遇すると情報が開きます。',
      'Encounter this task to reveal its details.',
    ],
    'unlockUpgrade': [
      '取得すると情報が開きます。',
      'Acquire this upgrade to reveal its details.',
    ],
    'name': ['名前', 'Name'],
    'behavior': ['特徴', 'Behavior'],
    'rush': ['タスク集中！', 'Task rush!'],
    'rushHint': ['大量のタスクを受信中', 'Incoming task burst'],
    'eliteWarning': ['エリート接続', 'Elite connected'],
    'nextRush': ['次のラッシュ', 'Next rush'],
    'heap': ['ヒープ', 'Heap'],
    'you': ['YOU', 'YOU'],
    'legend': [
      '◆ 経験値　 敵を避けて、タスクを処理しよう',
      '◆ Experience   Dodge enemies and process tasks',
    ],
    'log.ready': ['ランタイムの起動を待っています。', 'Waiting to start the runtime.'],
    'log.start': ['ランタイム起動。タスクの受信を開始。', 'Runtime started. Receiving tasks.'],
    'log.level': [
      'レベル {level}。新しい設計を選べます。',
      'Level {level}. Choose your next upgrade.',
    ],
    'log.upgrade': ['{name} ランク{rank}を実装。', 'Implemented {name}, rank {rank}.'],
    'log.won': [
      'ビルド成功。あなたの言語が完成しました。',
      'Build succeeded. Your language is complete.',
    ],
    'log.lost': ['メモリ不足でランタイムが停止しました。', 'Runtime stopped: out of memory.'],
    'log.rush': ['タスクが集中しています！', 'Task traffic is surging!'],
    'log.elite': [
      'エリートタスクを受信。突進の予告に注意！',
      'Elite task received. Watch for its charge warning!',
    ],
    'garbageCollection.title': ['ガベージコレクション', 'Garbage Collection'],
    'garbageCollection.description': [
      '3秒ごとに、周囲のタスクをまとめて処理します。',
      'Sweeps nearby tasks with an area pulse every 3 seconds.',
    ],
    'garbageCollection.tradeoff': [
      '通常攻撃の間隔 +0.08秒 / ランク',
      'Base attack interval +0.08 s per rank',
    ],
    'gc.change': [
      '範囲 {radius} / 威力 {damage}',
      'Radius {radius} / damage {damage}',
    ],
    'concurrency.title': ['並行処理', 'Concurrency'],
    'concurrency.description': [
      '近くの複数のタスクに、同時に攻撃します。',
      'Attacks several nearby tasks at the same time.',
    ],
    'concurrency.tradeoff': [
      '通常攻撃の単発威力 ×0.88 / ランク',
      'Base damage per shot ×0.88 per rank',
    ],
    'concurrency.change': [
      '同時攻撃数 {from} → {to}',
      'Attack targets {from} → {to}',
    ],
    'memory.title': ['メモリ増設', 'Memory Expansion'],
    'memory.description': [
      '最大メモリを増やし、現在のメモリも回復します。',
      'Expands your memory capacity and restores current HP.',
    ],
    'memory.tradeoff': ['なし', 'None'],
    'memory.change': [
      '最大HP {from} → {to} / HPを35回復',
      'Max HP {from} → {to} / restores 35 HP',
    ],
    'clock.title': ['クロックアップ', 'Clock Speed'],
    'clock.description': [
      '移動速度を上げ、タスクを避けやすくします。',
      'Moves your runtime faster to help dodge tasks.',
    ],
    'clock.tradeoff': ['なし', 'None'],
    'clock.change': [
      '移動速度 {from} → {to}（+12%）',
      'Movement speed {from} → {to} (+12%)',
    ],
    'cache.title': ['キャッシュ強化', 'Cache Locality'],
    'cache.description': [
      '経験値を遠くから回収でき、攻撃範囲も広がります。',
      'Collects experience from farther away and extends attack range.',
    ],
    'cache.tradeoff': ['なし', 'None'],
    'cache.change': [
      '回収範囲 {from} → {to} / 攻撃範囲 +20',
      'Pickup radius {from} → {to} / attack range +20',
    ],
    'compiler.title': ['コンパイラ最適化', 'Compiler Optimization'],
    'compiler.description': [
      '通常攻撃1発あたりの威力を上げます。',
      'Increases the damage of every base attack.',
    ],
    'compiler.tradeoff': ['なし', 'None'],
    'compiler.change': [
      '通常攻撃の威力 {from} → {to}（+25%）',
      'Base damage {from} → {to} (+25%)',
    ],
  };
}
