import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/widgets/add_field.dart';
import 'package:betterhome/ui/widgets/app_card.dart';
import 'package:betterhome/ui/widgets/app_pill.dart';
import 'package:betterhome/ui/widgets/check_row.dart';
import 'package:betterhome/ui/widgets/screen_header.dart';
import 'package:betterhome/ui/widgets/section_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

/// Every reusable widget of the design, in each of its states.
class _Showcase extends StatelessWidget {
  const _Showcase({this.onSubmitted, this.onChecked});

  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onChecked;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        children: [
          ScreenHeader(
            eyebrow: 'Seneffe',
            title: 'Lists',
            actions: [
              AppPill(
                label: 'Uncheck all',
                icon: Icons.restart_alt,
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceMd),
          Wrap(
            spacing: AppTokens.spaceSm,
            children: [
              AppPill(label: 'Groceries · 4', selected: true, onPressed: () {}),
              AppPill(label: 'Packing', onPressed: () {}),
              AppAddPill(tooltip: 'New list', onPressed: () {}),
            ],
          ),
          const SizedBox(height: AppTokens.spaceMd),
          AddField(
            label: 'Add an item',
            hint: 'Add an item…',
            buttonLabel: 'Add',
            onSubmitted: onSubmitted ?? (_) {},
          ),
          const SizedBox(height: AppTokens.spaceMd),
          AppCard(
            child: CheckRow(
              title: 'Milk',
              checked: false,
              semanticLabel: 'Check Milk',
              onChanged: onChecked ?? () {},
            ),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          const SectionLabel('In the basket · 1'),
          const SizedBox(height: AppTokens.spaceSm),
          AppCard(
            subdued: true,
            child: CheckRow(
              title: 'Bread',
              checked: true,
              semanticLabel: 'Uncheck Bread',
              onChanged: () {},
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  for (final locale in baselineLocales) {
    final id = locale.languageCode;

    testWidgets('golden: widgets showcase ($id)', (tester) async {
      await pumpScreen(tester, home: const _Showcase(), locale: locale);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/widgets_showcase_$id.png'),
      );
    });

    testWidgets('accessibility: widgets showcase ($id)', (tester) async {
      await pumpScreen(tester, home: const _Showcase(), locale: locale);
      await expectAccessible(tester);
    });

    testWidgets('200% text scale does not overflow: widgets showcase ($id)', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        home: const _Showcase(),
        locale: locale,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  }

  group('AppPill', () {
    testWidgets('keeps a 48 px tap target and reports its selection', (
      tester,
    ) async {
      var pressed = 0;
      final handle = tester.ensureSemantics();
      await pumpScreen(
        tester,
        home: Scaffold(
          body: Center(
            child: AppPill(
              label: 'Packing',
              selected: true,
              onPressed: () => pressed++,
            ),
          ),
        ),
        locale: const Locale('en'),
      );

      expect(
        tester.getSize(find.byType(AppPill)).height,
        greaterThanOrEqualTo(AppTokens.minTapTarget),
      );
      expect(
        tester.getSemantics(find.byType(AppPill)),
        isSemantics(
          label: 'Packing',
          isButton: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.byType(AppPill));
      expect(pressed, 1);
      handle.dispose();
    });
  });

  group('AppAddPill', () {
    testWidgets('is named by its tooltip and can be pressed', (tester) async {
      var pressed = 0;
      await pumpScreen(
        tester,
        home: Scaffold(
          body: Center(
            child: AppAddPill(tooltip: 'New list', onPressed: () => pressed++),
          ),
        ),
        locale: const Locale('en'),
      );

      await tester.tap(find.byTooltip('New list'));

      expect(pressed, 1);
    });
  });

  group('CheckRow', () {
    testWidgets(
      'a tap anywhere on its 48 px box toggles it, and it has a name',
      (tester) async {
        var toggled = 0;
        final handle = tester.ensureSemantics();
        await pumpScreen(
          tester,
          home: Scaffold(body: _Showcase(onChecked: () => toggled++)),
          locale: const Locale('en'),
        );

        final box = find.descendant(
          of: find.byType(CheckRow).first,
          matching: find.byType(InkResponse),
        );
        expect(tester.getSize(box), const Size(48, 48));
        expect(find.bySemanticsLabel('Check Milk'), findsOneWidget);
        await tester.tapAt(tester.getTopLeft(box) + const Offset(2, 2));

        expect(toggled, 1);
        handle.dispose();
      },
    );

    testWidgets('a checked row is struck through, an open one is not', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        home: const Scaffold(body: _Showcase()),
        locale: const Locale('en'),
      );

      expect(
        tester.widget<Text>(find.text('Bread')).style?.decoration,
        TextDecoration.lineThrough,
      );
      expect(tester.widget<Text>(find.text('Milk')).style?.decoration, isNull);
    });
  });

  group('AddField', () {
    testWidgets('submits trimmed text from the button, then clears', (
      tester,
    ) async {
      final submitted = <String>[];
      await pumpScreen(
        tester,
        home: Scaffold(body: _Showcase(onSubmitted: submitted.add)),
        locale: const Locale('en'),
      );

      await tester.enterText(find.byType(TextField), '  Eggs ');
      await tester.tap(find.byTooltip('Add'));
      await tester.pump();

      expect(submitted, ['Eggs']);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
      );
    });

    testWidgets('ignores blank text and submits from the keyboard', (
      tester,
    ) async {
      final submitted = <String>[];
      await pumpScreen(
        tester,
        home: Scaffold(body: _Showcase(onSubmitted: submitted.add)),
        locale: const Locale('en'),
      );

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byTooltip('Add'));
      await tester.enterText(find.byType(TextField), 'Tea');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(submitted, ['Tea']);
    });
  });

  group('SectionLabel and ScreenHeader', () {
    testWidgets('the label is upper case and the title is a header', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(
        tester,
        home: const Scaffold(body: _Showcase()),
        locale: const Locale('en'),
      );

      expect(find.text('IN THE BASKET · 1'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Lists')),
        matchesSemantics(label: 'Lists', isHeader: true),
      );
      handle.dispose();
    });
  });
}
