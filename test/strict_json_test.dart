@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zerobounce_sdk/zerobounce_sdk.dart';

import 'support/calls.dart';
import 'support/fake.dart';
import 'support/network_guard.dart';

/// The shared strict JSON corpus (check E7), copied byte for byte from
/// zerobounce/sdk-docs `sdk-docs/skills/zerobounce-sdk/references/strict-json-corpus.tsv`.
/// Copy it over again when it changes; never edit it here.
({List<String> reject, List<String> accept}) corpus() {
  final reject = <String>[];
  final accept = <String>[];
  for (final line
      in File('test/fixtures/strict-json-corpus.tsv').readAsLinesSync()) {
    if (line.trim().isEmpty || line.startsWith('#')) continue;
    final tab = line.indexOf('\t');
    final body = jsonDecode(line.substring(tab + 1)) as String;
    switch (line.substring(0, tab)) {
      case 'REJECT':
        reject.add(body);
      case 'ACCEPT':
        accept.add(body);
      default:
        throw StateError('Unknown verdict: $line');
    }
  }
  return (reject: reject, accept: accept);
}

void main() {
  installNetworkGuard();

  final (:reject, :accept) = corpus();
  final jsonCalls = apiCalls.where((c) => !c.download).toList();

  test('the corpus is read', () {
    expect(reject.length, greaterThan(40));
    expect(accept, isNotEmpty);
  });

  test('every REJECT body is an error with status 200 on every JSON call',
      () async {
    final accepted = <String>[];
    for (final call in jsonCalls) {
      for (final body in reject) {
        // A zero-byte 2xx is the documented success of this one call.
        if (call.name == 'deleteInboxPlacementTest' && body.isEmpty) continue;
        final (sdk, _) = sdkAnswering(body);
        try {
          await call.invoke(sdk);
          accepted.add('${call.name} ${jsonEncode(body)}');
        } on ZBException catch (error) {
          if (error.statusCode != 200) {
            accepted
                .add('${call.name} ${jsonEncode(body)}: ${error.statusCode}');
          }
        }
      }
    }
    expect(accepted, isEmpty);
  });

  test('every ACCEPT body parses as JSON', () async {
    for (final body in accept) {
      final (sdk, _) = sdkAnswering(body);
      // A call typed as any JSON value returns exactly what was parsed.
      expect(await sdk.getInboxPlacementTestTypes(), jsonDecode(body),
          reason: jsonEncode(body));
      // A typed call may refuse the shape or a field, but never as invalid JSON.
      for (final call in jsonCalls) {
        try {
          await call.invoke(sdkAnswering(body).$1);
        } on ZBException catch (error) {
          expect(error.message, isNot(contains('not valid JSON')),
              reason: '${call.name} ${jsonEncode(body)}');
        }
      }
    }
  });
}
