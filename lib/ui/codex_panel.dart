import 'package:flutter/material.dart';

import '../game/run_state.dart';
import '../game/character_painter.dart';
import '../l10n/game_text.dart';
import 'theme.dart';
import 'upgrade_icon.dart';

class CodexPanel extends StatelessWidget {
  const CodexPanel({
    super.key,
    required this.text,
    required this.discoveries,
    required this.expanded,
    required this.onToggle,
  });
  final GameText text;
  final Set<String> discoveries;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFFAFAF5),
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(8),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const Key('codex-toggle'),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.menu_book_outlined, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text('codex'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        expanded ? text('codexPaused') : text('codexHint'),
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 760;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    sectionLabel(text('taskKinds')),
                    const SizedBox(height: 12),
                    rows(
                      [
                        for (var kind = 0; kind < 4; kind++)
                          entry(
                            known: discoveries.contains('enemy.$kind'),
                            title: text('enemy.$kind.title'),
                            description: text('enemy.$kind.description'),
                            details: text('enemy.$kind.type'),
                            unknown: text('unlockEnemy'),
                            icon: SizedBox(
                              width: 42,
                              height: 42,
                              child: CustomPaint(painter: CharacterIcon(kind)),
                            ),
                          ),
                      ],
                      narrow,
                      detailLabel: text('type'),
                    ),
                    const SizedBox(height: 22),
                    for (final feature in [true, false]) ...[
                      badge(
                        text(feature ? 'feature' : 'infra'),
                        color: feature ? featureColor : infraColor,
                        icon: feature ? Icons.auto_awesome : Icons.memory,
                      ),
                      const SizedBox(height: 12),
                      rows([
                        for (final upgrade in Upgrade.values.where(
                          (u) => u.isFeature == feature,
                        ))
                          entry(
                            known: discoveries.contains(
                              'upgrade.${upgrade.name}',
                            ),
                            title: text.title(upgrade),
                            description: text.description(upgrade),
                            details:
                                '${text('tradeoff')}: ${text.tradeoff(upgrade)}',
                            unknown: text('unlockUpgrade'),
                            icon: UpgradeIcon(upgrade: upgrade, size: 42),
                          ),
                      ], narrow),
                      const SizedBox(height: 16),
                    ],
                  ],
                );
              },
            ),
          ),
      ],
    ),
  );

  ({Widget heading, Widget body, Widget details}) entry({
    required bool known,
    required String title,
    required String description,
    required String details,
    required String unknown,
    required Widget icon,
  }) => (
    heading: Row(
      children: [
        SizedBox(
          width: 46,
          height: 46,
          child: Center(
            child: known
                ? FittedBox(fit: BoxFit.scaleDown, child: icon)
                : const Icon(Icons.lock_outline, color: muted, size: 20),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            known ? title : '???',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
    body: Text(
      known ? description : unknown,
      style: const TextStyle(fontSize: 13, height: 1.7, color: muted),
    ),
    details: Text(
      known ? details : text('undiscovered'),
      style: const TextStyle(fontSize: 12, height: 1.6, color: muted),
    ),
  );

  Widget rows(
    List<({Widget heading, Widget body, Widget details})> entries,
    bool narrow, {
    String? detailLabel,
  }) {
    if (narrow) {
      return Column(
        children: [
          for (final entry in entries)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: line)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  entry.heading,
                  const SizedBox(height: 8),
                  entry.body,
                  const SizedBox(height: 6),
                  entry.details,
                ],
              ),
            ),
        ],
      );
    }
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(250),
        1: FlexColumnWidth(),
        2: FixedColumnWidth(240),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: const TableBorder(horizontalInside: BorderSide(color: line)),
      children: [
        TableRow(
          children: [
            for (final label in [
              text('name'),
              text('behavior'),
              detailLabel ?? text('tradeoff'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: sectionLabel(label),
              ),
          ],
        ),
        for (final entry in entries)
          TableRow(
            children: [
              for (final cell in [entry.heading, entry.body, entry.details])
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 18, 12),
                  child: cell,
                ),
            ],
          ),
      ],
    );
  }
}
