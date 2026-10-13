import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/theme/app_theme.dart';
import 'package:betterhome/ui/screens/households_screen.dart';
import 'package:betterhome/ui/screens/profile_sync_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class BetterHomeApp extends StatefulWidget {
  const BetterHomeApp({super.key, required this.session, this.initialLocale});

  final AppSession session;
  final Locale? initialLocale;

  @override
  State<BetterHomeApp> createState() => _BetterHomeAppState();
}

class _BetterHomeAppState extends State<BetterHomeApp> {
  bool _synced = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildAppTheme(),
      locale: widget.initialLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: _synced
          ? HouseholdsScreen(session: widget.session)
          : ProfileSyncScreen(
              session: widget.session,
              onSynced: () => setState(() => _synced = true),
              onUseDemo: () async {
                widget.session.useRepository(FakeHouseholdsRepository());
                await widget.session.syncProfile(
                  email: 'demo@betterhome.local',
                  givenName: 'Demo',
                  familyName: 'User',
                  language: widget.initialLocale?.languageCode ?? 'en',
                );
                if (mounted) {
                  setState(() => _synced = true);
                }
              },
            ),
    );
  }
}
