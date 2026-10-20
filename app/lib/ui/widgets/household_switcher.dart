import 'package:betterhome/data/models.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// What the person picked in the switcher sheet.
sealed class SwitcherChoice {
  const SwitcherChoice();
}

class SelectHousehold extends SwitcherChoice {
  const SelectHousehold(this.householdId);

  final String householdId;
}

class CreateNewHousehold extends SwitcherChoice {
  const CreateNewHousehold();
}

class OpenHouseholdDetails extends SwitcherChoice {
  const OpenHouseholdDetails();
}

/// The pill at the top of the app showing the current household; tapping it opens the sheet.
class HouseholdSwitcher extends StatelessWidget {
  const HouseholdSwitcher({
    super.key,
    required this.current,
    required this.households,
    required this.onChoice,
  });

  final Household current;
  final List<Household> households;
  final ValueChanged<SwitcherChoice> onChoice;

  Future<void> _open(BuildContext context) async {
    final choice = await showModalBottomSheet<SwitcherChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          HouseholdSheet(current: current, households: households),
    );
    if (choice != null) {
      onChoice(choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.switchHousehold(current.name),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        onTap: () => _open(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppTokens.minTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceSm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTokens.brand,
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  child: SizedBox.square(
                    dimension: AppTokens.pillHeight,
                    child: Icon(
                      Icons.home_outlined,
                      size: 20,
                      color: AppTokens.onBrand,
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.spaceSm + 2),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.householdEyebrow,
                        style: AppTypography.eyebrow.copyWith(fontSize: 12),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              current.name,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.display.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.expand_more,
                            size: 18,
                            color: AppTokens.ink,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The households to switch between, with the actions to create one or manage the current one.
class HouseholdSheet extends StatelessWidget {
  const HouseholdSheet({
    super.key,
    required this.current,
    required this.households,
  });

  final Household current;
  final List<Household> households;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceMd,
          0,
          AppTokens.spaceMd,
          AppTokens.spaceMd,
        ),
        children: [
          for (final household in households)
            ListTile(
              minTileHeight: AppTokens.minTapTarget,
              leading: Icon(
                household.id == current.id
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: household.id == current.id
                    ? AppTokens.brand
                    : AppTokens.controlOutline,
              ),
              title: Text(household.name),
              subtitle: Text(household.timezone),
              selected: household.id == current.id,
              onTap: () =>
                  Navigator.pop(context, SelectHousehold(household.id)),
            ),
          const Divider(),
          ListTile(
            minTileHeight: AppTokens.minTapTarget,
            leading: const Icon(Icons.add),
            title: Text(l10n.createHousehold),
            onTap: () => Navigator.pop(context, const CreateNewHousehold()),
          ),
          ListTile(
            minTileHeight: AppTokens.minTapTarget,
            leading: const Icon(Icons.group_outlined),
            title: Text(l10n.householdDetails),
            onTap: () => Navigator.pop(context, const OpenHouseholdDetails()),
          ),
        ],
      ),
    );
  }
}
