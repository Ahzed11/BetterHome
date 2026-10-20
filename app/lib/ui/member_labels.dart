import 'package:betterhome/data/models.dart';
import 'package:betterhome/l10n/app_localizations.dart';

/// How a household member is named on screen: "You" for the signed-in person, otherwise the name
/// the members API gives, and a neutral label when the account no longer has one.
String memberLabel(AppLocalizations l10n, Membership? member, String? meId) {
  if (member != null && member.userId == meId) {
    return l10n.you;
  }
  return member?.displayName ?? l10n.unknownMember;
}
