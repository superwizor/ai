// ignore_for_file: avoid_hardcoded_strings_in_widgets

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superwizor/theme/euphire_theme.dart';
import 'package:superwizor/widgets/euphire_button.dart';
import 'package:superwizor/widgets/euphire_header.dart';

void main() {
  testWidgets('EuphireButton renders text and responds to tap', (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: EuphireTheme.themeData,
        home: Scaffold(
          body: EuphireButton(
            text: 'Test Button',
            onPressed: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Test Button'), findsOneWidget);
    await tester.tap(find.text('Test Button'));
    expect(tapped, isTrue);
  });

  testWidgets('EuphireHeader renders title and subtitle', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EuphireTheme.themeData,
        home: const Scaffold(
          body: EuphireHeader(
            title: 'Test Title',
            subtitle: 'Test Subtitle',
          ),
        ),
      ),
    );

    expect(find.text('Test Title'), findsOneWidget);
    expect(find.text('Test Subtitle'), findsOneWidget);
  });
}
