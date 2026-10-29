import 'package:betterhome/data/lists_repository.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/state/read_cache.dart';
import 'package:betterhome/state/reads.dart';

/// Loads the other tabs of [householdId] behind the first one, so that their first visit has data
/// in its first frame (ADR 0031). It is called once the first tab has its answer, so these
/// requests come after the visible tab's own and never hold it up.
///
/// The tabs are filled one after the other, in the order of the tab bar, each with the requests
/// it needs together: a handful of requests at a time on a small server. An entry that already
/// has an answer is left alone, as the screen refreshes it when it is opened. A request that
/// fails is dropped: the cache handles a failed request itself (`ApiException`, by name), leaves
/// the entry without an answer and says nothing, and the screen asks again when it is opened.
///
/// [wanted] says whether the household and the user are still the ones this is for. It is
/// checked between the tabs, so a household switch or a sign-out stops what has not started; an
/// answer that arrives late is kept under the key of the household it is about, never another.
Future<void> prefetchOtherTabs(
  AppSession session,
  String householdId, {
  required bool Function() wanted,
}) async {
  final cache = session.readCache;
  final members = session.membersRead(householdId);
  final household = session.householdRead(householdId);

  // My chores.
  await Future.wait([
    cache.fill(session.tasksRead(householdId, mine: true)),
    cache.fill(session.weekRead(householdId)),
    cache.fill(members),
    cache.fill(household),
  ]);
  if (!wanted()) {
    return;
  }

  // The leaderboard, on the period it opens on.
  await Future.wait([
    cache.fill(session.leaderboardRead(householdId, defaultScorePeriod)),
    cache.fill(members),
    cache.fill(household),
  ]);
  if (!wanted()) {
    return;
  }

  // The lists, and the items of the first one, which is the one shown.
  final lists = session.listsRead(householdId);
  await cache.fill(lists);
  if (!wanted()) {
    return;
  }
  if (cache.entry<List<Checklist>>(lists.key).value
      case ReadLoaded<List<Checklist>>(:final data) when data.isNotEmpty) {
    await cache.fill(session.itemsRead(householdId, data.first.id));
  }
  if (!wanted()) {
    return;
  }

  // The dot of the bell.
  await cache.fill(session.unreadRead());
}
