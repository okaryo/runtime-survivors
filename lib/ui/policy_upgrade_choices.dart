import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/run_state.dart';
import '../l10n/game_text.dart';
import 'theme.dart';
import 'choice_card_surface.dart';

/// A bonus policy decision leaves the regular level-up choice queued.
class PolicyUpgradeChoices extends StatelessWidget {
  const PolicyUpgradeChoices({
    super.key,
    required this.run,
    required this.text,
    required this.onChoose,
    required this.safeInsets,
    this.focusNode,
  });
  final RunState run;
  final GameText text;
  final ValueChanged<PolicyUpgrade> onChoose;
  final EdgeInsets safeInsets;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => FocusTraversalGroup(
    child: Focus(
      focusNode: focusNode,
      skipTraversal: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent) {
          final index = [
            LogicalKeyboardKey.digit1,
            LogicalKeyboardKey.digit2,
          ].indexOf(event.logicalKey);
          if (index >= 0) {
            onChoose(PolicyUpgrade.values[index]);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: ColoredBox(
        key: const Key('policy-upgrade-choices'),
        color: const Color(0xFF102022).withValues(alpha: 0.94),
        child: Padding(
          padding:
              safeInsets +
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${text('policyUpgradeTitle')} · ${text.policyName(run.typingPolicy!)}',
                style: const TextStyle(
                  color: darkText,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                text('policyUpgradeHint'),
                style: const TextStyle(color: darkMuted, fontSize: 14),
              ),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: card(PolicyUpgrade.coverage)),
                    const SizedBox(width: 12),
                    Expanded(child: card(PolicyUpgrade.potency)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                text('policyUpgradeControls'),
                style: const TextStyle(color: darkMuted, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget card(PolicyUpgrade upgrade) {
    final coverage = upgrade == PolicyUpgrade.coverage;
    final isStatic = run.typingPolicy == TypingPolicy.staticTyping;
    final description = coverage
        ? text('policyUpgrade.coverage.${run.typingPolicy!.name}')
        : text('policyUpgrade.potency.description');
    final before = coverage
        ? (isStatic ? run.scanTargets : run.policyCoverage)
        : (run.policyBonus * 100).round();
    final after = before + (coverage ? (isStatic ? 2 : 1) : 15);
    final values = text(
      coverage
          ? (isStatic
                ? 'policyUpgrade.coverage.value'
                : 'policyUpgrade.spread.value')
          : 'policyUpgrade.potency.value',
      {'before': before, 'after': after},
    );
    return ChoiceCardSurface(
      key: Key('policy-upgrade-${upgrade.name}'),
      color: const Color(0xFFEDF6F1),
      borderColor: infraColor,
      onTap: () => onChoose(upgrade),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  coverage ? Icons.radar : Icons.verified_outlined,
                  color: infraColor,
                  size: 30,
                ),
                const Spacer(),
                Text(
                  '${upgrade.index + 1}',
                  style: const TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              text('policyUpgrade.${upgrade.name}'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 14),
            Text(
              values,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
