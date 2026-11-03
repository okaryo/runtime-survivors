import 'dart:math';

import 'package:flutter/material.dart';

import '../game/run_state.dart';
import '../l10n/game_text.dart';
import 'theme.dart';

/// Floating arena telemetry. Only the pause control intercepts pointer input.
class RuntimeHud extends StatelessWidget {
  const RuntimeHud({
    super.key,
    required this.run,
    required this.text,
    required this.onPause,
    required this.onResume,
  });

  final RunState run;
  final GameText text;
  final VoidCallback onPause;
  final VoidCallback onResume;

  /// Cards and setup/result overlays leave the same perimeter clear as the HUD.
  static EdgeInsets safeInsets(BuildContext context, double width) {
    final scale = max(1.0, MediaQuery.textScalerOf(context).scale(16) / 16);
    return EdgeInsets.only(
      top: (width < 680 ? 112 : 76) + 32 * (scale - 1),
      bottom: 52 + 16 * (scale - 1),
    );
  }

  static String clock(double seconds) {
    final value = max(0, seconds.ceil());
    return '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
  }

  static const _shadow = [Shadow(color: Colors.black, blurRadius: 5)];
  static const _amber = Color(0xFFFFCB78);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final compact = width < 680;
      final encounter = run.deadlocks.where((e) => e.core.alive).firstOrNull;
      final insets = safeInsets(context, width);
      final remaining = clock(RunState.duration - run.elapsed);
      final showRush = switch (run.phase) {
        RunPhase.running || RunPhase.choosing || RunPhase.paused => true,
        _ => false,
      };
      return Stack(
        key: const Key('runtime-hud'),
        children: [
          if (encounter != null)
            Positioned(
              left: compact ? (width - 220) / 2 : 32 + min(232.0, width * 0.28),
              top: compact ? 64 : 14,
              width: compact
                  ? 220
                  : ((width - 120) / 2 - min(232.0, width * 0.28) - 48).clamp(
                      90.0,
                      200.0,
                    ),
              child: IgnorePointer(
                child: Column(
                  key: const Key('deadlock-status'),
                  children: [
                    Text(
                      text('enemy.3.title'),
                      style: const TextStyle(
                        color: _amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        shadows: _shadow,
                      ),
                    ),
                    Text(
                      text(
                        encounter.exposed
                            ? 'bossExposedShort'
                            : 'bossLockedShort',
                      ),
                      style: const TextStyle(
                        color: _amber,
                        fontSize: 11,
                        shadows: _shadow,
                      ),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: (encounter.core.health / encounter.core.maxHealth)
                          .clamp(0, 1),
                      color: _amber,
                      backgroundColor: const Color(0xFF51432C),
                      minHeight: 4,
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: insets.top + 10,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: insets.bottom + 10,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 14,
            width: min(232.0, width * (compact ? 0.43 : 0.28)),
            child: IgnorePointer(child: memory()),
          ),
          Positioned(
            left: compact ? null : (width - 120) / 2,
            right: compact ? 62 : null,
            top: 12,
            width: 120,
            child: IgnorePointer(
              child: Column(
                key: const Key('remaining-time'),
                children: [
                  Text(
                    text('remainingTime'),
                    style: const TextStyle(
                      color: darkMuted,
                      fontSize: 11,
                      shadows: _shadow,
                    ),
                  ),
                  Text(
                    remaining,
                    style: const TextStyle(
                      color: darkText,
                      fontSize: 28,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      shadows: _shadow,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showRush)
            Positioned(
              right: compact ? 16 : 62,
              top: compact ? insets.top - 42 : 16,
              child: IgnorePointer(child: rush()),
            ),
          Positioned(
            top: 14,
            right: 16,
            child: Material(
              color: const Color(0xFF17312A).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(6),
              child: IconButton(
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                tooltip: text(
                  run.phase == RunPhase.paused ? 'resume' : 'pause',
                ),
                onPressed: run.phase == RunPhase.running
                    ? onPause
                    : run.phase == RunPhase.paused
                    ? onResume
                    : null,
                color: mint,
                disabledColor: darkMuted.withValues(alpha: 0.35),
                icon: Icon(
                  run.phase == RunPhase.paused ? Icons.play_arrow : Icons.pause,
                  size: 20,
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 14,
            width: min(640.0, width * 0.68),
            child: IgnorePointer(child: experience()),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: IgnorePointer(
              child: Text(
                text('processedTasks', {'count': run.kills}),
                key: const Key('processed-tasks'),
                style: const TextStyle(
                  color: darkMuted,
                  fontSize: 12,
                  shadows: _shadow,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget memory() {
    final color = run.health / run.maxHealth < 0.3 ? _amber : mint;
    return Column(
      key: const Key('memory-status'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.memory_outlined,
              size: 24,
              color: color,
              shadows: _shadow,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text('hudMemory'),
                    style: const TextStyle(
                      color: darkMuted,
                      fontSize: 11,
                      height: 1.1,
                      shadows: _shadow,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${run.health.ceil()} / ${run.maxHealth.toInt()} MB',
                    style: TextStyle(
                      color: color,
                      fontSize: 17,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      shadows: _shadow,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: (run.health / run.maxHealth).clamp(0, 1),
          minHeight: 6,
          color: color,
          backgroundColor: const Color(0xFF41594F),
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget rush() => Container(
    key: const Key('rush-status'),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFF3C2E17).withValues(alpha: 0.9),
      border: Border.all(
        color: _amber.withValues(alpha: run.isRush ? 1 : 0.65),
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.bolt, size: 17, color: _amber),
        const SizedBox(width: 4),
        Text(
          run.isRush
              ? text('rush.${run.rushTheme?.name ?? 'interrupts'}')
              : run.pressureStage > 0
              ? text(run.pressureStage == 2 ? 'overload' : 'pressure')
              : text('rushIn', {'time': clock(run.secondsToRush)}),
          style: const TextStyle(
            color: _amber,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget experience() => Column(
    key: const Key('experience-status'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Text(
            'Lv.${run.level.toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: darkText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              shadows: _shadow,
            ),
          ),
          const Spacer(),
          Text(
            '${run.xp} / ${run.nextLevelXp} XP',
            style: const TextStyle(
              color: darkMuted,
              fontSize: 12,
              shadows: _shadow,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      LinearProgressIndicator(
        value: (run.xp / run.nextLevelXp).clamp(0, 1),
        minHeight: 4,
        color: mint,
        backgroundColor: const Color(0xFF41594F),
        borderRadius: BorderRadius.circular(2),
      ),
    ],
  );
}
