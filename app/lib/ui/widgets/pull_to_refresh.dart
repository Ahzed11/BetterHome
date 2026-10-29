import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:betterhome/ui/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Pull down on the scrollable [child] to ask for fresh data. The data stays on screen while it
/// is on its way (the indicator is all that moves), and the indicator ends when it has arrived.
/// When it cannot be had the old data stays and a toast says so: the user asked for fresh data,
/// so silence would look like a broken gesture.
///
/// [onRefresh] completes with whether all of it arrived. [child] must be a scrollable that can be
/// pulled even when its content is short (`AlwaysScrollableScrollPhysics`). Screen readers get
/// the same action on the screen, named "Refresh", since they cannot pull.
class PullToRefresh extends StatelessWidget {
  const PullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<bool> Function() onRefresh;
  final Widget child;

  Future<void> _refresh(BuildContext context) async {
    final message = AppLocalizations.of(context).refreshFailed;
    final arrived = await onRefresh();
    if (!arrived && context.mounted) {
      showAppToast(context, message: message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.refresh): () => _refresh(context),
      },
      child: RefreshIndicator(
        color: AppTokens.brand,
        backgroundColor: AppTokens.card,
        onRefresh: () => _refresh(context),
        child: child,
      ),
    );
  }
}

/// The scroll behavior every list under a [PullToRefresh] has: it can be pulled even when it is
/// shorter than the screen.
const ScrollPhysics pullablePhysics = AlwaysScrollableScrollPhysics();

/// [child] in the middle of the room it has, in a scroll view that can be pulled: the error and
/// empty states of a screen, which have no list but must still accept the pull.
class PullableCenter extends StatelessWidget {
  const PullableCenter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: pullablePhysics,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}
