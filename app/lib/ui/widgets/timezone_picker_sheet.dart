import 'dart:math';

import 'package:betterhome/data/timezones.dart';
import 'package:betterhome/l10n/app_localizations.dart';
import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Opens the picker and returns the chosen zone name, or null when closed without a choice.
Future<String?> showTimezonePicker(
  BuildContext context, {
  required String current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppTokens.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => TimezonePickerSheet(current: current),
  );
}

/// A searchable list of the time zones a household can use ([timezoneNames]).
class TimezonePickerSheet extends StatefulWidget {
  const TimezonePickerSheet({super.key, required this.current});

  final String current;

  @override
  State<TimezonePickerSheet> createState() => _TimezonePickerSheetState();
}

class _TimezonePickerSheetState extends State<TimezonePickerSheet> {
  String _query = '';
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  void _search(String value) {
    setState(() => _query = value);
    final scroll = _scroll;
    if (scroll != null && scroll.hasClients) {
      scroll.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final zones = searchTimezones(_query);
    final media = MediaQuery.of(context);
    // Every row has the same height, which grows with the text size, so the list can open on the
    // current zone instead of at "Africa/Abidjan" with the choice out of sight.
    final rowHeight = max(
      AppTokens.minTapTarget,
      media.textScaler.scale(AppTokens.minTapTarget),
    );
    final current = zones.indexOf(widget.current);
    _scroll ??= ScrollController(
      initialScrollOffset: current < 2 ? 0 : (current - 2) * rowHeight,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.75,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceMd,
              0,
              AppTokens.spaceMd,
              AppTokens.spaceMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  container: true,
                  header: true,
                  child: Text(
                    l10n.pickTimezoneTitle,
                    style: AppTypography.display.copyWith(fontSize: 22),
                  ),
                ),
                const SizedBox(height: AppTokens.spaceSm + 4),
                TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: l10n.timezoneSearchHint,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: _search,
                ),
                const SizedBox(height: AppTokens.spaceSm),
                Expanded(
                  child: zones.isEmpty
                      ? Center(
                          child: Text(
                            l10n.timezoneNoMatch,
                            style: AppTypography.bodyMuted,
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          itemExtent: rowHeight,
                          itemCount: zones.length,
                          itemBuilder: (context, index) => _ZoneRow(
                            name: zones[index],
                            selected: zones[index] == widget.current,
                          ),
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

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({required this.name, required this.selected});

  final String name;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      onTap: () => Navigator.pop(context, name),
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          onTap: () => Navigator.pop(context, name),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceSm,
                vertical: AppTokens.spaceSm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: selected
                          ? AppTypography.body.copyWith(
                              color: AppTokens.brand,
                              fontWeight: FontWeight.w700,
                            )
                          : AppTypography.body,
                    ),
                  ),
                  if (selected) const Icon(Icons.check, color: AppTokens.brand),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
