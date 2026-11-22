import 'dart:convert';

import 'package:test/test.dart';
import 'package:zerobounce_sdk/src/field_types.dart';
import 'package:zerobounce_sdk/zerobounce_sdk.dart';

import 'support/calls.dart';
import 'support/documented_examples.dart';
import 'support/fake.dart';
import 'support/network_guard.dart';

/// The result types each JSON call checks its answer against.
const resultTypes = <String, List<String>>{
  'getCredits': ['GetCreditsResponse'],
  'getApiUsage': ['ApiUsageResponse'],
  'validateEmail': ['EmailValidationResult'],
  'validateBatch': ['ValidateBatchResponse'],
  'getEmailActivity': ['EmailActivityResponse'],
  'scoreEmail': ['EmailScoringResult'],
  'sendFile': ['BulkSendFileResponse'],
  'sendScoringFile': ['BulkSendFileResponse'],
  'getFileStatus': ['ValidationFileStatusResponse'],
  'getScoringFileStatus': ['ScoringFileStatusResponse'],
  'deleteFile': ['BulkFileDeletedResponse'],
  'deleteScoringFile': ['BulkFileDeletedResponse'],
  'findEmailByDomain': ['EmailFinderResponse'],
  'findEmailFormatByDomain': ['DomainFormatResponse'],
  'sendListEvaluatorFile': ['ListEvaluatorSubmitResponse'],
  'getListEvaluatorResult': ['ListEvaluatorResultResponse'],
  'listFilters': ['FilterListItem[]', 'FilterMessageResponse'],
  'listS3Files': ['S3ListFileEntry[]'],
  'validateS3File': ['S3BulkJobResponse'],
  'getInboxPlacementProviders': ['InboxPlacementProvidersResponse'],
  'createInboxPlacementTest': ['InboxPlacementTestCreated'],
  'getInboxPlacementTest': ['InboxPlacementTestResult'],
  'deleteInboxPlacementTest': ['InboxPlacementTestDeleted'],
  'getInboxPlacementWebhook': ['InboxPlacementWebhookResponse'],
};

/// Answers that are not documented examples: nulls, empty strings, values
/// added later, and the calls the docs give no success sample for.
final fixtures = <String, List<Object?>>{
  'getCredits': [
    {'Credits': '123456'},
    {'Credits': '-1'},
    {'Credits': 0},
  ],
  'validateEmail': [
    {
      'address': 'invalid@example.com',
      'status': 'invalid',
      'sub_status': 'failed_syntax_check',
      'free_email': false,
      'did_you_mean': null,
      'account': '',
      'domain': null,
      'mx_found': 'false',
      'processed_at': '2023-04-05 08:55:40.661',
    },
    {
      'address': 'a@example.com',
      'status': 'a_status_added_later',
      'mx_found': true
    },
    {
      'Message':
          'Greylist validation still in progress. Please try again later.'
    },
  ],
  'validateBatch': [
    {
      'email_batch': [
        {'address': 'valid@example.com', 'status': 'valid', 'mx_found': 'true'},
      ],
      'errors': [
        {'error': 'Mock error message', 'email_address': 'invalid@example.com'},
      ],
    },
    {'email_batch': <Object>[], 'errors': <Object>[]},
  ],
  'getEmailActivity': [
    {'found': true, 'active_in_days': '180'},
    {'found': false, 'active_in_days': null},
  ],
  'scoreEmail': [
    {'email': 'valid@example.com', 'score': 10},
  ],
  'getFileStatus': [
    {
      'success': true,
      'file_id': 'e90e9b1d',
      'file_status': 'Deleted',
      'complete_percentage': '0%',
      'error_reason': 'mock value',
      'return_url': null,
    },
  ],
  'findEmailByDomain': [
    {
      'email': 'john.doe@example.com',
      'email_confidence': 'high',
      'domain': '',
      'did_you_mean': ''
    },
  ],
  'findEmailFormatByDomain': [
    {
      'domain': 'example.com',
      'format': 'first.last',
      'confidence': 'high',
      'other_domain_formats': [
        {'format': 'first_last', 'confidence': 'high'},
      ],
    },
  ],
  'listFilters': [
    [
      {'rule': 'allow', 'target': 'domain', 'value': 'example.com'},
    ],
    <Object>[],
    {'Message': 'No filters.'},
  ],
  'listS3Files': [
    [
      {
        'name': 'in/list.csv',
        'size': 120,
        'last_modified': '2026-01-01T00:00:00Z'
      },
    ],
  ],
  'getInboxPlacementProviders': [
    {
      'emailProviders': {
        'items': [
          {
            'id': 1,
            'name': 'Gmail',
            'location': 'US',
            'seedCount': 2,
            'seedIds': [1, 2]
          },
        ],
      },
      'gatewayProviders': {'items': <Object>[]},
    },
  ],
  'createInboxPlacementTest': [
    {
      'id': 't1',
      'identifier': 'zb-1',
      'testType': 'seed',
      'emailAddressList': ['seed1@example.com']
    },
  ],
  'getInboxPlacementTest': [
    {
      'id': 't1',
      'testName': 't',
      'status': 'Completed',
      'inboxCount': 1,
      'percentages': <String, Object>{},
      'counts': {
        'inboxCount': 1,
        'spamCount': 0,
        'percentages': <String, Object>{}
      },
      'results': <Object>[],
      'seeds': <Object>[],
    },
  ],
};

ApiCall callNamed(String name) => apiCalls.firstWhere((c) => c.name == name);

Future<Object?> run(String name, Object? body,
    {int status = 200, String? contentType}) {
  final call = callNamed(name);
  final (sdk, _) = sdkAnswering(body,
      status: status,
      contentType:
          contentType ?? (call.download ? 'text/csv' : 'application/json'));
  return call.invoke(sdk);
}

/// Every answer the typed calls must accept, documented examples first.
Map<String, List<Object?>> get accepted => {
      for (final name in {...documentedExamples.keys, ...fixtures.keys})
        name: [...?documentedExamples[name], ...?fixtures[name]],
    };

/// Each nested field of [value] the declared [types] name, with a setter that
/// returns a copy of the whole answer with that field replaced.
List<(String, List<String>, bool, Object? Function(Object?))> slots(
    Object? value, List<String> types,
    [String path = '', Object? Function(Object?)? replace]) {
  replace ??= (next) => next;
  final out = <(String, List<String>, bool, Object? Function(Object?))>[];
  if (value is Map<String, Object?>) {
    final names = types.where(responseFields.containsKey).toList();
    final required = {for (final n in names) ...?requiredFields[n]};
    for (final key in value.keys) {
      final declared = <String>[
        for (final n in names)
          if (responseFields[n]!.containsKey(key))
            ...(responseFields[n]![key] is List
                ? (responseFields[n]![key] as List).cast<String>()
                : [responseFields[n]![key] as String]),
      ];
      if (declared.isEmpty) continue;
      final at = path.isEmpty ? key : '$path.$key';
      Object? set(Object? next) => replace!({...value, key: next});
      out
        ..add((at, declared, required.contains(key), set))
        ..addAll(slots(value[key], declared, at, set));
    }
  } else if (value is List) {
    final elementTypes = [
      for (final t in types)
        if (t.endsWith('[]')) t.substring(0, t.length - 2),
    ];
    if (elementTypes.isEmpty) return out;
    for (var i = 0; i < value.length; i++) {
      Object? set(Object? next) => replace!([...value]..[i] = next);
      out
        ..add(('$path[$i]', elementTypes, true, set))
        ..addAll(slots(value[i], elementTypes, '$path[$i]', set));
    }
  }
  return out;
}

bool allows(List<String> types, Object? value) => types.any((type) {
      if (type == 'any') return true;
      if (value == null) return false;
      if (type.endsWith('[]') || type == 'array') return value is List;
      return switch (type) {
        'string' => value is String,
        'integerString' =>
          (value is String && RegExp(r'^-?[0-9]+$').hasMatch(value)) ||
              value is int,
        'integer' => value is int,
        'number' => value is num,
        'boolean' => value is bool,
        _ => value is Map,
      };
    });

void main() {
  installNetworkGuard();

  group('accepted answers', () {
    test('every documented example and fixture parses', () async {
      for (final MapEntry(key: name, value: answers) in accepted.entries) {
        for (final answer in answers) {
          final body = answer is String ? answer : jsonEncode(answer);
          await expectLater(run(name, body), completion(isNotNull),
              reason: '$name: $body');
        }
      }
    });

    test('typed results read the documented fields', () async {
      final (sdk, _) =
          sdkAnswering(documentedExamples['validateEmail']!.single);
      final result = await sdk.validateEmail('john.doe@zerobounce.net');
      expect(result.address, 'john.doe@zerobounce.net');
      expect(result.status, ZBValidateStatus.valid);
      expect(result.freeEmail, isFalse);
      expect(result.catchallDomain, isTrue);
      expect(result.didYouMean, isNull);
      expect(result.mxFound, 'true');
      expect(result.activeInDays, '30');
      expect(result.activeFirstSeen, '2026-02-25');
      expect(result.toString(),
          startsWith('ZBValidateResult(address: john.doe@zerobounce.net'));
      expect(result.toString(), contains('domainRegistrantCompanyName: null'));

      expect(
          (await ZeroBounceSDK(testKey,
                      httpClient:
                          FakeClient((_) => answer({'Credits': 2375323})))
                  .getCredits())
              .credits,
          2375323);
      expect(
          (await ZeroBounceSDK(testKey,
                      httpClient: FakeClient((_) => answer({'Credits': '-1'})))
                  .getCredits())
              .credits,
          -1);
    });

    test('the greylist answer is a result with its message', () async {
      final (sdk, _) =
          sdkAnswering({'Message': 'Greylist validation still in progress.'});
      final result = await sdk.validateEmail('a@b.c');
      expect(result.address, isNull);
      expect(result.message, 'Greylist validation still in progress.');
    });

    test('a file job message list is joined with a newline', () async {
      final (sdk, _) = sdkAnswering({
        'success': true,
        'file_id': 'f1',
        'message': ['one', 'two']
      });
      expect(
          (await sdk.sendFile(
                  file: csv,
                  fileName: 'a.csv',
                  emailAddressColumn: 1,
                  hasHeaderRow: true))
              .message,
          'one\ntwo');
    });

    test('success given as 1 or "true" reads as true', () async {
      for (final flag in [1, 'true', 'True']) {
        final (sdk, _) = sdkAnswering({'success': flag, 'file_id': 'f1'});
        expect((await sdk.deleteFile('f1')).success, isTrue);
      }
    });

    test(
        'listFilters returns the API message when it sends one instead of a list',
        () async {
      final (sdk, _) = sdkAnswering({'Message': 'No filters.'});
      final list = await sdk.listFilters();
      expect(list.filters, isEmpty);
      expect(list.message, 'No filters.');
    });

    test('a batch keeps per-address errors on the result', () async {
      final (sdk, _) = sdkAnswering(fixtures['validateBatch']!.first);
      final result = await sdk.validateBatch([const ZBBatchEmail('a@b.c')]);
      expect(result.emailBatch.single.status, 'valid');
      expect(result.errors, hasLength(1));
    });

    test('Inbox Placement delete treats an empty 2xx as success', () async {
      for (final status in [200, 204]) {
        final (sdk, _) = sdkAnswering('', status: status, contentType: null);
        expect(await sdk.deleteInboxPlacementTest('t1'), isEmpty);
      }
    });
  });

  group('errors carry the HTTP status', () {
    test('a non-2xx answer is an error with its status and the API message',
        () async {
      for (final status in [400, 401, 403, 404, 429, 500, 503]) {
        await expectLater(
            run('getCredits', {'error': 'Something broke'}, status: status),
            throwsZB(status, 'Something broke'));
      }
      await expectLater(
          run('getInboxPlacementTest', {'detail': 'Not found.'}, status: 404),
          throwsZB(404, 'Not found.'));
    });

    test('an invalid key on HTTP 200 is an error', () async {
      for (final name in [
        'validateEmail',
        'getEmailActivity',
        'getApiUsage',
        'scoreEmail',
        'getCredits'
      ]) {
        await expectLater(
            run(name, {
              'error': 'Invalid API key or your account ran out of credits'
            }),
            throwsZB(200, contains('Invalid API key')));
      }
      await expectLater(run('addFilter', {'Error': 'Invalid API Key'}),
          throwsZB(200, 'Invalid API Key'));
      await expectLater(run('scoreEmail', {'error': 'invalid email'}),
          throwsZB(200, 'invalid email'));
    });

    test('an account-level batch error is thrown', () async {
      await expectLater(
          run('validateBatch', {
            'email_batch': <Object>[],
            'errors': [
              {'error': 'Error: Invalid API Key', 'email_address': 'all'},
            ],
          }),
          throwsZB(200, 'Invalid API Key'));
    });

    test(
        '"success": false on a 2xx is an error, whichever duplicate key says so',
        () async {
      await expectLater(
          run('sendFile', {'success': false, 'message': 'File rejected'}),
          throwsZB(200, 'File rejected'));
      await expectLater(
          run('sendFile', {
            'success': 'False',
            'message': ['Bad', 'file']
          }),
          throwsZB(200, 'Bad\nfile'));
      await expectLater(
          run('getFileStatus',
              '{"success": false, "success": true, "file_id": "f"}'),
          throwsZB(200));
      await expectLater(run('deleteFile', {'success': 0, 'message': 'no'}),
          throwsZB(200, 'no'));
    });

    test('a message-only answer is an error on every typed call', () async {
      for (final name in [
        'getCredits',
        'validateEmail',
        'getEmailActivity',
        'findEmailByDomain',
        'findEmailFormatByDomain',
        'sendFile',
        'getFileStatus',
        'deleteFile',
        'validateS3File',
        'exportSftpFile',
        'sendListEvaluatorFile',
      ]) {
        await expectLater(run(name, {'message': 'Something happened'}),
            throwsZB(200, 'Something happened'),
            reason: name);
        await expectLater(run(name, <String, Object>{}), throwsZB(200),
            reason: name);
      }
      await expectLater(
          run('validateEmail',
              {'message': 'x', 'address': null, 'status': null}),
          throwsZB(200, 'x'));
    });

    test('the exempt calls return a message-only answer as data', () async {
      expect(
          await run('getListEvaluatorResult', {'message': 'Still evaluating'}),
          {'message': 'Still evaluating'});
      expect(await run('addFilter', {'Message': 'Filter has been added.'}),
          {'Message': 'Filter has been added.'});
      expect(await run('getInboxPlacementWebhook', {'detail': 'No webhook'}),
          {'detail': 'No webhook'});
    });

    test('an empty 2xx is an error everywhere else', () async {
      for (final call
          in apiCalls.where((c) => c.name != 'deleteInboxPlacementTest')) {
        for (final status in [200, 204]) {
          await expectLater(
              run(call.name, '', status: status, contentType: null),
              throwsZB(status),
              reason: call.name);
        }
      }
    });

    test('HTML or non-JSON on a 2xx is a short error with status 200',
        () async {
      const page =
          '<!DOCTYPE html><html><head><title>Access denied | 1020</title></head>'
          '<body>blocked</body></html>';
      await expectLater(run('getCredits', page, contentType: 'text/html'),
          throwsZB(200, contains('HTML error page ("Access denied | 1020")')));
      await expectLater(
          run('getCredits', page, contentType: 'application/json'),
          throwsZB(200));
      await expectLater(run('getCredits', '{"Credits": "1",}'),
          throwsZB(200, contains('not valid JSON')));
      await expectLater(run('getCredits', 'NaN'), throwsZB(200));
      await expectLater(
          run('getCredits', '\u{FEFF}{"Credits": "1"}'), throwsZB(200));
      await expectLater(
          run('getCredits', [0xff, 0xfe, 0x7b, 0x7d]), throwsZB(200));
      await expectLater(run('getCredits', 'x' * 5000),
          throwsZB(200, contains('not valid JSON')));
      final error = await run('getCredits', 'Error: Error: plain failure')
          .then<Object?>((_) => null, onError: (Object e) => e);
      expect((error! as ZBException).message, 'plain failure');
    });

    test('a body nested too deeply is refused unparsed', () async {
      await expectLater(run('getCredits', '${'[' * 600}${']' * 600}'),
          throwsZB(200, contains('nested too deeply')));
    });

    test('a JSON value of the wrong shape is an error with status 200',
        () async {
      for (final body in ['[]', '"x"', '5', 'true', 'null']) {
        await expectLater(run('getCredits', body), throwsZB(200), reason: body);
      }
      await expectLater(run('listS3Files', {'name': 'x'}),
          throwsZB(200, contains('unexpected shape')));
    });

    test('a file status with no known field is an error', () async {
      await expectLater(
          run('getFileStatus', {'file_status': ''}), throwsZB(200));
      await expectLater(run('getFileStatus', {'unknown': 1}), throwsZB(200));
    });
  });

  group('field types are part of the shape', () {
    test('Credits must be an integer, as a JSON string or a JSON integer',
        () async {
      for (final credits in [
        'abc',
        '5.0',
        '',
        5.5,
        5.0,
        true,
        null,
        '99999999999999999999'
      ]) {
        await expectLater(
            run('getCredits', {'Credits': credits}), throwsZB(200),
            reason: '$credits');
      }
      await expectLater(
          run('getCredits', {'other': 1}), throwsZB(200, contains('Credits')));
      await expectLater(run('getCredits', '{"Credits": 1e3}'), throwsZB(200));
    });

    test('validate needs address and status, also in every batch row',
        () async {
      await expectLater(run('validateEmail', {'address': 'a@b.c'}),
          throwsZB(200, contains('status')));
      await expectLater(
          run('validateEmail', {'status': 'valid', 'Message': 'x'}),
          throwsZB(200, contains('address')));
      await expectLater(
          run('validateBatch', {
            'email_batch': [
              {'address': 'a@b.c'},
            ],
          }),
          throwsZB(200, contains('email_batch[0].status')));
    });

    test(
        'each wrong JSON type at every nested field is an error naming that field',
        () async {
      const wrongValues = <Object?>[
        5,
        1.5,
        'x',
        true,
        null,
        <String, Object>{},
        <Object>[],
        ['x']
      ];
      final problems = <String>[];
      var count = 0;
      for (final MapEntry(key: name, value: answers) in accepted.entries) {
        final types = resultTypes[name];
        if (types == null) continue;
        for (final raw in answers) {
          final answer = raw is String ? jsonDecode(raw) : raw;
          if (name == 'validateEmail' && (answer as Map)['address'] == null) {
            continue;
          }
          for (final (path, declared, required, set) in slots(answer, types)) {
            for (final value in wrongValues) {
              if (allows(declared, value) || (value == null && !required)) {
                continue;
              }
              final fileJobList = path == 'message' &&
                  types.any(fileJobMessageResults.contains) &&
                  value is List &&
                  value.every((line) => line is String);
              if (fileJobList) continue;
              count++;
              try {
                await run(name, jsonEncode(set(value)));
                problems.add('$name $path=$value was accepted');
              } on ZBException catch (error) {
                final ok = error.statusCode == 200 &&
                    (error.message.contains('($path)') ||
                        // Breaking a required field can also make the
                        // answer message-only or file-status-less.
                        !error.message.contains('unexpected type'));
                if (!ok) problems.add('$name $path=$value: ${error.message}');
              }
            }
          }
        }
      }
      expect(problems, isEmpty);
      expect(count, greaterThan(400));
    });
  });

  group('downloads', () {
    test('return the CSV text', () async {
      for (final call in apiCalls.where((c) => c.download)) {
        expect(
            await call
                .invoke(sdkAnswering('a,b\n1,2\n', contentType: 'text/csv').$1),
            'a,b\n1,2\n');
      }
    });

    test('reject JSON, HTML, an empty body and an error status', () async {
      for (final call in apiCalls.where((c) => c.download)) {
        final name = call.name;
        await expectLater(
            run(name, {'success': false, 'message': 'File not found'},
                contentType: 'text/csv'),
            throwsZB(200, 'File not found'));
        await expectLater(
            run(name, 'a,b', contentType: 'application/json'), throwsZB(200));
        await expectLater(
            run(name, 'a,b', contentType: 'application/problem+json'),
            throwsZB(200));
        await expectLater(
            run(name, '<html><body>x</body></html>', contentType: 'text/csv'),
            throwsZB(200));
        await expectLater(run(name, 'a,b\n', contentType: 'text/html'),
            throwsZB(200, contains('text/html')));
        await expectLater(run(name, '  \n', contentType: 'text/csv'),
            throwsZB(200, contains('Empty')));
        await expectLater(
            run(name, 'Not Found', status: 404, contentType: 'text/plain'),
            throwsZB(404, 'Not Found'));
      }
    });

    test('keep a CSV cell that mentions <body>', () async {
      expect(
          await run('getFile', 'email,note\na@b.c,"<body> tag"\n',
              contentType: 'text/csv'),
          contains('<body>'));
    });
  });
}
