import 'package:betterhome/data/lists_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/state/read_cache.dart';
import 'package:betterhome/state/reads.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/widgets/add_bar.dart';
import 'package:betterhome/ui/widgets/app_card.dart';
import 'package:betterhome/ui/widgets/app_pill.dart';
import 'package:betterhome/ui/widgets/check_row.dart';
import 'package:betterhome/ui/widgets/guarded.dart';
import 'package:betterhome/ui/widgets/list_options_sheet.dart';
import 'package:betterhome/ui/widgets/pull_to_refresh.dart';
import 'package:betterhome/ui/widgets/round_icon_button.dart';
import 'package:betterhome/ui/widgets/screen_header.dart';
import 'package:betterhome/ui/widgets/section_label.dart';
import 'package:betterhome/ui/widgets/text_prompt.dart';
import 'package:betterhome/ui/widgets/screen_skeletons.dart';
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
  late final CachedRead<List<Checklist>> _lists;
  late final CachedRead<List<Membership>> _members;
  late final CachedRead<Household> _household;

  /// The items of the selected list: one read per list, which has an entry of its own in the cache.
  CachedRead<List<ChecklistItem>>? _items;
  String? _itemsFor;
  String? _selectedId;

  /// Items swiped away: hidden at once, as a swiped row must leave the tree in the same frame,
  /// until the reloaded list no longer has them.
  final Set<String> _removed = {};

  ListsRepository get _repository => widget.session.listsRepository;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    final householdId = widget.householdId;
    _lists = CachedRead.of(
      session.readCache,
      session.listsRead(householdId),
      onChange: _listsChanged,
    );
    _members = CachedRead.of(
      session.readCache,
      session.membersRead(householdId),
      onChange: _changed,
    );
    _household = CachedRead.of(
      session.readCache,
      session.householdRead(householdId),
      onChange: _changed,
    );
    // Lists seen on an earlier visit are there before the first frame.
    _syncSelection();
  }

  @override
  void dispose() {
    _lists.dispose();
    _members.dispose();
    _household.dispose();
    _items?.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  void _listsChanged() {
    _syncSelection();
    _changed();
  }

  String? get _householdName => switch (_household.state) {
    ReadLoaded<Household>(:final data) => data.name,
    _ => null,
  };

  bool get _isAdmin {
    final me = widget.session.profile?.id;
    return switch (_members.state) {
      ReadLoaded<List<Membership>>(:final data) => data.any(
        (m) => m.userId == me && m.role == MembershipRole.admin,
      ),
      _ => false,
    };
  }

  /// Keeps the selection on a list that exists (the first one otherwise), and the items read on
  /// the selected list.
  void _syncSelection() {
    final lists = switch (_lists.state) {
      ReadLoaded<List<Checklist>>(:final data) => data,
      _ => null,
    };
    if (lists == null) {
      return;
    }
    final wanted = _selectedId;
    final id = lists.any((l) => l.id == wanted)
        ? wanted
        : lists.firstOrNull?.id;
    _selectedId = id;
    if (id != _itemsFor) {
      _items?.dispose();
      _itemsFor = id;
      _items = id == null ? null : _openItems(id);
    }
  }

  CachedRead<List<ChecklistItem>> _openItems(String listId) => CachedRead.of(
    widget.session.readCache,
    widget.session.itemsRead(widget.householdId, listId),
    onChange: _changed,
  );

  /// Pull to refresh: every read this screen shows. A request already running is joined.
  Future<bool> _pull() async {
    final answers = await Future.wait([
      _lists.refresh(),
      _members.refresh(),
      _household.refresh(),
      ?_items?.refresh(),
    ]);
    return answers.every((arrived) => arrived);
  }

  void _select(String id) {
    setState(() {
      _selectedId = id;
      _syncSelection();
    });
  }

  /// A failed request is shown, and the items are reloaded so the screen shows the truth.
  /// Returns whether the request succeeded.
  Future<bool> _guard(Future<void> Function() action) async {
    final ok = await runGuarded(context, action);
    if (!ok && mounted) {
      _items?.refreshAfterChange();
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
        _selectedId = created.id;
        _lists.refreshAfterChange();
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
        _lists.refreshAfterChange();
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
        _lists.refreshAfterChange();
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
        _items?.refreshAfterChange();
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
        _items?.refreshAfterChange();
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
        _items?.refreshAfterChange();
      }
    });
  }

  Future<void> _delete(Checklist list, ChecklistItem item) async {
    setState(() => _removed.add(item.id));
    final ok = await _guard(() async {
      await _repository.deleteItem(widget.householdId, list.id, item.id);
      if (mounted) {
        _items?.refreshAfterChange();
      }
    });
    if (!ok && mounted) {
      // A swiped row has to leave the tree for one frame, even when the request failed at once:
      // a dismissed Dismissible cannot stay in it. The row comes back after that frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _removed.remove(item.id));
        }
      });
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
        _items?.refreshAfterChange();
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
    return Builder(
      builder: (context) {
        final state = _lists.state;
        if (state is ReadLoading<List<Checklist>>) {
          return const Scaffold(body: ListsScreenSkeleton());
        }
        if (state is ReadFailed<List<Checklist>>) {
          return Scaffold(
            body: PullToRefresh(
              onRefresh: _pull,
              child: _Message(
                text: l10n.errorGeneric,
                actionLabel: l10n.retry,
                onAction: _lists.refresh,
              ),
            ),
          );
        }
        final lists = switch (state) {
          ReadLoaded<List<Checklist>>(:final data) => data,
          _ => const <Checklist>[],
        };
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
                            items: _items?.state,
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
                child: PullToRefresh(
                  onRefresh: _pull,
                  child: selected == null
                      ? PullableCenter(
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
                          state: _items?.state,
                          removed: _removed,
                          householdName: _householdName,
                          onToggle: (item) => _toggle(selected, item),
                          onDelete: (item) => _delete(selected, item),
                          onReset: () => _reset(selected),
                          onRetry: () => _items?.refresh(),
                        ),
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
  final ReadState<List<ChecklistItem>>? items;
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
            Builder(
              builder: (context) {
                final read = list.id == selectedId ? items : null;
                final open = switch (read) {
                  ReadLoaded<List<ChecklistItem>>(:final data) =>
                    data.where((i) => !i.isChecked).length,
                  _ => 0,
                };
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
    required this.state,
    required this.removed,
    required this.householdName,
    required this.onToggle,
    required this.onDelete,
    required this.onReset,
    required this.onRetry,
  });

  final ReadState<List<ChecklistItem>>? state;
  final Set<String> removed;
  final String? householdName;
  final ValueChanged<ChecklistItem> onToggle;
  final ValueChanged<ChecklistItem> onDelete;
  final VoidCallback onReset;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Builder(
      builder: (context) {
        final data = switch (state) {
          ReadLoaded<List<ChecklistItem>>(:final data) => data,
          _ => null,
        };
        if (data == null) {
          return state is ReadFailed<List<ChecklistItem>>
              ? _Message(
                  text: l10n.errorGeneric,
                  actionLabel: l10n.retry,
                  onAction: onRetry,
                )
              : const Padding(
                  padding: EdgeInsets.all(AppTokens.spaceMd),
                  child: ChecklistSkeleton(),
                );
        }
        final items = [
          for (final item in data)
            if (!removed.contains(item.id)) item,
        ];
        if (items.isEmpty) {
          return _EmptyList(householdName: householdName);
        }
        final open = items.where((i) => !i.isChecked).toList();
        final done = items.where((i) => i.isChecked).toList();
        return ListView(
          physics: pullablePhysics,
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
        physics: pullablePhysics,
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
    return PullableCenter(
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
