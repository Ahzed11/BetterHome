import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Logical phone size every golden is rendered at (device pixel ratio 1).
const Size goldenSurface = Size(400, 800);

const List<Locale> baselineLocales = [Locale('en'), Locale('fr')];

/// Pumps [home] inside the real app theme and localizations, mirroring
/// `BetterHomeApp` without its profile-sync gate.
///
/// [textScale] is applied through `MediaQuery`, as the operating system's font
/// size setting would be. [settle] false leaves running animations (a toast) alone.
Future<void> pumpScreen(
  WidgetTester tester, {
  required Widget home,
  required Locale locale,
  double textScale = 1,
  bool settle = true,
}) async {
  tester.view
    ..physicalSize = goldenSurface
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: home,
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
}

/// Asserts every accessibility guideline of the baseline on the pumped screen.
Future<void> expectAccessible(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  handle.dispose();
}
