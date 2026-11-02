import 'package:flutter/material.dart';

/// Keyboard focus uses an outline without tinting the entire choice.
class ChoiceCardSurface extends StatefulWidget {
  const ChoiceCardSurface({
    super.key,
    required this.color,
    required this.borderColor,
    required this.onTap,
    required this.child,
    this.focusNode,
  });

  final Color color;
  final Color borderColor;
  final VoidCallback onTap;
  final Widget child;
  final FocusNode? focusNode;

  @override
  State<ChoiceCardSurface> createState() => _ChoiceCardSurfaceState();
}

class _ChoiceCardSurfaceState extends State<ChoiceCardSurface> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Material(
    color: widget.color,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: widget.borderColor.withValues(alpha: _focused ? 1 : 0.55),
        width: _focused ? 2.5 : 1.2,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      focusNode: widget.focusNode,
      focusColor: Colors.transparent,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onTap: widget.onTap,
      child: widget.child,
    ),
  );
}
