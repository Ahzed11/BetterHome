// Real sign-in through Keycloak, in headless Chrome. integration_test cannot do this: the login form
// lives on another origin, so the browser is driven with WebDriver instead.
// Usage: dart run test_driver/web_sign_in.dart <app-url> <username> <password>
// Needs chromedriver on port 4444 and CHROME_EXECUTABLE (see tooling/e2e.sh).
import 'dart:io';

import 'package:webdriver/async_io.dart';

Future<void> main(List<String> args) async {
  if (args.length != 3) {
    stderr.writeln('usage: web_sign_in.dart <app-url> <username> <password>');
    exit(2);
  }
  final driver = await createDriver(
    uri: Uri.parse('http://localhost:4444/'),
    desired: {
      'browserName': 'chrome',
      'goog:chromeOptions': {
        'binary': Platform.environment['CHROME_EXECUTABLE'],
        'args': ['--headless=new', '--no-sandbox', '--window-size=1000,900'],
      },
    },
  );
  try {
    await _journey(driver, args[0], args[1], args[2]);
    stdout.writeln('web sign-in journey: OK');
  } on Object catch (error) {
    stderr.writeln('failed: $error');
    final open = await driver.windows.toList();
    if (open.isNotEmpty) {
      await driver.switchTo.window(open.first);
      stderr.writeln('--- page at failure ---\n${await _text(driver)}');
    }
    rethrow;
  } finally {
    await driver.quit();
  }
}

Future<void> _journey(
  WebDriver driver,
  String appUrl,
  String user,
  String password,
) async {
  await driver.get(appUrl);
  final appWindow = await driver.window;
  final app = appWindow.id;
  // Flutter draws to a canvas; its accessibility tree is what WebDriver can read and click.
  await _until(
    () async =>
        await driver.execute(
          "var p = document.querySelector('flt-semantics-placeholder');"
          'if (p) { p.click(); return true; } return false;',
          [],
        ) ==
        true,
    'the app to start',
  );

  await _click(driver, 'Sign in');

  // The sign-in opens in a new tab (the package's default web mode) that closes itself on return.
  await _until(
    () async => (await driver.windows.toList()).length == 2,
    'the Keycloak tab',
  );
  final windows = await driver.windows.toList();
  await driver.switchTo.window(windows.firstWhere((w) => w.id != app));
  await _until(
    () async =>
        (await driver.findElements(By.id('username')).toList()).isNotEmpty,
    'the Keycloak login form',
  );
  await (await driver.findElement(By.id('username'))).sendKeys(user);
  await (await driver.findElement(By.id('password'))).sendKeys(password);
  await (await driver.findElement(By.id('kc-login'))).click();

  // The Keycloak tab closes itself once the app has the answer; go back to the app tab.
  await driver.switchTo.window(appWindow);
  await _until(
    () => _contains(driver, 'No households yet'),
    'the households screen',
  );

  await _click(driver, 'Sign out');
  await _until(
    () => _contains(driver, 'Welcome to BetterHome'),
    'the sign-in screen',
  );
}

Future<String> _text(WebDriver driver) async =>
    '${await driver.execute('return document.body ? document.body.innerText + "\\n" + '
    r'Array.from(document.querySelectorAll("[aria-label]")).map(e => e.getAttribute("aria-label")).join(" | ") : ""', [])}';

Future<bool> _contains(WebDriver driver, String text) async =>
    (await _text(driver)).contains(text);

Future<void> _click(WebDriver driver, String label) async {
  await _until(() => _contains(driver, label), '"$label" to appear');
  final matches = await driver
      .findElements(
        By.xpath(
          "//*[@aria-label='$label' or normalize-space(text())='$label']",
        ),
      )
      .toList();
  if (matches.isEmpty) {
    throw StateError('Nothing to click for "$label"');
  }
  await matches.first.click();
}

Future<void> _until(
  Future<bool> Function() condition,
  String what, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  throw StateError('Timed out waiting for $what');
}
