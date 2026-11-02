import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/run_state.dart';
import '../l10n/game_text.dart';
import 'theme.dart';
import 'upgrade_card.dart';

/// Only the arena is covered. HP and the acquired build remain available.
class UpgradeChoices extends StatelessWidget {
  const UpgradeChoices({
    super.key,
    required this.run,
    required this.text,
    required this.onChoose,
    required this.onInspect,
    required this.inspected,
    this.focusNode,
  });
  final RunState run;
  final GameText text;
  final ValueChanged<Upgrade> onChoose;
  final ValueChanged<Upgrade> onInspect;
  final Upgrade? inspected;
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
          padding: const EdgeInsets.all(10),
          child: LayoutBuilder(
            builder: (context, constraints) => Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              text('choicesTitle'),
                              style: const TextStyle(
                                color: darkText,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            'Lv.${run.level}',
                            style: const TextStyle(color: mint, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      if (constraints.maxWidth < 620)
                        Column(
                          children: [
                            for (var i = 0; i < run.choices.length; i++)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: i == run.choices.length - 1 ? 0 : 6,
                                ),
                                child: card(i, horizontal: true),
                              ),
                          ],
                        )
                      else
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < run.choices.length; i++) ...[
                                if (i > 0) const SizedBox(width: 8),
                                Expanded(child: card(i)),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        text('choicesControls'),
                        style: const TextStyle(color: darkMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget card(int index, {bool horizontal = false}) => UpgradeCard(
    focusNode: index == 0 ? focusNode : null,
    upgrade: run.choices[index],
    index: index,
    run: run,
    text: text,
    inspected: inspected == run.choices[index],
    horizontal: horizontal,
    onInspect: () => onInspect(run.choices[index]),
    onChoose: () => onChoose(run.choices[index]),
  );
}
