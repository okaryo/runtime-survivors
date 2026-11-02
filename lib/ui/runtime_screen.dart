import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../audio/game_audio.dart';
import '../audio/sound_cue.dart';
import '../game/run_state.dart';
import '../game/runtime_game.dart';
import '../l10n/game_text.dart';
import '../settings.dart';
import 'theme.dart';
import 'codex_panel.dart';
import 'upgrade_choices.dart';
import 'selection_build.dart';

class RuntimeScreen extends StatefulWidget {
  const RuntimeScreen({super.key, required this.settings});
  final GameSettings settings;
  @override
  State<RuntimeScreen> createState() => _RuntimeScreenState();
}

class _RuntimeScreenState extends State<RuntimeScreen> {
  final run = RunState();
  late final game = RuntimeGame(run);
  final focus = FocusNode();
  final _choiceFocus = FocusNode();
  final _pageScroll = ScrollController();
  final _gameWidgetKey = GlobalKey();
  List<Upgrade>? _inspectionChoices;
  Upgrade? _inspectedUpgrade;

  Upgrade? get inspectedUpgrade {
    if (run.phase != RunPhase.choosing || run.choices.isEmpty) return null;
    if (!identical(_inspectionChoices, run.choices)) {
      _inspectionChoices = run.choices;
      _inspectedUpgrade = run.choices.first;
    }
    return _inspectedUpgrade;
  }

  void restoreFocus() {
    // Wait for choice nodes and Web semantics to be attached after transitions.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _modalOpen) return;
      (run.phase == RunPhase.choosing ? _choiceFocus : focus).requestFocus();
    });
  }

  void inspect(Upgrade upgrade) {
    if (run.phase != RunPhase.choosing || inspectedUpgrade == upgrade) return;
    setState(() => _inspectedUpgrade = upgrade);
  }

  final audio = GameAudio();
  late final AppLifecycleListener lifecycle;
  bool _codexOpen = false;
  bool _modalOpen = false;
  GameText get text => GameText(widget.settings.language);

  @override
  void initState() {
    super.initState();
    game.onSound = audio.play;
    game.onPhaseChanged = (phase) {
      audio.setMusicPlaying(phase == RunPhase.running);
      if (phase == RunPhase.choosing) {
        if (_pageScroll.hasClients) _pageScroll.jumpTo(0);
        restoreFocus();
      }
    };
    game.onDiscover = widget.settings.discover;
    lifecycle = AppLifecycleListener(onInactive: pause, onHide: pause);
  }

  void pause() {
    run.pause();
    game.refresh();
  }

  void start() {
    audio.restartMusic();
    audio.unlock();
    setState(() => _codexOpen = false);
    game.inputBlocked = _modalOpen;
    run.start();
    game.refresh();
    restoreFocus();
  }

  void resume() {
    if (_modalOpen) return;
    if (_codexOpen) setState(() => _codexOpen = false);
    game.inputBlocked = false;
    audio.unlock();
    run.resume();
    game.refresh();
    restoreFocus();
  }

  void choose(Upgrade upgrade) {
    if (_modalOpen) return;
    if (_codexOpen) setState(() => _codexOpen = false);
    game.inputBlocked = false;
    audio.unlock();
    run.choose(upgrade);
    game.refresh();
    restoreFocus();
  }

  @override
  void dispose() {
    lifecycle.dispose();
    game.onSound = null;
    game.onPhaseChanged = null;
    game.onDiscover = null;
    audio.dispose();
    _pageScroll.dispose();
    _choiceFocus.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> modal(Widget Function(BuildContext) builder) async {
    pause();
    _modalOpen = true;
    game.inputBlocked = true;
    try {
      await showDialog<void>(context: context, builder: builder);
    } finally {
      if (mounted) {
        _modalOpen = false;
        game.inputBlocked = _codexOpen;
        restoreFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    game.text = text;
    audio.configure(
      muted: widget.settings.muted,
      volume: widget.settings.volume,
    );
    return Scaffold(
      body: ValueListenableBuilder<int>(
        valueListenable: game.revision,
        builder: (context, _, _) => LayoutBuilder(
          builder: (context, constraints) {
            final selecting = run.phase == RunPhase.choosing;
            final beside = constraints.maxWidth >= (selecting ? 1000 : 1180);
            final compactSelection = selecting && !beside;
            final compact = constraints.maxWidth < 720;
            final arenaHeight = compactSelection
                ? max(260.0, min(520.0, constraints.maxHeight - 300))
                : max(320.0, min(740.0, constraints.maxHeight - 310));
            return SingleChildScrollView(
              controller: _pageScroll,
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 30,
                compactSelection ? 12 : 22,
                compact ? 16 : 30,
                20,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (compactSelection) ...[
                        SizedBox(
                          height: max(0, constraints.maxHeight - 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              selectionHeader(),
                              const SizedBox(height: 8),
                              selectionMemory(),
                              const SizedBox(height: 8),
                              SelectionBuild(
                                run: run,
                                text: text,
                                inspected: inspectedUpgrade,
                                inline: true,
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, available) =>
                                      arena(max(0, available.maxHeight - 48)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        header(compact),
                        const SizedBox(height: 22),
                        stats(compact),
                        const SizedBox(height: 18),
                        if (beside)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: arena(arenaHeight)),
                              const SizedBox(width: 20),
                              SizedBox(
                                width: constraints.maxWidth < 1180 ? 260 : 300,
                                child: selecting
                                    ? SelectionBuild(
                                        run: run,
                                        text: text,
                                        inspected: inspectedUpgrade,
                                      )
                                    : designPanel(),
                              ),
                            ],
                          )
                        else ...[
                          arena(arenaHeight),
                          const SizedBox(height: 16),
                          designPanel(),
                        ],
                      ],
                      const SizedBox(height: 14),
                      Text(
                        text('controls'),
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                      const SizedBox(height: 18),
                      CodexPanel(
                        text: text,
                        discoveries: widget.settings.discoveries,
                        expanded: _codexOpen,
                        onToggle: () {
                          if (!_codexOpen) pause();
                          setState(() => _codexOpen = !_codexOpen);
                          game.inputBlocked = _codexOpen || _modalOpen;
                          if (!_codexOpen) restoreFocus();
                        },
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
  }

  Widget selectionHeader() => Row(
    children: [
      const Expanded(
        child: Text(
          'Runtime Survivors',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      TextButton(
        key: const Key('language-toggle'),
        onPressed: () {
          widget.settings.update(language: text.isJapanese ? 'en' : 'ja');
          restoreFocus();
        },
        child: Text(text.isJapanese ? 'EN' : '日本語'),
      ),
      IconButton(
        tooltip: text('settings'),
        onPressed: settingsDialog,
        icon: const Icon(Icons.tune, size: 20),
      ),
      IconButton(
        tooltip: text('help'),
        onPressed: help,
        icon: const Icon(Icons.help_outline, size: 20),
      ),
    ],
  );

  Widget selectionMemory() => Container(
    key: const Key('memory-status'),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFFAFAF5),
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Icon(Icons.memory, size: 18, color: orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text('memory'),
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            ),
            Text(
              '${run.health.ceil()} / ${run.maxHealth.toInt()} HP',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 14),
            Text('Lv.${run.level}', style: const TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: (run.health / run.maxHealth).clamp(0, 1),
          color: orange,
          backgroundColor: line,
          minHeight: 4,
        ),
      ],
    ),
  );

  Widget header(bool compact) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 16,
    runSpacing: 12,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: orange,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '>_',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: paper,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Runtime Survivors',
                  style: TextStyle(
                    fontSize: compact ? 23 : 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text('tagline'),
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            key: const Key('language-toggle'),
            onPressed: () {
              run.movement.setZero();
              widget.settings.update(language: text.isJapanese ? 'en' : 'ja');
              restoreFocus();
            },
            icon: const Icon(Icons.translate, size: 18),
            label: Text(text.isJapanese ? 'English' : '日本語'),
          ),
          IconButton(
            key: const Key('mute-toggle'),
            tooltip: text(widget.settings.muted ? 'soundOn' : 'soundOff'),
            onPressed: () {
              audio.unlock();
              widget.settings.update(muted: !widget.settings.muted);
              audio.configure(
                muted: widget.settings.muted,
                volume: widget.settings.volume,
              );
              if (!widget.settings.muted) audio.play(SoundCue.select);
              run.movement.setZero();
              restoreFocus();
            },
            icon: Icon(
              widget.settings.muted
                  ? Icons.volume_off_outlined
                  : Icons.volume_up_outlined,
              size: 22,
            ),
          ),
          IconButton(
            tooltip: text('settings'),
            onPressed: settingsDialog,
            icon: const Icon(Icons.tune, size: 22),
          ),
          IconButton(
            tooltip: text('help'),
            onPressed: help,
            icon: const Icon(Icons.help_outline, size: 22),
          ),
        ],
      ),
    ],
  );

  Widget stats(bool compact) {
    final cards = [
      stat(
        text('memory'),
        '${run.health.ceil()}',
        '/ ${run.maxHealth.toInt()} MB',
        Icons.memory,
        run.health / run.maxHealth,
        orange,
        key: const Key('memory-status'),
      ),
      stat(
        text('uptime'),
        run.timeLabel,
        '/ 05:00',
        Icons.timer_outlined,
        run.elapsed / RunState.duration,
        ink,
      ),
      stat(
        text('tasks'),
        '${run.kills}',
        text('completed'),
        Icons.done_all,
        null,
        ink,
      ),
      stat(
        text('level'),
        run.level.toString().padLeft(2, '0'),
        '${run.xp} / ${run.nextLevelXp} XP',
        Icons.auto_awesome_outlined,
        run.xp / run.nextLevelXp,
        infraColor,
      ),
    ];
    if (compact) {
      return Column(
        children: [
          for (var row = 0; row < 2; row++)
            Padding(
              padding: EdgeInsets.only(top: row == 0 ? 0 : 10),
              child: Row(
                children: [
                  Expanded(child: cards[row * 2]),
                  const SizedBox(width: 10),
                  Expanded(child: cards[row * 2 + 1]),
                ],
              ),
            ),
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }

  Widget stat(
    String label,
    String value,
    String suffix,
    IconData icon,
    double? progress,
    Color color, {
    Key? key,
  }) => Container(
    key: key,
    height: 101,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFFAFAF5),
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: muted),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 27,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  suffix,
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ),
            ],
          ),
        ),
        if (progress != null)
          LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 4,
            color: color,
            backgroundColor: line,
            borderRadius: BorderRadius.circular(2),
          ),
      ],
    ),
  );

  Widget arena(double height) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(8),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Container(
          height: 46,
          color: const Color(0xFFE9EDE2),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              const Icon(Icons.terminal, size: 18),
              const SizedBox(width: 8),
              const Text('runtime://local', style: TextStyle(fontSize: 12)),
              const Spacer(),
              Expanded(
                child: Text(
                  textAlign: TextAlign.right,
                  text(switch (run.phase) {
                    RunPhase.ready => 'standby',
                    RunPhase.running => 'running',
                    RunPhase.choosing => 'choosing',
                    RunPhase.paused => 'paused',
                    _ => 'terminated',
                  }),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ),
              IconButton(
                tooltip: text(
                  run.phase == RunPhase.paused ? 'resume' : 'pause',
                ),
                onPressed: run.phase == RunPhase.running
                    ? pause
                    : run.phase == RunPhase.paused
                    ? resume
                    : null,
                icon: Icon(
                  run.phase == RunPhase.paused ? Icons.play_arrow : Icons.pause,
                  size: 20,
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
                  child: GameWidget(
                    key: _gameWidgetKey,
                    game: game,
                    focusNode: focus,
                  ),
                ),
              ),
              if (run.phase == RunPhase.running)
                Positioned(
                  right: 14,
                  top: 14,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: ink,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        run.isRush
                            ? '⚡ ${text('rush')}'
                            : '${text('nextRush')} ${run.secondsToRush.ceil()}s',
                        style: TextStyle(
                          color: run.isRush
                              ? const Color(0xFFFFBA8C)
                              : darkMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              if (run.phase == RunPhase.choosing)
                Positioned.fill(
                  child: UpgradeChoices(
                    run: run,
                    text: text,
                    onChoose: choose,
                    focusNode: _choiceFocus,
                    onInspect: inspect,
                    inspected: inspectedUpgrade,
                  ),
                ),
              if (run.phase != RunPhase.running &&
                  run.phase != RunPhase.choosing)
                Positioned.fill(child: overlay()),
              if (run.phase == RunPhase.running && run.elapsed < 7)
                Positioned(
                  left: 16,
                  right: 16,
                  top: 50,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: ink,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          text('moveHint'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: mint, fontSize: 13),
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

  Widget designPanel() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFE9EDE2),
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.account_tree_outlined, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text('design'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          text('designHint'),
          style: const TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(height: 20),
        for (final feature in [true, false]) ...[
          badge(
            text(feature ? 'feature' : 'infra'),
            color: feature ? featureColor : infraColor,
            icon: feature ? Icons.auto_awesome : Icons.memory,
          ),
          const SizedBox(height: 7),
          Text(
            text(feature ? 'featureHint' : 'infraHint'),
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 10),
          if (!run.upgrades.keys.any((u) => u.isFeature == feature))
            Text(
              text(feature ? 'emptyFeatures' : 'emptyInfra'),
              style: const TextStyle(fontSize: 13, color: muted),
            ),
          for (final entry in run.upgrades.entries.where(
            (e) => e.key.isFeature == feature,
          ))
            Tooltip(
              message:
                  '${text.description(entry.key)}\n${text.tradeoff(entry.key)}',
              child: Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    SizedBox(
                      width: 37,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          entry.key.symbol,
                          style: TextStyle(
                            fontSize: 17,
                            color: feature ? featureColor : infraColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        text.title(entry.key),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Lv.${entry.value}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
        ],
        const Divider(color: line),
        const SizedBox(height: 10),
        sectionLabel(text('metrics')),
        const SizedBox(height: 8),
        metric(text('targets'), '${run.targetCount}'),
        metric(text('damage'), run.attackDamage.toStringAsFixed(1)),
        metric(text('interval'), '${run.attackInterval.toStringAsFixed(2)} s'),
        const SizedBox(height: 20),
        sectionLabel(text('log')),
        const SizedBox(height: 10),
        for (final event in run.events.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Text(
              '› ${text.event(event)}',
              style: const TextStyle(fontSize: 12, height: 1.6, color: muted),
            ),
          ),
      ],
    ),
  );
  Widget metric(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: muted),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Widget overlay() => ColoredBox(
    color: const Color(0xFF102022).withValues(alpha: 0.93),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: min(900, constraints.maxWidth),
              child: switch (run.phase) {
                RunPhase.ready => welcome(),
                RunPhase.paused => paused(),
                _ => result(),
              },
            ),
          ),
        ),
      ),
    ),
  );
  Widget darkLabel(String value) => Text(
    value,
    textAlign: TextAlign.center,
    style: const TextStyle(color: mint, fontSize: 13, letterSpacing: 1),
  );
  Widget darkBody(String value) => Text(
    value,
    textAlign: TextAlign.center,
    style: const TextStyle(color: darkMuted, fontSize: 14, height: 1.8),
  );
  Widget title(String value) => Text(
    value,
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: darkText,
      fontSize: 30,
      fontWeight: FontWeight.w800,
    ),
  );
  Widget action(String label, IconData icon, VoidCallback onPressed) =>
      FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: mint,
          foregroundColor: ink,
        ),
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
  Widget welcome() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      darkLabel(text('welcomeLabel')),
      const SizedBox(height: 20),
      const Text(
        'Hello, runtime.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: darkText,
          fontSize: 40,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.3,
        ),
      ),
      const SizedBox(height: 18),
      darkBody(text('welcomeBody')),
      const SizedBox(height: 28),
      action(text('start'), Icons.play_arrow, start),
      const SizedBox(height: 24),
      darkBody(text('controls')),
      const SizedBox(height: 7),
      darkBody(text('pickupHint')),
    ],
  );
  Widget paused() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      darkLabel(text('paused')),
      const SizedBox(height: 18),
      title(text('pauseTitle')),
      const SizedBox(height: 12),
      darkBody(text('pauseBody')),
      const SizedBox(height: 25),
      action(text('resume'), Icons.play_arrow, resume),
      const SizedBox(height: 18),
      darkBody(text(_codexOpen ? 'codexResume' : 'pauseKeys')),
    ],
  );
  Widget result() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      darkLabel(text(run.phase == RunPhase.won ? 'wonLabel' : 'lostLabel')),
      const SizedBox(height: 18),
      title(text(run.phase == RunPhase.won ? 'wonTitle' : 'lostTitle')),
      const SizedBox(height: 18),
      darkBody(
        '${text('uptime')} ${run.timeLabel}  /  ${run.kills} ${text('tasks')}  /  Lv.${run.level}',
      ),
      const SizedBox(height: 22),
      if (run.upgrades.isEmpty) darkBody(text('emptyResult')),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final entry in run.upgrades.entries)
            Chip(
              backgroundColor: ink,
              side: BorderSide.none,
              label: Text(
                '${text.title(entry.key)} Lv.${entry.value}',
                style: const TextStyle(color: mint, fontSize: 13),
              ),
            ),
        ],
      ),
      const SizedBox(height: 26),
      action(text('restart'), Icons.refresh, start),
    ],
  );

  void help() => modal(
    (context) => AlertDialog(
      title: Text(text('help')),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Text(
            text('helpBody'),
            style: const TextStyle(fontSize: 15, height: 1.8),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(text('close')),
        ),
      ],
    ),
  );

  void settingsDialog() => modal(
    (context) => ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) => AlertDialog(
        title: Text(text('settings')),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                sectionLabel(text('language')),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ja', label: Text('日本語')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {widget.settings.language},
                  onSelectionChanged: (value) =>
                      widget.settings.update(language: value.first),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(text('mute')),
                  value: widget.settings.muted,
                  onChanged: (value) {
                    audio.unlock();
                    widget.settings.update(muted: value);
                  },
                ),
                Text(
                  '${text('volume')} ${(widget.settings.volume * 100).round()}%',
                ),
                Slider(
                  value: widget.settings.volume,
                  divisions: 20,
                  label: '${(widget.settings.volume * 100).round()}%',
                  onChanged: (value) {
                    audio.unlock();
                    widget.settings.update(volume: value);
                  },
                ),
                OutlinedButton.icon(
                  onPressed:
                      widget.settings.muted || widget.settings.volume == 0
                      ? null
                      : () {
                          audio.unlock();
                          audio.play(SoundCue.levelUp);
                        },
                  icon: const Icon(Icons.music_note_outlined),
                  label: Text(text('soundTest')),
                ),
                const SizedBox(height: 16),
                Text(
                  text('savedLocally'),
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(text('close')),
          ),
        ],
      ),
    ),
  );
}
