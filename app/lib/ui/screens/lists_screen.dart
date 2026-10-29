import 'package:betterhome/data/lists_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/widgets/add_bar.dart';
import 'package:betterhome/ui/widgets/app_card.dart';
import 'package:betterhome/ui/widgets/app_pill.dart';
import 'package:betterhome/ui/widgets/check_row.dart';
import 'package:betterhome/ui/widgets/guarded.dart';
import 'package:betterhome/ui/widgets/list_options_sheet.dart';
import 'package:betterhome/ui/widgets/round_icon_button.dart';
import 'package:betterhome/ui/widgets/screen_header.dart';
import 'package:betterhome/ui/widgets/section_label.dart';
import 'package:betterhome/ui/widgets/text_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// The household's shared checklists (spec section 4, design "Lists v2"): a pill per list and a
/// button for the list's options, the open items and the checked ones, and a bar docked at the
/// bottom to add items. Admins create, rename and archive lists; any member adds, checks, unchecks
/// and deletes items (a swipe on the row), unchecks them all or removes the checked ones.
class ListsScreen extends StatefulWidget {
  const ListsScreen({
    super.key,
    required this.session,
    required this.householdId,
  });

  final AppSession session;
  final String householdId;

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  late Future<List<Checklist>> _lists;
  Future<List<ChecklistItem>>? _items;
  String? _selectedId;
  String? _householdName;
  bool _isAdmin = false;

  /// Items swiped away: hidden at once, as a swiped row must leave the tree in the same frame,
  /// until the reloaded list no longer has them.
  final Set<String> _removed = {};

  ListsRepository get _repository => widget.session.listsRepository;

  @override
  void initState() {
    super.initState();
    _loadHousehold();
    _reloadLists();
  }

  Future<void> _loadHousehold() async {
    final members = await widget.session.repository.listMembers(
      widget.householdId,
    );
    final household = await widget.session.repository.getHousehold(
      widget.householdId,
    );
    final me = widget.session.profile?.id;
    if (!mounted) {
      return;
    }
    setState(() {
      _householdName = household.name;
      _isAdmin = members.any(
        (m) => m.userId == me && m.role == MembershipRole.admin,
      );
    });
  }

  void _reloadLists({String? select}) {
    _lists = _repository.listLists(widget.householdId).then((lists) {
      final wanted = select ?? _selectedId;
      _selectedId = lists.any((l) => l.id == wanted)
          ? wanted
          : (lists.isEmpty ? null : lists.first.id);
      _reloadItems();
      return lists;
    });
  }

  void _reloadItems() {
    final id = _selectedId;
    _items = id == null ? null : _repository.listItems(widget.householdId, id);
  }

  void _select(String id) {
    setState(() {
      _selectedId = id;
      _reloadItems();
    });
  }

  /// A failed request is shown, and the items are reloaded so the screen shows the truth.
  /// Returns whether the request succeeded.
  Future<bool> _guard(Future<void> Function() action) async {
    final ok = await runGuarded(context, action);
    if (!ok && mounted) {
      setState(_reloadItems);
    }
    return ok;
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final title = await promptForText(
      context,
      title: l10n.createList,
      label: l10n.listName,
    );
    if (title == null) {
      return;
    }
    await _guard(() async {
      final created = await _repository.createList(widget.householdId, title);
      if (mounted) {
        setState(() => _reloadLists(select: created.id));
      }
    });
  }

  Future<void> _rename(Checklist list) async {
    final l10n = AppLocalizations.of(context);
    final title = await promptForText(
      context,
      title: l10n.renameList,
      label: l10n.listName,
      initial: list.title,
    );
    if (title == null) {
      return;
    }
    await _guard(() async {
      await _repository.renameList(widget.householdId, list.id, title);
      if (mounted) {
        setState(_reloadLists);
      }
    });
  }

  Future<void> _archive(Checklist list) async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(
      title: l10n.archiveListConfirmTitle,
      body: l10n.archiveListConfirmBody,
      action: l10n.archiveList,
    )) {
      return;
    }
    await _guard(() async {
      await _repository.archiveList(widget.householdId, list.id);
      if (mounted) {
        setState(_reloadLists);
      }
    });
  }

  Future<void> _reset(Checklist list) async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(
      title: l10n.resetListConfirmTitle,
      body: l10n.resetListConfirmBody,
      action: l10n.resetList,
    )) {
      return;
    }
    await _guard(() async {
      await _repository.resetList(widget.householdId, list.id);
      if (mounted) {
        setState(_reloadItems);
      }
    });
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
  }) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTokens.card,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _add(Checklist list, String title) async {
    await _guard(() async {
      await _repository.addItem(widget.householdId, list.id, title);
      if (mounted) {
        setState(_reloadItems);
      }
    });
  }

  Future<void> _toggle(Checklist list, ChecklistItem item) async {
    await _guard(() async {
      if (item.isChecked) {
        await _repository.uncheckItem(widget.householdId, list.id, item.id);
      } else {
        await _repository.checkItem(widget.householdId, list.id, item.id);
      }
      if (mounted) {
        setState(_reloadItems);
      }
    });
  }

  Future<void> _delete(Checklist list, ChecklistItem item) async {
    setState(() => _removed.add(item.id));
    final ok = await _guard(() async {
      await _repository.deleteItem(widget.householdId, list.id, item.id);
      if (mounted) {
        setState(_reloadItems);
      }
    });
    if (!ok && mounted) {
      setState(() => _removed.remove(item.id));
    }
  }

  Future<void> _removeChecked(Checklist list) async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(
      title: l10n.removeCheckedConfirmTitle,
      body: l10n.removeCheckedConfirmBody,
      action: l10n.removeChecked,
    )) {
      return;
    }
    await _guard(() async {
      final items = await _repository.listItems(widget.householdId, list.id);
      for (final item in items.where((i) => i.isChecked)) {
        await _repository.deleteItem(widget.householdId, list.id, item.id);
      }
      if (mounted) {
        setState(_reloadItems);
      }
    });
  }

  Future<void> _showOptions(Checklist list) async {
    final action = await showListOptions(
      context,
      title: list.title,
      isAdmin: _isAdmin,
    );
    if (action == null || !mounted) {
      return;
    }
    switch (action) {
      case ListAction.reset:
        await _reset(list);
      case ListAction.removeChecked:
        await _removeChecked(list);
      case ListAction.rename:
        await _rename(list);
      case ListAction.archive:
        await _archive(list);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<List<Checklist>>(
      future: _lists,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(body: Center(child: Text(l10n.loading)));
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: _Message(
              text: l10n.errorGeneric,
              actionLabel: l10n.retry,
              onAction: () => setState(_reloadLists),
            ),
          );
        }
        final lists = snapshot.data ?? const <Checklist>[];
        final selected = lists.where((l) => l.id == _selectedId).firstOrNull;
        return Scaffold(
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.spaceMd,
                  AppTokens.spaceMd,
                  AppTokens.spaceMd,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ScreenHeader(
                      eyebrow: _householdName,
                      title: l10n.listsTitle,
                    ),
                    const SizedBox(height: AppTokens.spaceSm + 4),
                    Row(
                      children: [
                        Expanded(
                          child: _Pills(
                            lists: lists,
                            selectedId: _selectedId,
                            items: _items,
                            canCreate: _isAdmin,
                            onSelect: _select,
                            onCreate: _create,
                          ),
                        ),
                        if (selected != null)
                          RoundIconButton(
                            tooltip: l10n.listOptions,
                            icon: Icons.more_horiz,
                            onPressed: () => _showOptions(selected),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: selected == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTokens.spaceLg),
                          child: Text(
                            l10n.listsEmpty,
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMuted,
                          ),
                        ),
                      )
                    : _Items(
                        future: _items,
                        removed: _removed,
                        householdName: _householdName,
                        onToggle: (item) => _toggle(selected, item),
                        onDelete: (item) => _delete(selected, item),
                        onReset: () => _reset(selected),
                        onRetry: () => setState(_reloadItems),
                      ),
              ),
            ],
          ),
          bottomNavigationBar: selected == null
              ? null
              : AddBar(
                  label: l10n.addItem,
                  hint: l10n.addToListHint(selected.title),
                  buttonLabel: l10n.addItemButton,
                  onSubmitted: (title) => _add(selected, title),
                ),
        );
      },
    );
  }
}

/// One pill per list, plus the add pill for admins, in a row that scrolls sideways when the lists
/// do not fit. The selected pill shows how many items are still open, when there are some.
class _Pills extends StatelessWidget {
  const _Pills({
    required this.lists,
    required this.selectedId,
    required this.items,
    required this.canCreate,
    required this.onSelect,
    required this.onCreate,
  });

  final List<Checklist> lists;
  final String? selectedId;
  final Future<List<ChecklistItem>>? items;
  final bool canCreate;
  final ValueChanged<String> onSelect;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final list in lists) ...[
            FutureBuilder<List<ChecklistItem>>(
              future: list.id == selectedId ? items : null,
              builder: (context, snapshot) {
                final open =
                    snapshot.data?.where((i) => !i.isChecked).length ?? 0;
                return AppPill(
                  selected: list.id == selectedId,
                  label: open == 0 ? list.title : '${list.title} · $open',
                  onPressed: () => onSelect(list.id),
                );
              },
            ),
            const SizedBox(width: AppTokens.spaceSm),
          ],
          if (canCreate) AppAddPill(tooltip: l10n.newList, onPressed: onCreate),
        ],
      ),
    );
  }
}

/// The open items in one card, the checked ones in a quieter card below, or a friendly note when
/// the list has no item at all. A row is deleted by swiping it away.
class _Items extends StatelessWidget {
  const _Items({
    required this.future,
    required this.removed,
    required this.householdName,
    required this.onToggle,
    required this.onDelete,
    required this.onReset,
    required this.onRetry,
  });

  final Future<List<ChecklistItem>>? future;
  final Set<String> removed;
  final String? householdName;
  final ValueChanged<ChecklistItem> onToggle;
  final ValueChanged<ChecklistItem> onDelete;
  final VoidCallback onReset;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<List<ChecklistItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: Text(l10n.loading));
        }
        if (snapshot.hasError) {
          return _Message(
            text: l10n.errorGeneric,
            actionLabel: l10n.retry,
            onAction: onRetry,
          );
        }
        final items = [
          for (final item in snapshot.data ?? const <ChecklistItem>[])
            if (!removed.contains(item.id)) item,
        ];
        if (items.isEmpty) {
          return _EmptyList(householdName: householdName);
        }
        final open = items.where((i) => !i.isChecked).toList();
        final done = items.where((i) => i.isChecked).toList();
        return ListView(
          padding: const EdgeInsets.all(AppTokens.spaceMd),
          children: [
            if (open.isNotEmpty)
              AppCard(child: _rows(open, fill: AppTokens.card, dividers: true)),
            if (done.isNotEmpty) ...[
              const SizedBox(height: AppTokens.spaceMd),
              // A Wrap, not a Row: with large text the button goes under the label.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SectionLabel('${l10n.basketTitle} · ${done.length}'),
                  TextButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: Text(l10n.resetList),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTokens.brand,
                      minimumSize: const Size(0, AppTokens.minTapTarget),
                      textStyle: AppTypography.label.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              AppCard(
                subdued: true,
                child: _rows(
                  done,
                  // What the translucent card looks like over the page, since a swiped row needs
                  // an opaque fill.
                  fill: Color.alphaBlend(
                    AppTokens.card.withValues(alpha: 0.6),
                    AppTokens.surface,
                  ),
                  dividers: false,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _rows(
    List<ChecklistItem> items, {
    required Color fill,
    required bool dividers,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      child: Column(
        children: [
          for (final item in items)
            _ItemRow(
              item: item,
              fill: fill,
              divider: dividers,
              onToggle: () => onToggle(item),
              onDelete: () => onDelete(item),
            ),
        ],
      ),
    );
  }
}

/// One item: a check row that is deleted by swiping it to the left. Screen readers get the
/// same action from the row's custom actions.
class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.fill,
    required this.divider,
    required this.onToggle,
    required this.onDelete,
  });

  final ChecklistItem item;
  final Color fill;
  final bool divider;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: AppTokens.overdueTint,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTokens.spaceMd),
        child: const ExcludeSemantics(
          child: Icon(Icons.delete_outline, color: AppTokens.overdueText),
        ),
      ),
      child: Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: l10n.deleteItem): onDelete,
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            border: divider
                ? const Border(bottom: BorderSide(color: AppTokens.divider))
                : null,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppTokens.spaceXs,
              end: AppTokens.spaceMd,
            ),
            child: CheckRow(
              title: item.title,
              checked: item.isChecked,
              semanticLabel: item.isChecked
                  ? l10n.uncheckItem(item.title)
                  : l10n.checkItem(item.title),
              onChanged: onToggle,
            ),
          ),
        ),
      ),
    );
  }
}

/// A list with no item: a round tile, a title and a line saying everyone sees what is added.
class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.householdName});

  final String? householdName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = householdName;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.spaceLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: AppTokens.brandTint,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const ExcludeSemantics(
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        size: 40,
                        color: AppTokens.brand,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceMd - 2),
                  Semantics(
                    container: true,
                    header: true,
                    child: Text(
                      l10n.itemsEmptyTitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.display.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceXs),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(
                      name == null
                          ? l10n.itemsEmptyBodyHome
                          : l10n.itemsEmptyBody(name),
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMuted.copyWith(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
