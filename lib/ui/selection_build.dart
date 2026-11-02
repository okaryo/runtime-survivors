import 'package:flutter/material.dart';

import '../game/run_state.dart';
import '../l10n/game_text.dart';
import 'theme.dart';

class SelectionBuild extends StatelessWidget {
  const SelectionBuild({
    super.key,
    required this.run,
    required this.text,
    required this.inspected,
    this.inline = false,
  });
  final RunState run;
  final GameText text;
  final Upgrade? inspected;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final entries = run.upgrades.entries.toList();
    if (inline) {
      return Container(
        key: const Key('selection-build'),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFE9EDE2),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Wrap(
          spacing: 6,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              text('currentBuild'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            if (entries.isEmpty)
              Text(
                text('emptyFeatures'),
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            for (final entry in entries)
              AcquiredUpgrade(
                upgrade: entry.key,
                rank: entry.value,
                text: text,
                highlighted: inspected == entry.key,
                inline: true,
              ),
          ],
        ),
      );
    }
    return Container(
      key: const Key('selection-build'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE9EDE2),
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text('currentBuild'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            text('inspectHint'),
            style: const TextStyle(fontSize: 11, color: muted),
          ),
          for (final feature in [true, false]) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  feature ? Icons.auto_awesome : Icons.memory,
                  size: 13,
                  color: feature ? featureColor : infraColor,
                ),
                const SizedBox(width: 6),
                Text(
                  text(feature ? 'featureShort' : 'infraShort'),
                  style: TextStyle(
                    fontSize: 12,
                    color: feature ? featureColor : infraColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (!entries.any((e) => e.key.isFeature == feature))
              Text(
                text(feature ? 'emptyFeatures' : 'emptyInfra'),
                style: const TextStyle(fontSize: 12, height: 1.5, color: muted),
              ),
            for (final entry in entries.where(
              (e) => e.key.isFeature == feature,
            ))
              AcquiredUpgrade(
                upgrade: entry.key,
                rank: entry.value,
                text: text,
                highlighted: inspected == entry.key,
              ),
          ],
        ],
      ),
    );
  }
}

class AcquiredUpgrade extends StatelessWidget {
  const AcquiredUpgrade({
    super.key,
    required this.upgrade,
    required this.rank,
    required this.text,
    required this.highlighted,
    this.inline = false,
  });
  final Upgrade upgrade;
  final int rank;
  final GameText text;
  final bool highlighted;
  final bool inline;
  @override
  Widget build(BuildContext context) {
    final color = upgrade.isFeature ? featureColor : infraColor;
    final label = Text(
      text.shortTitle(upgrade),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        color: ink,
        fontWeight: highlighted ? FontWeight.w800 : FontWeight.normal,
      ),
    );
    return Tooltip(
      message: '${text.title(upgrade)} Lv.$rank\n${text.description(upgrade)}',
      child: Container(
        key: Key('acquired-${upgrade.name}'),
        margin: EdgeInsets.only(bottom: inline ? 0 : 3),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: highlighted ? color.withValues(alpha: 0.12) : null,
          border: Border.all(color: highlighted ? color : line),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: inline ? MainAxisSize.min : MainAxisSize.max,
          children: [
            if (!inline) ...[
              SizedBox(
                width: 25,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    upgrade.symbol,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            if (inline) label else Expanded(child: label),
            const SizedBox(width: 6),
            Text(
              highlighted ? '$rank → ${rank + 1}' : 'Lv.$rank',
              style: TextStyle(
                fontSize: 11,
                color: highlighted ? color : muted,
                fontWeight: highlighted ? FontWeight.w800 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
