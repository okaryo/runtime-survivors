import 'package:flutter/material.dart';

const ink = Color(0xFF243C36);
const muted = Color(0xFF58695E);
const paper = Color(0xFFF4F3EB);
const line = Color(0xFFD5DBCF);
const orange = Color(0xFFAD4925);
const featureColor = Color(0xFF9A421E);
const infraColor = Color(0xFF286258);
const mint = Color(0xFF91E2CA);
const darkText = Color(0xFFEFF5E9);
const darkMuted = Color(0xFFB2C5BB);

final gameTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: paper,
  fontFamily: 'Roboto',
  fontFamilyFallback: const ['RuntimeSansJP'],
  colorScheme: ColorScheme.fromSeed(
    seedColor: ink,
    primary: ink,
    surface: paper,
  ),
  textTheme: ThemeData.light().textTheme.apply(
    fontFamilyFallback: const ['RuntimeSansJP'],
    bodyColor: ink,
    displayColor: ink,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: ink,
      foregroundColor: Colors.white,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
    ),
  ),
);

Widget badge(String label, {Color color = ink, IconData? icon}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.07),
    border: Border.all(color: color.withValues(alpha: 0.3)),
    borderRadius: BorderRadius.circular(5),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
      ],
      Flexible(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  ),
);

Widget sectionLabel(String text) => Text(
  text,
  style: const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: muted,
    letterSpacing: 0.6,
  ),
);
