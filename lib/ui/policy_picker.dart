import 'package:flutter/material.dart';

import '../game/build.dart';
import '../l10n/game_text.dart';
import 'theme.dart';

class PolicyPicker extends StatelessWidget {
  const PolicyPicker({
    super.key,
    required this.selected,
    required this.text,
    required this.onChanged,
  });
  final TypingPolicy selected;
  final GameText text;
  final ValueChanged<TypingPolicy> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        text('policyTitle'),
        style: const TextStyle(
          color: darkText,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final policy in TypingPolicy.values)
            ChoiceChip(
              key: Key('policy-${policy.name}'),
              selected: selected == policy,
              onSelected: (_) => onChanged(policy),
              label: Text('${policy.index + 1} · ${text.policyName(policy)}'),
              avatar: Icon(
                policy == TypingPolicy.staticTyping
                    ? Icons.verified_outlined
                    : Icons.swap_horiz,
                size: 18,
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        text('policy.${selected.name}.description'),
        style: const TextStyle(color: darkText, fontSize: 15, height: 1.5),
      ),
      const SizedBox(height: 8),
      Text(
        text('policy.${selected.name}.cost'),
        style: const TextStyle(
          color: Color(0xFFFFBC96),
          fontSize: 14,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        text('policyKeys'),
        style: const TextStyle(color: darkMuted, fontSize: 12),
      ),
    ],
  );
}
