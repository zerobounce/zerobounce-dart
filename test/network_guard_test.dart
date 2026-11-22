@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zerobounce_sdk/zerobounce_sdk.dart';

import 'support/fake.dart';
import 'support/network_guard.dart';

void main() {
  installNetworkGuard();

  test('refuses a socket to a remote host', () async {
    await expectLater(
        Socket.connect('api.zerobounce.net', 443),
        throwsA(isA<SocketException>()
            .having((e) => e.message, 'message', contains('Network guard'))));
  });

  test('refuses an HttpClient request to a remote host', () async {
    final client = HttpClient();
    addTearDown(client.close);
    await expectLater(
        client.getUrl(Uri.parse('https://api.zerobounce.net/v2/getcredits')),
        throwsA(isA<SocketException>()
            .having((e) => e.message, 'message', contains('Network guard'))));
  });

  test("refuses the SDK's own default client, as a transport error", () async {
    final sdk = ZeroBounceSDK(testKey);
    addTearDown(sdk.close);
    await expectLater(sdk.getCredits(), throwsZB(0, contains('Network guard')));
  });

  test('allows loopback', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final socket = await Socket.connect('127.0.0.1', server.port);
    await socket.close();
  });

  test('is installed by every test file', () {
    final files = Directory('test')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('_test.dart'));
    expect(files, isNotEmpty);
    for (final file in files) {
      expect(file.readAsStringSync(), contains('installNetworkGuard();'),
          reason: file.path);
    }
  });
}
