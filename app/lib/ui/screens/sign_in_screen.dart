import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Shown while nobody is signed in: the green hero of the design's Log in board, then the welcome
/// text and the button. [busy] covers the browser round trip to the identity provider.
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
      body: ListView(
        children: [
          _Hero(name: l10n.appTitle),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.spaceLg,
                  AppTokens.spaceLg + AppTokens.spaceXs,
                  AppTokens.spaceLg,
                  AppTokens.spaceLg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      container: true,
                      header: true,
                      child: Text(
                        l10n.signInTitle,
                        style: AppTypography.display.copyWith(fontSize: 30),
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceXs),
                    Text(
                      l10n.signInSubtitle,
                      style: AppTypography.bodyMuted.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: AppTokens.spaceLg),
                    if (failed) ...[
                      Text(
                        l10n.signInFailed,
                        style: AppTypography.label.copyWith(
                          color: AppTokens.overdueText,
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
        ],
      ),
    );
  }
}

/// The brand block at the top: green, rounded at the bottom, with a white logo tile.
class _Hero extends StatelessWidget {
  const _Hero({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        height: 280,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppTokens.brand,
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(AppTokens.radiusHero),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned(
              right: -60,
              top: -70,
              child: _Blob(size: 220, color: Color(0xFF0E8A7F), round: true),
            ),
            Positioned(
              left: -30,
              bottom: -40,
              child: Transform.rotate(
                angle: 0.31,
                child: const _Blob(size: 140, color: Color(0xFF0A6C63)),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTokens.card,
                    borderRadius: BorderRadius.all(Radius.circular(26)),
                  ),
                  child: SizedBox.square(
                    dimension: 76,
                    child: Icon(
                      Icons.home_outlined,
                      size: 38,
                      color: AppTokens.brand,
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.spaceSm + 6),
                Text(
                  name,
                  style: AppTypography.display.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.onBrand,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color, this.round = false});

  final double size;
  final Color color;
  final bool round;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: round ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: round ? null : BorderRadius.circular(40),
      ),
      child: SizedBox.square(dimension: size),
    );
  }
}
