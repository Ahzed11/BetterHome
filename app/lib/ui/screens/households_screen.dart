import 'package:betterhome/data/models.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/screens/create_household_screen.dart';
import 'package:betterhome/ui/screens/household_detail_screen.dart';
import 'package:betterhome/ui/widgets/notifications_bell.dart';
import 'package:flutter/material.dart';

class HouseholdsScreen extends StatefulWidget {
  const HouseholdsScreen({super.key, required this.session, this.onSignOut});

  final AppSession session;

  /// Shown as a sign-out action when the app signs in with an identity provider.
  final VoidCallback? onSignOut;

  @override
  State<HouseholdsScreen> createState() => _HouseholdsScreenState();
}

class _HouseholdsScreenState extends State<HouseholdsScreen> {
  late Future<List<Household>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = widget.session.repository.listHouseholds();
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<Household>(
      MaterialPageRoute(
        builder: (_) => CreateHouseholdScreen(session: widget.session),
      ),
    );
    if (created != null && mounted) {
      setState(_reload);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.householdsTitle),
        actions: [
          NotificationsBell(session: widget.session),
          if (widget.onSignOut != null)
            IconButton(
              tooltip: l10n.signOut,
              icon: const Icon(Icons.logout),
              onPressed: widget.onSignOut,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: Text(l10n.createHousehold),
      ),
      body: FutureBuilder<List<Household>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: Text(l10n.loading));
          }
          if (snapshot.hasError) {
            return Center(
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
            );
          }
          final households = snapshot.data ?? const [];
          if (households.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.spaceLg),
                child: Text(l10n.householdsEmpty, textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppTokens.spaceMd),
            itemCount: households.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppTokens.spaceSm),
            itemBuilder: (context, index) {
              final household = households[index];
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                tileColor: Colors.white,
                title: Text(household.name),
                subtitle: Text(household.timezone),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HouseholdDetailScreen(
                        session: widget.session,
                        householdId: household.id,
                      ),
                    ),
                  );
                  if (mounted) {
                    setState(_reload);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
