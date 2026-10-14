import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/lists_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/lists_screen.dart';
import 'package:betterhome/ui/widgets/check_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screen_harness.dart';

const _household = 'hh-1';

/// A session whose user is the household's admin, or a plain member when [admin] is false.
Future<AppSession> _session({required bool admin}) async {
  final session = AppSession(repository: FakeHouseholdsRepository());
  await session.syncProfile(email: 'ada@example.com', givenName: 'Ada');
  await session.repository.createHousehold(name: 'Flat', timezone: 'UTC');
  if (!admin) {
    session.profile = const UserProfile(
      id: 'someone-else',
      authSubject: 'sub',
      email: 'bob@example.com',
      givenName: 'Bob',
      familyName: '',
      language: 'en',
      timezone: 'UTC',
    );
  }
  return session;
}

Future<void> _open(
  WidgetTester tester,
  AppSession session, {
  Locale locale = const Locale('en'),
}) async {
  await pumpScreen(
    tester,
    home: ListsScreen(session: session, householdId: _household),
    locale: locale,
  );
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).last, text);
  await tester.tap(find.widgetWithText(FilledButton, 'Save'));
  await tester.pumpAndSettle();
}

/// The check box of the row titled [title].
Finder _checkBoxOf(String title) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(CheckRow)),
  matching: find.byType(InkResponse),
);

Future<AppSession> _withList(WidgetTester tester, {bool admin = true}) async {
  final session = await _session(admin: admin);
  final list = await session.listsRepository.createList(
    _household,
    'Weekly shop',
  );
  await session.listsRepository.addItem(_household, list.id, 'Milk');
  await _open(tester, session);
  return session;
}

void main() {
  group('lists', () {
    testWidgets('shows the household name and the lists as pills', (
      tester,
    ) async {
      final session = await _session(admin: true);
      await session.listsRepository.createList(_household, 'Weekly shop');
      await session.listsRepository.createList(_household, 'Packing');
      await _open(tester, session);

      expect(find.text('Flat'), findsOneWidget);
      expect(find.text('Lists'), findsOneWidget);
      expect(find.text('Weekly shop · 0'), findsOneWidget);
      expect(find.text('Packing'), findsOneWidget);
    });

    testWidgets('an admin creates, renames and archives a list', (
      tester,
    ) async {
      final session = await _session(admin: true);
      await _open(tester, session);
      expect(
        find.text('No lists yet. An admin can create one.'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('New list'));
      await tester.pumpAndSettle();
      await _type(tester, 'Weekly shop');
      expect(find.text('Weekly shop · 0'), findsOneWidget);

      await tester.tap(find.byTooltip('List options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await _type(tester, 'Food');
      expect(find.text('Food · 0'), findsOneWidget);

      await tester.tap(find.byTooltip('List options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(find.text('Archive this list?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
      await tester.pumpAndSettle();

      expect(find.text('Food · 0'), findsNothing);
      expect(await session.listsRepository.listLists(_household), isEmpty);
    });

    testWidgets('cancelling the archive keeps the list', (tester) async {
      await _withList(tester);

      await tester.tap(find.byTooltip('List options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Weekly shop · 1'), findsOneWidget);
    });

    testWidgets('a member sees the lists but no admin action', (tester) async {
      await _withList(tester, admin: false);

      expect(find.text('Weekly shop · 1'), findsOneWidget);
      expect(find.byTooltip('New list'), findsNothing);
      expect(find.byTooltip('List options'), findsNothing);
    });

    testWidgets('picking a pill shows that list', (tester) async {
      final session = await _session(admin: true);
      final lists = session.listsRepository;
      final shop = await lists.createList(_household, 'Weekly shop');
      final packing = await lists.createList(_household, 'Packing');
      await lists.addItem(_household, shop.id, 'Milk');
      await lists.addItem(_household, packing.id, 'Socks');
      await _open(tester, session);
      expect(find.text('Milk'), findsOneWidget);

      await tester.tap(find.text('Packing'));
      await tester.pumpAndSettle();

      expect(find.text('Socks'), findsOneWidget);
      expect(find.text('Milk'), findsNothing);
      expect(find.text('Packing · 1'), findsOneWidget);
    });

    testWidgets('shows the error state and retries', (tester) async {
      final session = await _session(admin: true);
      session.useListsRepository(_FlakyLists());
      await _open(tester, session);
      expect(find.text('Something went wrong'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Weekly shop · 0'), findsOneWidget);
    });

    testWidgets('is available in French', (tester) async {
      final session = await _session(admin: true);
      await _open(tester, session, locale: const Locale('fr'));

      expect(find.text('Listes'), findsOneWidget);
      expect(find.byTooltip('Nouvelle liste'), findsOneWidget);
      expect(
        find.text('Aucune liste pour le moment. Un admin peut en créer une.'),
        findsOneWidget,
      );
    });
  });

  group('items', () {
    testWidgets('any member adds, checks, unchecks and deletes an item', (
      tester,
    ) async {
      final session = await _withList(tester, admin: false);
      final lists = session.listsRepository;

      await tester.enterText(find.byType(TextField), 'Bread');
      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Bread'), findsOneWidget);
      expect(find.text('Weekly shop · 2'), findsOneWidget);

      await tester.tap(_checkBoxOf('Milk'));
      await tester.pumpAndSettle();
      expect(find.text('IN THE BASKET · 1'), findsOneWidget);
      expect(
        (await lists.listItems(_household, 'list-1')).first.isChecked,
        isTrue,
      );

      await tester.tap(_checkBoxOf('Milk'));
      await tester.pumpAndSettle();
      expect(find.text('IN THE BASKET · 1'), findsNothing);

      await tester.tap(find.byTooltip('Delete item').first);
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsNothing);
      expect(find.text('Bread'), findsOneWidget);
    });

    testWidgets('submitting from the keyboard adds the item', (tester) async {
      final session = await _withList(tester);

      await tester.enterText(find.byType(TextField), 'Eggs');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final items = await session.listsRepository.listItems(
        _household,
        'list-1',
      );
      expect(items.map((i) => i.title), ['Milk', 'Eggs']);
    });

    testWidgets('two items added one after the other both arrive', (
      tester,
    ) async {
      final session = await _session(admin: true);
      final slow = _SlowLists();
      session.useListsRepository(slow);
      await slow.createList(_household, 'Weekly shop');
      await _open(tester, session);

      for (final title in ['Milk', 'Bread']) {
        await tester.enterText(find.byType(TextField), title);
        await tester.tap(find.byTooltip('Add'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
      }

      expect((await slow.itemsNow('list-1')).map((i) => i.title), [
        'Milk',
        'Bread',
      ]);
      expect(find.text('Bread'), findsOneWidget);
    });

    testWidgets('a failed request is shown and the list stays as it was', (
      tester,
    ) async {
      final session = await _session(admin: true);
      final rejecting = _RejectingAdd();
      session.useListsRepository(rejecting);
      await rejecting.createList(_household, 'Weekly shop');
      await _open(tester, session);

      await tester.enterText(find.byType(TextField), 'Milk');
      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Milk'), findsNothing);
    });

    testWidgets('a blank item is not added', (tester) async {
      final session = await _withList(tester);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();

      expect(
        await session.listsRepository.listItems(_household, 'list-1'),
        hasLength(1),
      );
    });

    testWidgets('uncheck all asks first, then unchecks every item', (
      tester,
    ) async {
      final session = await _withList(tester);
      await tester.tap(_checkBoxOf('Milk'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Uncheck all'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      var items = await session.listsRepository.listItems(_household, 'list-1');
      expect(items.single.isChecked, isTrue);

      await tester.tap(find.text('Uncheck all'));
      await tester.pumpAndSettle();
      expect(find.text('Uncheck every item?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Uncheck all'));
      await tester.pumpAndSettle();

      items = await session.listsRepository.listItems(_household, 'list-1');
      expect(items.single.isChecked, isFalse);
    });
  });
}

/// Fails once, then behaves like the fake.
class _FlakyLists extends FakeListsRepository {
  bool _failed = false;

  @override
  Future<List<Checklist>> listLists(String householdId) async {
    if (!_failed) {
      _failed = true;
      throw ApiException('boom', statusCode: 500);
    }
    await createList(householdId, 'Weekly shop');
    return super.listLists(householdId);
  }
}

/// Answers item calls after a delay, as a network would.
class _SlowLists extends FakeListsRepository {
  /// What is stored, without the delay.
  Future<List<ChecklistItem>> itemsNow(String listId) =>
      super.listItems(_household, listId);

  Future<T> _later<T>(Future<T> value) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return value;
  }

  @override
  Future<ChecklistItem> addItem(
    String householdId,
    String listId,
    String title,
  ) => _later(super.addItem(householdId, listId, title));

  @override
  Future<List<ChecklistItem>> listItems(String householdId, String listId) =>
      _later(super.listItems(householdId, listId));
}

/// Refuses to add items.
class _RejectingAdd extends FakeListsRepository {
  @override
  Future<ChecklistItem> addItem(
    String householdId,
    String listId,
    String title,
  ) async => throw ApiException('boom', statusCode: 500);
}
