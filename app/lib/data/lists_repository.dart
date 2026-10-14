import 'package:betterhome/data/api_mappers.dart';
import 'package:betterhome/data/api_support.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome_api/api.dart' as api;
import 'package:http/http.dart' as http;

class Checklist {
  const Checklist({
    required this.id,
    required this.householdId,
    required this.title,
    this.archivedAt,
  });

  final String id;
  final String householdId;
  final String title;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;
}

class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.listId,
    required this.title,
    required this.position,
    this.completedAt,
  });

  final String id;
  final String listId;
  final String title;
  final int position;
  final DateTime? completedAt;

  bool get isChecked => completedAt != null;
}

/// Shared checklists of a household (spec section 4). Items award no points.
abstract class ListsRepository {
  Future<List<Checklist>> listLists(String householdId);

  Future<Checklist> createList(String householdId, String title);

  Future<Checklist> renameList(String householdId, String listId, String title);

  Future<Checklist> archiveList(String householdId, String listId);

  Future<List<ChecklistItem>> listItems(String householdId, String listId);

  Future<ChecklistItem> addItem(
    String householdId,
    String listId,
    String title,
  );

  Future<ChecklistItem> checkItem(
    String householdId,
    String listId,
    String itemId,
  );

  Future<ChecklistItem> uncheckItem(
    String householdId,
    String listId,
    String itemId,
  );

  Future<void> deleteItem(String householdId, String listId, String itemId);

  /// Unchecks every item of the list.
  Future<List<ChecklistItem>> resetList(String householdId, String listId);
}

class HttpListsRepository implements ListsRepository {
  HttpListsRepository({
    required String baseUrl,
    required String Function() accessToken,
    http.Client? client,
  }) : _client = buildApiClient(
         baseUrl: baseUrl,
         accessToken: accessToken,
         client: client,
       );

  final api.ApiClient _client;

  api.ListsApi get _lists => api.ListsApi(_client);
  api.ItemsApi get _items => api.ItemsApi(_client);

  @override
  Future<List<Checklist>> listLists(String householdId) async {
    final list = await call(() => _lists.listLists(householdId));
    return list.map(checklistFromApi).toList();
  }

  @override
  Future<Checklist> createList(String householdId, String title) async =>
      checklistFromApi(
        await call(
          () => _lists.createList(householdId, api.TitleRequest(title: title)),
        ),
      );

  @override
  Future<Checklist> renameList(
    String householdId,
    String listId,
    String title,
  ) async => checklistFromApi(
    await call(
      () => _lists.renameList(
        householdId,
        listId,
        api.TitleRequest(title: title),
      ),
    ),
  );

  @override
  Future<Checklist> archiveList(String householdId, String listId) async =>
      checklistFromApi(
        await call(() => _lists.archiveList(householdId, listId)),
      );

  @override
  Future<List<ChecklistItem>> listItems(
    String householdId,
    String listId,
  ) async {
    final list = await call(() => _items.listItems(householdId, listId));
    return list.map(checklistItemFromApi).toList();
  }

  @override
  Future<ChecklistItem> addItem(
    String householdId,
    String listId,
    String title,
  ) async => checklistItemFromApi(
    await call(
      () => _items.addItem(householdId, listId, api.TitleRequest(title: title)),
    ),
  );

  @override
  Future<ChecklistItem> checkItem(
    String householdId,
    String listId,
    String itemId,
  ) async => checklistItemFromApi(
    await call(() => _items.checkItem(householdId, itemId, listId)),
  );

  @override
  Future<ChecklistItem> uncheckItem(
    String householdId,
    String listId,
    String itemId,
  ) async => checklistItemFromApi(
    await call(() => _items.uncheckItem(householdId, itemId, listId)),
  );

  @override
  Future<void> deleteItem(String householdId, String listId, String itemId) =>
      callVoid(() => _items.deleteItem(householdId, itemId, listId));

  @override
  Future<List<ChecklistItem>> resetList(
    String householdId,
    String listId,
  ) async {
    final list = await call(() => _items.resetList(householdId, listId));
    return list.map(checklistItemFromApi).toList();
  }
}

/// In-memory repository for widget tests and offline demo mode. Mirrors the service rules the
/// screens rely on: archived lists are hidden, deleted items disappear, positions only grow.
class FakeListsRepository implements ListsRepository {
  final Map<String, List<Checklist>> _lists = {};
  final Map<String, List<ChecklistItem>> _items = {};
  int _sequence = 0;

  String _nextId(String prefix) => '$prefix-${++_sequence}';

  @override
  Future<List<Checklist>> listLists(String householdId) async =>
      List.unmodifiable(
        (_lists[householdId] ?? const <Checklist>[]).where(
          (l) => !l.isArchived,
        ),
      );

  @override
  Future<Checklist> createList(String householdId, String title) async {
    final list = Checklist(
      id: _nextId('list'),
      householdId: householdId,
      title: title,
    );
    _lists.putIfAbsent(householdId, () => []).add(list);
    return list;
  }

  @override
  Future<Checklist> renameList(
    String householdId,
    String listId,
    String title,
  ) async => _replaceList(
    householdId,
    listId,
    (l) => Checklist(
      id: l.id,
      householdId: l.householdId,
      title: title,
      archivedAt: l.archivedAt,
    ),
  );

  @override
  Future<Checklist> archiveList(String householdId, String listId) async =>
      _replaceList(
        householdId,
        listId,
        (l) => Checklist(
          id: l.id,
          householdId: l.householdId,
          title: l.title,
          archivedAt: DateTime.now().toUtc(),
        ),
      );

  Checklist _replaceList(
    String householdId,
    String listId,
    Checklist Function(Checklist) change,
  ) {
    final lists = _lists[householdId] ?? [];
    final index = lists.indexWhere((l) => l.id == listId);
    if (index < 0) {
      throw ApiException('not found', statusCode: 404);
    }
    final updated = change(lists[index]);
    lists[index] = updated;
    return updated;
  }

  @override
  Future<List<ChecklistItem>> listItems(
    String householdId,
    String listId,
  ) async => List.unmodifiable(_items[listId] ?? const <ChecklistItem>[]);

  @override
  Future<ChecklistItem> addItem(
    String householdId,
    String listId,
    String title,
  ) async {
    final items = _items.putIfAbsent(listId, () => []);
    final item = ChecklistItem(
      id: _nextId('item'),
      listId: listId,
      title: title,
      position: items.length,
    );
    items.add(item);
    return item;
  }

  @override
  Future<ChecklistItem> checkItem(
    String householdId,
    String listId,
    String itemId,
  ) async => _replaceItem(listId, itemId, (i) {
    if (i.isChecked) {
      return i;
    }
    return ChecklistItem(
      id: i.id,
      listId: i.listId,
      title: i.title,
      position: i.position,
      completedAt: DateTime.now().toUtc(),
    );
  });

  @override
  Future<ChecklistItem> uncheckItem(
    String householdId,
    String listId,
    String itemId,
  ) async => _replaceItem(
    listId,
    itemId,
    (i) => ChecklistItem(
      id: i.id,
      listId: i.listId,
      title: i.title,
      position: i.position,
    ),
  );

  ChecklistItem _replaceItem(
    String listId,
    String itemId,
    ChecklistItem Function(ChecklistItem) change,
  ) {
    final items = _items[listId] ?? [];
    final index = items.indexWhere((i) => i.id == itemId);
    if (index < 0) {
      throw ApiException('not found', statusCode: 404);
    }
    final updated = change(items[index]);
    items[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteItem(
    String householdId,
    String listId,
    String itemId,
  ) async {
    final items = _items[listId] ?? [];
    if (!items.any((i) => i.id == itemId)) {
      throw ApiException('not found', statusCode: 404);
    }
    items.removeWhere((i) => i.id == itemId);
  }

  @override
  Future<List<ChecklistItem>> resetList(
    String householdId,
    String listId,
  ) async {
    final items = _items[listId] ?? [];
    for (final item in List<ChecklistItem>.of(items)) {
      await uncheckItem(householdId, listId, item.id);
    }
    return listItems(householdId, listId);
  }
}
