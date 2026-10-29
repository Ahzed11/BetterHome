import 'dart:async';

import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/lists_repository.dart';
import 'package:betterhome/data/notifications_repository.dart';
import 'package:betterhome/data/scoring_repository.dart';
import 'package:betterhome/data/tasks_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/theme/app_theme.dart';
import 'package:betterhome/ui/screens/chores_screen.dart';
import 'package:betterhome/ui/screens/home_shell.dart';
import 'package:betterhome/ui/screens/household_detail_screen.dart';
import 'package:betterhome/ui/screens/leaderboard_screen.dart';
import 'package:betterhome/ui/screens/lists_screen.dart';
import 'package:betterhome/ui/screens/notification_preferences_screen.dart';
import 'package:betterhome/ui/screens/notifications_screen.dart';
import 'package:betterhome/ui/widgets/screen_skeletons.dart';
import 'package:betterhome/ui/widgets/skeleton.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/repository_doubles.dart';
import 'support/screen_harness.dart';

const _household = 'hh-1';

DateTime _now() => DateTime.utc(2026, 10, 20, 12);

/// Items that never arrive, in a list that exists.
class _PendingItems extends FakeListsRepository {
  @override
  Future<List<ChecklistItem>> listItems(String householdId, String listId) =>
      Completer<List<ChecklistItem>>().future;
}

Future<AppSession> _session({
  HouseholdsRepository? households,
  TasksRepository? tasks,
  ScoringRepository? scoring,
  ListsRepository? lists,
  NotificationsRepository? notifications,
}) async {
  final session = AppSession(
    repository: households ?? FakeHouseholdsRepository(),
  );
  await session.syncProfile(email: 'ada@example.com', givenName: 'Ada');
  await session.repository.createHousehold(name: 'Flat', timezone: 'UTC');
  if (tasks != null) {
    session.useTasksRepository(tasks);
  }
  if (scoring != null) {
    session.useScoringRepository(scoring);
  }
  if (lists != null) {
    session.useListsRepository(lists);
  }
  if (notifications != null) {
    session.useNotificationsRepository(notifications);
  }
  return session;
}

/// Pumps [home] with the system's reduce-motion setting as given and the locale of [locale].
Future<void> _pumpWithMotion(
  WidgetTester tester,
  Widget home, {
  required bool reduceMotion,
  Locale locale = const Locale('en'),
}) {
  return tester.pumpWidget(
    MaterialApp(
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
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child ?? const SizedBox.shrink(),
      ),
      home: home,
    ),
  );
}

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.descendant(
        of: find.byType(Skeleton),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

const _shapes = Skeleton(
  child: Column(
    children: [SkeletonLine(), SkeletonCircle(40), SkeletonBlock(height: 20)],
  ),
);

/// A screen in the state "its first answer has not arrived", the skeleton it must draw, and the
/// same screen with the fake repositories, which answer at once.
class _Case {
  const _Case(this.name, this.pending, this.answered, this.skeleton);

  final String name;
  final Future<Widget> Function() pending;
  final Future<Widget> Function() answered;
  final Type skeleton;
}

final List<_Case> _cases = [
  _Case(
    'the home screen',
    () async => HomeShell(
      session: await _session(households: PendingHouseholdsRepository()),
      now: _now,
    ),
    () async => HomeShell(session: await _session(), now: _now),
    ChoreListSkeleton,
  ),
  _Case(
    'chores',
    () async => ChoresScreen(
      session: await _session(tasks: PendingTasksRepository()),
      householdId: _household,
      now: _now,
    ),
    () async => ChoresScreen(
      session: await _session(),
      householdId: _household,
      now: _now,
    ),
    ChoreListSkeleton,
  ),
  _Case(
    'my chores',
    () async => ChoresScreen(
      session: await _session(tasks: PendingTasksRepository()),
      householdId: _household,
      mine: true,
      now: _now,
    ),
    () async => ChoresScreen(
      session: await _session(),
      householdId: _household,
      mine: true,
      now: _now,
    ),
    ChoreListSkeleton,
  ),
  _Case(
    'the leaderboard',
    () async => LeaderboardScreen(
      session: await _session(scoring: PendingScoringRepository()),
      householdId: _household,
    ),
    () async =>
        LeaderboardScreen(session: await _session(), householdId: _household),
    LeaderboardSkeleton,
  ),
  _Case(
    'the lists',
    () async => ListsScreen(
      session: await _session(lists: PendingListsRepository()),
      householdId: _household,
    ),
    () async => ListsScreen(session: await _session(), householdId: _household),
    ListsScreenSkeleton,
  ),
  _Case(
    'the items of a list',
    () async {
      final lists = _PendingItems();
      await lists.createList(_household, 'Weekly shop');
      return ListsScreen(
        session: await _session(lists: lists),
        householdId: _household,
      );
    },
    () async {
      final session = await _session();
      await session.listsRepository.createList(_household, 'Weekly shop');
      return ListsScreen(session: session, householdId: _household);
    },
    ChecklistSkeleton,
  ),
  _Case(
    'the inbox',
    () async => NotificationsScreen(
      session: await _session(notifications: PendingNotificationsRepository()),
    ),
    () async => NotificationsScreen(session: await _session()),
    NotificationsSkeleton,
  ),
  _Case(
    'the notification settings',
    () async => NotificationPreferencesScreen(
      session: await _session(notifications: PendingNotificationsRepository()),
    ),
    () async => NotificationPreferencesScreen(session: await _session()),
    SettingsSkeleton,
  ),
  _Case(
    'the household',
    () async => HouseholdDetailScreen(
      session: await _session(households: PendingHouseholdsRepository()),
      householdId: _household,
    ),
    () async => HouseholdDetailScreen(
      session: await _session(),
      householdId: _household,
    ),
    HouseholdSkeleton,
  ),
];

void main() {
  group('Skeleton', () {
    testWidgets('is one "Loading…" for screen readers and hides its shapes', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(
        tester,
        home: const Scaffold(body: _shapes),
        locale: const Locale('en'),
      );

      final node = tester.getSemantics(find.byType(Skeleton));
      var children = 0;
      node.visitChildren((_) {
        children++;
        return true;
      });

      expect(node.label, 'Loading…');
      expect(children, 0);
      handle.dispose();
    });

    testWidgets('says "Chargement…" in French', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(
        tester,
        home: const Scaffold(body: _shapes),
        locale: const Locale('fr'),
      );

      expect(tester.getSemantics(find.byType(Skeleton)).label, 'Chargement…');
      handle.dispose();
    });

    testWidgets('pulses slowly when motion is allowed', (tester) async {
      await _pumpWithMotion(
        tester,
        const Scaffold(body: _shapes),
        reduceMotion: false,
      );
      final start = _opacity(tester);
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pump(const Duration(milliseconds: 700));
      final middle = _opacity(tester);
      await tester.pump(const Duration(milliseconds: 700));
      final end = _opacity(tester);

      expect(start, closeTo(0.5, 0.01));
      expect(middle, greaterThan(start));
      expect(end, closeTo(1, 0.01));
      expect(start, greaterThanOrEqualTo(0.5));
    });

    testWidgets('stands still, fully drawn, when the system reduces motion', (
      tester,
    ) async {
      await _pumpWithMotion(
        tester,
        const Scaffold(body: _shapes),
        reduceMotion: true,
      );

      expect(_opacity(tester), 1);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(_opacity(tester), 1);
    });

    testWidgets('stops when reduce motion is switched on while it shows', (
      tester,
    ) async {
      await _pumpWithMotion(
        tester,
        const Scaffold(body: _shapes),
        reduceMotion: false,
      );
      expect(tester.hasRunningAnimations, isTrue);

      await _pumpWithMotion(
        tester,
        const Scaffold(body: _shapes),
        reduceMotion: true,
      );
      // Settles only if nothing animates any more (the theme's own change is over in 200 ms).
      await tester.pumpAndSettle();

      expect(tester.hasRunningAnimations, isFalse);
      expect(_opacity(tester), 1);
    });
  });

  for (final locale in const [Locale('en'), Locale('fr')]) {
    final loading = locale.languageCode == 'fr' ? 'Chargement…' : 'Loading…';
    group(
      'screens while their first answer is on its way (${locale.languageCode})',
      () {
        for (final c in _cases) {
          testWidgets('${c.name} draws its skeleton, not the word', (
            tester,
          ) async {
            final handle = tester.ensureSemantics();
            await pumpScreen(tester, home: await c.pending(), locale: locale);

            expect(find.byType(c.skeleton), findsOneWidget);
            expect(find.text(loading), findsNothing);
            expect(find.bySemanticsLabel(loading), findsOneWidget);
            handle.dispose();
          });

          testWidgets('${c.name} draws its content once there is some', (
            tester,
          ) async {
            await pumpScreen(tester, home: await c.answered(), locale: locale);

            expect(find.byType(c.skeleton), findsNothing);
            expect(find.byType(Skeleton), findsNothing);
          });
        }
      },
    );
  }

  testWidgets(
    'a screen still loading lets a settled test end (motion reduced)',
    (tester) async {
      await pumpScreen(
        tester,
        home: await _cases[1].pending(),
        locale: const Locale('en'),
      );

      expect(tester.hasRunningAnimations, isFalse);
    },
  );
}
