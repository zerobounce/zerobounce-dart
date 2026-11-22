import 'errors.dart';

const _refusedUrlDetail =
    ' (plain http:// only to 127.0.0.1, localhost or [::1]) with a host, '
    'without user information, a query string or a fragment ("@", "?" or "#"), '
    'a backslash, whitespace, control or non-ASCII characters, a "%" in the '
    'host, or an encoded slash or a dot segment in the path';

const _loopbackHosts = {'127.0.0.1', 'localhost', '[::1]'};

final _digits = RegExp(r'^[0-9]*$');
final _ipv6Literal = RegExp(r'^\[[0-9A-Fa-f:.]+\]$');
final _portSuffix = RegExp(r'^:[0-9]+$');

/// The authority's host in lower case, or null when it is not a plain ASCII
/// host with an optional numeric port.
String? _rawHost(String authority) {
  var host = authority;
  if (host.startsWith('[')) {
    final close = host.indexOf(']');
    if (close < 0) return null;
    final port = host.substring(close + 1);
    host = host.substring(0, close + 1);
    if (!_ipv6Literal.hasMatch(host)) return null;
    if (port.isNotEmpty && !_portSuffix.hasMatch(port)) return null;
    return host.toLowerCase();
  }
  final colon = host.lastIndexOf(':');
  if (colon >= 0) {
    if (!_digits.hasMatch(host.substring(colon + 1))) return null;
    host = host.substring(0, colon);
  }
  if (host.isEmpty || host.contains(':') || host.contains('%')) return null;
  return host.toLowerCase();
}

/// Checks a URL the API key is about to be sent to.
///
/// The raw text is checked before [Uri.parse] sees it: a parser can trim,
/// strip tabs, turn backslashes into slashes or fold an encoded host, so a URL
/// it accepts could send the key somewhere other than the text says. The
/// messages never quote the URL, which may carry a credential.
///
/// A base URL ([isBase]) also refuses a query string, a fragment, an encoded
/// slash and a dot segment in its path.
String checkTransportUrl(String url, String name, {required bool isBase}) {
  ZBException short() =>
      ZBException('ZeroBounce: $name must be an https:// URL.');
  ZBException refused() => ZBException(
      'ZeroBounce: $name must be an https:// URL$_refusedUrlDetail.');

  final lowered = url.toLowerCase();
  final isHttps = lowered.startsWith('https://');
  final isHttp = lowered.startsWith('http://');
  if (!isHttps && !isHttp) throw short();
  final rest = url.substring(isHttps ? 8 : 7);
  var authorityEnd = rest.length;
  for (var i = 0; i < rest.length; i++) {
    final c = rest[i];
    if (c == '/' || c == '?' || c == '#' || c == r'\') {
      authorityEnd = i;
      break;
    }
  }
  final authority = rest.substring(0, authorityEnd);
  if (authority.contains('@')) {
    throw ZBException(
        'ZeroBounce: $name must not contain a username or password.');
  }
  if (isBase && (url.contains('?') || url.contains('#'))) {
    throw ZBException(
      'ZeroBounce: $name must not contain a query string or a fragment ("?" or "#").',
    );
  }
  for (final unit in url.codeUnits) {
    // Printable ASCII only: no control, whitespace, invisible, non-ASCII or
    // lone surrogate character, and no backslash.
    if (unit <= 0x20 || unit >= 0x7f || unit == 0x5c) throw refused();
  }
  final host = _rawHost(authority);
  if (host == null) throw refused();
  if (isHttp && !_loopbackHosts.contains(host)) throw short();
  if (isBase) {
    for (final segment in rest.substring(authority.length).split('/')) {
      var decoded = segment;
      try {
        decoded = Uri.decodeComponent(segment);
      } on ArgumentError {
        // Keep the raw segment.
      } on FormatException {
        // Keep the raw segment.
      }
      final lower = segment.toLowerCase();
      if (decoded == '.' ||
          decoded == '..' ||
          decoded.contains('/') ||
          decoded.contains(r'\')) {
        throw refused();
      }
      if (lower.contains('%2f') ||
          lower.contains('%5c') ||
          lower.contains('%00')) {
        throw refused();
      }
    }
  }
  final Uri parsed;
  try {
    parsed = Uri.parse(url);
  } on FormatException {
    throw short();
  }
  if (parsed.userInfo.isNotEmpty) {
    throw ZBException(
        'ZeroBounce: $name must not contain a username or password.');
  }
  final parsedHost = parsed.host.toLowerCase();
  final bareHost =
      host.startsWith('[') ? host.substring(1, host.length - 1) : host;
  if (parsedHost != host && parsedHost != bareHost) throw refused();
  return url;
}

/// An https base URL with its trailing slashes removed (no `/v2//validate`).
String normalizeBaseUrl(String url, String name) {
  checkTransportUrl(url, name, isBase: true);
  var end = url.length;
  while (end > 0 && url.codeUnitAt(end - 1) == 0x2f) {
    end--;
  }
  return url.substring(0, end);
}

/// Checks an API key before it is stored or sent: not empty, no surrounding
/// whitespace, printable ASCII only (an ordinary space in the middle stays
/// allowed). ZeroBounce keys are ASCII; refusing anything else keeps every
/// spelling of the key that redaction has to cover in ASCII as well.
String checkApiKey(String apiKey) {
  if (apiKey.trim().isEmpty) {
    throw const ZBException(
      'ZeroBounce: API key parameter is missing. Please provide a valid API key.',
    );
  }
  if (apiKey != apiKey.trim()) {
    throw const ZBException(
      'ZeroBounce: API key has surrounding whitespace or control characters.',
    );
  }
  for (final unit in apiKey.codeUnits) {
    if (unit < 0x20 || unit == 0x7f) {
      throw const ZBException(
        'ZeroBounce: API key has surrounding whitespace or control characters.',
      );
    }
    if (unit > 0x7f) {
      throw const ZBException(
        'ZeroBounce: API key must contain printable ASCII characters only.',
      );
    }
  }
  return apiKey;
}

/// Whether a text argument is missing: null, empty or only whitespace.
bool isMissing(String? value) => value == null || value.trim().isEmpty;

/// Throws the SDK's "parameter is missing" error.
Never parameterIsMissing(String name, [String extra = '']) {
  throw ZBException(
    'ZeroBounce: $name parameter is missing.${extra.isEmpty ? '' : ' $extra'}',
  );
}

/// Throws the SDK's "parameter is invalid" error.
Never parameterIsInvalid(String name, [String extra = '']) {
  throw ZBException(
    'ZeroBounce: $name parameter is invalid.${extra.isEmpty ? '' : ' $extra'}',
  );
}

/// A required text argument, checked for presence.
String requireText(String? value, String name, [String extra = '']) {
  if (isMissing(value)) parameterIsMissing(name, extra);
  return value!;
}

/// A caller value as one URL path segment: trimmed, percent-encoded, never
/// `.` or `..`.
String pathSegment(String? value, String name) {
  final text = (value ?? '').trim();
  if (text.isEmpty) parameterIsMissing(name);
  if (text == '.' || text == '..') parameterIsInvalid(name);
  return Uri.encodeComponent(text);
}

/// A 1-based column index.
int checkColumn(int value, String name) {
  if (value < 1) parameterIsInvalid(name, 'Column indexes start at 1.');
  return value;
}
