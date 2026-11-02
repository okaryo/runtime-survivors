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
  Widget build(BuildContext context) => Container(
    key: const Key('runtime-hud'),
    color: const Color(0xFF192F2B),
    padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth < 500 ? 2 : 4;
                  final width = constraints.maxWidth / columns;
                  return Wrap(
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: width,
                        child: reading(
                          text('memory'),
                          '${run.health.ceil()} / ${run.maxHealth.toInt()} MB',
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
                          text('uptime'),
                          '${run.timeLabel} / 05:00',
                          progress: run.elapsed / RunState.duration,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: reading(text('tasks'), '${run.kills}'),
                      ),
                      SizedBox(
                        width: width,
                        child: reading(
                          '${text('level')} ${run.level.toString().padLeft(2, '0')}',
                          '${run.xp} / ${run.nextLevelXp} XP',
                          progress: run.xp / run.nextLevelXp,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            IconButton(
              tooltip: text(run.phase == RunPhase.paused ? 'resume' : 'pause'),
              onPressed: run.phase == RunPhase.running
                  ? onPause
                  : run.phase == RunPhase.paused
                  ? onResume
                  : null,
              color: mint,
              disabledColor: darkMuted.withValues(alpha: 0.3),
              icon: Icon(
                run.phase == RunPhase.paused ? Icons.play_arrow : Icons.pause,
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 18,
          runSpacing: 6,
          children: [
            SizedBox(
              width: 108,
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6, color: mint),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      text(switch (run.phase) {
                        RunPhase.ready => 'standby',
                        RunPhase.running => 'running',
                        RunPhase.choosing => 'choosing',
                        RunPhase.paused => 'paused',
                        _ => 'terminated',
                      }),
                      style: const TextStyle(color: mint, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            metric(text('targets'), '${run.targetCount}'),
            metric(text('damage'), run.attackDamage.toStringAsFixed(1)),
            metric(
              text('interval'),
              '${run.attackInterval.toStringAsFixed(2)} s',
            ),
            Text(
              run.isRush
                  ? '⚡ ${text('rush')}'
                  : '${text('nextRush')} ${run.secondsToRush.ceil()}s',
              style: TextStyle(
                color: run.isRush ? const Color(0xFFFFBA8C) : darkMuted,
                fontSize: 12,
              ),
            ),
            if (run.rank(Upgrade.jitCompilation) > 0)
              status(text('jitStatus', {'stacks': run.abilities.focusStacks})),
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
        Text(label, style: const TextStyle(color: darkMuted, fontSize: 11)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        if (progress != null)
          LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 3,
            color: color,
            backgroundColor: const Color(0xFF3F5650),
            borderRadius: BorderRadius.circular(2),
          )
        else
          const SizedBox(height: 3),
      ],
    ),
  );

  Widget metric(String label, String value) => Text.rich(
    TextSpan(
      text: '$label ',
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
