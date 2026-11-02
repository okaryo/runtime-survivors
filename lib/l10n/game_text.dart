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
      Upgrade.oop => call('oop.change', {
        'count': rank + 1,
        'damage': 16 + (rank + 1) * 4,
        'hp': (run.maxHealth - 5).toInt(),
      }),
      Upgrade.functional => call('functional.change', {
        'jumps': rank + 1,
        'range': (run.attackRange - 15).toInt(),
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
    'taskKinds': ['タスクの種類', 'Task types'],
    'type': ['区分', 'Type'],
    'tasks': ['処理したタスク', 'Tasks processed'],
    'completed': ['完了', 'completed'],
    'level': ['言語レベル', 'Language level'],
    'help': ['遊び方', 'How to play'],
    'settings': ['設定', 'Settings'],
    'language': ['表示言語', 'Language'],
    'sound': ['音声（BGM・効果音）', 'Audio (music and effects)'],
    'volume': ['音量', 'Volume'],
    'mute': ['ミュート', 'Mute'],
    'soundOn': ['音声をオン', 'Unmute sound'],
    'soundOff': ['音声をミュート', 'Mute sound'],
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
    'codexResume': [
      '図鑑を閉じるか、再開ボタンを押してください。',
      'Close the codex or use the Resume button.',
    ],
    'codexSelect': [
      '図鑑を閉じるか、カードをクリックしてください。',
      'Close the codex or click an upgrade card.',
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
    'oop.title': ['オブジェクト指向', 'Object-Oriented Programming'],
    'oop.description': [
      '周囲を回るオブジェクトが、それぞれ独立して攻撃します。0.9秒ごとに近くのタスクを狙います。',
      'Orbiting objects independently attack nearby tasks every 0.9 seconds.',
    ],
    'oop.tradeoff': ['最大メモリ −5 HP / ランク', 'Maximum memory −5 HP per rank'],
    'oop.change': [
      'オブジェクト {count}体 / 威力 {damage} / 最大HP {hp}',
      'Objects: {count} / damage {damage} / max HP {hp}',
    ],
    'functional.title': ['関数型プログラミング', 'Functional Programming'],
    'functional.description': [
      '通常攻撃が命中すると、近くの別のタスクへ連鎖。連鎖ごとに威力が70%になります。',
      'Base attacks chain to nearby tasks on hit. Each jump retains 70% of its incoming damage.',
    ],
    'functional.tradeoff': [
      '通常攻撃の索敵範囲 −15 / ランク',
      'Base attack targeting range −15 per rank',
    ],
    'functional.change': [
      '最大 {jumps}回連鎖 / 索敵範囲 {range}',
      'Chain jumps: {jumps} / targeting range {range}',
    ],
    'enemy.0.type': ['通常タスク', 'Standard task'],
    'enemy.1.type': ['高速タスク', 'Fast task'],
    'enemy.2.type': ['高耐久タスク', 'Heavy task'],
    'enemy.3.type': ['エリートタスク', 'Elite task'],
    'enemy.0.title': ['リクエスト', 'Request'],
    'enemy.0.description': [
      '基本のタスク。ゆっくり追いかけてくる。接触ダメージ9。',
      'A basic task that steadily follows you. Contact damage: 9.',
    ],
    'enemy.1.title': ['割り込み', 'Interrupt'],
    'enemy.1.description': [
      '小さくすばしっこいタスク。集団で近づいてくる。接触ダメージ9。',
      'A small, quick task that closes in fast. Contact damage: 9.',
    ],
    'enemy.2.title': ['メモリ確保', 'Allocation'],
    'enemy.2.description': [
      '大きく頑丈なタスク。移動は遅いが耐久力は通常の3倍。接触ダメージ15。',
      'A bulky task. Slow, with three times the usual health. Contact damage: 15.',
    ],
    'enemy.3.title': ['デッドロック', 'Deadlock'],
    'enemy.3.description': [
      'エリートタスク。光るラインで方向を予告してから突進する。予告が出たら横へ避けよう。接触ダメージ22。',
      'An elite task that telegraphs its charge with a bright lane. Dodge sideways when it winds up. Contact damage: 22.',
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
