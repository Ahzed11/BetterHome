import 'dart:async';

import 'package:betterhome/data/households_repository.dart';
import 'package:betterhome/data/models.dart';
import 'package:betterhome/state/app_session.dart';
import 'package:betterhome/state/read_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The data of [state], or null when it holds none.
List<String>? _data(ReadState<List<String>> state) =>
    state is ReadLoaded<List<String>> ? state.data : null;

bool _refreshing(ReadState<List<String>> state) =>
    state is ReadLoaded<List<String>> && state.refreshing;

UserProfile _profile(String id) => UserProfile(
  id: id,
  authSubject: 'sub-$id',
  email: '$id@example.com',
  givenName: id,
  familyName: '',
  language: 'en',
  timezone: 'UTC',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReadCache', () {
    test('an entry nobody has read yet is loading', () {
      final cache = ReadCache();

      expect(cache.entry<List<String>>('k').value, isA<ReadLoading>());
    });

    test(
      'a refresh fills the entry, and the answer stays for the next read',
      () async {
        final cache = ReadCache();

        await cache.refresh<List<String>>('k', () async => ['a']);

        expect(_data(cache.entry<List<String>>('k').value), ['a']);
        expect(_refreshing(cache.entry<List<String>>('k').value), isFalse);
      },
    );

    test(
      'the old answer stays while a newer one is on its way, then is replaced',
      () async {
        final cache = ReadCache();
        await cache.refresh<List<String>>('k', () async => ['old']);
        final release = Completer<List<String>>();

        final running = cache.refresh<List<String>>('k', () => release.future);

        final during = cache.entry<List<String>>('k').value;
        expect(_data(during), ['old']);
        expect(_refreshing(during), isTrue);

        release.complete(['new']);
        await running;
        final after = cache.entry<List<String>>('k').value;
        expect(_data(after), ['new']);
        expect(_refreshing(after), isFalse);
      },
    );

    test('readers who ask while a request runs share it', () async {
      final cache = ReadCache();
      var calls = 0;
      final release = Completer<List<String>>();
      Future<List<String>> fetch() {
        calls++;
        return release.future;
      }

      final first = cache.refresh<List<String>>('k', fetch);
      final second = cache.refresh<List<String>>('k', fetch);
      release.complete(['a']);
      await Future.wait([first, second]);

      expect(calls, 1);
    });

    test('a read after the first request ended asks again', () async {
      final cache = ReadCache();
      var calls = 0;
      Future<List<String>> fetch() async => ['call ${++calls}'];

      await cache.refresh<List<String>>('k', fetch);
      await cache.refresh<List<String>>('k', fetch);

      expect(calls, 2);
      expect(_data(cache.entry<List<String>>('k').value), ['call 2']);
    });

    test('a refresh says whether a fresh answer arrived', () async {
      final cache = ReadCache();

      final fresh = await cache.refresh<List<String>>('k', () async => ['a']);
      final failed = await cache.refresh<List<String>>(
        'k',
        () async => throw ApiException('boom', statusCode: 500),
      );

      expect(fresh, isTrue);
      expect(failed, isFalse);
    });

    test(
      'a refresh after a change never joins a request that began before it',
      () async {
        final cache = ReadCache();
        final firstRelease = Completer<List<String>>();
        var calls = 0;
        Future<List<String>> fetch() {
          final call = ++calls;
          return call == 1 ? firstRelease.future : Future.value(['call $call']);
        }

        final first = cache.refresh<List<String>>('k', fetch);
        // The user changes something while that request, which began before, is still running.
        final after = cache.refreshAfterChange<List<String>>('k', fetch);
        final andAnother = cache.refreshAfterChange<List<String>>('k', fetch);
        expect(calls, 1);

        firstRelease.complete(['read before the change']);
        await Future.wait([first, after, andAnother]);

        expect(calls, 2); // one follow-up, shared by both who asked
        expect(_data(cache.entry<List<String>>('k').value), ['call 2']);
      },
    );

    test(
      'a refresh after a change with nothing running is a plain refresh',
      () async {
        final cache = ReadCache();
        var calls = 0;

        await cache.refreshAfterChange<List<String>>(
          'k',
          () async => ['call ${++calls}'],
        );

        expect(calls, 1);
        expect(_data(cache.entry<List<String>>('k').value), ['call 1']);
      },
    );

    test('fill gives an entry that has no answer one, and says so', () async {
      final cache = ReadCache();
      var calls = 0;
      final spec = ReadSpec<List<String>>(
        key: 'k',
        fetch: () async => ['filled ${++calls}'],
      );

      final filled = await cache.fill(spec);

      expect(filled, isTrue);
      expect(_data(cache.entry<List<String>>('k').value), ['filled 1']);
    });

    test('fill leaves an entry that already has an answer alone', () async {
      final cache = ReadCache();
      await cache.refresh<List<String>>('k', () async => ['seen']);
      var calls = 0;
      final spec = ReadSpec<List<String>>(
        key: 'k',
        fetch: () async => ['filled ${++calls}'],
      );

      final filled = await cache.fill(spec);

      expect(filled, isTrue);
      expect(calls, 0);
      expect(_data(cache.entry<List<String>>('k').value), ['seen']);
    });

    test('fill joins a request that is already running', () async {
      final cache = ReadCache();
      final release = Completer<List<String>>();
      var calls = 0;
      Future<List<String>> fetch() {
        calls++;
        return release.future;
      }

      final running = cache.refresh<List<String>>('k', fetch);
      final filling = cache.fill(
        ReadSpec<List<String>>(key: 'k', fetch: fetch),
      );
      release.complete(['a']);
      await Future.wait([running, filling]);

      expect(calls, 1);
    });

    test('fill asks again for an entry whose last request failed', () async {
      final cache = ReadCache();
      await cache.refresh<List<String>>(
        'k',
        () async => throw ApiException('down', statusCode: 503),
      );

      final filled = await cache.fill(
        ReadSpec<List<String>>(key: 'k', fetch: () async => ['back']),
      );

      expect(filled, isTrue);
      expect(_data(cache.entry<List<String>>('k').value), ['back']);
    });

    test('fill says no when the request fails and leaves no answer', () async {
      final cache = ReadCache();

      final filled = await cache.fill(
        ReadSpec<List<String>>(
          key: 'k',
          fetch: () async => throw ApiException('down', statusCode: 503),
        ),
      );

      expect(filled, isFalse);
      expect(
        cache.entry<List<String>>('k').value,
        isA<ReadFailed<List<String>>>(),
      );
    });

    test('a failed refresh keeps the old answer and shows no error', () async {
      final cache = ReadCache();
      await cache.refresh<List<String>>('k', () async => ['kept']);

      await cache.refresh<List<String>>(
        'k',
        () async => throw ApiException('boom', statusCode: 500),
      );

      final state = cache.entry<List<String>>('k').value;
      expect(_data(state), ['kept']);
      expect(_refreshing(state), isFalse);
    });

    test(
      'a read that never had an answer ends as failed, and can recover',
      () async {
        final cache = ReadCache();

        await cache.refresh<List<String>>(
          'k',
          () async => throw ApiException('boom', statusCode: 503),
        );
        final failed = cache.entry<List<String>>('k').value;
        expect(failed, isA<ReadFailed<List<String>>>());
        expect((failed as ReadFailed<List<String>>).error.statusCode, 503);

        await cache.refresh<List<String>>('k', () async => ['back']);
        expect(_data(cache.entry<List<String>>('k').value), ['back']);
      },
    );

    test(
      'only a failed request is handled: another error is not hidden',
      () async {
        final cache = ReadCache();

        await expectLater(
          cache.refresh<List<String>>('k', () async => throw StateError('bug')),
          throwsStateError,
        );
      },
    );

    test('another key is another entry', () async {
      final cache = ReadCache();

      await cache.refresh<List<String>>('a', () async => ['a']);

      expect(cache.entry<List<String>>('b').value, isA<ReadLoading>());
      expect(_data(cache.entry<List<String>>('a').value), ['a']);
    });

    test('clear forgets every answer', () async {
      final cache = ReadCache();
      await cache.refresh<List<String>>('k', () async => ['a']);

      cache.clear();

      expect(cache.entry<List<String>>('k').value, isA<ReadLoading>());
    });

    test(
      'a request still running at clear time does not fill the new entry',
      () async {
        final cache = ReadCache();
        final release = Completer<List<String>>();
        final running = cache.refresh<List<String>>('k', () => release.future);

        cache.clear();
        release.complete(['of the user who left']);
        await running;

        expect(cache.entry<List<String>>('k').value, isA<ReadLoading>());
      },
    );

    test('listeners hear every change of an entry', () async {
      final cache = ReadCache();
      final seen = <String>[];
      cache
          .entry<List<String>>('k')
          .addListener(
            () => seen.add(switch (cache.entry<List<String>>('k').value) {
              ReadLoading() => 'loading',
              ReadLoaded<List<String>>(:final refreshing) =>
                refreshing ? 'refreshing' : 'loaded',
              ReadFailed() => 'failed',
            }),
          );

      await cache.refresh<List<String>>('k', () async => ['a']);
      await cache.refresh<List<String>>('k', () async => ['b']);

      expect(seen, ['loaded', 'refreshing', 'loaded']);
    });
  });

  group('a read started while a frame is built', () {
    testWidgets(
      'a screen that sets its state on a change is not asked to in the middle of a build',
      (tester) async {
        final cache = ReadCache();
        await cache.refresh<List<String>>('k', () async => ['old']);
        await tester.pumpWidget(
          MaterialApp(
            home: _Listener(cache: cache, child: const SizedBox()),
          ),
        );
        // A second screen starts a read of the same key in its initState, while building.
        await tester.pumpWidget(
          MaterialApp(
            home: _Listener(
              cache: cache,
              child: _StartsAReadWhenBuilt(cache: cache),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('CachedRead', () {
    test(
      'starts a refresh as soon as it is made, even when an answer is cached',
      () async {
        final cache = ReadCache();
        await cache.refresh<List<String>>('k', () async => ['old']);
        var calls = 0;

        final read = CachedRead<List<String>>(
          cache: cache,
          key: 'k',
          fetch: () async => ['new ${++calls}'],
          onChange: () {},
        );

        // The cached answer is there on the first read, before the refresh has ended.
        expect(_data(read.state), ['old']);
        expect(_refreshing(read.state), isTrue);
        await read.refresh();
        expect(calls, 1);
        expect(_data(read.state), ['new 1']);
        read.dispose();
      },
    );

    test('tells its screen about changes until it is disposed', () async {
      final cache = ReadCache();
      var changes = 0;
      final read = CachedRead<List<String>>(
        cache: cache,
        key: 'k',
        fetch: () async => ['a'],
        onChange: () => changes++,
      );
      await read.refresh();
      final before = changes;
      expect(before, greaterThan(0));

      read.dispose();
      await cache.refresh<List<String>>('k', () async => ['b']);

      expect(changes, before);
    });

    test(
      'a screen opened again finds the answer of the one before it',
      () async {
        final cache = ReadCache();
        final first = CachedRead<List<String>>(
          cache: cache,
          key: 'k',
          fetch: () async => ['seen'],
          onChange: () {},
        );
        await first.refresh();
        first.dispose();

        final second = CachedRead<List<String>>(
          cache: cache,
          key: 'k',
          fetch: () async => ['seen'],
          onChange: () {},
        );

        expect(_data(second.state), ['seen']);
        second.dispose();
      },
    );
  });

  group('AppSession', () {
    AppSession session() => AppSession(repository: FakeHouseholdsRepository());

    test('a key says which user and household it is for', () {
      final a = session()..profile = _profile('ada');
      final b = session()..profile = _profile('bob');

      expect(
        a.readKey('tasks', householdId: 'h1', params: false),
        a.readKey('tasks', householdId: 'h1', params: false),
      );
      expect(
        a.readKey('tasks', householdId: 'h1'),
        isNot(a.readKey('tasks', householdId: 'h2')),
      );
      expect(
        a.readKey('tasks', householdId: 'h1', params: true),
        isNot(a.readKey('tasks', householdId: 'h1', params: false)),
      );
      expect(
        a.readKey('tasks', householdId: 'h1'),
        isNot(b.readKey('tasks', householdId: 'h1')),
      );
    });

    test('two users never share an answer, even through one cache', () async {
      final s = session();
      s.profile = _profile('ada');
      await s.readCache.refresh<List<String>>(
        s.readKey('tasks', householdId: 'h1'),
        () async => ['ada only'],
      );
      final adaKey = s.readKey('tasks', householdId: 'h1');

      s.profile = _profile('bob');

      expect(
        s.readCache.entry<List<String>>(adaKey).value,
        isA<ReadLoading<List<String>>>(),
      );
      expect(
        s.readCache
            .entry<List<String>>(s.readKey('tasks', householdId: 'h1'))
            .value,
        isA<ReadLoading<List<String>>>(),
      );
    });

    test('the same user keeping the profile keeps the cache', () async {
      final s = session();
      s.profile = _profile('ada');
      await s.readCache.refresh<List<String>>('k', () async => ['a']);

      s.profile = _profile('ada');

      expect(_data(s.readCache.entry<List<String>>('k').value), ['a']);
    });

    test('signing out of the profile empties the cache', () async {
      final s = session();
      s.profile = _profile('ada');
      await s.readCache.refresh<List<String>>('k', () async => ['a']);

      s.profile = null;

      expect(
        s.readCache.entry<List<String>>('k').value,
        isA<ReadLoading<List<String>>>(),
      );
    });
  });
}

/// A screen that listens to the entry of 'k' and sets its state when it changes.
class _Listener extends StatefulWidget {
  const _Listener({required this.cache, required this.child});

  final ReadCache cache;
  final Widget child;

  @override
  State<_Listener> createState() => _ListenerState();
}

class _ListenerState extends State<_Listener> {
  late final CachedRead<List<String>> _read = CachedRead(
    cache: widget.cache,
    key: 'k',
    fetch: () async => ['listener'],
    onChange: () {
      if (mounted) {
        setState(() {});
      }
    },
  );

  @override
  void dispose() {
    _read.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _read.state;
    return widget.child;
  }
}

/// A screen that starts a read of 'k' in its `initState`, as every screen does.
class _StartsAReadWhenBuilt extends StatefulWidget {
  const _StartsAReadWhenBuilt({required this.cache});

  final ReadCache cache;

  @override
  State<_StartsAReadWhenBuilt> createState() => _StartsAReadWhenBuiltState();
}

class _StartsAReadWhenBuiltState extends State<_StartsAReadWhenBuilt> {
  late final CachedRead<List<String>> _read = CachedRead(
    cache: widget.cache,
    key: 'k',
    fetch: () async => ['new'],
    onChange: () {},
  );

  @override
  void initState() {
    super.initState();
    _read.state;
  }

  @override
  void dispose() {
    _read.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
