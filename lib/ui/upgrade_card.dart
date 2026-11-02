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
    this.dense = false,
    this.compact = false,
  });
  final Upgrade upgrade;
  final int index;
  final RunState run;
  final GameText text;
  final VoidCallback onChoose;
  final bool dense;
  final bool compact;

  String get rankLabel => text('nextRank', {
    'from': run.rank(upgrade),
    'to': run.rank(upgrade) + 1,
  });
  Widget gap(double size) => SizedBox(height: dense ? size * 0.55 : size);

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
          padding: EdgeInsets.all(
            compact
                ? 12
                : dense
                ? 14
                : 18,
          ),
          child: compact
              ? compactBody(color)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    category(color),
                    gap(17),
                    Row(
                      children: [
                        Text(
                          upgrade.symbol,
                          style: TextStyle(
                            fontSize: dense ? 23 : 27,
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        shortcut(color),
                      ],
                    ),
                    gap(12),
                    Text(
                      text.title(upgrade),
                      style: TextStyle(
                        fontSize: dense ? 17 : 19,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    gap(5),
                    Text(
                      rankLabel,
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                    gap(14),
                    Text(
                      text.description(upgrade),
                      style: TextStyle(
                        fontSize: dense ? 13 : 14,
                        height: dense ? 1.45 : 1.6,
                      ),
                    ),
                    gap(16),
                    sectionLabel(text('change')),
                    gap(6),
                    Text(
                      text.change(upgrade, run),
                      style: TextStyle(
                        fontSize: dense ? 13 : 14,
                        height: 1.5,
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    gap(16),
                    sectionLabel(text('tradeoff')),
                    gap(6),
                    Text(
                      text.tradeoff(upgrade),
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                    gap(20),
                    implement(color),
                  ],
                ),
        ),
      ),
    );
  }

  Widget shortcut(Color color) => Text(
    '[${index + 1}]',
    style: TextStyle(fontFamily: 'monospace', color: color, fontSize: 13),
  );
  Widget category(Color color) => badge(
    text.category(upgrade),
    color: color,
    icon: upgrade.isFeature ? Icons.auto_awesome : Icons.memory,
  );
  Widget implement(Color color) => Row(
    children: [
      Text(
        text('implement'),
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      const Spacer(),
      Icon(Icons.arrow_forward, color: color, size: 18),
    ],
  );

  Widget compactBody(Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              upgrade.symbol,
              style: TextStyle(
                fontSize: 21,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text.title(upgrade),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          shortcut(color),
        ],
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 10,
        runSpacing: 5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          category(color),
          Text(rankLabel, style: const TextStyle(fontSize: 12, color: muted)),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text.description(upgrade),
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text.change(upgrade, run),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${text('tradeoff')}: ${text.tradeoff(upgrade)}',
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      implement(color),
    ],
  );
}
