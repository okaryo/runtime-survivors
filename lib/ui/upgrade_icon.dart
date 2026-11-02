import 'package:flutter/material.dart';

import '../game/run_state.dart';

/// Reuse the same artwork in choices, the acquired build, and the codex.
class UpgradeIcon extends StatelessWidget {
  const UpgradeIcon({super.key, required this.upgrade, this.size = 40});
  final Upgrade upgrade;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/icons/upgrades/${upgrade.name}.png',
    width: size,
    height: size,
    filterQuality: FilterQuality.medium,
    excludeFromSemantics: true,
  );
}
