import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/main.dart';

void main() {
  testWidgets('start, keyboard pause and resume work without layout errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const RuntimeSurvivorsApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Hello, runtime.'), findsOneWidget);
    await tester.tap(find.text('ランタイムを起動'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('● RUNNING'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('ひと息、つこう。'), findsOneWidget);
    await tester.tap(find.text('処理を再開'));
    await tester.pump();
    expect(find.text('● RUNNING'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('compact screen has a usable start screen', (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const RuntimeSurvivorsApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('ランタイムを起動'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
