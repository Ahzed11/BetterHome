import 'package:betterhome/data/models.dart';
import 'package:flutter/foundation.dart';

/// What a screen knows about one read ([ReadCache]).
sealed class ReadState<T> {
  const ReadState();
}

/// Nothing to show yet: the first request is on its way.
final class ReadLoading<T> extends ReadState<T> {
  const ReadLoading();
}

/// The last answer, shown at once. [refreshing] while a newer one is on its way.
final class ReadLoaded<T> extends ReadState<T> {
  const ReadLoaded(this.data, {this.refreshing = false});

  final T data;
  final bool refreshing;
}

/// The first request failed and there is no older answer to show.
final class ReadFailed<T> extends ReadState<T> {
  const ReadFailed(this.error);

  final ApiException error;
}

/// The state of one cached read, which the screens listening to it redraw from.
class ReadEntry<T> extends ValueNotifier<ReadState<T>> {
  ReadEntry() : super(const ReadLoading());

  /// The request that is running for this entry, shared by everyone who asks meanwhile.
  Future<bool>? _inFlight;

  /// The request that follows [_inFlight] after a change, shared by everyone who asked meanwhile.
  Future<bool>? _followUp;
}

/// The last answer to each read, kept in memory only (ADR 0031), so a screen opened again shows
/// what it showed last time at once and refreshes it in the background.
///
/// A key says what was asked: use [AppSession.readKey], which includes the signed-in user. The
/// cache is emptied when the user changes, at sign-out and at account deletion.
class ReadCache {
  final Map<Object, Object> _entries = {};

  /// The entry of [key], created empty when it is new.
  ReadEntry<T> entry<T>(Object key) {
    final existing = _entries[key];
    if (existing != null) {
      return existing as ReadEntry<T>;
    }
    final created = ReadEntry<T>();
    _entries[key] = created;
    return created;
  }

  /// Asks [fetch] for a fresh answer to [key]. Callers who ask while a request is running share
  /// it. The old answer stays in place while it runs, and when it fails; only a read that never
  /// had an answer ends as [ReadFailed]. Completes with whether a fresh answer arrived, for the
  /// caller who must not act on an old one.
  Future<bool> refresh<T>(Object key, Future<T> Function() fetch) {
    final entry = this.entry<T>(key);
    return entry._inFlight ??= _run(entry, fetch);
  }

  /// Like [refresh], for after a change the user made. A request that is already running may have
  /// read the data before the change, so a new one follows it (one, shared by everyone who asks
  /// meanwhile). With nothing running it is [refresh].
  Future<bool> refreshAfterChange<T>(Object key, Future<T> Function() fetch) {
    final entry = this.entry<T>(key);
    final running = entry._inFlight;
    if (running == null) {
      return refresh<T>(key, fetch);
    }
    return entry._followUp ??= running.then((_) {
      entry._followUp = null;
      return refresh<T>(key, fetch);
    });
  }

  Future<bool> _run<T>(ReadEntry<T> entry, Future<T> Function() fetch) async {
    entry.value = switch (entry.value) {
      ReadLoaded<T>(:final data) => ReadLoaded(data, refreshing: true),
      _ => const ReadLoading(),
    };
    try {
      entry.value = ReadLoaded(await fetch());
      return true;
    } on ApiException catch (error) {
      entry.value = switch (entry.value) {
        ReadLoaded<T>(:final data) => ReadLoaded(data),
        _ => ReadFailed(error),
      };
      return false;
    } finally {
      entry._inFlight = null;
    }
  }

  /// Forgets every answer. A request still running writes into an entry nobody can reach.
  void clear() => _entries.clear();
}

/// One screen's use of one cached read: the state to draw, and a way to ask for fresh data.
/// Created in `initState` (it starts a refresh at once, so every visit refreshes) and disposed
/// with the screen. [onChange] is called whenever the state changes, usually `setState`.
class CachedRead<T> {
  CachedRead({
    required ReadCache cache,
    required Object key,
    required Future<T> Function() fetch,
    required VoidCallback onChange,
  }) : _cache = cache,
       _key = key,
       _fetch = fetch,
       _onChange = onChange,
       _entry = cache.entry<T>(key) {
    // Refreshing first: it changes the state at once, and the screen is not built yet.
    refresh();
    _entry.addListener(_onChange);
  }

  final ReadCache _cache;
  final Object _key;
  final Future<T> Function() _fetch;
  final VoidCallback _onChange;
  final ReadEntry<T> _entry;

  ReadState<T> get state => _entry.value;

  /// Asks for a fresh answer; the old one stays on screen meanwhile. Completes with whether a
  /// fresh answer arrived.
  Future<bool> refresh() => _cache.refresh<T>(_key, _fetch);

  /// Asks for a fresh answer after a change the user made: it reads after the change, even when
  /// a request that started before it is running.
  Future<bool> refreshAfterChange() =>
      _cache.refreshAfterChange<T>(_key, _fetch);

  void dispose() => _entry.removeListener(_onChange);
}
