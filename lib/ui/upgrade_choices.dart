import 'dart:math';

import 'package:flutter/material.dart';

import '../game/run_state.dart';
import '../l10n/game_text.dart';
import 'theme.dart';
import 'upgrade_card.dart';

/// Uses the viewport rather than the smaller arena. Every choice stays visible.
class UpgradeChoices extends StatelessWidget {
  const UpgradeChoices({
    super.key,
    required this.run,
    required this.text,
    required this.onChoose,
    required this.onLanguageToggle,
  });
  final RunState run;
  final GameText text;
  final ValueChanged<Upgrade> onChoose;
  final VoidCallback onLanguageToggle;

  @override
  Widget build(BuildContext context) => BlockSemantics(
    child: ColoredBox(
      key: const Key('upgrade-choices'),
      color: const Color(0xFF102022).withValues(alpha: 0.98),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 760;
              final dense = constraints.maxHeight < 760;
              // Only extreme viewports/text scaling need downscaling; no nested scroll.
              return Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: min(1120, constraints.maxWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${text('level')} ${run.level}',
                                style: const TextStyle(
                                  color: mint,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              key: const Key('choice-language-toggle'),
                              onPressed: onLanguageToggle,
                              icon: const Icon(Icons.translate, size: 17),
                              label: Text(text.isJapanese ? 'English' : '日本語'),
                              style: TextButton.styleFrom(
                                foregroundColor: mint,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          text('choicesTitle'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: darkText,
                            fontSize: dense ? 25 : 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          text('choicesHint'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: darkMuted,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: dense ? 14 : 22),
                        if (narrow)
                          Column(
                            children: [
                              for (var i = 0; i < run.choices.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: card(i, dense: true, compact: true),
                                ),
                            ],
                          )
                        else
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (
                                  var i = 0;
                                  i < run.choices.length;
                                  i++
                                ) ...[
                                  if (i > 0) const SizedBox(width: 12),
                                  Expanded(child: card(i, dense: dense)),
                                ],
                              ],
                            ),
                          ),
                        SizedBox(height: dense ? 10 : 16),
                        Text(
                          text('choicesKeys'),
                          style: const TextStyle(
                            color: darkMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget card(int index, {required bool dense, bool compact = false}) =>
      UpgradeCard(
        upgrade: run.choices[index],
        index: index,
        run: run,
        text: text,
        dense: dense,
        compact: compact,
        onChoose: () => onChoose(run.choices[index]),
      );
}
