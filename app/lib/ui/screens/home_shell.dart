import 'package:betterhome/data/models.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/state/read_cache.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/screens/chores_screen.dart';
import 'package:betterhome/ui/screens/create_household_screen.dart';
import 'package:betterhome/ui/screens/delete_account_screen.dart';
import 'package:betterhome/ui/screens/household_detail_screen.dart';
import 'package:betterhome/ui/screens/leaderboard_screen.dart';
import 'package:betterhome/ui/screens/lists_screen.dart';
import 'package:betterhome/ui/widgets/household_switcher.dart';
import 'package:betterhome/ui/widgets/notifications_bell.dart';
import 'package:betterhome/ui/widgets/screen_skeletons.dart';
import 'package:flutter/material.dart';

enum _Tab { allChores, myChores, leaderboard, lists }

/// The signed-in app: the household switcher at the top and four tabs at the bottom, all showing
/// the selected household.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.session,
    this.onSignOut,
    this.onAccountDeleted,
    this.now = DateTime.now,
  });

  final AppSession session;

  /// Shown as a sign-out action when the app signs in with an identity provider.
  final VoidCallback? onSignOut;

  /// Called after the user deleted their account, to end the session. Shown as a delete-account
  /// action when the app signs in with an identity provider.
  final VoidCallback? onAccountDeleted;

  /// The clock of the chores tabs; golden tests pin it.
  final DateTime Function() now;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final CachedRead<List<Household>> _households;
  _Tab _tab = _Tab.allChores;

  @override
  void initState() {
    super.initState();
    _households = CachedRead(
      cache: widget.session.readCache,
      key: widget.session.readKey('households'),
      fetch: widget.session.repository.listHouseholds,
      onChange: _householdsChanged,
    );
    // Households seen on an earlier visit are there, with their selection, before the first frame.
    if (_households.state case ReadLoaded<List<Household>>(:final data)) {
      widget.session.ensureSelection(data);
    }
  }

  @override
  void dispose() {
    _households.dispose();
    super.dispose();
  }

  void _householdsChanged() {
    // Only a fresh answer settles the selection: while it is on its way, the household the user
    // just made or chose may not be in the old one yet.
    if (_households.state case ReadLoaded<List<Household>>(
      :final data,
      refreshing: false,
    )) {
      widget.session.ensureSelection(data);
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<Household>(
      MaterialPageRoute(
        builder: (_) => CreateHouseholdScreen(session: widget.session),
      ),
    );
    if (created == null || !mounted) {
      return;
    }
    await widget.session.selectHousehold(created.id);
    if (mounted) {
      _households.refreshAfterChange();
    }
  }

  Future<void> _details(String householdId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HouseholdDetailScreen(
          session: widget.session,
          householdId: householdId,
        ),
      ),
    );
    if (mounted) {
      _households.refreshAfterChange();
    }
  }

  Future<void> _choose(SwitcherChoice choice, String currentId) async {
    switch (choice) {
      case SelectHousehold(:final householdId):
        await widget.session.selectHousehold(householdId);
        if (mounted) {
          setState(() {});
        }
      case CreateNewHousehold():
        await _create();
      case OpenHouseholdDetails():
        await _details(currentId);
    }
  }

  void _openDeleteAccount(VoidCallback onDeleted) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            DeleteAccountScreen(session: widget.session, onDeleted: onDeleted),
      ),
    );
  }

  List<Widget> _actions(AppLocalizations l10n) => [
    NotificationsBell(session: widget.session),
    if (widget.onAccountDeleted case final onDeleted?)
      IconButton(
        tooltip: l10n.deleteAccount,
        icon: const Icon(Icons.person_remove_outlined),
        onPressed: () => _openDeleteAccount(onDeleted),
      ),
    if (widget.onSignOut != null)
      IconButton(
        tooltip: l10n.signOut,
        icon: const Icon(Icons.logout),
        onPressed: widget.onSignOut,
      ),
  ];

  Widget _tabBody(String householdId) {
    final key = ValueKey('$householdId/${_tab.name}');
    return switch (_tab) {
      _Tab.allChores => ChoresScreen(
        key: key,
        session: widget.session,
        householdId: householdId,
        now: widget.now,
      ),
      _Tab.myChores => ChoresScreen(
        key: key,
        session: widget.session,
        householdId: householdId,
        mine: true,
        now: widget.now,
      ),
      _Tab.leaderboard => LeaderboardScreen(
        key: key,
        session: widget.session,
        householdId: householdId,
      ),
      _Tab.lists => ListsScreen(
        key: key,
        session: widget.session,
        householdId: householdId,
      ),
    };
  }

  Widget _loadingScaffold(AppLocalizations l10n) => Scaffold(
    appBar: AppBar(actions: _actions(l10n)),
    body: ListView(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      children: const [ChoreListSkeleton()],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Builder(
      builder: (context) {
        final state = _households.state;
        if (state is ReadLoading<List<Household>>) {
          return _loadingScaffold(l10n);
        }
        if (state is ReadFailed<List<Household>>) {
          return Scaffold(
            appBar: AppBar(actions: _actions(l10n)),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.errorGeneric),
                  TextButton(
                    onPressed: _households.refresh,
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          );
        }
        final households = switch (state) {
          ReadLoaded<List<Household>>(:final data) => data,
          _ => const <Household>[],
        };
        final current = households
            .where((h) => h.id == widget.session.selectedHouseholdId)
            .firstOrNull;
        if (current == null) {
          // The household the user just made or chose may not be in the old answer yet.
          if (state is ReadLoaded<List<Household>> && state.refreshing) {
            return _loadingScaffold(l10n);
          }
          return Scaffold(
            appBar: AppBar(actions: _actions(l10n)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.spaceLg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.householdsEmpty, textAlign: TextAlign.center),
                    const SizedBox(height: AppTokens.spaceMd),
                    FilledButton.icon(
                      onPressed: _create,
                      icon: const Icon(Icons.add),
                      label: Text(l10n.createHousehold),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final onChores = _tab == _Tab.allChores;
        return Scaffold(
          // Only the Chores tab has the switcher bar; the other tabs have their own headers.
          appBar: onChores
              ? AppBar(
                  title: HouseholdSwitcher(
                    current: current,
                    households: households,
                    onChoice: (choice) => _choose(choice, current.id),
                  ),
                  actions: _actions(l10n),
                )
              : null,
          body: onChores
              ? _tabBody(current.id)
              : SafeArea(bottom: false, child: _tabBody(current.id)),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab.index,
            onDestinationSelected: (index) =>
                setState(() => _tab = _Tab.values[index]),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.checklist),
                label: l10n.allChores,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                label: l10n.myChores,
              ),
              NavigationDestination(
                icon: const Icon(Icons.emoji_events_outlined),
                label: l10n.leaderboardTitle,
              ),
              NavigationDestination(
                icon: const Icon(Icons.list_alt),
                label: l10n.listsTitle,
              ),
            ],
          ),
        );
      },
    );
  }
}
