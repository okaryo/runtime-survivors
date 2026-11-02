import 'package:flutter/material.dart';

import '../game/run_state.dart';
import '../l10n/game_text.dart';
import 'theme.dart';

/// Telemetry stays visible above the arena, including during ability selection.
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

  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: const TextStyle(fontFamily: 'RobotoMono'),
    child: Container(
      key: const Key('runtime-hud'),
      color: const Color(0xFF142521),
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: r'runtime@local:~$ ',
                        style: TextStyle(color: mint),
                      ),
                      TextSpan(
                        text: 'status --live',
                        style: TextStyle(color: darkText),
                      ),
                    ],
                  ),
                  style: TextStyle(fontSize: 12),
                ),
              ),
              Text(
                text(switch (run.phase) {
                  RunPhase.ready => 'standby',
                  RunPhase.running => 'running',
                  RunPhase.choosing => 'choosing',
                  RunPhase.paused => 'paused',
                  _ => 'terminated',
                }),
                style: const TextStyle(color: mint, fontSize: 12),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
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
                disabledColor: darkMuted.withValues(alpha: 0.3),
                icon: Icon(
                  run.phase == RunPhase.paused ? Icons.play_arrow : Icons.pause,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 500 ? 2 : 4;
              final width = constraints.maxWidth / columns;
              return Wrap(
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: width,
                    child: reading(
                      text('hud.memory'),
                      '${run.health.ceil()}/${run.maxHealth.toInt()} MB',
                      progress: run.health / run.maxHealth,
                      key: const Key('memory-status'),
                      color: run.health / run.maxHealth < 0.3
                          ? const Color(0xFFFFBA8C)
                          : mint,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: reading(
                      text('hud.uptime'),
                      '${run.timeLabel}/05:00',
                      progress: run.elapsed / RunState.duration,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: reading(text('hud.tasks'), '${run.kills}'),
                  ),
                  SizedBox(
                    width: width,
                    child: reading(
                      'lv',
                      '${run.level} xp=${run.xp}/${run.nextLevelXp}',
                      progress: run.xp / run.nextLevelXp,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              metric(text('targets'), '${run.targetCount}'),
              metric(text('damage'), run.attackDamage.toStringAsFixed(1)),
              metric(
                text('interval'),
                '${run.attackInterval.toStringAsFixed(2)}s',
              ),
              Text(
                run.isRush
                    ? '! ${text('rush')}'
                    : '${text('nextRush')}=${run.secondsToRush.ceil()}s',
                style: TextStyle(
                  color: run.isRush ? const Color(0xFFFFBA8C) : darkMuted,
                  fontSize: 12,
                ),
              ),
              if (run.rank(Upgrade.jitCompilation) > 0)
                status(
                  text('jitStatus', {'stacks': run.abilities.focusStacks}),
                ),
              if (run.rank(Upgrade.memoization) > 0)
                status(
                  text('echoStatus', {'count': run.abilities.echoes.length}),
                ),
              if (run.rank(Upgrade.nullSafety) > 0)
                status(
                  run.shieldReady
                      ? text('shieldReady')
                      : text('shieldCharging', {
                          'seconds': run.shieldTimer.ceil(),
                        }),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget reading(
    String label,
    String value, {
    double? progress,
    Color color = mint,
    Key? key,
  }) => Padding(
    key: key,
    padding: const EdgeInsets.only(right: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            text: '$label=',
            style: const TextStyle(color: darkMuted, fontSize: 11),
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (progress != null)
          LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 2,
            color: color,
            backgroundColor: const Color(0xFF3F5650),
            borderRadius: BorderRadius.circular(2),
          )
        else
          const SizedBox(height: 2),
      ],
    ),
  );

  Widget metric(String label, String value) => Text.rich(
    TextSpan(
      text: '$label=',
      style: const TextStyle(color: darkMuted, fontSize: 12),
      children: [
        TextSpan(
          text: value,
          style: const TextStyle(color: darkText, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget status(String value) =>
      Text(value, style: const TextStyle(color: darkMuted, fontSize: 12));
}
