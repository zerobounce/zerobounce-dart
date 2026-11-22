@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zerobounce_sdk/zerobounce_sdk.dart';

import 'support/fake.dart';
import 'support/network_guard.dart';

/// A loopback server that answers every connection with [respond] (raw bytes,
/// so a test can send a broken answer), then closes it.
Future<(ServerSocket, String)> rawServer(
    FutureOr<void> Function(Socket socket, String request) respond) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((socket) {
    final buffer = StringBuffer();
    var answered = false;
    socket.listen((data) async {
      buffer.write(latin1.decode(data));
      final text = buffer.toString();
      final headerEnd = text.indexOf('\r\n\r\n');
      if (answered || headerEnd < 0) return;
      final length = RegExp(r'content-length: *(\d+)', caseSensitive: false)
          .firstMatch(text);
      if (length != null &&
          text.length < headerEnd + 4 + int.parse(length[1]!)) {
        return;
      }
      answered = true;
      await respond(socket, text);
    }, onError: (Object _) {});
  });
  return (server, 'http://127.0.0.1:${server.port}');
}

/// A client on the SDK's own default HTTP client, every base URL at [base].
ZeroBounceSDK loopbackSdk(String base,
        {Duration timeout = const Duration(seconds: 5)}) =>
    ZeroBounceSDK(testKey,
        baseUrl: '$base/v2',
        bulkBaseUrl: '$base/v2',
        bulkRootBaseUrl: base,
        listEvaluatorBaseUrl: '$base/v2/listevaluator',
        inboxPlacementBaseUrl: '$base/api/ipt',
        emailFinderBaseUrl: '$base/email-finder',
        domainSearchBaseUrl: '$base/domain-search',
        timeout: timeout);

/// One call per HTTP method the SDK uses.
final byMethod = <String, Future<Object?> Function(ZeroBounceSDK)>{
  'GET': (z) => z.getCredits(),
  'POST': (z) => z.addFilter(
      rule: ZBFilterRule.allow, target: ZBFilterTarget.domain, value: 'a.b'),
  'PUT': (z) => z.setInboxPlacementWebhook('https://example.com/hook'),
  'DELETE': (z) => z.deleteInboxPlacementTest('t1'),
  'download': (z) => z.getFile('f1'),
};

void main() {
  installNetworkGuard();

  test('the default client answers a real loopback server', () async {
    final (server, base) = await rawServer((socket, request) async {
      expect(
          request, startsWith('GET /v2/getcredits?api_key=$testKey HTTP/1.1'));
      socket.write('HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n'
          'Content-Length: 16\r\nConnection: close\r\n\r\n{"Credits":"77"}');
      await socket.close();
    });
    addTearDown(server.close);
    final sdk = loopbackSdk(base);
    addTearDown(sdk.close);
    expect((await sdk.getCredits()).credits, 77);
  });

  test(
      'a refused connection is a transport error with status 0 on every method',
      () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    final sdk = loopbackSdk('http://127.0.0.1:$port');
    addTearDown(sdk.close);
    for (final MapEntry(key: method, value: call) in byMethod.entries) {
      await expectLater(call(sdk), throwsZB(0, contains('request failed')),
          reason: method);
    }
  });

  for (final MapEntry(key: method, value: call) in byMethod.entries) {
    test('$method: a body cut short of its Content-Length is an error',
        () async {
      final (server, base) = await rawServer((socket, _) async {
        socket.write('HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n'
            'Content-Length: 1016\r\n\r\n{"Credits":"77"}');
        await socket.flush();
        await socket.close();
      });
      addTearDown(server.close);
      final sdk = loopbackSdk(base);
      addTearDown(sdk.close);
      await expectLater(call(sdk), throwsZB(0));
    });

    test('$method: a chunked body cut mid-stream is an error', () async {
      final (server, base) = await rawServer((socket, _) async {
        socket.write('HTTP/1.1 200 OK\r\nContent-Type: text/csv\r\n'
            'Transfer-Encoding: chunked\r\n\r\n10\r\n{"Credits":"7"} \r\n40\r\nabc');
        await socket.flush();
        await socket.close();
      });
      addTearDown(server.close);
      final sdk = loopbackSdk(base);
      addTearDown(sdk.close);
      await expectLater(call(sdk), throwsZB(0));
    });

    test('$method: a real redirect with a Location is refused and not followed',
        () async {
      for (final status in [301, 302, 303, 307, 308]) {
        var connections = 0;
        final (server, base) = await rawServer((socket, _) async {
          connections++;
          socket.write(
              'HTTP/1.1 $status Moved\r\nLocation: http://127.0.0.1:1/elsewhere\r\n'
              'Content-Length: 0\r\nConnection: close\r\n\r\n');
          await socket.close();
        });
        final sdk = loopbackSdk(base);
        await expectLater(call(sdk), throwsZB(status, contains('redirect')));
        expect(connections, 1);
        sdk.close();
        await server.close();
      }
    });

    test('$method: the default client times out on a server that never answers',
        () async {
      final (server, base) = await rawServer((socket, _) {});
      addTearDown(server.close);
      final sdk = loopbackSdk(base, timeout: const Duration(milliseconds: 300));
      addTearDown(sdk.close);
      await expectLater(
          call(sdk), throwsZB(0, contains('timed out after 300 ms')));
    });
  }

  test('the default timeout is 120 seconds', () {
    final sdk = ZeroBounceSDK(testKey);
    addTearDown(sdk.close);
    expect(sdk.toString(), contains('timeout: 0:02:00.000000'));
  });

  test('a 3xx from any fake is refused, for every redirect status', () async {
    for (final status in [300, 301, 302, 303, 304, 307, 308]) {
      final fake = FakeClient((_) => answer('',
          status: status, headers: {'location': 'https://evil.example/'}));
      await expectLater(ZeroBounceSDK(testKey, httpClient: fake).getCredits(),
          throwsZB(status));
    }
  });
}
