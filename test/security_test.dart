@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:zerobounce_sdk/src/redaction.dart';
import 'package:zerobounce_sdk/zerobounce_sdk.dart';

import 'support/calls.dart';
import 'support/fake.dart';
import 'support/network_guard.dart';

/// Every spelling of [key] a message must not contain.
List<String> spellings(String key) => [
      key,
      Uri.encodeComponent(key),
      Uri.encodeQueryComponent(key),
      jsonEncode(key).substring(1, jsonEncode(key).length - 1),
    ];

void expectNoKey(ZBException error, String key) {
  for (final spelling in spellings(key)) {
    expect(error.message, isNot(contains(spelling)),
        reason: 'spelling "$spelling"');
    expect(error.toString(), isNot(contains(spelling)));
  }
  expect(holdsSecret(error.message, [key]), isFalse, reason: error.message);
}

Future<ZBException> failure(Future<Object?> Function() call) async {
  try {
    await call();
  } on ZBException catch (error) {
    return error;
  }
  fail('expected a ZBException');
}

void main() {
  installNetworkGuard();

  group('the sweep list', () {
    test('names every public request method of ZeroBounceSDK', () {
      // Read from the source, so a new public method fails this test until it
      // is added to the sweep list.
      final source = File('lib/src/client.dart').readAsStringSync();
      final public = {
        for (final match in RegExp(r'^  Future<.*?> ([a-zA-Z][A-Za-z0-9]*)\(',
                multiLine: true)
            .allMatches(source))
          match[1]!,
      };
      final declared = RegExp(
              r'^  [A-Za-z][A-Za-z0-9<>?, ]* ([a-zA-Z][A-Za-z0-9]*)\(',
              multiLine: true)
          .allMatches(source)
          .map((m) => m[1]!)
          .toSet()
        ..removeAll({'close', 'toString'});
      expect(declared.difference(public), isEmpty,
          reason: 'a public method not returning Future');
      expect(public.length, greaterThan(50));
      expect(apiCalls.map((c) => c.name).toSet(), equals(public));
      expect(apiCalls.length, public.length,
          reason: 'a method is listed twice');
    });
  });

  group('every public request method', () {
    for (final call in apiCalls) {
      group(call.name, () {
        test(
            'sends ${call.method} over https to its documented URL and accepts the answer',
            () async {
          final (sdk, fake) = sdkAnswering(call.ok,
              contentType: call.download ? 'text/csv' : 'application/json');
          final result = await call.invoke(sdk);
          expect(result, isNotNull);
          expect(fake.requests, hasLength(1));
          final request = fake.last;
          expect(request.method, call.method);
          expect(request.url.scheme, 'https');
          expect(
              request.url
                  .replace(query: '')
                  .toString()
                  .replaceAll(RegExp(r'\?$'), ''),
              call.url);
          expect(request.followRedirects, isFalse);
          expect(request, isA<http.Abortable>());
        });

        test('refuses a redirect with its status and never follows it',
            () async {
          final fake = FakeClient((_) => answer('',
              status: 302,
              headers: {'location': 'https://evil.example/steal'}));
          final sdk = ZeroBounceSDK(testKey, httpClient: fake);
          await expectLater(
              call.invoke(sdk), throwsZB(302, contains('redirect')));
          expect(fake.requests, hasLength(1));
        });

        test('keeps the key out of an error built from a body that echoes it',
            () async {
          final echo = 'bad request for ${spellings(specialKey).join(' ')} '
              'and ?api_key=$specialKey&x=1';
          for (final body in [
            {'error': echo},
            {'message': echo, 'success': false},
            echo,
          ]) {
            final fake = FakeClient((_) => answer(body,
                status: 400,
                contentType:
                    body is String ? 'text/plain' : 'application/json'));
            final sdk = ZeroBounceSDK(specialKey, httpClient: fake);
            final error = await failure(() => call.invoke(sdk));
            expect(error.statusCode, 400);
            expectNoKey(error, specialKey);
          }
        });

        test('reports a transport failure with status 0 and without the key',
            () async {
          final fake = FakeClient((request) => throw http.ClientException(
              'Connection failed: ${request.url} key=$specialKey',
              request.url));
          final sdk = ZeroBounceSDK(specialKey, httpClient: fake);
          final error = await failure(() => call.invoke(sdk));
          expect(error.statusCode, 0);
          expect(error.message, contains('request failed'));
          expectNoKey(error, specialKey);
        });

        test('times out, aborts the request and reports status 0', () async {
          final aborted = Completer<void>();
          final fake = FakeClient((request) {
            (request as http.Abortable)
                .abortTrigger!
                .then((_) => aborted.complete());
            return Completer<http.StreamedResponse>().future;
          });
          final sdk = ZeroBounceSDK(testKey,
              httpClient: fake, timeout: const Duration(milliseconds: 50));
          await expectLater(
              call.invoke(sdk), throwsZB(0, contains('timed out')));
          await aborted.future.timeout(const Duration(seconds: 2));
        });

        test('times out on a body that stalls after the headers', () async {
          final fake = FakeClient((_) => http.StreamedResponse(
              StreamController<List<int>>().stream, 200,
              headers: {'content-type': 'application/json'}));
          final sdk = ZeroBounceSDK(testKey,
              httpClient: fake, timeout: const Duration(milliseconds: 50));
          await expectLater(
              call.invoke(sdk), throwsZB(0, contains('timed out')));
        });

        test('refuses a body cut short of its Content-Length', () async {
          final text = call.download ? '${call.ok}' : jsonEncode(call.ok);
          final fake = FakeClient((_) => answer(text,
              contentType: call.download ? 'text/csv' : 'application/json',
              contentLength: utf8.encode(text).length + 10));
          final sdk = ZeroBounceSDK(testKey, httpClient: fake);
          await expectLater(
              call.invoke(sdk), throwsZB(0, contains('cut short')));
        });

        test('sends the key only to the https host it was built for', () async {
          final (sdk, fake) = sdkAnswering(call.ok,
              contentType: call.download ? 'text/csv' : 'application/json');
          await call.invoke(sdk);
          final request = fake.last;
          final inQuery = request.url.queryParameters['api_key'] == testKey;
          final inHeader =
              request.headers['Authorization'] == 'Bearer $testKey';
          final inForm = request is http.Request &&
              request.method == 'POST' &&
              request.body.contains(testKey);
          final inMultipart = request is http.MultipartRequest &&
              request.fields['api_key'] == testKey;
          expect([inQuery, inHeader, inForm, inMultipart].where((x) => x),
              hasLength(1),
              reason: 'the key travels exactly one way');
          if (inHeader) {
            expect(request.url.queryParameters, isNot(contains('api_key')));
          }
        });
      });
    }
  });

  group('the constructor', () {
    test('refuses a missing, padded, control or non-ASCII key', () {
      for (final key in [
        '',
        '   ',
        ' key',
        'key ',
        'ke\ny',
        'ke\ty',
        'k\u0000y',
        'k\u00e9y',
        'k\u200by'
      ]) {
        expect(() => ZeroBounceSDK(key), throwsZB(0), reason: jsonEncode(key));
      }
      expect(
          ZeroBounceSDK('a key with spaces',
              httpClient: FakeClient((_) => answer({}))),
          isA<ZeroBounceSDK>());
    });

    test('refuses every base URL that is not clean https, without quoting it',
        () {
      const secret = 'S3cretInUrl';
      final bad = [
        'http://api.zerobounce.net/v2',
        'ftp://api.zerobounce.net',
        'api.zerobounce.net/v2',
        'https://user:$secret@api.zerobounce.net/v2',
        'https://api.zerobounce.net/v2?k=$secret',
        'https://api.zerobounce.net/v2#$secret',
        'https://api.zerobounce.net\\@evil.example/$secret',
        'https://api.zerobounce.net /v2$secret',
        'https://api.zerobounce.net\t/v2$secret',
        'https://\u0430pi.zerobounce.net/v2$secret',
        'https://api.zerobounce.net%2eevil.example/$secret',
        'https://api.zerobounce.net/v2/%2F$secret',
        'https://api.zerobounce.net/v2/../$secret',
        'https:///v2$secret',
        'https://api.zerobounce.net:port/$secret',
      ];
      final names = [
        'baseUrl',
        'bulkBaseUrl',
        'bulkRootBaseUrl',
        'listEvaluatorBaseUrl',
        'inboxPlacementBaseUrl',
        'emailFinderBaseUrl',
        'domainSearchBaseUrl',
      ];
      for (final name in names) {
        for (final url in bad) {
          final args = {Symbol(name): url};
          try {
            Function.apply(ZeroBounceSDK.new, [testKey], args);
            fail('$name accepted $url');
          } on ZBException catch (error) {
            expect(error.statusCode, 0);
            expect(error.message, contains(name));
            expect(error.message, isNot(contains(secret)));
          }
        }
      }
    });

    test('allows loopback http for tests and drops trailing slashes', () async {
      for (final base in [
        'http://127.0.0.1:8080/v2/',
        'http://localhost/v2//',
        'http://[::1]:9/v2'
      ]) {
        final fake = FakeClient((_) => answer({'Credits': '1'}));
        await ZeroBounceSDK(testKey, baseUrl: base, httpClient: fake)
            .getCredits();
        expect(fake.last.url.path, '/v2/getcredits');
      }
    });

    test('refuses a timeout that is not positive', () {
      expect(() => ZeroBounceSDK(testKey, timeout: Duration.zero), throwsZB(0));
    });

    test('never shows the key in toString', () {
      final sdk =
          ZeroBounceSDK(specialKey, httpClient: FakeClient((_) => answer({})));
      expect(sdk.toString(), contains('apiKey: ***'));
      expect(sdk.toString(), isNot(contains(specialKey)));
    });

    test('closes only a client it created itself', () {
      final fake = FakeClient((_) => answer({}));
      ZeroBounceSDK(testKey, httpClient: fake).close();
      expect(fake.closed, isFalse);
      ZeroBounceSDK(testKey).close();
    });
  });

  group('redaction', () {
    test('masks every spelling the SDK or an echo can produce', () {
      for (final form in secretForms(specialKey)) {
        final out = redactSecrets('before $form after', [specialKey]);
        expect(holdsSecret(out, [specialKey]), isFalse, reason: form);
        expect(out, isNot(contains(specialKey)));
      }
    });

    test('masks case-changed and Unicode-folded spellings', () {
      const key = 'abcKEY123';
      for (final text in ['ABCkey123', 'abc\u212AEY123', 'xx ABCKEY123 yy']) {
        final out = redactSecrets(text, [key]);
        expect(out.toLowerCase(), isNot(contains(key.toLowerCase())),
            reason: text);
      }
    });

    test('drops the whole text when a decoded view still holds the key', () {
      const key = 'abcKEY123';
      final layered = Uri.encodeComponent(
          Uri.encodeComponent(jsonEncode({'k': specialKey})));
      expect(redactSecrets('echo $layered', [specialKey]),
          credentialOmittedMessage);
      expect(redactSecrets('echo %2561%2562cKEY123', [key]),
          credentialOmittedMessage);
      expect(
          redactSecrets('echo &#97;bcKEY123', [key]), credentialOmittedMessage);
      expect(redactSecrets(r'echo \u0061bcKEY123', [key]),
          credentialOmittedMessage);
      expect(redactSecrets('echo %61%62%63KEY123', [key]),
          credentialOmittedMessage);
    });

    test(
        'leaves text without the key alone and replaces text too long to check',
        () {
      expect(redactSecrets('nothing to see', [testKey]), 'nothing to see');
      expect(redactSecrets('x' * (maxRedactedLength + 1), [testKey]),
          textTooLongMessage);
    });
  });
}
