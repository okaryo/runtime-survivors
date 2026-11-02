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
    this.onInspect,
    this.focusNode,
    this.inspected = false,
    this.horizontal = false,
  });
  final Upgrade upgrade;
  final int index;
  final RunState run;
  final GameText text;
  final VoidCallback onChoose;
  final VoidCallback? onInspect;
  final FocusNode? focusNode;
  final bool inspected;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final color = upgrade.isFeature ? featureColor : infraColor;
    final comparisons = text.comparisons(run.preview(upgrade));
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final comparison in comparisons)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${comparison.cost ? '⚠ ' : ''}${comparison.label} ',
                  ),
                  TextSpan(
                    text: comparison.values,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              key: Key(
                'preview-${upgrade.name}-${comparisons.indexOf(comparison)}',
              ),
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: comparison.cost ? featureColor : ink,
              ),
            ),
          ),
        if (!comparisons.any((c) => c.cost))
          Text(
            '${text('tradeoff')}: ${text('noTradeoff')}',
            style: const TextStyle(fontSize: 11, height: 1.4, color: muted),
          ),
      ],
    );
    final nameAndSummary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text.title(upgrade),
          style: const TextStyle(
            fontSize: 16,
            height: 1.25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          text.summary(upgrade),
          style: const TextStyle(fontSize: 13, height: 1.45),
        ),
      ],
    );
    return Semantics(
      button: true,
      hint: text.description(upgrade),
      child: Material(
        color: upgrade.isFeature
            ? const Color(0xFFFFF3E5)
            : const Color(0xFFEDF6F1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(upgrade.isFeature ? 12 : 4),
          side: BorderSide(
            color: inspected ? color : color.withValues(alpha: 0.45),
            width: inspected ? 2.5 : 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          focusNode: focusNode,
          onTap: onChoose,
          onHover: (hovering) {
            if (hovering) onInspect?.call();
          },
          onFocusChange: (focused) {
            if (focused) onInspect?.call();
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      upgrade.isFeature ? Icons.auto_awesome : Icons.memory,
                      size: 14,
                      color: color,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        text(upgrade.isFeature ? 'featureBadge' : 'infraBadge'),
                        style: TextStyle(
                          fontSize: 11,
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
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '[${index + 1}]',
                      style: TextStyle(fontSize: 11, color: color),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      triggerMode: TooltipTriggerMode.tap,
                      message:
                          '${text.description(upgrade)}\n${text.tradeoff(upgrade)}',
                      child: Icon(Icons.info_outline, size: 14, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                if (horizontal)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: nameAndSummary),
                      const SizedBox(width: 12),
                      Expanded(flex: 6, child: details),
                    ],
                  )
                else ...[
                  nameAndSummary,
                  const SizedBox(height: 9),
                  details,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
