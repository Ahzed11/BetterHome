import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

/// Every design-system building block the screens use, rendered with the app
/// theme: the token swatches, buttons, the text field, the segmented control,
/// the extended floating action button and the rounded card tile.
class _DesignSystemShowcase extends StatelessWidget {
  const _DesignSystemShowcase();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design system')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Action'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        children: [
          const Row(
            children: [
              _Swatch(color: AppTokens.brand, label: 'Brand'),
              SizedBox(width: AppTokens.spaceSm),
              _Swatch(color: AppTokens.overdue, label: 'Overdue'),
              SizedBox(width: AppTokens.spaceSm),
              _Swatch(color: AppTokens.surface, label: 'Surface'),
            ],
          ),
          const SizedBox(height: AppTokens.spaceMd),
          FilledButton(onPressed: () {}, child: const Text('Filled')),
          const SizedBox(height: AppTokens.spaceSm),
          FilledButton.tonal(onPressed: () {}, child: const Text('Tonal')),
          const SizedBox(height: AppTokens.spaceSm),
          OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
          const SizedBox(height: AppTokens.spaceSm),
          TextButton(onPressed: () {}, child: const Text('Text')),
          const SizedBox(height: AppTokens.spaceMd),
          const TextField(decoration: InputDecoration(labelText: 'Field')),
          const SizedBox(height: AppTokens.spaceMd),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('One')),
              ButtonSegment(value: 1, label: Text('Two')),
            ],
            selected: const {0},
            onSelectionChanged: (_) {},
          ),
          const SizedBox(height: AppTokens.spaceMd),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
            tileColor: Colors.white,
            title: const Text('Card tile'),
            subtitle: const Text('Subtitle'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: AppTokens.minTouchTarget * 2,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: AppTokens.brand),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color.computeLuminance() > 0.4
                ? Colors.black
                : AppTokens.onBrand,
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('golden: design system widgets', (tester) async {
    await pumpScreen(
      tester,
      home: const _DesignSystemShowcase(),
      locale: const Locale('en'),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/design_system.png'),
    );
  });

  testWidgets('design system widgets meet the accessibility guidelines', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      home: const _DesignSystemShowcase(),
      locale: const Locale('en'),
    );
    await expectAccessible(tester);
  });

  testWidgets('design system widgets do not overflow at 200% text scale', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      home: const _DesignSystemShowcase(),
      locale: const Locale('en'),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
  });

  test('the minimum touch target token is 44 logical pixels', () {
    expect(AppTokens.minTouchTarget, 44);
  });
}
