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
  List<UpgradeComparison> comparisons(UpgradePreview preview) {
    final before = preview.before;
    final after = preview.after;
    final upgrade = preview.upgrade;
    final first = before.rank(upgrade) == 0;
    String number(double value) => value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    UpgradeComparison metric(
      String label,
      Object? from,
      Object to, {
      bool cost = false,
    }) => UpgradeComparison(call(label), from?.toString(), '$to', cost: cost);
    UpgradeComparison hp({bool cost = false}) => metric(
      'stat.memory',
      '${number(preview.beforeHealth)}/${number(before.maxHealth)}',
      '${number(preview.afterHealth)}/${number(after.maxHealth)}',
      cost: cost,
    );
    return switch (upgrade) {
      Upgrade.garbageCollection => [
        metric(
          'stat.pulseDamage',
          first ? null : number(before.gcDamage),
          number(after.gcDamage),
        ),
        metric(
          'stat.radius',
          first ? null : number(before.gcRadius),
          number(after.gcRadius),
        ),
        metric(
          'stat.interval',
          '${before.attackInterval.toStringAsFixed(2)}s',
          '${after.attackInterval.toStringAsFixed(2)}s',
          cost: true,
        ),
      ],
      Upgrade.concurrency => [
        metric('stat.targets', before.targetCount, after.targetCount),
        metric(
          'stat.damage',
          before.attackDamage.toStringAsFixed(1),
          after.attackDamage.toStringAsFixed(1),
          cost: true,
        ),
      ],
      Upgrade.oop => [
        metric(
          'stat.objects',
          first ? null : before.rank(upgrade),
          after.rank(upgrade),
        ),
        metric(
          'stat.objectDamage',
          first ? null : number(before.objectDamage),
          number(after.objectDamage),
        ),
        hp(cost: true),
      ],
      Upgrade.functional => [
        metric(
          'stat.jumps',
          first ? null : before.rank(upgrade),
          after.rank(upgrade),
        ),
        metric(
          'stat.range',
          number(before.attackRange),
          number(after.attackRange),
          cost: true,
        ),
      ],
      Upgrade.nullSafety => [
        metric(
          'stat.shieldCooldown',
          first ? null : '${before.shieldCooldown.toStringAsFixed(0)}s',
          '${after.shieldCooldown.toStringAsFixed(0)}s',
        ),
        hp(cost: true),
      ],
      Upgrade.patternMatching => [
        metric(
          'stat.patternDamage',
          first ? null : number(before.patternDamage),
          number(after.patternDamage),
        ),
        metric(
          'stat.patternWidth',
          first ? null : number(before.patternRadius * 2),
          number(after.patternRadius * 2),
        ),
      ],
      Upgrade.pipeline => [
        metric(
          'stat.interval',
          '${before.attackInterval.toStringAsFixed(2)}s',
          '${after.attackInterval.toStringAsFixed(2)}s',
        ),
      ],
      Upgrade.bandwidth => [
        metric(
          'stat.projectileSpeed',
          number(before.projectileSpeed),
          number(after.projectileSpeed),
        ),
      ],
      Upgrade.memory => [hp()],
      Upgrade.clock => [
        metric('stat.speed', before.speed.round(), after.speed.round()),
      ],
      Upgrade.cache => [
        metric(
          'stat.pickup',
          number(before.pickupRadius),
          number(after.pickupRadius),
        ),
        metric(
          'stat.range',
          number(before.attackRange),
          number(after.attackRange),
        ),
      ],
      Upgrade.compiler => [
        metric(
          'stat.damage',
          before.attackDamage.toStringAsFixed(1),
          after.attackDamage.toStringAsFixed(1),
        ),
      ],
    };
  }

  String event(RunLog event) => call(event.key, {
    ...event.args,
    if (event.upgrade != null) 'name': title(event.upgrade!),
  });

  static const copy = <String, List<String>>{
    'enemy.4.title': ['RPC要求', 'RPC request'],
    'enemy.4.type': ['射撃タスク', 'Ranged task'],
    'enemy.4.description': [
      '青いアンテナのタスク。射線を予告してから固定方向へ弾を撃つ。横へ避けて近づこう。弾のダメージ11。',
      'An antenna task that telegraphs a fixed-direction shot. Sidestep, then approach. Projectile damage: 11.',
    ],
    'enemy.5.title': ['Fork Bomb', 'Fork Bomb'],
    'enemy.5.type': ['召喚タスク', 'Summoner task'],
    'enemy.5.description': [
      '小型タスクを一度に3体、最大6体まで召喚。本体を倒すと追加召喚が止まる。召喚雑魚の経験値は1。',
      'Summons three small tasks, up to six active children. Defeat the parent to stop spawning. Children grant 1 XP each.',
    ],
    'nullSafety.title': ['Null Safety', 'Null Safety'],
    'nullSafety.description': [
      '敵弾を1発防ぐ防壁。消費後に再充填します。接触は防げません。',
      'Blocks one enemy projectile, then recharges. Does not block contact.',
    ],
    'nullSafety.tradeoff': ['最大メモリ −8 / ランク', 'Maximum memory −8 per rank'],
    'patternMatching.title': ['パターンマッチング', 'Pattern Matching'],
    'patternMatching.description': [
      '3.2秒ごとに直線の貫通弾を発射。発射後は追尾しません。',
      'Fires a piercing shot every 3.2s. Its trajectory is fixed after firing.',
    ],
    'patternMatching.tradeoff': ['発射後の追尾なし', 'Does not home after firing'],
    'pipeline.title': ['命令パイプライン', 'Instruction Pipeline'],
    'pipeline.description': [
      '通常攻撃の間隔を短縮。連鎖や同時攻撃の起点を増やします。',
      'Reduces base attack interval, creating more opportunities for chains and concurrent shots.',
    ],
    'pipeline.tradeoff': ['なし（間隔の下限0.12秒）', 'None (minimum interval 0.12s)'],
    'bandwidth.title': ['転送帯域', 'Transfer Bandwidth'],
    'bandwidth.description': [
      '通常弾・オブジェクト弾・連鎖弾・貫通弾の速度を上げます。',
      'Speeds up base, object, chain, and piercing projectiles.',
    ],
    'bandwidth.tradeoff': ['なし（弾速の上限1600）', 'None (maximum speed 1600)'],
    'stat.shieldCooldown': ['防壁の再充填', 'Shield recharge'],
    'stat.patternDamage': ['貫通攻撃の威力', 'Piercing damage'],
    'stat.patternWidth': ['貫通弾の幅', 'Shot width'],
    'stat.projectileSpeed': ['弾速', 'Projectile speed'],
    'featureSlots': ['採用枠 {used} / {max}', 'Feature slots {used} / {max}'],
    'shieldReady': ['防壁：準備完了', 'Shield: ready'],
    'shieldCharging': ['防壁：{seconds}秒', 'Shield: {seconds}s'],
    'newUpgrade': ['新規', 'NEW'],
    'featureBadge': ['言語機能', 'FEATURE'],
    'infraBadge': ['基盤強化', 'INFRA'],
    'choicesControls': ['1 / 2 / 3 で取得', '1 / 2 / 3 to acquire'],
    'stat.memory': ['メモリ', 'Memory'],
    'stat.pulseDamage': ['範囲攻撃の威力', 'Pulse damage'],
    'stat.radius': ['範囲', 'Radius'],
    'stat.interval': ['攻撃間隔', 'Interval'],
    'stat.targets': ['同時攻撃数', 'Targets'],
    'stat.damage': ['通常攻撃の威力', 'Base damage'],
    'stat.objects': ['オブジェクト数', 'Objects'],
    'stat.objectDamage': ['各オブジェクトの威力', 'Object damage'],
    'stat.jumps': ['連鎖回数', 'Chain jumps'],
    'stat.range': ['索敵範囲', 'Target range'],
    'stat.speed': ['移動速度', 'Move speed'],
    'stat.pickup': ['経験値の回収範囲', 'Pickup radius'],
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
    'encyclopedia': ['ランタイム図鑑', 'Runtime encyclopedia'],
    'encyclopediaHint': [
      '遭遇したタスクと、取得した能力の記録。',
      'A record of encountered tasks and acquired upgrades.',
    ],
    'encyclopediaResume': [
      '図鑑を閉じるか、再開ボタンを押してください。',
      'Close the encyclopedia or use the Resume button.',
    ],
    'encyclopediaSelect': [
      '図鑑を閉じるか、カードをクリックしてください。',
      'Close the encyclopedia or click an upgrade card.',
    ],
    'encyclopediaPaused': [
      '図鑑を開いている間は一時停止します。',
      'Opening the encyclopedia pauses the run.',
    ],
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
    'concurrency.title': ['並行処理', 'Concurrency'],
    'concurrency.description': [
      '近くの複数のタスクに、同時に攻撃します。',
      'Attacks several nearby tasks at the same time.',
    ],
    'concurrency.tradeoff': [
      '通常攻撃の単発威力 ×0.88 / ランク',
      'Base damage per shot ×0.88 per rank',
    ],
    'oop.title': ['オブジェクト指向', 'Object-Oriented Programming'],
    'oop.description': [
      '周囲を回るオブジェクトが、それぞれ独立して攻撃します。0.9秒ごとに近くのタスクを狙います。',
      'Orbiting objects independently attack nearby tasks every 0.9 seconds.',
    ],
    'oop.tradeoff': ['最大メモリ −5 / ランク', 'Maximum memory −5 per rank'],
    'functional.title': ['関数型プログラミング', 'Functional Programming'],
    'functional.description': [
      '通常攻撃が命中すると、近くの別のタスクへ連鎖。連鎖ごとに威力が70%になります。',
      'Base attacks chain to nearby tasks on hit. Each jump retains 70% of its incoming damage.',
    ],
    'functional.tradeoff': [
      '通常攻撃の索敵範囲 −15 / ランク',
      'Base attack targeting range −15 per rank',
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
      'Expands your memory capacity and restores current memory.',
    ],
    'memory.tradeoff': ['なし', 'None'],
    'clock.title': ['クロックアップ', 'Clock Speed'],
    'clock.description': [
      '移動速度を上げ、タスクを避けやすくします。',
      'Moves your runtime faster to help dodge tasks.',
    ],
    'clock.tradeoff': ['なし', 'None'],
    'cache.title': ['キャッシュ強化', 'Cache Locality'],
    'cache.description': [
      '経験値を遠くから回収でき、攻撃範囲も広がります。',
      'Collects experience from farther away and extends attack range.',
    ],
    'cache.tradeoff': ['なし', 'None'],
    'compiler.title': ['コンパイラ最適化', 'Compiler Optimization'],
    'compiler.description': [
      '通常攻撃1発あたりの威力を上げます。',
      'Increases the damage of every base attack.',
    ],
    'compiler.tradeoff': ['なし', 'None'],
  };
}

/// A displayed stat change, marked explicitly when it is a tradeoff.
class UpgradeComparison {
  const UpgradeComparison(
    this.label,
    this.before,
    this.after, {
    this.cost = false,
  });
  final String label;
  final String? before;
  final String after;
  final bool cost;
  String get values => before == null ? after : '$before → $after';
}
