import 'package:flutter/material.dart';

import '../game/run_state.dart';
import '../l10n/game_text.dart';
import 'theme.dart';

class UpgradeCard extends StatelessWidget {
  const UpgradeCard({
    super.key,
    required this.upgrade,
    required this.index,
    required this.run,
    required this.text,
    required this.onChoose,
  });
  final Upgrade upgrade;
  final int index;
  final RunState run;
  final GameText text;
  final VoidCallback onChoose;
  @override
  Widget build(BuildContext context) {
    final feature = upgrade.isFeature;
    final color = feature ? featureColor : infraColor;
    return Material(
      color: feature ? const Color(0xFFFFF3E5) : const Color(0xFFEDF6F1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(feature ? 14 : 4),
        side: BorderSide(color: color.withValues(alpha: 0.6), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onChoose,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              badge(
                text.category(upgrade),
                color: color,
                icon: feature ? Icons.auto_awesome : Icons.memory,
              ),
              const SizedBox(height: 17),
              Row(
                children: [
                  Text(
                    upgrade.symbol,
                    style: TextStyle(
                      fontSize: 27,
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '[${index + 1}]',
                    style: TextStyle(fontFamily: 'monospace', color: color),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                text.title(upgrade),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                text('nextRank', {
                  'from': run.rank(upgrade),
                  'to': run.rank(upgrade) + 1,
                }),
                style: const TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 14),
              Text(
                text.description(upgrade),
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 16),
              sectionLabel(text('change')),
              const SizedBox(height: 6),
              Text(
                text.change(upgrade, run),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              sectionLabel(text('tradeoff')),
              const SizedBox(height: 6),
              Text(
                text.tradeoff(upgrade),
                style: const TextStyle(fontSize: 12, height: 1.6),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    text('implement'),
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward, color: color, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
