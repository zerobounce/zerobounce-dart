import 'dart:async';
import 'dart:io';

/// The test suite is offline. Every test file calls this first: from then on
/// a socket to any host other than 127.0.0.1, localhost or [::1] fails with
/// "Network guard: ... refused", so a test that reaches the real API (through
/// the SDK's default client, a stray HttpClient or a raw socket) cannot pass.
/// `test/network_guard_test.dart` checks that every test file installs it.
void installNetworkGuard() {
  IOOverrides.global = _NetworkGuard();
  HttpOverrides.global = _HttpGuard();
}

const _loopback = {'127.0.0.1', 'localhost', '::1', '[::1]'};

String _hostOf(Object? host) =>
    host is InternetAddress ? host.address : '$host';

SocketException _refusal(Object? host, int port) => SocketException(
    'Network guard: connection to ${_hostOf(host)}:$port refused (tests are offline)');

base class _NetworkGuard extends IOOverrides {
  @override
  Future<Socket> socketConnect(Object? host, int port,
      {Object? sourceAddress, int sourcePort = 0, Duration? timeout}) {
    if (!_loopback.contains(_hostOf(host))) {
      return Future.error(_refusal(host, port));
    }
    return super.socketConnect(host, port,
        sourceAddress: sourceAddress, sourcePort: sourcePort, timeout: timeout);
  }

  @override
  Future<ConnectionTask<Socket>> socketStartConnect(Object? host, int port,
      {Object? sourceAddress, int sourcePort = 0}) {
    if (!_loopback.contains(_hostOf(host))) {
      return Future.error(_refusal(host, port));
    }
    return super.socketStartConnect(host, port,
        sourceAddress: sourceAddress, sourcePort: sourcePort);
  }
}

/// HttpClient opens https connections through SecureSocket, which does not
/// consult IOOverrides, so every client gets a guarded connection factory.
base class _HttpGuard extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..connectionFactory = (uri, proxyHost, proxyPort) {
          final host = proxyHost ?? uri.host;
          final port = proxyPort ?? uri.port;
          if (!_loopback.contains(host)) {
            return Future.error(_refusal(host, port));
          }
          return uri.scheme == 'https'
              ? SecureSocket.startConnect(host, port, context: context)
              : Socket.startConnect(host, port);
        };
}
