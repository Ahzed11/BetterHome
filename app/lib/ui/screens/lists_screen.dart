import 'package:betterhome/data/lists_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/widgets/add_field.dart';
import 'package:betterhome/ui/widgets/app_card.dart';
import 'package:betterhome/ui/widgets/app_pill.dart';
import 'package:betterhome/ui/widgets/check_row.dart';
import 'package:betterhome/ui/widgets/guarded.dart';
import 'package:betterhome/ui/widgets/screen_header.dart';
import 'package:betterhome/ui/widgets/section_label.dart';
import 'package:betterhome/ui/widgets/text_prompt.dart';
import 'package:flutter/material.dart';

/// The household's shared checklists (spec section 4, design "Lists"): a pill per list, a field to
/// add items, the open items and the checked ones. Admins create, rename and archive lists; any
/// member adds, checks, unchecks and deletes items or unchecks them all.
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
  Future<void> _guard(Future<void> Function() action) async {
    final ok = await runGuarded(context, action);
    if (!ok && mounted) {
      setState(_reloadItems);
    }
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
    await _guard(() async {
      await _repository.deleteItem(widget.householdId, list.id, item.id);
      if (mounted) {
        setState(_reloadItems);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<List<Checklist>>(
        future: _lists,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: Text(l10n.loading));
          }
          if (snapshot.hasError) {
            return _Message(
              text: l10n.errorGeneric,
              actionLabel: l10n.retry,
              onAction: () => setState(_reloadLists),
            );
          }
          final lists = snapshot.data ?? const <Checklist>[];
          final selected = lists.where((l) => l.id == _selectedId).firstOrNull;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceLg - AppTokens.spaceXs,
              0,
              AppTokens.spaceLg - AppTokens.spaceXs,
              AppTokens.spaceLg,
            ),
            children: [
              ScreenHeader(
                eyebrow: _householdName,
                title: l10n.listsTitle,
                actions: [
                  if (selected != null)
                    AppPill(
                      icon: Icons.restart_alt,
                      label: l10n.resetList,
                      onPressed: () => _reset(selected),
                    ),
                  if (selected != null && _isAdmin)
                    _ListMenu(
                      onRename: () => _rename(selected),
                      onArchive: () => _archive(selected),
                    ),
                ],
              ),
              const SizedBox(height: AppTokens.spaceMd),
              _Pills(
                lists: lists,
                selectedId: _selectedId,
                items: _items,
                canCreate: _isAdmin,
                onSelect: _select,
                onCreate: _create,
              ),
              if (selected == null)
                Padding(
                  padding: const EdgeInsets.only(top: AppTokens.spaceLg),
                  child: Text(
                    l10n.listsEmpty,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMuted,
                  ),
                )
              else ...[
                const SizedBox(height: AppTokens.spaceMd),
                AddField(
                  label: l10n.addItem,
                  hint: l10n.addItemHint,
                  buttonLabel: l10n.addItemButton,
                  onSubmitted: (title) => _add(selected, title),
                ),
                const SizedBox(height: AppTokens.spaceMd),
                _Items(
                  future: _items,
                  onToggle: (item) => _toggle(selected, item),
                  onDelete: (item) => _delete(selected, item),
                  onRetry: () => setState(_reloadItems),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// One pill per list, plus the add pill for admins. The selected pill shows how many items are
/// still open.
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
    return Wrap(
      spacing: AppTokens.spaceSm,
      runSpacing: AppTokens.spaceSm,
      children: [
        for (final list in lists)
          FutureBuilder<List<ChecklistItem>>(
            future: list.id == selectedId ? items : null,
            builder: (context, snapshot) {
              final open = snapshot.data?.where((i) => !i.isChecked).length;
              return AppPill(
                selected: list.id == selectedId,
                label: open == null ? list.title : '${list.title} · $open',
                onPressed: () => onSelect(list.id),
              );
            },
          ),
        if (canCreate) AppAddPill(tooltip: l10n.newList, onPressed: onCreate),
      ],
    );
  }
}

/// The open items in one card and the checked ones in a quieter card below.
class _Items extends StatelessWidget {
  const _Items({
    required this.future,
    required this.onToggle,
    required this.onDelete,
    required this.onRetry,
  });

  final Future<List<ChecklistItem>>? future;
  final ValueChanged<ChecklistItem> onToggle;
  final ValueChanged<ChecklistItem> onDelete;
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
        final items = snapshot.data ?? const <ChecklistItem>[];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppTokens.spaceLg),
            child: Text(
              l10n.itemsEmpty,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMuted,
            ),
          );
        }
        final open = items.where((i) => !i.isChecked).toList();
        final done = items.where((i) => i.isChecked).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (open.isNotEmpty) AppCard(child: _rows(l10n, open)),
            if (done.isNotEmpty) ...[
              const SizedBox(height: AppTokens.spaceMd),
              SectionLabel('${l10n.basketTitle} · ${done.length}'),
              const SizedBox(height: AppTokens.spaceSm),
              AppCard(subdued: true, child: _rows(l10n, done)),
            ],
          ],
        );
      },
    );
  }

  Widget _rows(AppLocalizations l10n, List<ChecklistItem> items) {
    return Column(
      children: [
        for (final item in items)
          CheckRow(
            title: item.title,
            checked: item.isChecked,
            semanticLabel: item.isChecked
                ? l10n.uncheckItem(item.title)
                : l10n.checkItem(item.title),
            onChanged: () => onToggle(item),
            trailing: IconButton(
              tooltip: l10n.deleteItem,
              icon: const Icon(Icons.delete_outline, color: AppTokens.inkMuted),
              onPressed: () => onDelete(item),
            ),
          ),
      ],
    );
  }
}

class _ListMenu extends StatelessWidget {
  const _ListMenu({required this.onRename, required this.onArchive});

  final VoidCallback onRename;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<VoidCallback>(
      tooltip: l10n.listOptions,
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        PopupMenuItem(value: onRename, child: Text(l10n.renameList)),
        PopupMenuItem(value: onArchive, child: Text(l10n.archiveList)),
      ],
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
