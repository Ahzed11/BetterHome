import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Shown while nobody is signed in. [busy] covers the browser round trip to the identity provider.
class SignInScreen extends StatelessWidget {
  const SignInScreen({
    super.key,
    required this.onSignIn,
    this.busy = false,
    this.failed = false,
  });

  final VoidCallback onSignIn;
  final bool busy;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(AppTokens.spaceLg),
              children: [
                Text(
                  l10n.signInTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppTokens.spaceMd),
                Text(l10n.signInSubtitle),
                const SizedBox(height: AppTokens.spaceLg),
                if (failed) ...[
                  Text(
                    l10n.signInFailed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceMd),
                ],
                FilledButton(
                  onPressed: busy ? null : onSignIn,
                  child: Text(busy ? l10n.signingIn : l10n.signInButton),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
