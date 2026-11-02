import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/game_audio.dart';
import '../audio/sound_cue.dart';
import '../game/run_state.dart';
import '../game/runtime_game.dart';
import '../game/language_profile.dart';
import '../l10n/game_text.dart';
import '../settings.dart';
import 'theme.dart';
import 'encyclopedia_panel.dart';
import 'upgrade_choices.dart';
import 'upgrade_icon.dart';
import 'policy_picker.dart';
import 'runtime_hud.dart';

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
  TypingPolicy selectedPolicy = TypingPolicy.staticTyping;
  final _choiceFocus = FocusNode();
  final _gameWidgetKey = GlobalKey();
  void restoreFocus() {
    // Wait for choice nodes and Web semantics to be attached after transitions.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _modalOpen) return;
      (run.phase == RunPhase.choosing ? _choiceFocus : focus).requestFocus();
    });
  }

  final audio = GameAudio();
  late final AppLifecycleListener lifecycle;
  bool _modalOpen = false;
  GameText get text => GameText(widget.settings.language);

  @override
  void initState() {
    super.initState();
    game.onSound = audio.play;
    game.onPhaseChanged = (phase) {
      audio.setMusicPlaying(phase == RunPhase.running);
      if (phase == RunPhase.choosing) {
        restoreFocus();
      }
    };
    game.onDiscover = widget.settings.discover;
    lifecycle = AppLifecycleListener(onInactive: pause, onHide: pause);
  }

  void pause() {
    run.pause();
    game.refresh();
    restoreFocus();
  }

  void start() {
    audio.restartMusic();
    audio.unlock();
    game.inputBlocked = _modalOpen;
    run.start(policy: selectedPolicy);
    game.refresh();
    restoreFocus();
  }

  void resume() {
    if (_modalOpen) return;
    game.inputBlocked = false;
    audio.unlock();
    run.resume();
    game.refresh();
    restoreFocus();
  }

  void choose(Upgrade upgrade) {
    if (_modalOpen) return;
    game.inputBlocked = false;
    audio.unlock();
    run.choose(upgrade);
    game.refresh();
    restoreFocus();
  }

  void choosePolicy(PolicyUpgrade upgrade) {
    if (_modalOpen) return;
    audio.unlock();
    run.choosePolicy(upgrade);
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
        game.inputBlocked = false;
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
    return ValueListenableBuilder<int>(
      valueListenable: game.revision,
      child: EncyclopediaPanel(
        text: text,
        discoveries: Set.of(widget.settings.discoveries),
      ),
      builder: (context, _, encyclopedia) => CallbackShortcuts(
        bindings: run.phase == RunPhase.ready
            ? {
                const SingleActivator(LogicalKeyboardKey.digit1): () {
                  if (run.phase == RunPhase.ready) {
                    setState(() => selectedPolicy = TypingPolicy.staticTyping);
                  }
                },
                const SingleActivator(LogicalKeyboardKey.digit2): () {
                  if (run.phase == RunPhase.ready) {
                    setState(() => selectedPolicy = TypingPolicy.dynamicTyping);
                  }
                },
                const SingleActivator(LogicalKeyboardKey.enter): () {
                  if (run.phase == RunPhase.ready) start();
                },
              }
            : const {},
        child: Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final beside = constraints.maxWidth >= 1180;
              final compact = constraints.maxWidth < 720;
              final arenaHeight = max(
                500.0,
                min(960.0, constraints.maxHeight - 120),
              );
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 30,
                  22,
                  compact ? 16 : 30,
                  20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header(compact),
                        const SizedBox(height: 18),
                        if (beside)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: arena(arenaHeight)),
                              const SizedBox(width: 20),
                              SizedBox(width: 300, child: designPanel()),
                            ],
                          )
                        else ...[
                          arena(arenaHeight),
                          const SizedBox(height: 16),
                          designPanel(),
                        ],
                        const SizedBox(height: 14),
                        Text(
                          text('controls'),
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                        const SizedBox(height: 18),
                        encyclopedia!,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

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

  Widget arena(double height) => Container(
    height: height,
    decoration: BoxDecoration(
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(8),
    ),
    clipBehavior: Clip.antiAlias,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final safeInsets = RuntimeHud.safeInsets(context, constraints.maxWidth);
        return Stack(
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
            if (run.phase == RunPhase.choosing)
              Positioned.fill(
                child: UpgradeChoices(
                  run: run,
                  text: text,
                  onChoose: choose,
                  onChoosePolicy: choosePolicy,
                  focusNode: _choiceFocus,
                  safeInsets: safeInsets,
                ),
              ),
            if (run.phase != RunPhase.running && run.phase != RunPhase.choosing)
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0xFF102022).withValues(alpha: 0.93),
                  child: Padding(padding: safeInsets, child: overlay()),
                ),
              ),
            Positioned.fill(
              child: RuntimeHud(
                run: run,
                text: text,
                onPause: pause,
                onResume: resume,
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget designPanel() => Container(
    key: const Key('design-panel'),
    padding: const EdgeInsets.all(16),
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
        if (run.typingPolicy != null) ...[
          const SizedBox(height: 10),
          Text(
            '${text('policyCurrent')}: ${text.policyName(run.typingPolicy!)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          Text(
            text('policySummary.${run.typingPolicy!.name}', {
              'count': run.typingPolicy == TypingPolicy.staticTyping
                  ? run.scanTargets
                  : run.policyCoverage,
              'bonus': (run.policyBonus * 100).round(),
            }),
            style: const TextStyle(fontSize: 12, height: 1.4, color: muted),
          ),
          Text(
            'Lv.${run.policyRank}',
            style: const TextStyle(fontSize: 12, color: muted),
          ),
        ],
        const SizedBox(height: 12),
        for (final feature in [true, false]) ...[
          badge(
            text(feature ? 'feature' : 'infra'),
            color: feature ? featureColor : infraColor,
            icon: feature ? Icons.auto_awesome : Icons.memory,
          ),
          const SizedBox(height: 8),
          for (final entry in run.upgrades.entries.where(
            (e) => e.key.isFeature == feature,
          ))
            acquiredSlot(entry.key, entry.value),
          for (
            var i = feature ? run.featureCount : run.infraCount;
            i < (feature ? RunState.featureSlots : RunState.infraSlots);
            i++
          )
            emptySlot(
              Key('empty-${feature ? 'feature' : 'infra'}-$i'),
              text(feature ? 'emptyUpgradeSlot' : 'emptyInfraSlot'),
            ),
          const SizedBox(height: 12),
        ],
        if (run.rank(Upgrade.jitCompilation) > 0) ...[
          Text(
            text(run.abilities.jitOptimized ? 'jitReady' : 'jitAnalyzing', {
              'count': run.abilities.jitExecutions,
            }),
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 6),
        ],
        if (run.rank(Upgrade.memoization) > 0) ...[
          Text(
            text('memoStatus', {'count': run.abilities.cachedInputs.length}),
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 6),
        ],
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
  Widget acquiredSlot(Upgrade upgrade, int rank) => Tooltip(
    message: '${text.description(upgrade)}\n${text.tradeoff(upgrade)}',
    child: Container(
      key: Key('acquired-${upgrade.name}'),
      constraints: const BoxConstraints(minHeight: 34),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: paper,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          UpgradeIcon(upgrade: upgrade, size: 24),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text.title(upgrade),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Lv.$rank/${upgrade.maxRank}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );

  Widget emptySlot(Key key, String label) => Container(
    key: key,
    constraints: const BoxConstraints(minHeight: 34),
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      children: [
        const SizedBox(
          width: 24,
          child: Icon(Icons.add, size: 16, color: muted),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: muted),
          ),
        ),
      ],
    ),
  );

  Widget overlay() => Padding(
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
  Widget welcome() => LayoutBuilder(
    builder: (context, constraints) {
      final intro = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Hello, runtime.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: darkText,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          darkBody(text('welcomeBody')),
          const SizedBox(height: 20),
          action(text('start'), Icons.play_arrow, start),
          const SizedBox(height: 14),
          darkBody(text('controls')),
        ],
      );
      final policy = PolicyPicker(
        selected: selectedPolicy,
        text: text,
        onChanged: (value) => setState(() => selectedPolicy = value),
      );
      if (constraints.maxWidth < 650) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [intro, const SizedBox(height: 24), policy],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: intro),
          const SizedBox(width: 28),
          Expanded(child: policy),
        ],
      );
    },
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
      darkBody(text('pauseKeys')),
    ],
  );
  Widget result() => LayoutBuilder(
    builder: (context, constraints) {
      final profile = LanguageProfile.analyze(run.typingPolicy, run.upgrades);
      final summary = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          darkLabel(text(run.phase == RunPhase.won ? 'wonLabel' : 'lostLabel')),
          const SizedBox(height: 8),
          Text(
            text(run.phase == RunPhase.won ? 'wonTitle' : 'lostTitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: darkText,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          darkLabel(text('profile.label')),
          const SizedBox(height: 8),
          Text(
            text.profileTitle(profile),
            key: const Key('language-profile'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: mint,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            text.profileDescription(profile),
            textAlign: TextAlign.center,
            style: const TextStyle(color: darkText, fontSize: 14, height: 1.5),
          ),
        ],
      );
      final build = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          darkLabel(text('resultBuild')),
          const SizedBox(height: 10),
          if (run.upgrades.isEmpty) darkBody(text('emptyResult')),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final entry in run.upgrades.entries)
                Chip(
                  backgroundColor: ink,
                  side: BorderSide.none,
                  avatar: UpgradeIcon(upgrade: entry.key, size: 22),
                  label: Text(
                    '${text.title(entry.key)} Lv.${entry.value}',
                    style: const TextStyle(color: mint, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          action(text('restart'), Icons.refresh, () {
            run.resetToSetup();
            game.refresh();
            restoreFocus();
          }),
        ],
      );
      if (constraints.maxWidth < 650) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [summary, const SizedBox(height: 24), build],
        );
      }
      return Row(
        children: [
          Expanded(child: summary),
          const SizedBox(width: 24),
          Expanded(child: build),
        ],
      );
    },
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
