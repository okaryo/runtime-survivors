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
    this.focusNode,
  });
  final Upgrade upgrade;
  final int index;
  final RunState run;
  final GameText text;
  final VoidCallback onChoose;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final color = upgrade.isFeature ? featureColor : infraColor;
    final comparisons = text.comparisons(run.preview(upgrade));
    return Material(
      color: upgrade.isFeature
          ? const Color(0xFFFFF3E5)
          : const Color(0xFFEDF6F1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(upgrade.isFeature ? 12 : 4),
        side: BorderSide(color: color.withValues(alpha: 0.55), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        focusNode: focusNode,
        onTap: onChoose,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    upgrade.isFeature ? Icons.auto_awesome : Icons.memory,
                    size: 18,
                    color: color,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      text(upgrade.isFeature ? 'featureBadge' : 'infraBadge'),
                      style: TextStyle(
                        fontSize: 13,
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    run.rank(upgrade) == 0
                        ? text('newUpgrade')
                        : 'Lv.${run.rank(upgrade)} → ${run.rank(upgrade) + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '[${index + 1}]',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                text.title(upgrade),
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                text.description(upgrade),
                style: const TextStyle(fontSize: 15, height: 1.45),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: line),
              ),
              for (var i = 0; i < comparisons.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == comparisons.length - 1 ? 0 : 6,
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${comparisons[i].label} '),
                        TextSpan(
                          text: comparisons[i].values,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    key: Key('change-${upgrade.name}-$i'),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: comparisons[i].cost ? featureColor : ink,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
