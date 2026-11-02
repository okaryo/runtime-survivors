import 'package:flutter/material.dart';

import '../game/run_state.dart';
import '../l10n/game_text.dart';
import 'theme.dart';

/// A stable list of acquired abilities, independent of card focus or hover.
class SelectionBuild extends StatelessWidget {
  const SelectionBuild({super.key, required this.run, required this.text});
  final RunState run;
  final GameText text;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('selection-build'),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFE9EDE2),
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          text('currentBuild'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        for (final feature in [true, false]) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                feature ? Icons.auto_awesome : Icons.memory,
                size: 16,
                color: feature ? featureColor : infraColor,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  text(feature ? 'featureShort' : 'infraShort'),
                  style: TextStyle(
                    fontSize: 13,
                    color: feature ? featureColor : infraColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!run.upgrades.keys.any((u) => u.isFeature == feature))
            Text(
              text(feature ? 'emptyFeatures' : 'emptyInfra'),
              style: const TextStyle(fontSize: 14, height: 1.5, color: muted),
            ),
          for (final entry in run.upgrades.entries.where(
            (e) => e.key.isFeature == feature,
          ))
            Padding(
              key: Key('acquired-${entry.key.name}'),
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      text.shortTitle(entry.key),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.value}',
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
        ],
      ],
    ),
  );
}
