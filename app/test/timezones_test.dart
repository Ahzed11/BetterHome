import 'package:betterhome/data/timezones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('timezoneNames', () {
    test('holds each zone once, in alphabetical order', () {
      expect(timezoneNames.toSet().length, timezoneNames.length);
      expect([...timezoneNames]..sort(), timezoneNames);
    });

    test('holds only region/city names and UTC', () {
      final shape = RegExp(r'^[A-Z][A-Za-z]+(/[A-Z][A-Za-z0-9_+-]+)+$');
      for (final name in timezoneNames) {
        expect(name == 'UTC' || shape.hasMatch(name), isTrue, reason: name);
      }
    });

    test('has the default zone, UTC and the zones of the supported users', () {
      expect(timezoneNames, contains(defaultTimezone));
      expect(
        timezoneNames,
        containsAll([
          'UTC',
          'Europe/Brussels',
          'Europe/London',
          'America/New_York',
        ]),
      );
    });

    test('leaves out a zone the services may not know yet', () {
      expect(timezoneNames, isNot(contains('America/Coyhaique')));
    });
  });

  group('searchTimezones', () {
    test('an empty or blank query matches every zone', () {
      expect(searchTimezones(''), timezoneNames);
      expect(searchTimezones('   '), timezoneNames);
    });

    test('finds a city whatever the case', () {
      expect(searchTimezones('paris'), ['Europe/Paris']);
      expect(searchTimezones('PARIS'), ['Europe/Paris']);
    });

    test('a space, an underscore or a slash all match an underscore', () {
      expect(searchTimezones('new york'), ['America/New_York']);
      expect(searchTimezones('new_york'), ['America/New_York']);
      expect(searchTimezones('america/new'), contains('America/New_York'));
    });

    test('several words must all match, in any order', () {
      expect(searchTimezones('york america'), ['America/New_York']);
    });

    test('a region lists its zones in list order', () {
      final europe = searchTimezones('europe');
      expect(europe, contains('Europe/Brussels'));
      expect(europe.every((n) => n.startsWith('Europe/')), isTrue);
      expect([...europe]..sort(), europe);
    });

    test('a query that matches nothing gives an empty list', () {
      expect(searchTimezones('Europe/Pariss'), isEmpty);
      expect(searchTimezones('zzzz'), isEmpty);
    });
  });
}
