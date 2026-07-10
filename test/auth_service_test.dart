import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reddlit/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const loggedIn = '<html><body class="loggedin">home</body></html>';
  const loggedOut = '<html><body class="loggedout">home</body></html>';

  AuthService serving(String body, {int status = 200}) =>
      AuthService.withClient(MockClient((_) async => http.Response(body, status)));

  AuthService offline() => AuthService.withClient(
        MockClient((_) async => fail('no network call expected')),
      );

  group('submitSessionCookie', () {
    test('blank input is rejected before any request', () async {
      final auth = offline();
      expect(await auth.submitSessionCookie('   '),
          'Paste your reddit_session cookie.');
      expect(auth.isAuthenticated, isFalse);
      expect(auth.busy, isFalse);
    });

    test('a bare value is wrapped and accepted when the session is live',
        () async {
      final auth = serving(loggedIn);
      expect(await auth.submitSessionCookie('abc123'), isNull);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.validated, isTrue);
      expect(auth.cookieHeader, 'reddit_session=abc123');
      expect(auth.busy, isFalse);
    });

    test('a session that resolves logged-out is refused', () async {
      final auth = serving(loggedOut);
      expect(await auth.submitSessionCookie('abc123'),
          'That session is not logged in to Reddit. Try again.');
      expect(auth.isAuthenticated, isFalse);
    });
  });

  group('setSession', () {
    test('a value without reddit_session= is rejected before any request',
        () async {
      final auth = offline();
      expect(await auth.setSession('token_v2=xyz'),
          'No reddit_session found in that value.');
    });
  });

  group('validate', () {
    test('reports no session when none is stored', () async {
      final auth = serving(loggedIn);
      expect(await auth.validate(), 'No session saved.');
    });
  });

  group('busy guard error mapping', () {
    test('a timeout maps to a friendly message and clears busy', () async {
      final auth = AuthService.withClient(
        MockClient((_) async => throw TimeoutException('slow')),
      );
      expect(await auth.submitSessionCookie('abc123'),
          'Timed out reaching Reddit.');
      expect(auth.busy, isFalse);
      expect(auth.isAuthenticated, isFalse);
    });

    test('an unexpected error is surfaced and clears busy', () async {
      final auth = AuthService.withClient(
        MockClient((_) async => throw Exception('boom')),
      );
      final error = await auth.submitSessionCookie('abc123');
      expect(error, startsWith('Error:'));
      expect(auth.busy, isFalse);
    });
  });

  group('mediaHeaders', () {
    test('attaches the cookie to reddit hosts only', () async {
      final auth = serving(loggedIn);
      await auth.submitSessionCookie('abc123');

      final reddit = auth.mediaHeaders('https://i.redd.it/x.jpg');
      expect(reddit['Cookie'], 'reddit_session=abc123');
      expect(reddit['User-Agent'], isNotNull);

      final external = auth.mediaHeaders('https://example.com/x.jpg');
      expect(external.containsKey('Cookie'), isFalse);
      expect(external['User-Agent'], isNotNull);
    });

    test('sends no cookie when anonymous', () {
      final auth = offline();
      final headers = auth.mediaHeaders('https://i.redd.it/x.jpg');
      expect(headers.containsKey('Cookie'), isFalse);
    });
  });

  group('logout', () {
    test('clears the session and validation state', () async {
      final auth = serving(loggedIn);
      await auth.submitSessionCookie('abc123');
      expect(auth.isAuthenticated, isTrue);

      await auth.logout();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.validated, isFalse);
      expect(auth.cookieHeader, isNull);
    });
  });
}
