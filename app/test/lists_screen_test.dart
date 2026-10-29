import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/lists_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/ui/screens/lists_screen.dart';
import 'package:betterhome/ui/widgets/check_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

/// Opens the options sheet of the selected list.
Future<void> _openOptions(WidgetTester tester) async {
  await tester.tap(find.byTooltip('List options'));
  await tester.pumpAndSettle();
}

/// Opens the options sheet and taps the row called [title].
Future<void> _choose(WidgetTester tester, String title) async {
  await _openOptions(tester);
  // The title can also be a button of the screen under the sheet ("Uncheck all").
  await tester.tap(
    find.descendant(of: find.byType(BottomSheet), matching: find.text(title)),
  );
  await tester.pumpAndSettle();
}

/// Swipes the row titled [title] away.
Future<void> _swipeAway(WidgetTester tester, String title) async {
  await tester.drag(find.text(title), const Offset(-600, 0));
  await tester.pumpAndSettle();
}

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
      expect(find.text('Weekly shop'), findsOneWidget);
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
      expect(find.text('Weekly shop'), findsOneWidget);

      await _choose(tester, 'Rename list');
      await _type(tester, 'Food');
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Weekly shop'), findsNothing);

      await _choose(tester, 'Archive list');
      expect(find.text('Archive this list?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Archive list'));
      await tester.pumpAndSettle();

      expect(find.text('Food'), findsNothing);
      expect(await session.listsRepository.listLists(_household), isEmpty);
    });

    testWidgets('cancelling the archive keeps the list', (tester) async {
      await _withList(tester);

      await _choose(tester, 'Archive list');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Weekly shop · 1'), findsOneWidget);
    });

    testWidgets('a member sees the lists but no admin action', (tester) async {
      await _withList(tester, admin: false);

      expect(find.text('Weekly shop · 1'), findsOneWidget);
      expect(find.byTooltip('New list'), findsNothing);

      await _openOptions(tester);
      expect(find.text('Weekly shop'), findsOneWidget); // the sheet's title
      expect(find.text('Uncheck all'), findsOneWidget);
      expect(find.text('Remove checked items'), findsOneWidget);
      expect(find.text('Rename list'), findsNothing);
      expect(find.text('Archive list'), findsNothing);
      expect(find.text('Admin'), findsNothing);
    });

    testWidgets('an admin sees the admin actions, marked as such', (
      tester,
    ) async {
      await _withList(tester);

      await _openOptions(tester);

      expect(find.text('Rename list'), findsOneWidget);
      expect(find.text('Archive list'), findsOneWidget);
      expect(find.text('Admin'), findsNWidgets(2));
      expect(find.text('Everyone sees the new name'), findsOneWidget);
      expect(find.text('Hide it for the whole household'), findsOneWidget);
    });

    testWidgets('closing the options without a choice changes nothing', (
      tester,
    ) async {
      final session = await _withList(tester);

      await _openOptions(tester);
      await tester.tapAt(
        const Offset(200, 40),
      ); // the dimmed page above the sheet
      await tester.pumpAndSettle();

      expect(find.text('Remove checked items'), findsNothing);
      expect(find.text('Weekly shop · 1'), findsOneWidget);
      expect(await session.listsRepository.listLists(_household), hasLength(1));
    });

    testWidgets('the pills scroll sideways when the lists do not fit', (
      tester,
    ) async {
      final session = await _session(admin: true);
      for (var i = 1; i <= 8; i++) {
        await session.listsRepository.createList(_household, 'List number $i');
      }
      await _open(tester, session);

      expect(tester.takeException(), isNull);
      await tester.drag(find.text('List number 1'), const Offset(-800, 0));
      await tester.pumpAndSettle();
      expect(find.text('List number 8'), findsOneWidget);
      expect(find.byTooltip('New list'), findsOneWidget);
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

      // The test font is wide: the second pill starts under the options button until scrolled.
      await tester.ensureVisible(find.text('Packing'));
      await tester.pumpAndSettle();
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

      expect(find.text('Weekly shop'), findsOneWidget);
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

    testWidgets('the options and the empty list are in French', (tester) async {
      final session = await _session(admin: true);
      await session.listsRepository.createList(_household, 'Courses');
      await _open(tester, session, locale: const Locale('fr'));

      expect(find.text('Tout est en stock'), findsOneWidget);
      expect(
        find.text(
          'Ajoutez ci-dessous ce dont vous avez besoin — tout le monde chez Flat le voit.',
        ),
        findsOneWidget,
      );
      expect(find.text('Ajouter à Courses…'), findsOneWidget);

      await tester.tap(find.byTooltip('Options de la liste'));
      await tester.pumpAndSettle();
      expect(find.text('Tout décocher'), findsOneWidget);
      expect(find.text('Retirer les éléments cochés'), findsOneWidget);
      expect(find.text('Renommer la liste'), findsOneWidget);
      expect(find.text('Archiver la liste'), findsOneWidget);
    });
  });

  group('items', () {
    testWidgets('any member adds, checks, unchecks and deletes an item', (
      tester,
    ) async {
      final session = await _withList(tester, admin: false);
      final lists = session.listsRepository;

      expect(find.text('Add to Weekly shop…'), findsOneWidget);
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

      await _swipeAway(tester, 'Milk');
      expect(find.text('Milk'), findsNothing);
      expect(find.text('Bread'), findsOneWidget);
      final left = await lists.listItems(_household, 'list-1');
      expect(left.map((i) => i.title), ['Bread']);
    });

    testWidgets('a checked item is swiped away too', (tester) async {
      final session = await _withList(tester);
      await tester.tap(_checkBoxOf('Milk'));
      await tester.pumpAndSettle();

      await _swipeAway(tester, 'Milk');

      expect(find.text('Milk'), findsNothing);
      expect(
        await session.listsRepository.listItems(_household, 'list-1'),
        isEmpty,
      );
    });

    testWidgets('a swipe to the right does not delete', (tester) async {
      final session = await _withList(tester);

      await tester.drag(find.text('Milk'), const Offset(600, 0));
      await tester.pumpAndSettle();

      expect(find.text('Milk'), findsOneWidget);
      expect(
        await session.listsRepository.listItems(_household, 'list-1'),
        hasLength(1),
      );
    });

    testWidgets('a row offers screen readers a delete action', (tester) async {
      final handle = tester.ensureSemantics();
      await _withList(tester);
      final row = tester.getSemantics(
        find.ancestor(
          of: find.text('Milk'),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Semantics && w.properties.customSemanticsActions != null,
          ),
        ),
      );

      final ids = row.getSemanticsData().customSemanticsActionIds ?? [];

      // Doing the action is the swipe's callback (see the tests above), so only that the row
      // offers it, under its name, is checked here.
      expect(
        [for (final id in ids) CustomSemanticsAction.getAction(id)?.label],
        ['Delete item'],
      );
      handle.dispose();
    });

    testWidgets('a swipe that fails brings the row back', (tester) async {
      final session = await _session(admin: true);
      final failing = _RejectingDelete();
      session.useListsRepository(failing);
      await failing.createList(_household, 'Weekly shop');
      await failing.addItem(_household, 'list-1', 'Milk');
      await _open(tester, session);

      await tester.drag(find.text('Milk'), const Offset(-600, 0));
      // Not settled: the toast that says it failed goes away on its own.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Milk'), findsOneWidget);
    });

    testWidgets('remove checked items asks first, then keeps the open ones', (
      tester,
    ) async {
      final session = await _withList(tester);
      final lists = session.listsRepository;
      await lists.addItem(_household, 'list-1', 'Bread');
      await lists.addItem(_household, 'list-1', 'Eggs');
      for (final item in await lists.listItems(_household, 'list-1')) {
        if (item.title != 'Bread') {
          await lists.checkItem(_household, 'list-1', item.id);
        }
      }
      await tester.tap(find.text('Weekly shop · 1'));
      await tester.pumpAndSettle();
      expect(find.text('IN THE BASKET · 2'), findsOneWidget);

      await _choose(tester, 'Remove checked items');
      expect(find.text('Remove the checked items?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await lists.listItems(_household, 'list-1'), hasLength(3));

      await _choose(tester, 'Remove checked items');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Remove checked items'),
      );
      await tester.pumpAndSettle();

      expect(
        (await lists.listItems(_household, 'list-1')).map((i) => i.title),
        ['Bread'],
      );
      expect(find.text('IN THE BASKET · 2'), findsNothing);
      expect(find.text('Bread'), findsOneWidget);
    });

    testWidgets('a list without an item says everyone sees what is added', (
      tester,
    ) async {
      final session = await _session(admin: true);
      await session.listsRepository.createList(_household, 'Weekly shop');
      await _open(tester, session);

      expect(find.text('All stocked up'), findsOneWidget);
      expect(
        find.text('Add what you need below — everyone in Flat sees it.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'Milk');
      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();

      expect(find.text('All stocked up'), findsNothing);
      expect(find.text('Milk'), findsOneWidget);
    });

    testWidgets('a list whose items are all checked is not the empty list', (
      tester,
    ) async {
      final session = await _withList(tester);
      await tester.tap(_checkBoxOf('Milk'));
      await tester.pumpAndSettle();

      expect(find.text('All stocked up'), findsNothing);
      expect(find.text('IN THE BASKET · 1'), findsOneWidget);
      expect(find.text('Weekly shop'), findsOneWidget); // no count: none open
      expect(
        (await session.listsRepository.listItems(
          _household,
          'list-1',
        )).single.isChecked,
        isTrue,
      );
    });

    testWidgets('uncheck all is also in the options', (tester) async {
      final session = await _withList(tester);
      await tester.tap(_checkBoxOf('Milk'));
      await tester.pumpAndSettle();

      await _choose(tester, 'Uncheck all');
      expect(find.text('Uncheck every item?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Uncheck all'));
      await tester.pumpAndSettle();

      final items = await session.listsRepository.listItems(
        _household,
        'list-1',
      );
      expect(items.single.isChecked, isFalse);
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
      await tester.pump();
      await tester.pump();

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

/// Refuses to delete items.
class _RejectingDelete extends FakeListsRepository {
  @override
  Future<void> deleteItem(
    String householdId,
    String listId,
    String itemId,
  ) async => throw ApiException('boom', statusCode: 500);
}
