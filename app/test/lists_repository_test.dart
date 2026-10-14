import 'package:betterhome/data/lists_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

const _household = 'hh-1';

void main() {
  test('archived lists disappear and cannot be renamed again by id', () async {
    final repo = FakeListsRepository();
    final list = await repo.createList(_household, 'Groceries');

    await repo.archiveList(_household, list.id);

    expect(await repo.listLists(_household), isEmpty);
    await expectLater(
      repo.renameList(_household, 'unknown', 'x'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
  });

  test('items keep their order, check, uncheck and delete', () async {
    final repo = FakeListsRepository();
    final list = await repo.createList(_household, 'Groceries');
    final milk = await repo.addItem(_household, list.id, 'Milk');
    final bread = await repo.addItem(_household, list.id, 'Bread');

    final checked = await repo.checkItem(_household, list.id, milk.id);
    final again = await repo.checkItem(_household, list.id, milk.id);

    expect(checked.isChecked, isTrue);
    expect(
      again.completedAt,
      checked.completedAt,
      reason: 'checking twice is a no-op',
    );
    expect(
      (await repo.uncheckItem(_household, list.id, milk.id)).isChecked,
      isFalse,
    );

    await repo.deleteItem(_household, list.id, milk.id);
    final items = await repo.listItems(_household, list.id);
    expect(items.map((i) => i.id), [bread.id]);
    await expectLater(
      repo.deleteItem(_household, list.id, milk.id),
      throwsA(isA<ApiException>()),
    );
  });

  test('reset unchecks every item and leaves them in place', () async {
    final repo = FakeListsRepository();
    final list = await repo.createList(_household, 'Packing');
    for (final title in ['Socks', 'Passport']) {
      final item = await repo.addItem(_household, list.id, title);
      await repo.checkItem(_household, list.id, item.id);
    }

    final reset = await repo.resetList(_household, list.id);

    expect(reset.map((i) => i.title), ['Socks', 'Passport']);
    expect(reset.any((i) => i.isChecked), isFalse);
  });
}
