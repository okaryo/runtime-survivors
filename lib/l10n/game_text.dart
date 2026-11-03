import '../game/ability_runtime.dart';
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

  String profileTitle(LanguageProfile profile) => profile.language == 'custom'
      ? call('profile.custom')
      : call('profile.affinity', {'language': profile.language});
  String profileDescription(LanguageProfile profile) {
    final features = profile.dominantFeatures
        .map((u) => '${title(u)} Lv.${profile.investments[u]}')
        .join(' / ');
    return call('profile.description', {
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
        metric(
          'stat.gcPause',
          first ? null : '${before.gcPause.toStringAsFixed(2)}s',
          '${after.gcPause.toStringAsFixed(2)}s',
          cost: true,
        ),
      ],
      Upgrade.concurrency => [
        metric('stat.targets', before.targetCount, after.targetCount),
        metric(
          'stat.damage',
          number(before.attackDamage),
          number(after.attackDamage),
          cost: true,
        ),
      ],
      Upgrade.oop => [
        metric(
          'stat.objects',
          first ? null : before.rank(upgrade),
          after.rank(upgrade),
        ),
        value('stat.objectDamage', before.objectDamage, after.objectDamage),
        hp(cost: true),
      ],
      Upgrade.functional => [
        metric(
          'stat.jumps',
          first ? null : before.rank(upgrade),
          after.rank(upgrade),
        ),
        metric(
          'stat.chainRetention',
          first ? null : '${(before.chainRetention * 100).round()}%',
          '${(after.chainRetention * 100).round()}%',
        ),
        metric(
          'stat.interval',
          '${before.attackInterval.toStringAsFixed(2)}s',
          '${after.attackInterval.toStringAsFixed(2)}s',
          cost: true,
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
        hp(cost: true),
      ],
      Upgrade.jitCompilation => [
        metric(
          'stat.jitSpeed',
          first ? null : '×${(1 + before.jitSpeedBonus).toStringAsFixed(2)}',
          '×${(1 + after.jitSpeedBonus).toStringAsFixed(2)}',
        ),
        metric(
          'stat.jitDecay',
          first ? null : '${AbilityRuntime.jitDecay.round()}/s',
          '${AbilityRuntime.jitDecay.round()}/s',
          cost: true,
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
      Upgrade.asyncStream => [
        value('stat.streamDamage', before.streamDamage, after.streamDamage),
        seconds(
          'stat.streamInterval',
          before.streamInterval,
          after.streamInterval,
        ),
        metric(
          'stat.streamPreparation',
          first ? null : '${before.streamPreparation.toStringAsFixed(2)}s',
          '${after.streamPreparation.toStringAsFixed(2)}s',
          cost: first,
        ),
      ],
      Upgrade.spatialIndex => [
        metric(
          'stat.range',
          number(before.attackRange),
          number(after.attackRange),
        ),
        metric(
          'stat.areaScale',
          '${(before.areaScale * 100).round()}%',
          '${(after.areaScale * 100).round()}%',
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
    if (event.key == 'log.rush') 'theme': call('rush.${event.args['theme']}'),
    if (event.upgrade != null) 'name': title(event.upgrade!),
  });

  static const copy = <String, List<String>>{
    'stat.streamDamage': ['継続処理の威力', 'Stream tick damage'],
    'stat.streamInterval': ['継続処理の間隔', 'Stream tick interval'],
    'stat.streamPreparation': ['接続の準備時間', 'Connection setup'],
    'asyncStream.title': ['非同期ストリーム', 'Async Stream'],
    'asyncStream.description': [
      'タスクへ接続し、データ片を流して継続攻撃。移動しながら同じ対象を処理し続けます。',
      'Connects to one task and streams continuous attacks while you move.',
    ],
    'asyncStream.tradeoff': [
      '接続ごとに準備が必要。対象の撃破や射程外への移動で接続が切れるため、頻繁な切り替えは苦手。',
      'Every connection needs setup. Defeated or out-of-range targets break it, making frequent switches costly.',
    ],
    'asyncStream.matchup': [
      '頑丈な単体・距離を保つ戦闘',
      'Durable targets and mobile ranged combat',
    ],
    'enemy.13.title': ['メモリリーク', 'Memory Leak'],
    'enemy.13.description': [
      '解放されないメモリが四角い領域として残り、内側にいる間メモリを消費。発生源を処理すると領域は無害になり、早く消えます。',
      'Leaves blocky allocations that drain memory while you stand inside. Processing the source disarms its patches and clears them sooner.',
    ],
    'enemy.14.title': ['タイマーイベント', 'Timer Event'],
    'enemy.14.description': [
      '目盛りが満ちると、二つの隙間を持つ輪状パルスを放つ。隙間の向きは発射ごとに変わる。',
      'Releases a pulse with two gaps when its clock fills. Openings change with each cast.',
    ],
    'stat.chainRetention': ['連鎖時の威力維持', 'Damage retained per jump'],
    'stat.jitDecay': ['ゲージの時間減少', 'Gauge decay'],
    'jitGauge': [
      'JIT {charge}% · 連射 ×{rate}',
      'JIT {charge}% · Fire rate ×{rate}',
    ],
    'pressure': ['高負荷', 'High load'],
    'overload': ['過負荷', 'Overload'],
    'log.pressure': [
      '残り1分。処理要求が急増しています。',
      'One minute left. Workload is accelerating.',
    ],
    'log.overload': [
      '残り30秒。ランタイム過負荷！',
      'Thirty seconds left. Runtime overload!',
    ],
    'rush.interrupts': ['割り込み集中', 'Interrupt storm'],
    'rush.memory': ['メモリ・RPC集中', 'Memory / RPC rush'],
    'rush.forks': ['コピー増殖', 'Fork cascade'],
    'rush.leaks': ['リーク多発', 'Leak spill'],
    'rush.timers': ['イベント集中', 'Event storm'],
    'rush.overload': ['複合過負荷', 'Mixed overload'],
    'bossLockedShort': ['ロックを処理', 'Break a lock'],
    'bossExposedShort': ['本体を処理', 'Core exposed'],
    'enemy.11.title': ['バッチ処理', 'Batch job'],
    'enemy.11.description': [
      '同じ処理を行うデータが隊列を組んで進む。列を揃えて貫通するか、まとめて範囲攻撃。同じ入力の再来にはメモ化も有効。',
      'Data for the same operation advances in a formation. Line up piercing shots or clear the batch with area attacks; repeated inputs also suit memoization.',
    ],
    'bossLocked': ['デッドロック · ロックを処理して解除', 'Deadlock · break a lock to release'],
    'bossExposed': [
      'デッドロック · 循環解除、処理のチャンス',
      'Deadlock · cycle released, core exposed',
    ],
    'log.deadlock': [
      'デッドロックが発生。ロックを処理して進路を開こう。',
      'Deadlock detected. Break a lock to open the route.',
    ],

    'stat.gcPause': ['回収時の通常攻撃待機', 'Base pause on collection'],
    'stat.areaScale': ['攻撃範囲の倍率', 'Attack area scale'],
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
    'stat.jitSpeed': ['最大時の通常攻撃速度', 'Base fire rate at full gauge'],
    'stat.cooldownScale': ['攻撃間隔の倍率', 'Attack interval scale'],
    'memoStatus': ['保存済み入力：{count}種類', 'Cached inputs: {count}'],

    'matchup': ['使いどころ', 'Best use'],
    'enemyAffinity': ['相性の良い言語機能', 'Compatible features'],
    'noSpecificAffinity': ['特になし', 'No specific affinity'],
    'armorAffinityNote': [
      'GCは範囲攻撃、OOPは側背面からの命中時に正面防御を回避。',
      'GC area damage and OOP shots from the sides or rear bypass frontal armor.',
    ],
    'garbageCollection.matchup': [
      '密集・バッチ・増えたコピー',
      'Crowds, batches and forked copies',
    ],
    'concurrency.matchup': ['分散した複数の敵', 'Several spread-out enemies'],
    'oop.matchup': ['分散したタスク・ロックノード', 'Spread-out tasks and lock nodes'],
    'functional.matchup': ['コピーの群れ・近接したタスク', 'Forked crowds and nearby tasks'],
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
    'jitCompilation.matchup': [
      '撃破を続けられる群れ・ラッシュ',
      'Crowds and rushes with frequent kills',
    ],
    'ownership.matchup': [
      '近距離で攻撃しながらメモリ回収',
      'Close-range attacks with memory recovery',
    ],
    'memory.matchup': ['生存力の確保とメモリ回復', 'Survivability and memory recovery'],
    'clock.matchup': ['弾・障壁からの回避', 'Dodge projectiles and barriers'],
    'cache.matchup': ['散った経験値の回収', 'Collect scattered experience'],
    'compiler.matchup': [
      '通常攻撃とFeatureの攻撃頻度',
      'Base and feature attack frequency',
    ],
    'pipeline.matchup': ['並行処理・連鎖の起点', 'More concurrent volleys and chains'],
    'bandwidth.matchup': ['動く敵に弾を届かせる', 'Deliver shots to moving enemies'],
    'spatialIndex.matchup': ['射程と複数の攻撃範囲', 'Targeting range and attack areas'],
    'coprocessor.matchup': ['OOPの独立攻撃', 'Independent OOP attacks'],
    'memoryProtection.matchup': [
      '連続被弾からの立て直し',
      'Recover from consecutive hits',
    ],
    'lazyEvaluation.title': ['遅延評価', 'Lazy Evaluation'],
    'lazyEvaluation.description': [
      '足元で処理を待機。敵が近づくと強力な範囲攻撃が起動し、残った敵を減速します。',
      'Waits at your position, then unleashes a powerful area burst when tasks approach, slowing survivors.',
    ],
    'lazyEvaluation.tradeoff': [
      '設置位置は動かず、敵が近づかなければ起動しない。',
      'Traps stay in place and need nearby tasks to trigger.',
    ],
    'memoization.title': ['メモ化', 'Memoization'],
    'memoization.description': [
      '計算結果を保存し、同じ入力を強力な高速弾で処理。保存できないタスクにも通常の処理弾を撃ちます。',
      'Caches completed calculations. Matching inputs get stronger, faster shots; other tasks get normal shots.',
    ],
    'memoization.tradeoff': [
      '結果の保存領域として、使える最大メモリの一部を予約。',
      'Reserves part of maximum memory for cached results.',
    ],
    'jitCompilation.title': ['JITコンパイル', 'JIT Compilation'],
    'jitCompilation.description': [
      '撃破で最適化ゲージを蓄積。残量が多いほど通常攻撃が速くなります。',
      'Kills build optimization. A fuller gauge makes base attacks fire faster.',
    ],
    'jitCompilation.tradeoff': [
      'ゲージは時間とともに減少。攻撃を続けていても、撃破できなければ高速化が弱まる。',
      'The gauge drains over time. Firing alone cannot sustain it; keep processing tasks.',
    ],
    'ownership.title': ['所有権', 'Ownership'],
    'ownership.description': [
      '近距離のタスクを強く処理。近くでの撃破時にメモリを回収します。',
      'Hits nearby tasks hard and reclaims memory from nearby kills.',
    ],
    'ownership.tradeoff': [
      '近づいて戦う必要がある。回復に上限があり、コピーやロックノードは回復対象外。',
      'Requires close combat. Healing is capped; copies and lock nodes grant none.',
    ],
    'spatialIndex.title': ['広域化', 'Spatial Expansion'],
    'spatialIndex.description': [
      '通常攻撃の射程、範囲攻撃、設置攻撃、連鎖距離や貫通弾の幅を広げます。',
      'Expands targeting range, area attacks, traps, chain reach and piercing width.',
    ],
    'spatialIndex.tradeoff': ['なし', 'None'],
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
    'enemy.4.title': ['タイムアウトRPC', 'Timeout RPC'],
    'enemy.4.type': ['射撃タスク', 'Ranged task'],
    'enemy.4.description': [
      '送信後に応答を待ち、未処理なら間隔を置いて再送。再送するたびに弾が増える。発光の後に撃つため、待機中に近づこう。',
      'Sends a request, waits, then retries if unprocessed. Retries add projectiles. Approach during the wait between volleys.',
    ],
    'enemy.5.title': ['Fork Bomb', 'Fork Bomb'],
    'enemy.5.type': ['召喚タスク', 'Summoner task'],
    'enemy.5.description': [
      '自分の小さなコピーを段階的に増やす。親を処理すると、子からの追加生成も止まる。増えたコピーは範囲攻撃や連鎖でまとめて処理。',
      'Creates smaller copies in stages. Processing the parent stops all further copying; area attacks and chains clear the children.',
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
    'resultBuild': ['取得した能力', 'Your build'],
    'profile.label': ['今回の言語プロフィール', 'Your language profile'],
    'profile.custom': ['独自設計の言語', 'An original language'],
    'profile.affinity': ['{language}寄りの言語', 'A {language}-leaning language'],
    'profile.description': [
      '主に伸ばした機能：{features}。',
      'Main investments: {features}.',
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
    'log.rush': ['{theme}が発生！', '{theme} incoming!'],
    'garbageCollection.title': ['ガベージコレクション', 'Garbage Collection'],
    'garbageCollection.description': [
      '周囲をまとめて掃除する範囲攻撃。密集したタスクを一度に処理します。',
      'Sweeps the surrounding area, processing crowded tasks together.',
    ],
    'garbageCollection.tradeoff': [
      '回収の瞬間、通常攻撃が短く待機。移動や他のFeatureは止まらない。',
      'Collection briefly pauses base attacks. Movement and other features continue.',
    ],
    'concurrency.title': ['並行処理', 'Concurrency'],
    'concurrency.description': [
      '近くの複数のタスクに、同時に攻撃します。',
      'Attacks several nearby tasks at the same time.',
    ],
    'concurrency.tradeoff': [
      '処理を分散するため、通常弾の単発威力が下がる。',
      'Spreading work reduces damage per base shot.',
    ],
    'oop.title': ['オブジェクト指向', 'Object-Oriented Programming'],
    'oop.description': [
      'オブジェクトへ処理を委譲。周囲を回るオブジェクトが、それぞれ強力な独立攻撃を行います。',
      'Delegates work to orbiting objects, each firing strong independent attacks.',
    ],
    'oop.tradeoff': [
      'オブジェクトを保持するため、使える最大メモリの一部を予約。',
      'Reserves part of maximum memory to keep objects alive.',
    ],
    'functional.title': ['関数型プログラミング', 'Functional Programming'],
    'functional.description': [
      '準備した合成処理で、通常弾が次々と近くの別タスクへ連鎖します。',
      'Composes a prepared attack that chains through nearby tasks.',
    ],
    'functional.tradeoff': [
      '合成の準備で通常攻撃の間隔が長くなる。連鎖するたびに威力も減衰。',
      'Composition slows base fire. Each chain jump also loses damage.',
    ],
    'enemy.0.type': ['通常タスク', 'Standard task'],
    'enemy.1.type': ['高速タスク', 'Fast task'],
    'enemy.2.type': ['高耐久タスク', 'Heavy task'],
    'enemy.0.title': ['リクエスト', 'Request'],
    'enemy.0.description': [
      '基本の計算要求。同じ入力が繰り返し届くので、メモ化した結果を再利用できる。',
      'A basic computation request. Repeated inputs allow memoized results to be reused.',
    ],
    'enemy.1.title': ['割り込み', 'Interrupt'],
    'enemy.1.description': [
      '小さくすばしっこい処理要求。集団で近づいてくる。',
      'A small, quick task that closes in as a crowd.',
    ],
    'enemy.2.title': ['メモリ確保', 'Allocation'],
    'enemy.2.description': [
      '大きなメモリ領域を要求する、頑丈で遅いタスク。周囲を先に処理するか、継続攻撃で要求を完了しよう。',
      'A large memory request: sturdy and slow. Clear nearby tasks first, or sustain fire to complete the allocation.',
    ],
    'enemy.3.title': ['デッドロック', 'Deadlock'],
    'enemy.3.description': [
      '本体の前に頑丈なロックと障壁を展開。どれかのロックを処理して循環を解くと、短時間だけ本体を攻撃しやすくなる。',
      'Deploys durable locks and barriers in front of its core. Break a lock to release the cycle and briefly expose the core.',
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
