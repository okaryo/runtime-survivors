import 'package:flutter/material.dart';

import '../game/run_state.dart';
import '../game/character_painter.dart';
import '../game/enemy_affinities.dart';
import '../l10n/game_text.dart';
import 'theme.dart';
import 'upgrade_icon.dart';

typedef _EncyclopediaEntry = ({
  Widget heading,
  Widget body,
  Widget details,
  Widget? affinity,
});

class EncyclopediaPanel extends StatelessWidget {
  const EncyclopediaPanel({
    super.key,
    required this.text,
    required this.discoveries,
  });
  final GameText text;
  final Set<String> discoveries;

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
        Padding(
          key: const Key('encyclopedia-heading'),
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
                      text('encyclopedia'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      text('encyclopediaHint'),
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 760;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  badge(
                    text('taskKinds'),
                    color: const Color(0xFF3D6081),
                    icon: Icons.hub_outlined,
                  ),
                  const SizedBox(height: 12),
                  _rows(
                    [
                      for (var kind = 0; kind < EnemyType.values.length; kind++)
                        _entry(
                          known: discoveries.contains('enemy.$kind'),
                          title: text('enemy.$kind.title'),
                          description: text('enemy.$kind.description'),
                          details: text('enemy.$kind.type'),
                          affinity: _featureList(EnemyType.values[kind]),
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
                    affinityLabel: text('enemyAffinity'),
                  ),
                  const SizedBox(height: 22),
                  for (final feature in [true, false]) ...[
                    badge(
                      text(feature ? 'feature' : 'infra'),
                      color: feature ? featureColor : infraColor,
                      icon: feature ? Icons.auto_awesome : Icons.memory,
                    ),
                    const SizedBox(height: 12),
                    _rows([
                      for (final upgrade in Upgrade.values.where(
                        (u) => u.isFeature == feature,
                      ))
                        _entry(
                          known: discoveries.contains(
                            'upgrade.${upgrade.name}',
                          ),
                          title: text.title(upgrade),
                          description: text.description(upgrade),
                          details: text.tradeoff(upgrade),
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

  Widget _featureList(EnemyType type) => Column(
    key: Key('enemy-affinity-${type.name}'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (type.compatibleFeatures.isEmpty)
        Text(
          text('noSpecificAffinity'),
          style: const TextStyle(fontSize: 13, color: muted),
        ),
      for (final feature in type.compatibleFeatures)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              UpgradeIcon(upgrade: feature, size: 22),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  text.title(feature),
                  style: const TextStyle(fontSize: 13, color: ink),
                ),
              ),
            ],
          ),
        ),
      if (type == EnemyType.armoredAllocation) ...[
        const SizedBox(height: 4),
        Text(
          text('armorAffinityNote'),
          style: const TextStyle(fontSize: 12, height: 1.5, color: muted),
        ),
      ],
    ],
  );

  _EncyclopediaEntry _entry({
    required bool known,
    required String title,
    required String description,
    required String details,
    Widget? affinity,
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
    affinity: affinity == null
        ? null
        : known
        ? affinity
        : Text(
            text('undiscovered'),
            style: const TextStyle(fontSize: 13, color: muted),
          ),
    details: Text(
      known ? details : text('undiscovered'),
      style: const TextStyle(fontSize: 12, height: 1.6, color: muted),
    ),
  );

  Widget _rows(
    List<_EncyclopediaEntry> entries,
    bool narrow, {
    String? detailLabel,
    String? affinityLabel,
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
                  sectionLabel(detailLabel ?? text('tradeoff')),
                  const SizedBox(height: 4),
                  entry.details,
                  if (affinityLabel != null) ...[
                    const SizedBox(height: 8),
                    sectionLabel(affinityLabel),
                    const SizedBox(height: 4),
                    entry.affinity!,
                  ],
                ],
              ),
            ),
        ],
      );
    }
    return Table(
      columnWidths: affinityLabel == null
          ? const {
              0: FixedColumnWidth(210),
              1: FlexColumnWidth(),
              2: FixedColumnWidth(240),
            }
          : const {
              0: FixedColumnWidth(210),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(),
              3: FlexColumnWidth(1.3),
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
              ?affinityLabel,
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
              for (final cell in [
                entry.heading,
                entry.body,
                entry.details,
                if (affinityLabel != null) entry.affinity!,
              ])
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
