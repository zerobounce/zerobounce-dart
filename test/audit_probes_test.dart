import 'dart:convert';

import 'package:test/test.dart';
import 'package:zerobounce_sdk/src/redaction.dart';
import 'package:zerobounce_sdk/zerobounce_sdk.dart';

import 'support/calls.dart';
import 'support/fake.dart';
import 'support/network_guard.dart';

// The probes of the shared audit check matrix (sdk-docs skill
// references/checks.md) that the other test files do not already make.

Future<ZBException> failure(Future<Object?> future) async {
  try {
    await future;
  } on ZBException catch (error) {
    return error;
  }
  fail('expected a ZBException');
}

void main() {
  installNetworkGuard();

  test('S2: a key with an invisible character is refused before any request',
      () {
    for (final code in [
      0x202e,
      0x2066,
      0x0600,
      0x0890,
      0x0891,
      0x00ad,
      0xfff9,
      0x1d173,
      0xfeff,
      0x00a0
    ]) {
      final key = 'abc${String.fromCharCode(code)}def';
      final fake = FakeClient((_) => answer({}));
      expect(() => ZeroBounceSDK(key, httpClient: fake), throwsZB(0),
          reason: 'U+${code.toRadixString(16)}');
      expect(fake.requests, isEmpty);
    }
  });

  group('S4: no key in a message built from a body, in any spelling', () {
    const key = "zb'key1";
    final quoteSpellings = [
      r'\u{27}',
      r'\047',
      r'\U{27}',
      r'\U0027',
      r'\U00000027',
      r'\u0027',
      '&#39;',
      '&apos;',
      '%27'
    ];

    for (final quote in quoteSpellings) {
      test('quote spelled $quote', () async {
        final echoed = key.replaceAll("'", quote);
        for (final (body, status) in [
          ({'error': 'Invalid API key $echoed'}, 200),
          ({'success': false, 'message': 'rejected $echoed'}, 200),
          ('bad request ?api_key=$echoed', 400),
          ({'detail': 'no $echoed'}, 400),
        ]) {
          final fake = FakeClient((_) => answer(body,
              status: status,
              contentType: body is String ? 'text/plain' : 'application/json'));
          final error =
              await failure(ZeroBounceSDK(key, httpClient: fake).getCredits());
          expect(error.statusCode, status);
          expect(holdsSecret(error.message, [key]), isFalse,
              reason: '$body -> ${error.message}');
        }
      });
    }

    test('in an HTML title and a batch "all" error', () async {
      final html =
          '<html><head><title>Denied for $specialKey</title></head><body></body></html>';
      final fake = FakeClient(
          (_) => answer(html, status: 403, contentType: 'text/html'));
      final error = await failure(
          ZeroBounceSDK(specialKey, httpClient: fake).getCredits());
      expect(error.statusCode, 403);
      expect(holdsSecret(error.message, [specialKey]), isFalse);

      final batch = FakeClient((_) => answer({
            'email_batch': <Object>[],
            'errors': [
              {'error': 'Invalid API Key $specialKey', 'email_address': 'all'},
            ],
          }));
      final batchError = await failure(
          ZeroBounceSDK(specialKey, httpClient: batch)
              .validateBatch([const ZBBatchEmail('a@b.c')]));
      expect(batchError.statusCode, 200);
      expect(holdsSecret(batchError.message, [specialKey]), isFalse);
    });

    test('U+1F80 followed by U+0301 is folded like the precomposed form', () {
      // Case folding without locale: a key's upper-case spelling is masked.
      const secret = 'key\u1f80';
      expect(holdsSecret('KEY\u1f88', [secret]), isTrue);
    });
  });

  group('E3: message-only bodies', () {
    test('a message beside documented fields that are all null is an error',
        () async {
      final (sdk, _) =
          sdkAnswering({'message': 'Invalid domain', 'domain': null});
      await expectLater(sdk.findEmailFormatByDomain('example.com'),
          throwsZB(200, 'Invalid domain'));
    });

    test('documented fields that are null, with no message, stay a result',
        () async {
      final (sdk, _) = sdkAnswering({'domain': null});
      expect((await sdk.findEmailFormatByDomain('example.com')).domain, isNull);
    });

    test('a file status with no non-null status field is an error', () async {
      for (final body in [
        {'foo': 1},
        {'message': 'm', 'file_id': null},
        {'': ''},
      ]) {
        final (sdk, _) = sdkAnswering(body);
        await expectLater(sdk.getFileStatus('f1'), throwsZB(200),
            reason: jsonEncode(body));
      }
      final (sdk, _) = sdkAnswering({'file_status': 'Processing'});
      expect((await sdk.getFileStatus('f1')).fileStatus, 'Processing');
    });
  });

  test('E4: a success that is no flag is not false', () async {
    for (final flag in [
      0.4,
      5,
      'maybe',
      <Object>[],
      <String, Object>{},
      '',
      'x'
    ]) {
      final (sdk, _) = sdkAnswering(
          {'success': flag, 'message': 'File Deleted', 'file_id': 'f1'});
      final error = await failure(sdk.deleteFile('f1'));
      // Never read as "success": false (that would report the message).
      expect(error.message, isNot('File Deleted'), reason: '$flag');
      expect(error.statusCode, 200);
    }
  });

  test(
      'E8: every Inbox Placement call reports an empty non-2xx with its status',
      () async {
    for (final call in apiCalls.where((c) => c.url.contains('/api/ipt'))) {
      for (final status in [404, 500]) {
        final (sdk, _) = sdkAnswering('', status: status, contentType: null);
        await expectLater(call.invoke(sdk), throwsZB(status),
            reason: call.name);
      }
    }
  });

  group('D1/D2: downloads', () {
    final downloads = apiCalls.where((c) => c.download).toList();

    test('a leading BOM or NBSP does not hide a JSON body', () async {
      for (final call in downloads) {
        for (final pad in ['\ufeff', '\u00a0', ' \n']) {
          final (sdk, _) = sdkAnswering(
              '$pad{"success":false,"message":"File not found"}',
              contentType: 'text/csv');
          await expectLater(call.invoke(sdk), throwsZB(200, 'File not found'),
              reason: call.name);
        }
      }
    });

    test('padding before an HTML tag does not hide it', () async {
      for (final call in downloads) {
        for (final spaces in [2500, 4095, 5000]) {
          final (sdk, _) = sdkAnswering(
              '${' ' * spaces}<html><body>x</body></html>',
              contentType: 'text/csv');
          await expectLater(call.invoke(sdk), throwsZB(200),
              reason: '${call.name} $spaces');
        }
      }
    });

    test('a file that starts with spaces is returned whole', () async {
      final csvText = '${' ' * 3000}email\na@b.c\n${'x,' * 4000}';
      final (sdk, _) = sdkAnswering(csvText, contentType: 'text/csv');
      expect(await sdk.getFile('f1'), csvText);
    });
  });

  test('P2: every result names its type and fields in toString', () async {
    for (final call in apiCalls.where((c) => !c.download)) {
      final (sdk, _) = sdkAnswering(call.ok);
      final result = await call.invoke(sdk);
      if (result is Map || result is List) continue;
      final text = result.toString();
      expect(text, matches(RegExp(r'^ZB[A-Za-z0-9]+\(')), reason: call.name);
      expect(text, isNot(contains("Instance of")), reason: call.name);
    }
  });
}
