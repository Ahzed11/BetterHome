import 'package:betterhome/auth/auth_service.dart';
import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/theme/app_theme.dart';
import 'package:betterhome/ui/screens/home_shell.dart';
import 'package:betterhome/ui/screens/profile_sync_screen.dart';
import 'package:betterhome/ui/screens/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class BetterHomeApp extends StatefulWidget {
  const BetterHomeApp({
    super.key,
    required this.session,
    this.auth,
    this.initialLocale,
    this.serverHost,
    this.onChangeServer,
  });

  final AppSession session;

  /// Signs the user in with the identity provider. Without it the app runs in demo mode.
  final AuthService? auth;
  final Locale? initialLocale;

  /// The server the app talks to, shown on the sign-in screen with a way to change it (T-0115).
  final String? serverHost;
  final VoidCallback? onChangeServer;

  @override
  State<BetterHomeApp> createState() => _BetterHomeAppState();
}

enum _Phase { restoring, signedOut, signingIn, loadingProfile, ready }

class _BetterHomeAppState extends State<BetterHomeApp> {
  bool _synced = false;
  _Phase _phase = _Phase.restoring;
  bool _signInFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.auth != null) {
      _restore();
    }
  }

  Future<void> _restore() async {
    try {
      await _enter(await widget.auth?.restore());
    } on AuthException {
      _set(_Phase.signedOut, failed: true);
    }
  }

  Future<void> _signIn() async {
    _set(_Phase.signingIn);
    try {
      await _enter(await widget.auth?.signIn());
    } on AuthException {
      _set(_Phase.signedOut, failed: true);
    }
  }

  Future<void> _signOut() async {
    try {
      // While the token is still valid. Another user on this phone must not get this user's pushes.
      await widget.session.notificationsRepository.removePushTarget();
    } on ApiException {
      // Offline or the server is down: signing out must still work. The target is replaced at the
      // next registration and removed with the account.
    }
    await _leave();
  }

  Future<void> _leave() async {
    // Nothing of this user's household may be shown to whoever signs in next (ADR 0031).
    widget.session.readCache.clear();
    await widget.auth?.signOut();
    _set(_Phase.signedOut);
  }

  Future<void> _enter(AuthUser? user) async {
    if (user == null) {
      _set(_Phase.signedOut);
      return;
    }
    _set(_Phase.loadingProfile);
    await widget.session.loadProfile(
      email: user.email,
      givenName: user.givenName,
      familyName: user.familyName,
      language: _language,
    );
    if (widget.session.profile == null) {
      _set(_Phase.signedOut, failed: true);
    } else {
      _set(_Phase.ready);
    }
  }

  void _set(_Phase phase, {bool failed = false}) {
    if (mounted) {
      setState(() {
        _phase = phase;
        _signInFailed = failed;
      });
    }
  }

  String get _language {
    final code =
        widget.initialLocale?.languageCode ??
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return code == 'fr' ? 'fr' : 'en';
  }

  Widget _home() {
    if (widget.auth == null) {
      return _synced
          ? HomeShell(
              session: widget.session,
              onAccountDeleted: () {
                widget.session.readCache.clear();
                setState(() => _synced = false);
              },
            )
          : _demoProfileScreen();
    }
    return switch (_phase) {
      _Phase.restoring || _Phase.loadingProfile => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      _Phase.signedOut || _Phase.signingIn => SignInScreen(
        onSignIn: _signIn,
        busy: _phase == _Phase.signingIn,
        failed: _signInFailed,
        serverHost: widget.serverHost,
        onChangeServer: widget.onChangeServer,
      ),
      _Phase.ready => HomeShell(
        session: widget.session,
        onSignOut: _signOut,
        onAccountDeleted: _leave,
      ),
    };
  }

  Widget _demoProfileScreen() {
    return ProfileSyncScreen(
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
    );
  }

  @override
  Widget build(BuildContext context) =>
      buildAppMaterial(locale: widget.initialLocale, home: _home());
}

/// The app's theme and localizations around [home]; the setup screen shares them with the app.
MaterialApp buildAppMaterial({required Widget home, Locale? locale}) {
  return MaterialApp(
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    theme: buildAppTheme(),
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}
