import 'package:betterhome/data/models.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/screens/chores_screen.dart';
import 'package:betterhome/ui/screens/create_household_screen.dart';
import 'package:betterhome/ui/screens/delete_account_screen.dart';
import 'package:betterhome/ui/screens/household_detail_screen.dart';
import 'package:betterhome/ui/screens/leaderboard_screen.dart';
import 'package:betterhome/ui/screens/lists_screen.dart';
import 'package:betterhome/ui/widgets/household_switcher.dart';
import 'package:betterhome/ui/widgets/notifications_bell.dart';
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
  late Future<List<Household>> _future;
  _Tab _tab = _Tab.allChores;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = widget.session.repository.listHouseholds().then((households) {
      widget.session.ensureSelection(households);
      return households;
    });
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
      setState(_reload);
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
      setState(_reload);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<List<Household>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(actions: _actions(l10n)),
            body: Center(child: Text(l10n.loading)),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(actions: _actions(l10n)),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.errorGeneric),
                  TextButton(
                    onPressed: () => setState(_reload),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          );
        }
        final households = snapshot.data ?? const <Household>[];
        final current = households
            .where((h) => h.id == widget.session.selectedHouseholdId)
            .firstOrNull;
        if (current == null) {
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
