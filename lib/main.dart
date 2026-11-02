import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/run_state.dart';
import 'game/runtime_game.dart';

const ink = Color(0xFF263D37);
const muted = Color(0xFF7B8479);
const paper = Color(0xFFF4F3EB);
const line = Color(0xFFDDDFD3);
const orange = Color(0xFFDC653D);

void main() => runApp(const RuntimeSurvivorsApp());

class RuntimeSurvivorsApp extends StatelessWidget {
  const RuntimeSurvivorsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Runtime Survivors',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ink,
        primary: ink,
        surface: paper,
      ),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
      ),
    ),
    home: const RuntimeScreen(),
  );
}

class RuntimeScreen extends StatefulWidget {
  const RuntimeScreen({super.key});
  @override
  State<RuntimeScreen> createState() => _RuntimeScreenState();
}

class _RuntimeScreenState extends State<RuntimeScreen> {
  late final RunState run = RunState();
  late final RuntimeGame game = RuntimeGame(run);
  final focus = FocusNode();
  late final AppLifecycleListener lifecycle;

  @override
  void initState() {
    super.initState();
    lifecycle = AppLifecycleListener(onInactive: pause, onHide: pause);
  }

  void pause() {
    run.pause();
    game.refresh();
  }

  void start() {
    run.start();
    game.refresh();
    focus.requestFocus();
  }

  void resume() {
    run.resume();
    game.refresh();
    focus.requestFocus();
  }

  void choose(Upgrade upgrade) {
    run.choose(upgrade);
    game.refresh();
    focus.requestFocus();
  }

  @override
  void dispose() {
    lifecycle.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ValueListenableBuilder<int>(
      valueListenable: game.revision,
      builder: (context, _, _) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1050;
          final compact = constraints.maxWidth < 700;
          final arenaHeight = max(
            480.0,
            min(740.0, constraints.maxHeight - 280),
          );
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 36,
              24,
              compact ? 16 : 36,
              18,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(compact),
                    const SizedBox(height: 24),
                    _stats(compact),
                    const SizedBox(height: 20),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _arena(arenaHeight)),
                          const SizedBox(width: 20),
                          SizedBox(width: 278, child: _designPanel()),
                        ],
                      )
                    else ...[
                      _arena(arenaHeight),
                      const SizedBox(height: 16),
                      _designPanel(),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      runSpacing: 10,
                      spacing: 20,
                      children: [
                        const Text(
                          'W A S D / ↑ ↓ ← →  移動     ESC / P  一時停止',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                        Text(
                          'FLUTTER + FLAME  /  PROTOTYPE 0.1',
                          style: TextStyle(
                            fontSize: 10,
                            color: muted.withValues(alpha: 0.8),
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _header(bool compact) => Row(
    children: [
      Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: orange,
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Text(
          '>_',
          style: TextStyle(
            color: paper,
            fontSize: 23,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Runtime Survivors',
              style: TextStyle(
                fontSize: compact ? 20 : 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'SURVIVE THE TASKS. DESIGN YOUR LANGUAGE.',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                letterSpacing: 1.4,
                color: muted,
              ),
            ),
          ],
        ),
      ),
      if (!compact) ...[
        _badge('WEB BUILD', color: muted),
        const SizedBox(width: 20),
      ],
      IconButton(
        tooltip: '遊び方',
        onPressed: _help,
        icon: const Icon(Icons.help_outline, size: 21),
      ),
    ],
  );

  Widget _stats(bool compact) {
    final cards = [
      _stat(
        'MEMORY',
        '${run.health.ceil()}',
        '/ ${run.maxHealth.toInt()} MB',
        Icons.memory,
        progress: run.health / run.maxHealth,
        color: orange,
      ),
      _stat(
        'UPTIME',
        run.timeLabel,
        '/ 05:00',
        Icons.timer_outlined,
        progress: run.elapsed / RunState.duration,
        color: ink,
      ),
      _stat('TASKS PROCESSED', '${run.kills}', 'completed', Icons.done_all),
      _stat(
        'LANGUAGE LEVEL',
        run.level.toString().padLeft(2, '0'),
        '${run.xp} / ${run.nextLevelXp} XP',
        Icons.auto_awesome_outlined,
        progress: run.xp / run.nextLevelXp,
        color: const Color(0xFF729679),
      ),
    ];
    if (compact) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 10),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 10),
              Expanded(child: cards[3]),
            ],
          ),
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i != 0) const SizedBox(width: 14),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }

  Widget _stat(
    String label,
    String value,
    String suffix,
    IconData icon, {
    double? progress,
    Color color = ink,
  }) => Container(
    height: 97,
    padding: const EdgeInsets.fromLTRB(17, 13, 17, 12),
    decoration: BoxDecoration(
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(6),
      color: const Color(0xFFFAFAF5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: muted),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: muted,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 27,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  suffix,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: muted,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (progress != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 3,
              color: color,
              backgroundColor: line,
            ),
          ),
      ],
    ),
  );

  Widget _arena(double height) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(7),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Container(
          height: 45,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: const Color(0xFFECEEE5),
          child: Row(
            children: [
              const Icon(Icons.terminal, size: 17, color: muted),
              const SizedBox(width: 8),
              const Text(
                'runtime://local',
                style: TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
              const Spacer(),
              _badge(
                run.phase == RunPhase.running
                    ? '● RUNNING'
                    : switch (run.phase) {
                        RunPhase.ready => '○ STANDBY',
                        RunPhase.choosing => '◇ COMPILING',
                        RunPhase.paused => 'Ⅱ PAUSED',
                        _ => '■ TERMINATED',
                      },
                color: run.phase == RunPhase.running
                    ? const Color(0xFF4E8967)
                    : muted,
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 17,
                  tooltip: run.phase == RunPhase.paused ? '再開' : '一時停止',
                  onPressed: run.phase == RunPhase.running
                      ? pause
                      : run.phase == RunPhase.paused
                      ? resume
                      : null,
                  icon: Icon(
                    run.phase == RunPhase.paused
                        ? Icons.play_arrow
                        : Icons.pause,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRect(
                  child: GameWidget(game: game, focusNode: focus),
                ),
              ),
              if (run.phase != RunPhase.running)
                Positioned.fill(child: _overlay()),
              if (run.phase == RunPhase.running && run.elapsed < 7)
                Positioned(
                  left: 16,
                  right: 16,
                  top: 52,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF243B37),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '移動して回避。攻撃は自動。◆ を拾って成長。',
                          style: TextStyle(
                            fontSize: 11,
                            color: RuntimeGame.mint,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _designPanel() {
    final acquired = run.upgrades.entries.toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFECEEE5),
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.account_tree_outlined, size: 16),
              SizedBox(width: 8),
              Text(
                'LANGUAGE DESIGN',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'ひとつの選択が、言語を変える。',
            style: TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 22),
          _label('01 / LANGUAGE FEATURES'),
          const SizedBox(height: 12),
          if (!acquired.any((entry) => entry.key.isFeature))
            _empty('まだ機能はありません', 'レベルアップで機能を実装'),
          for (final entry in acquired.where((entry) => entry.key.isFeature))
            _acquired(entry.key, entry.value),
          const SizedBox(height: 20),
          _label('02 / INFRASTRUCTURE'),
          const SizedBox(height: 12),
          if (!acquired.any((entry) => !entry.key.isFeature))
            _empty('最小構成で稼働中', '基盤を強化して処理を効率化'),
          for (final entry in acquired.where((entry) => !entry.key.isFeature))
            _acquired(entry.key, entry.value),
          const SizedBox(height: 20),
          const Divider(color: line, height: 1),
          const SizedBox(height: 16),
          _label('RUNTIME METRICS'),
          const SizedBox(height: 10),
          _metric(
            '並列処理',
            '${run.targetCount} task${run.targetCount > 1 ? 's' : ''}',
          ),
          _metric('処理威力', run.attackDamage.toStringAsFixed(1)),
          _metric('処理間隔', '${run.attackInterval.toStringAsFixed(2)} s'),
          const SizedBox(height: 20),
          _label('> SYSTEM LOG'),
          const SizedBox(height: 10),
          for (var i = 0; i < min(3, run.events.length); i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${i == 0 ? '›' : '·'} ${run.events[i]}',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.6,
                  color: i == 0 ? ink : muted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: muted)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        ),
      ],
    ),
  );

  Widget _empty(String title, String subtitle) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      children: [
        const Icon(Icons.add, size: 18, color: muted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: muted)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 9, color: muted)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _acquired(Upgrade upgrade, int rank) => Tooltip(
    message: '${upgrade.description}\n${upgrade.tradeoff}',
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9F2),
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Text(
            upgrade.symbol,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: upgrade.isFeature ? orange : ink,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(upgrade.title, style: const TextStyle(fontSize: 11)),
          ),
          Text(
            'v$rank',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: muted,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _overlay() => ColoredBox(
    color: const Color(0xFF102022).withValues(alpha: 0.91),
    child: LayoutBuilder(
      builder: (context, constraints) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: switch (run.phase) {
              RunPhase.ready => _welcome(),
              RunPhase.choosing => _choices(constraints.maxWidth > 680),
              RunPhase.paused => _paused(),
              _ => _result(),
            },
          ),
        ),
      ),
    ),
  );

  Widget _welcome() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _darkLabel('A LANGUAGE IS BORN AT RUNTIME.'),
      const SizedBox(height: 22),
      const Text(
        'Hello, runtime.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFFF2F3E8),
          fontFamily: 'monospace',
          fontSize: 42,
          fontWeight: FontWeight.bold,
          letterSpacing: -2,
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'あなたは、まだ名前のないプログラミング言語。\nタスクを処理し、機能を選び、5分間を生き残ろう。',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF9AAFA6), fontSize: 13, height: 1.9),
      ),
      const SizedBox(height: 30),
      FilledButton.icon(
        onPressed: start,
        style: FilledButton.styleFrom(
          backgroundColor: RuntimeGame.mint,
          foregroundColor: ink,
        ),
        icon: const Icon(Icons.play_arrow, size: 19),
        label: const Text(
          'ランタイムを起動',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 27),
      const Text(
        'WASD / 矢印キーで移動    ·    攻撃は自動',
        style: TextStyle(fontSize: 10, color: Color(0xFF77918B)),
      ),
      const SizedBox(height: 8),
      const Text(
        '倒したタスクの ◆ を回収するとレベルアップ',
        style: TextStyle(fontSize: 10, color: Color(0xFF77918B)),
      ),
    ],
  );

  Widget _choices(bool horizontal) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _darkLabel(
        'LEVEL ${run.level.toString().padLeft(2, '0')} / EVOLVE YOUR LANGUAGE',
      ),
      const SizedBox(height: 13),
      const Text(
        '次の設計を、選ぼう。',
        style: TextStyle(
          fontSize: 27,
          color: Color(0xFFF2F3E8),
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        '処理は一時停止中。選択した機能は、このランの間有効です。',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: Color(0xFF9AAFA6)),
      ),
      const SizedBox(height: 24),
      if (horizontal)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < run.choices.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: _choice(run.choices[i], i)),
              ],
            ],
          ),
        )
      else
        Column(
          children: [
            for (var i = 0; i < run.choices.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _choice(run.choices[i], i),
              ),
          ],
        ),
      const SizedBox(height: 16),
      const Text(
        'クリック、または 1 / 2 / 3 キーで実装',
        style: TextStyle(fontSize: 10, color: Color(0xFF77918B)),
      ),
    ],
  );

  Widget _choice(Upgrade upgrade, int index) => Material(
    color: const Color(0xFFF3F3E9),
    borderRadius: BorderRadius.circular(6),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => choose(upgrade),
      hoverColor: const Color(0xFFE2EDDF),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  upgrade.symbol,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 24,
                    color: orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '0${index + 1}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _label(
              '${upgrade.isFeature ? 'FEATURE' : 'INFRASTRUCTURE'} · v${run.rank(upgrade) + 1}',
            ),
            const SizedBox(height: 7),
            Text(
              upgrade.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              upgrade.description,
              style: const TextStyle(fontSize: 11, height: 1.7),
            ),
            const SizedBox(height: 18),
            Text(
              upgrade.tradeoff,
              style: TextStyle(
                fontSize: 10,
                height: 1.6,
                color: upgrade.isFeature ? orange : muted,
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Text(
                  '実装する',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _paused() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _darkLabel('PROCESS SUSPENDED'),
      const SizedBox(height: 18),
      const Text(
        'ひと息、つこう。',
        style: TextStyle(
          fontSize: 30,
          color: Color(0xFFF2F3E8),
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        '時間とタスクの処理を一時停止しています。',
        style: TextStyle(fontSize: 12, color: Color(0xFF9AAFA6)),
      ),
      const SizedBox(height: 26),
      FilledButton.icon(
        onPressed: resume,
        style: FilledButton.styleFrom(
          backgroundColor: RuntimeGame.mint,
          foregroundColor: ink,
        ),
        icon: const Icon(Icons.play_arrow),
        label: const Text('処理を再開'),
      ),
      const SizedBox(height: 20),
      const Text(
        'ESC / P でも再開できます',
        style: TextStyle(fontSize: 10, color: Color(0xFF77918B)),
      ),
    ],
  );

  Widget _result() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _darkLabel(
        run.phase == RunPhase.won
            ? 'BUILD SUCCEEDED / LANGUAGE COMPLETE'
            : 'OUT OF MEMORY / PROCESS EXITED',
      ),
      const SizedBox(height: 18),
      Text(
        run.phase == RunPhase.won ? 'あなたの言語が、完成。' : '次の設計に、つなげよう。',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 28,
          color: Color(0xFFF2F3E8),
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 18),
      Text(
        'UPTIME ${run.timeLabel}   /   ${run.kills} TASKS   /   LEVEL ${run.level}',
        style: const TextStyle(
          color: RuntimeGame.mint,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 24),
      if (run.upgrades.isEmpty)
        const Text(
          'まだ最小構成。次は機能を実装しよう。',
          style: TextStyle(color: Color(0xFF9AAFA6), fontSize: 12),
        ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final entry in run.upgrades.entries)
            Chip(
              backgroundColor: const Color(0xFF263D37),
              side: BorderSide.none,
              label: Text(
                '${entry.key.title} v${entry.value}',
                style: const TextStyle(color: RuntimeGame.mint, fontSize: 11),
              ),
            ),
        ],
      ),
      const SizedBox(height: 28),
      FilledButton.icon(
        onPressed: start,
        style: FilledButton.styleFrom(
          backgroundColor: RuntimeGame.mint,
          foregroundColor: ink,
        ),
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('新しいランタイムを起動'),
      ),
    ],
  );

  void _help() {
    pause();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Runtime manual'),
        content: const SizedBox(
          width: 420,
          child: Text(
            'WASD / 矢印キーで移動。最も近いタスクを自動で攻撃します。\n\n'
            '◆ は経験値です。近づいて回収し、レベルアップ時に3つの設計から1つを選びます。クリック、または1 / 2 / 3で選択できます。\n\n'
            'GCは3秒ごとの範囲攻撃、Concurrencyは複数の対象への同時攻撃。機能にはトレードオフがあります。\n\n'
            'メモリが0になると終了。5分間生き残れば言語が完成します。ESC / Pで一時停止できます。',
            style: TextStyle(fontSize: 13, height: 1.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              focus.requestFocus();
            },
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontFamily: 'monospace',
      fontSize: 9,
      color: muted,
      letterSpacing: 0.8,
    ),
  );
  Widget _darkLabel(String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontFamily: 'monospace',
      fontSize: 10,
      color: RuntimeGame.mint,
      letterSpacing: 1.8,
    ),
  );
  Widget _badge(String text, {Color color = ink}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      border: Border.all(color: color.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 9,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: color,
      ),
    ),
  );
}
