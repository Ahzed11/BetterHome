import 'package:betterhome/ui/widgets/screen_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

void main() {
  testWidgets('the actions sit at the far right of the header', (tester) async {
    await pumpScreen(
      tester,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ScreenHeader(
            eyebrow: 'Flat',
            title: 'Lists',
            actions: [
              for (final key in ['a', 'b'])
                SizedBox(key: ValueKey(key), width: 48, height: 48),
            ],
          ),
        ),
      ),
      locale: const Locale('en'),
    );

    final right = tester.getTopRight(find.byKey(const ValueKey('b'))).dx;
    expect(right, goldenSurface.width - 16);
    expect(
      tester.getTopLeft(find.text('Lists')).dx,
      16,
      reason: 'the title stays at the left',
    );
  });

  testWidgets('without actions the title still fits', (tester) async {
    await pumpScreen(
      tester,
      home: const Scaffold(body: ScreenHeader(title: 'Leaderboard')),
      locale: const Locale('en'),
    );

    expect(find.text('Leaderboard'), findsOneWidget);
  });
}
