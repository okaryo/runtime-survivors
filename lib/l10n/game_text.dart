import '../game/run_state.dart';
import '../game/language_profile.dart';

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

  String policyName(TypingPolicy policy) => call('policy.${policy.name}.title');
  String profileTitle(LanguageProfile profile) => profile.language == 'custom'
      ? call('profile.custom')
      : call('profile.affinity', {'language': profile.language});
  String profileDescription(LanguageProfile profile) {
    final policy = profile.policy == null
        ? call('profile.unspecified')
        : policyName(profile.policy!);
    final features = profile.dominantFeatures
        .map((u) => '${title(u)} Lv.${profile.investments[u]}')
        .join(' / ');
    return call('profile.description', {
      'policy': policy,
      'features': features.isEmpty ? call('emptyFeatures') : features,
    });
  }

  String title(Upgrade upgrade) => call('${upgrade.name}.title');
  String description(Upgrade upgrade) => call('${upgrade.name}.description');
  String tradeoff(Upgrade upgrade) => call('${upgrade.name}.tradeoff');
  String matchup(Upgrade upgrade) => call('${upgrade.name}.matchup');
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
    UpgradeComparison value(String label, double oldValue, double newValue) =>
        metric(label, first ? null : number(oldValue), number(newValue));
    UpgradeComparison seconds(
      String label,
      double oldValue,
      double newValue, {
      bool added = true,
    }) => metric(
      label,
      first && added ? null : '${oldValue.toStringAsFixed(2)}s',
      '${newValue.toStringAsFixed(2)}s',
    );
    final List<UpgradeComparison> rows = switch (upgrade) {
      Upgrade.garbageCollection => [
        value('stat.pulseDamage', before.gcDamage, after.gcDamage),
        value('stat.radius', before.gcRadius, after.gcRadius),
        seconds('stat.abilityInterval', before.gcInterval, after.gcInterval),
      ],
      Upgrade.concurrency => [
        metric('stat.targets', before.targetCount, after.targetCount),
      ],
      Upgrade.oop => [
        metric(
          'stat.objects',
          first ? null : before.rank(upgrade),
          after.rank(upgrade),
        ),
        value('stat.objectDamage', before.objectDamage, after.objectDamage),
        seconds(
          'stat.objectInterval',
          before.objectInterval,
          after.objectInterval,
        ),
      ],
      Upgrade.functional => [
        metric(
          'stat.jumps',
          first ? null : before.rank(upgrade),
          after.rank(upgrade),
        ),
      ],
      Upgrade.nullSafety => [
        value('stat.pulseDamage', before.nullDamage, after.nullDamage),
        seconds(
          'stat.abilityInterval',
          before.nullInterval,
          after.nullInterval,
        ),
        seconds(
          'stat.shieldCooldown',
          before.shieldCooldown,
          after.shieldCooldown,
        ),
      ],
      Upgrade.patternMatching => [
        value('stat.patternDamage', before.patternDamage, after.patternDamage),
        value(
          'stat.patternWidth',
          before.patternRadius * 2,
          after.patternRadius * 2,
        ),
        seconds(
          'stat.abilityInterval',
          before.patternInterval,
          after.patternInterval,
        ),
      ],
      Upgrade.pipeline => [],
      Upgrade.bandwidth => [
        metric(
          'stat.projectileSpeed',
          number(before.projectileSpeed),
          number(after.projectileSpeed),
        ),
      ],
      Upgrade.lazyEvaluation => [
        value('stat.trapDamage', before.lazyDamage, after.lazyDamage),
        value('stat.slowRadius', before.slowRadius, after.slowRadius),
        metric(
          'stat.slowAmount',
          first ? null : '${((1 - before.slowMultiplier) * 100).round()}%',
          '${((1 - after.slowMultiplier) * 100).round()}%',
        ),
      ],
      Upgrade.memoization => [
        value('stat.memoDamage', before.memoDamage, after.memoDamage),
        value(
          'stat.cacheDamage',
          before.memoDamage * 1.8,
          after.memoDamage * 1.8,
        ),
      ],
      Upgrade.jitCompilation => [
        metric(
          'stat.jitSpeed',
          first ? null : '×${(1 + before.jitSpeedBonus).toStringAsFixed(2)}',
          '×${(1 + after.jitSpeedBonus).toStringAsFixed(2)}',
        ),
      ],
      Upgrade.ownership => [
        value(
          'stat.pulseDamage',
          before.ownershipDamage,
          after.ownershipDamage,
        ),
        value('stat.healKill', before.ownershipHeal, after.ownershipHeal),
        metric(
          'stat.healCap',
          first ? null : '${number(before.ownershipCap)}/s',
          '${number(after.ownershipCap)}/s',
        ),
      ],
      Upgrade.spatialIndex => [
        if (after.rank(Upgrade.garbageCollection) > 0)
          metric(
            'stat.radius',
            number(before.gcRadius),
            number(after.gcRadius),
          ),
        if (after.rank(Upgrade.lazyEvaluation) > 0)
          metric(
            'stat.slowRadius',
            number(before.slowRadius),
            number(after.slowRadius),
          ),
      ],
      Upgrade.coprocessor => [
        seconds(
          'stat.objectInterval',
          before.objectInterval,
          after.objectInterval,
          added: false,
        ),
      ],
      Upgrade.memoryProtection => [
        seconds(
          'stat.invulnerability',
          before.hitInvulnerability,
          after.hitInvulnerability,
          added: false,
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
          'stat.cooldownScale',
          '${(before.cooldownScale * 100).round()}%',
          '${(after.cooldownScale * 100).round()}%',
        ),
        seconds(
          'stat.interval',
          before.attackInterval,
          after.attackInterval,
          added: false,
        ),
      ],
    };
    return rows
        .where((row) => row.before == null || row.before != row.after)
        .toList();
  }

  String event(RunLog event) => call(event.key, {
    ...event.args,
    if (event.upgrade != null) 'name': title(event.upgrade!),
  });

  static const copy = <String, List<String>>{
    'enemy.9.title': ['Null参照', 'Null reference'],
    'enemy.9.description': [
      '中身のない参照からNull弾を放つ。Null Safetyなら強く処理でき、防壁でNull弾や接触を防げる。',
      'An empty reference firing null shots. Null Safety hits it harder and guards against its shots and contact.',
    ],
    'enemy.10.title': ['重複リクエスト', 'Duplicate request'],
    'enemy.10.description': [
      '同じ入力の要求が対になって現れる。メモ化で一方の結果を保存すると、後続の処理が速くなる。',
      'Arrives in pairs with identical input. Memoization stores one result to accelerate the next.',
    ],
    'stat.abilityInterval': ['発動間隔', 'Attack interval'],
    'stat.trapDamage': ['設置攻撃の威力', 'Trap damage'],
    'stat.memoDamage': ['初回入力の威力', 'New-input damage'],
    'stat.cacheDamage': ['保存済み入力の威力', 'Cached-input damage'],
    'stat.jitSpeed': ['最適化後の通常攻撃速度', 'Optimized base fire rate'],
    'stat.cooldownScale': ['攻撃間隔の倍率', 'Attack interval scale'],
    'jitAnalyzing': ['JIT 解析中 {count}/8', 'JIT analysis {count}/8'],
    'jitReady': ['JIT 最適化済み', 'JIT optimized'],
    'memoStatus': ['保存済み入力：{count}種類', 'Cached inputs: {count}'],
    'policySummary.staticTyping': [
      '事前検査 {count}体・初撃 +{bonus}%',
      'Pre-check {count} tasks · opening hit +{bonus}%',
    ],
    'policySummary.dynamicTyping': [
      '検査済みへの攻撃 +{bonus}%・伝播 {count}体',
      'Checked hits +{bonus}% · spread to {count}',
    ],
    'policyUpgradeTitle': ['型付けを強化', 'Develop your typing policy'],
    'policyUpgradeHint': [
      '追加の設計選択です。この後、通常の能力も選べます。',
      'A bonus design choice. Your regular upgrade follows.',
    ],
    'policyUpgradeControls': ['1 / 2 で選択', '1 / 2 to choose'],
    'policyUpgrade.coverage': ['検査範囲を広げる', 'Expand checks'],
    'policyUpgrade.potency': ['検査の効果を高める', 'Empower checks'],
    'policyUpgrade.coverage.staticTyping': [
      '事前に印を付ける対象数を増やします。',
      'Marks more tasks before they are hit.',
    ],
    'policyUpgrade.coverage.dynamicTyping': [
      '命中時の検査を近くの敵にも伝えます。',
      'Spreads impact checks to nearby tasks.',
    ],
    'policyUpgrade.potency.description': [
      '印の付いた敵へのダメージ加算を高めます。',
      'Increases the damage bonus against marked tasks.',
    ],
    'policyUpgrade.coverage.value': [
      '検査対象 {before} → {after}体',
      'Checked tasks {before} → {after}',
    ],
    'policyUpgrade.spread.value': [
      '伝播先 {before} → {after}体',
      'Spread targets {before} → {after}',
    ],
    'policyUpgrade.potency.value': [
      'ダメージ加算 +{before}% → +{after}%',
      'Damage bonus +{before}% → +{after}%',
    ],
    'log.policy': [
      '型付けの設計をLv.{rank}へ強化',
      'Typing design upgraded to Lv.{rank}',
    ],
    'log.optimized': [
      'JITの解析が完了。通常攻撃を高速化',
      'JIT analysis complete. Rapid fire enabled',
    ],

    'matchup': ['使いどころ', 'Best use'],
    'enemyAffinity': ['相性の良い言語機能', 'Compatible features'],
    'noSpecificAffinity': ['特になし', 'No specific affinity'],
    'armorAffinityNote': [
      'GCは範囲攻撃、OOPは側背面からの命中時に正面防御を回避。',
      'GC area damage and OOP shots from the sides or rear bypass frontal armor.',
    ],
    'garbageCollection.matchup': [
      '密集・正面装甲への範囲攻撃',
      'Crowds; bypasses frontal armor',
    ],
    'concurrency.matchup': ['分散した複数の敵', 'Several spread-out enemies'],
    'oop.matchup': ['側背面からの攻撃', 'Attacks from the sides and rear'],
    'functional.matchup': [
      '召喚雑魚・群れの奥の敵',
      'Summoned crowds; enemies behind them',
    ],
    'nullSafety.matchup': [
      '近距離の群れ・Null参照の処理',
      'Nearby crowds; null references',
    ],
    'patternMatching.matchup': ['密集・群れの奥の敵', 'Crowds; enemies behind them'],
    'lazyEvaluation.matchup': [
      '追跡する群れを設置攻撃へ誘導',
      'Lead pursuing crowds into traps',
    ],
    'memoization.matchup': [
      '同じ入力のタスクが繰り返す場面',
      'Repeated tasks with the same input',
    ],
    'jitCompilation.matchup': ['攻撃を続ける長い戦闘', 'Sustained combat'],
    'ownership.matchup': [
      '近距離で攻撃しながらメモリ回収',
      'Close-range attacks with memory recovery',
    ],
    'memory.matchup': ['生存力の確保とメモリ回復', 'Survivability and memory recovery'],
    'clock.matchup': ['射線・爆発からの回避', 'Dodge shot lanes and blasts'],
    'cache.matchup': ['散った経験値の回収', 'Collect scattered experience'],
    'compiler.matchup': [
      '通常攻撃とFeatureの攻撃頻度',
      'Base and feature attack frequency',
    ],
    'pipeline.matchup': ['並行処理・連鎖の起点', 'More concurrent volleys and chains'],
    'bandwidth.matchup': ['動く敵に弾を届かせる', 'Deliver shots to moving enemies'],
    'spatialIndex.matchup': ['GC・遅延評価の範囲', 'GC and Lazy Evaluation areas'],
    'coprocessor.matchup': ['OOPの独立攻撃', 'Independent OOP attacks'],
    'memoryProtection.matchup': [
      '連続被弾からの立て直し',
      'Recover from consecutive hits',
    ],
    'lazyEvaluation.title': ['遅延評価', 'Lazy Evaluation'],
    'lazyEvaluation.description': [
      '必要になるまで処理を待機。設置した領域に敵が近づくと範囲攻撃が起動し、その後しばらく敵を減速します。',
      'Defers work until needed. A placed trap bursts when tasks approach, then briefly slows survivors.',
    ],
    'lazyEvaluation.tradeoff': [
      '設置位置は動かず、敵が近づかなければ起動しない。',
      'Traps stay in place and need nearby tasks to trigger.',
    ],
    'memoization.title': ['メモ化', 'Memoization'],
    'memoization.description': [
      'タスクを処理して結果を保存。同じ入力のタスクには、結果を再利用する強力な高速弾を発射します。',
      'Stores completed results. Fires stronger, faster cache shots at tasks with the same input.',
    ],
    'memoization.tradeoff': [
      '初めての入力にも通常の処理弾を撃つ。入力の印が同じなら結果を再利用。',
      'New inputs still receive normal shots. Matching input marks reuse the result.',
    ],
    'jitCompilation.title': ['JITコンパイル', 'JIT Compilation'],
    'jitCompilation.description': [
      '通常攻撃の実行で解析が進み、完了すると連射が高速化。対象が変わっても最適化は維持されます。',
      'Base volleys advance analysis, then unlock rapid fire. Optimization persists across target changes.',
    ],
    'jitCompilation.tradeoff': [
      '取得直後は解析中。最適化後はラン終了まで有効。',
      'Needs a warm-up. Once optimized, stays active for the rest of the run.',
    ],
    'ownership.title': ['所有権', 'Ownership'],
    'ownership.description': [
      '近くのタスクを攻撃し、処理完了とともにメモリを回収。近距離の撃破でメモリが回復します。',
      'Attacks nearby tasks and reclaims memory as their work ends. Nearby kills restore memory.',
    ],
    'ownership.tradeoff': [
      '回復には時間あたりの上限があり、召喚雑魚からは回復しない。',
      'Healing is rate-limited; summoned tasks grant no healing.',
    ],
    'spatialIndex.title': ['空間インデックス', 'Spatial Index'],
    'spatialIndex.description': [
      'GCと、新しく設置する遅延評価の攻撃範囲を広げます。',
      'Expands GC pulses and newly placed Lazy Evaluation traps.',
    ],
    'spatialIndex.tradeoff': [
      'GCまたは遅延評価の取得後に出現。',
      'Offered after GC or Lazy Evaluation.',
    ],
    'coprocessor.title': ['補助プロセッサ', 'Coprocessor'],
    'coprocessor.description': [
      'OOPのオブジェクトが攻撃する間隔を短縮します。',
      'Reduces the attack interval of OOP objects.',
    ],
    'coprocessor.tradeoff': ['なし。OOPの取得後に出現。', 'None. Offered after OOP.'],
    'memoryProtection.title': ['メモリ保護', 'Memory Protection'],
    'memoryProtection.description': [
      '被弾後の無敵時間を延ばし、連続被弾から守ります。',
      'Extends invulnerability after a hit, protecting against repeated damage.',
    ],
    'memoryProtection.tradeoff': [
      'なし。被弾そのものは防がない。',
      'None. Does not prevent the initial hit.',
    ],
    'stat.slowRadius': ['設置攻撃の半径', 'Trap radius'],
    'stat.slowAmount': ['移動の減速', 'Movement slow'],
    'stat.healKill': ['撃破時の回復', 'Healing per kill'],
    'stat.healCap': ['回復の上限', 'Healing budget'],
    'stat.objectInterval': ['オブジェクトの間隔', 'Object interval'],
    'stat.invulnerability': ['被弾後の無敵', 'Hit invulnerability'],
    'enemy.6.title': ['Buffer Overflow', 'Buffer Overflow'],
    'enemy.6.type': ['撃破後爆発タスク', 'Death-blast task'],
    'enemy.6.description': [
      '処理後、その場所の赤い円が爆発する。倒したら円の外へ離れよう。',
      'Leaves a marked blast after processing. Move outside the red circle.',
    ],
    'enemy.7.title': ['Scheduler', 'Scheduler'],
    'enemy.7.type': ['支援タスク', 'Support task'],
    'enemy.7.description': [
      '周囲のタスクの移動と攻撃を加速。本体を処理すると支援が消える。貫通や連鎖で奥を狙おう。',
      'Speeds up nearby tasks and attacks. Defeat it to remove support; piercing and chains reach past the crowd.',
    ],
    'enemy.8.title': ['装甲メモリ確保', 'Armored Allocation'],
    'enemy.8.type': ['正面防御タスク', 'Directional armor task'],
    'enemy.8.description': [
      '正面からの弾を軽減。側面・背面からの弾や範囲攻撃は防御を回避する。',
      'Resists frontal shots. Flanking shots and area attacks bypass its armor.',
    ],
    'enemy.4.title': ['RPC要求', 'RPC request'],
    'enemy.4.type': ['射撃タスク', 'Ranged task'],
    'enemy.4.description': [
      '発射前に光り、固定方向へ弾を撃つ。弾を横へ避けながら近づこう。',
      'Flashes before firing a fixed-direction shot. Sidestep the projectile, then approach.',
    ],
    'enemy.5.title': ['Fork Bomb', 'Fork Bomb'],
    'enemy.5.type': ['召喚タスク', 'Summoner task'],
    'enemy.5.description': [
      '小型タスクを繰り返し召喚。本体を処理すると追加召喚が止まる。密集した小型タスクはまとめて処理しよう。',
      'Repeatedly spawns small tasks. Process the parent to stop spawning; clear the children together.',
    ],
    'nullSafety.title': ['Null Safety', 'Null Safety'],
    'nullSafety.description': [
      '防壁から周囲へ攻撃。Null参照を強く処理し、Null弾を消去。再充填する防壁がNull由来の被弾を防ぎます。',
      'A barrier attacks nearby tasks, hits null references harder and clears null shots. Its recharging guard blocks null hits.',
    ],
    'nullSafety.tradeoff': [
      '通常弾・通常タスクの接触・爆発は防げない。',
      'Does not block ordinary shots, ordinary contact or explosions.',
    ],
    'patternMatching.title': ['ベクトル化', 'Vectorization'],
    'patternMatching.description': [
      '複数データを一列にまとめて処理する直線貫通弾。群れを抜いて奥のタスクまで届きます。',
      'Processes a row of data with a piercing shot, reaching tasks behind the crowd.',
    ],
    'patternMatching.tradeoff': [
      '発射後の追尾なし。列を揃えると複数に命中。',
      'Fixed trajectory. Line tasks up to hit several at once.',
    ],
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
    'bandwidth.tradeoff': ['なし', 'None'],
    'stat.shieldCooldown': ['防壁の再充填', 'Shield recharge'],
    'stat.patternDamage': ['貫通攻撃の威力', 'Piercing damage'],
    'stat.patternWidth': ['貫通弾の幅', 'Shot width'],
    'stat.projectileSpeed': ['弾速', 'Projectile speed'],
    'emptyUpgradeSlot': ['未実装', 'Unimplemented'],
    'emptyInfraSlot': ['未拡張', 'Not expanded'],
    'hudMemory': ['メモリ', 'Memory'],
    'remainingTime': ['残り時間', 'Time left'],
    'rushIn': ['ラッシュまで {time}', 'Rush in {time}'],
    'processedTasks': ['処理済 {count}', 'Processed {count}'],
    'log.maintenance': [
      '全能力の強化が完了。メモリを35回復。',
      'Build fully upgraded. Restored 35 memory.',
    ],
    'shieldReady': ['防壁：準備完了', 'Shield: ready'],
    'shieldCharging': ['防壁：{seconds}秒', 'Shield: {seconds}s'],
    'policyTitle': ['型付けの設計方針', 'Typing policy'],
    'policy.staticTyping.title': ['Static Typing', 'Static Typing'],
    'policy.dynamicTyping.title': ['Dynamic Typing', 'Dynamic Typing'],
    'policy.staticTyping.description': [
      '事前検査で周囲の敵に金色の印を付け、印のある敵への初撃を強化します。',
      'Pre-checks nearby tasks with gold marks, empowering the first hit on each marked task.',
    ],
    'policy.staticTyping.cost': [
      '初撃に強い設計。途中の設計強化で検査対象数か効果を伸ばせます。',
      'Strong opening hits. Later design upgrades improve coverage or power.',
    ],
    'policy.dynamicTyping.description': [
      '命中時に敵を検査して青い印を付け、その敵への後続の攻撃を強化します。',
      'Checks tasks on impact with blue marks, empowering subsequent hits on them.',
    ],
    'policy.dynamicTyping.cost': [
      '継続処理に強い設計。途中の設計強化で検査の伝播か効果を伸ばせます。',
      'Strong repeated hits. Later design upgrades improve propagation or power.',
    ],
    'policyKeys': [
      '1 / 2 で方針選択 · Enter で起動',
      '1 / 2 selects a policy · Enter starts the run',
    ],
    'policyCurrent': ['設計方針', 'Typing policy'],
    'resultBuild': ['取得した能力', 'Your build'],
    'profile.label': ['今回の言語プロフィール', 'Your language profile'],
    'profile.custom': ['独自設計の言語', 'An original language'],
    'profile.affinity': ['{language}寄りの言語', 'A {language}-leaning language'],
    'profile.unspecified': ['型付け未選択', 'No typing policy selected'],
    'profile.description': [
      '{policy}を採用。主に伸ばした機能：{features}。',
      '{policy}. Main investments: {features}.',
    ],
    'newUpgrade': ['New', 'New'],
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
    'choosing': ['設計を選択中', 'Choosing'],
    'terminated': ['終了', 'Terminated'],
    'controls': [
      'WASD / HJKL / 矢印キー：移動　 ESC / P：一時停止',
      'WASD / HJKL / Arrows: move   ESC / P: pause',
    ],
    'design': ['言語の設計', 'Language design'],
    'feature': ['言語機能 / FEATURE', 'LANGUAGE FEATURE'],
    'infra': ['基盤強化 / INFRA', 'INFRASTRUCTURE'],
    'emptyFeatures': ['機能はまだありません', 'No features yet'],
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
    'tradeoff': ['性質・制約', 'Notes'],
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
    'restart': ['次の言語を設計', 'Design another language'],
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
      '遭遇したタスクと、取得した能力の記録。読むときは Esc / P で一時停止。',
      'A record of encountered tasks and acquired upgrades. Press Esc / P to pause while reading.',
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
    'you': ['YOU', 'YOU'],
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
      '周囲をまとめて掃除する範囲攻撃。密集したタスクを一度に処理します。',
      'Sweeps the surrounding area, processing crowded tasks together.',
    ],
    'garbageCollection.tradeoff': [
      '攻撃の合間があるため、近づくタイミングが重要。',
      'Pulses have downtime; time your approach.',
    ],
    'concurrency.title': ['並行処理', 'Concurrency'],
    'concurrency.description': [
      '近くの複数のタスクに、同時に攻撃します。',
      'Attacks several nearby tasks at the same time.',
    ],
    'concurrency.tradeoff': [
      '単体への攻撃数は増えない。',
      'Does not add shots against a single target.',
    ],
    'oop.title': ['オブジェクト指向', 'Object-Oriented Programming'],
    'oop.description': [
      'オブジェクトに処理を委譲。周囲を回るオブジェクトが、それぞれ近くのタスクを攻撃します。',
      'Delegates work to orbiting objects, each attacking nearby tasks independently.',
    ],
    'oop.tradeoff': ['各オブジェクトが独立して対象を選ぶ。', 'Objects choose their own targets.'],
    'functional.title': ['関数型プログラミング', 'Functional Programming'],
    'functional.description': [
      '処理を次の処理へつなぐ連鎖攻撃。命中した通常弾が近くの別のタスクへ移ります。',
      'Composes work into a chain. Base shots jump from a hit task to another nearby task.',
    ],
    'functional.tradeoff': [
      '連鎖するたびに威力が下がる。同じ連鎖は同じ敵を再処理しない。',
      'Damage fades with each jump. A chain never revisits the same task.',
    ],
    'enemy.0.type': ['通常タスク', 'Standard task'],
    'enemy.1.type': ['高速タスク', 'Fast task'],
    'enemy.2.type': ['高耐久タスク', 'Heavy task'],
    'enemy.3.type': ['エリートタスク', 'Elite task'],
    'enemy.0.title': ['リクエスト', 'Request'],
    'enemy.0.description': [
      '基本の処理要求。ゆっくり追いかけてくる。',
      'A basic request that steadily follows you.',
    ],
    'enemy.1.title': ['割り込み', 'Interrupt'],
    'enemy.1.description': [
      '小さくすばしっこい処理要求。集団で近づいてくる。',
      'A small, quick task that closes in as a crowd.',
    ],
    'enemy.2.title': ['メモリ確保', 'Allocation'],
    'enemy.2.description': [
      '大きく頑丈なタスク。移動は遅いが処理に時間がかかる。',
      'A bulky, slow task that takes longer to process.',
    ],
    'enemy.3.title': ['デッドロック', 'Deadlock'],
    'enemy.3.description': [
      '方向を予告してから突進するエリート。予告が出たら横へ避けよう。',
      'An elite that marks its direction before charging. Dodge sideways when it winds up.',
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
      '処理を最適化し、通常攻撃とFeatureの攻撃間隔を短縮します。',
      'Optimizes execution, shortening base and feature attack intervals.',
    ],
    'compiler.tradeoff': [
      '防壁の再充填と被弾後の無敵時間は対象外。',
      'Does not change shield recharge or hit invulnerability.',
    ],
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
