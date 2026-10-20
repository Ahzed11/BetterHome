import 'package:betterhome/ui/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

class _Host extends StatelessWidget {
  const _Host({required this.onShow});

  final Future<void> Function(BuildContext context) onShow;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () => onShow(context),
        child: const Text('show'),
      ),
    ),
  );
}

Future<void> _show(
  WidgetTester tester,
  Future<void> Function(BuildContext context) onShow,
) async {
  await pumpScreen(
    tester,
    home: _Host(onShow: onShow),
    locale: const Locale('en'),
  );
  await tester.tap(find.text('show'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('the toast sits at the top in a rounded dark box', (
    tester,
  ) async {
    await _show(tester, (c) async {
      showAppToast(c, message: 'Saved');
    });

    expect(find.text('Saved'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Saved')).dy, lessThan(100));
    final box = tester.widget<DecoratedBox>(
      find
          .ancestor(of: find.text('Saved'), matching: find.byType(DecoratedBox))
          .last,
    );
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.borderRadius, isNotNull);
    expect(decoration.color, const Color(0xFF12201D));

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('the action button ends the toast and reports it', (
    tester,
  ) async {
    bool? acted;
    await _show(tester, (c) async {
      acted = await showAppToast(c, message: 'Logged', actionLabel: 'Undo');
    });

    await tester.tap(find.text('Undo'));
    await tester.pump();

    expect(acted, isTrue);
    expect(find.text('Logged'), findsNothing);
  });

  testWidgets('a toast that runs out reports no action', (tester) async {
    bool? acted;
    await _show(tester, (c) async {
      acted = await showAppToast(
        c,
        message: 'Logged',
        actionLabel: 'Undo',
        duration: const Duration(seconds: 2),
      );
    });

    await tester.pump(const Duration(seconds: 3));

    expect(acted, isFalse);
    expect(find.text('Logged'), findsNothing);
  });

  testWidgets('a new toast replaces the one on screen', (tester) async {
    await _show(tester, (c) async {
      showAppToast(c, message: 'First');
      showAppToast(c, message: 'Second');
    });

    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
