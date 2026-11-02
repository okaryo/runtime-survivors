import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/run_state.dart';
import '../l10n/game_text.dart';
import 'theme.dart';
import 'upgrade_card.dart';

/// Only the arena is covered. Memory and the acquired build remain available.
class UpgradeChoices extends StatelessWidget {
  const UpgradeChoices({
    super.key,
    required this.run,
    required this.text,
    required this.onChoose,
    this.focusNode,
  });
  final RunState run;
  final GameText text;
  final ValueChanged<Upgrade> onChoose;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => FocusTraversalGroup(
    child: Focus(
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final index = [
            LogicalKeyboardKey.digit1,
            LogicalKeyboardKey.digit2,
            LogicalKeyboardKey.digit3,
          ].indexOf(event.logicalKey);
          if (index >= 0 && index < run.choices.length) {
            onChoose(run.choices[index]);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: ColoredBox(
        key: const Key('upgrade-choices'),
        color: const Color(0xFF102022).withValues(alpha: 0.94),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      text('choicesTitle'),
                      style: const TextStyle(
                        color: darkText,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    text('choicesControls'),
                    style: const TextStyle(color: darkMuted, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth < 620
                    ? Column(
                        children: [
                          for (var i = 0; i < run.choices.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            card(i),
                          ],
                        ],
                      )
                    : IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < run.choices.length; i++) ...[
                              if (i > 0) const SizedBox(width: 12),
                              Expanded(child: card(i)),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget card(int index) => UpgradeCard(
    focusNode: index == 0 ? focusNode : null,
    upgrade: run.choices[index],
    index: index,
    run: run,
    text: text,
    onChoose: () => onChoose(run.choices[index]),
  );
}
