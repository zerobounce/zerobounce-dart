import 'dart:convert';

/// What a message says instead when a decoded view of it still holds a
/// secret.
const credentialOmittedMessage =
    'ZeroBounce: the response text was omitted because it contained a credential.';

/// What a message says instead of text too long to redact.
const textTooLongMessage =
    'ZeroBounce: the text was omitted because it is too long to show.';

/// The most text redaction works on. No message the SDK builds is near this
/// long; longer text is replaced, whole, by [textTooLongMessage].
const maxRedactedLength = 65536;

/// The SDK's own request encoding plus three echo layers.
const _decodeLayers = 4;

const _hex = '0123456789ABCDEF';

String _percentEncode(String text, bool Function(int unit) keep,
    {bool spaceAsPlus = false}) {
  final out = StringBuffer();
  for (final byte in utf8.encode(text)) {
    if (spaceAsPlus && byte == 0x20) {
      out.write('+');
    } else if (byte < 0x80 && keep(byte)) {
      out.writeCharCode(byte);
    } else {
      out
        ..write('%')
        ..write(_hex[byte >> 4])
        ..write(_hex[byte & 0xf]);
    }
  }
  return out.toString();
}

bool _isAlnum(int c) =>
    (c >= 0x30 && c <= 0x39) ||
    (c >= 0x41 && c <= 0x5a) ||
    (c >= 0x61 && c <= 0x7a);

/// encodeURIComponent: spaces as %20.
String _urlEncoded(String text) => _percentEncode(
    text, (c) => _isAlnum(c) || "-_.!~*'()".codeUnits.contains(c));

/// application/x-www-form-urlencoded, as `package:http` writes form bodies and
/// query strings: spaces as "+".
String _formEncoded(String text) =>
    _percentEncode(text, (c) => _isAlnum(c) || '*-._'.codeUnits.contains(c),
        spaceAsPlus: true);

/// JavaScript's escape(): the spelling some servers echo.
String _escaped(String text) =>
    _percentEncode(text, (c) => _isAlnum(c) || '@*_+-./'.codeUnits.contains(c));

/// The body of jsonEncode(text): how a JSON request body quotes it.
String _jsonEscaped(String text) {
  final quoted = jsonEncode(text);
  return quoted.substring(1, quoted.length - 1);
}

/// The same with "/" written as "\/", as PHP's json_encode writes it.
String _jsonEscapedSlash(String text) =>
    _jsonEscaped(text).replaceAll('/', r'\/');

/// Every form a secret can take in a message: the raw secret and each one- or
/// two-step JSON quoting of it, each as is, URL-encoded and form-encoded; plus
/// escape() of the raw secret. Longest first, so no form leaves part of a
/// longer one behind.
List<String> secretForms(String secret) {
  const quotings = [_jsonEscaped, _jsonEscapedSlash];
  final quoted = <String>[secret];
  for (final once in quotings) {
    final first = once(secret);
    quoted.add(first);
    for (final twice in quotings) {
      quoted.add(twice(first));
    }
  }
  final forms = <String>{_escaped(secret)};
  for (final text in quoted) {
    forms
      ..add(text)
      ..add(_urlEncoded(text))
      ..add(_formEncoded(text));
  }
  final list = forms.where((f) => f.isNotEmpty).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  return list;
}

// ---------------------------------------------------------------------------
// Case folding.

/// Canonical singletons whose decomposition is ASCII (Unicode NFD), so a body
/// cannot spell an ASCII key with them.
const _asciiSingletons = {0x037e: 0x3b, 0x1fef: 0x60, 0x212a: 0x4b};

List<String> _foldRune(int rune) {
  var text = String.fromCharCode(_asciiSingletons[rune] ?? rune);
  for (var round = 0; round < 3; round++) {
    final next = text.toUpperCase().toLowerCase();
    if (next == text) break;
    text = next;
  }
  return [for (final r in text.runes) String.fromCharCode(r)];
}

/// Folded text with code unit offsets into the original, for masking.
class _FoldedView {
  final scalars = <String>[];
  final starts = <int>[];
  final ends = <int>[];
  final droppable = <bool>[];
}

bool _isAscii(String text) => text.codeUnits.every((c) => c < 0x80);

_FoldedView _buildFolded(String text) {
  final view = _FoldedView();
  if (_isAscii(text)) {
    for (var i = 0; i < text.length; i++) {
      view.scalars.add(text[i].toLowerCase());
      view.starts.add(i);
      view.ends.add(i + 1);
      view.droppable.add(false);
    }
    return view;
  }
  var offset = 0;
  for (final rune in text.runes) {
    final width = rune > 0xffff ? 2 : 1;
    for (final scalar in _foldRune(rune)) {
      final drop = scalar == '\u0307' &&
          view.scalars.isNotEmpty &&
          view.scalars.last == 'i';
      view.scalars.add(scalar);
      view.starts.add(offset);
      view.ends.add(offset + width);
      view.droppable.add(drop);
    }
    offset += width;
  }
  return view;
}

String _foldedSpelling(String text) {
  final view = _buildFolded(text);
  final out = StringBuffer();
  for (var i = 0; i < view.scalars.length; i++) {
    if (!view.droppable[i]) out.write(view.scalars[i]);
  }
  return out.toString();
}

/// Full case fold (no locale), then U+0307 after `i` dropped.
String _simpleFold(String text) => _foldedSpelling(text);

List<List<int>> _occurrences(List<String> needle, _FoldedView hay) {
  final text = hay.scalars;
  final found = <List<int>>[];
  if (needle.isEmpty || text.length < needle.length) return found;
  for (var start = 0; start < text.length; start++) {
    if (text[start] != needle[0]) continue;
    var matches = true;
    var position = start + 1;
    for (var offset = 1; offset < needle.length; offset++) {
      while (position < text.length &&
          hay.droppable[position] &&
          text[position] != needle[offset]) {
        position++;
      }
      if (position >= text.length || text[position] != needle[offset]) {
        matches = false;
        break;
      }
      position++;
    }
    if (matches) found.add([hay.starts[start], hay.ends[position - 1]]);
  }
  return found;
}

/// Masks every case-insensitive spelling of the secrets' forms with `***`.
String _maskFolded(String text, List<String> secrets) {
  final needles = <String>{};
  for (final secret in secrets) {
    if (secret.isEmpty) continue;
    for (final form in [secret, ...secretForms(secret)]) {
      final spelling = _foldedSpelling(form);
      if (spelling.isNotEmpty) needles.add(spelling);
    }
  }
  if (needles.isEmpty || text.isEmpty) return text;
  final view = _buildFolded(text);
  final ranges = <List<int>>[];
  for (final needle in needles) {
    final scalars = [for (final r in needle.runes) String.fromCharCode(r)];
    for (final range in _occurrences(scalars, view)) {
      final span = text.substring(range[0], range[1]);
      // Left to the decode check, which drops the whole text if needed.
      if (span.contains('%') || span.contains(r'\') || span.contains('&')) {
        continue;
      }
      ranges.add(range);
    }
  }
  if (ranges.isEmpty) return text;
  ranges.sort((a, b) => a[0] != b[0] ? a[0] - b[0] : b[1] - a[1]);
  final merged = <List<int>>[];
  for (final range in ranges) {
    if (merged.isNotEmpty && range[0] < merged.last[1]) {
      if (range[1] > merged.last[1]) merged.last[1] = range[1];
    } else {
      merged.add([range[0], range[1]]);
    }
  }
  final out = StringBuffer();
  var index = 0;
  for (final range in merged) {
    out
      ..write(text.substring(index, range[0]))
      ..write('***');
    index = range[1];
  }
  out.write(text.substring(index));
  return out.toString();
}

// ---------------------------------------------------------------------------
// Decoders.

int _hexDigit(int unit) {
  if (unit >= 0x30 && unit <= 0x39) return unit - 0x30;
  if (unit >= 0x41 && unit <= 0x46) return unit - 0x37;
  if (unit >= 0x61 && unit <= 0x66) return unit - 0x57;
  return -1;
}

int _hexAt(String text, int i) =>
    i < text.length ? _hexDigit(text.codeUnitAt(i)) : -1;

String _codePointText(int code) =>
    (code < 0 || code > 0x10ffff) ? '\uFFFD' : String.fromCharCode(code);

/// The UTF-8 sequence length a lead byte announces, or 0.
int _utf8SequenceLength(int byte) {
  if (byte < 0x80) return 1;
  if (byte >= 0xc2 && byte <= 0xdf) return 2;
  if (byte >= 0xe0 && byte <= 0xef) return 3;
  if (byte >= 0xf0 && byte <= 0xf4) return 4;
  return 0;
}

/// Bytes decoded one UTF-8 sequence at a time; a byte that starts no valid
/// sequence stays as [keep] renders it.
String _bytesAsUtf8(List<int> bytes, String Function(int byte) keep) {
  final out = StringBuffer();
  var i = 0;
  while (i < bytes.length) {
    final length = _utf8SequenceLength(bytes[i]);
    if (length > 0 && i + length <= bytes.length) {
      try {
        out.write(utf8.decode(bytes.sublist(i, i + length)));
        i += length;
        continue;
      } on FormatException {
        // Not a complete, valid sequence: keep this byte.
      }
    }
    out.write(keep(bytes[i]));
    i++;
  }
  return out.toString();
}

final _percentRun = RegExp(r'(?:%[0-9A-Fa-f]{2})+');
final _percentByte = RegExp(r'%([0-9A-Fa-f]{2})');

/// %XX runs decoded as UTF-8; a byte that is not part of valid UTF-8 stays as
/// its %XX.
String _percentDecoded(String text) => text.replaceAllMapped(_percentRun, (m) {
      final run = m[0]!;
      final bytes = <int>[
        for (var i = 0; i < run.length; i += 3)
          int.parse(run.substring(i + 1, i + 3), radix: 16),
      ];
      return _bytesAsUtf8(bytes, (b) => '%${_hex[b >> 4]}${_hex[b & 0xf]}');
    });

/// Every %XX as the Latin-1 character of its byte.
String _percentLatin1(String text) => text.replaceAllMapped(
    _percentByte, (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)));

final _latin1Run = RegExp('[\u0080-\u00ff]+');

/// Runs of U+0080..U+00FF read as UTF-8 bytes (`\xC3\xA9` is "é").
String _latin1RunsAsUtf8(String text) => text.replaceAllMapped(
    _latin1Run, (m) => _bytesAsUtf8(m[0]!.codeUnits, String.fromCharCode));

const _simpleEscapes = {
  0x22: '"', 0x5c: r'\', 0x2f: '/', 0x62: '\b', 0x66: '\f', //
  0x6e: '\n', 0x72: '\r', 0x74: '\t', 0x27: "'",
};

/// JSON and other backslash escapes: `\uXXXX` (and pairs), `\u{27}`,
/// `\U0001F600`, `\x27`, `\x{27}` and octal `\047`.
String _jsonUnescaped(String text) {
  if (!text.contains(r'\')) return text;
  final out = StringBuffer();
  var i = 0;
  final n = text.length;
  while (i < n) {
    final c = text.codeUnitAt(i);
    if (c != 0x5c || i + 1 >= n) {
      out.writeCharCode(c);
      i++;
      continue;
    }
    final next = text.codeUnitAt(i + 1);
    final simple = _simpleEscapes[next];
    if (simple != null) {
      out.write(simple);
      i += 2;
      continue;
    }
    if ((next == 0x75 || next == 0x55) &&
        i + 2 < n &&
        text.codeUnitAt(i + 2) == 0x7b) {
      var j = i + 3;
      var value = 0;
      var digits = 0;
      while (j < n && digits < 8 && _hexDigit(text.codeUnitAt(j)) >= 0) {
        value = value * 16 + _hexDigit(text.codeUnitAt(j));
        digits++;
        j++;
      }
      if (digits > 0 && j < n && text.codeUnitAt(j) == 0x7d) {
        out.write(_codePointText(value));
        i = j + 1;
        continue;
      }
    }
    if (next == 0x55 && i + 10 <= n) {
      var value = 0;
      var ok = true;
      for (var k = i + 2; k < i + 10; k++) {
        final d = _hexDigit(text.codeUnitAt(k));
        if (d < 0) {
          ok = false;
          break;
        }
        value = value * 16 + d;
      }
      if (ok && value <= 0x10ffff) {
        out.write(_codePointText(value));
        i += 10;
        continue;
      }
    }
    if ((next == 0x75 || next == 0x55) && i + 6 <= n) {
      var value = 0;
      var ok = true;
      for (var k = i + 2; k < i + 6; k++) {
        final d = _hexDigit(text.codeUnitAt(k));
        if (d < 0) {
          ok = false;
          break;
        }
        value = value * 16 + d;
      }
      if (ok) {
        if (value >= 0xd800 &&
            value <= 0xdbff &&
            i + 12 <= n &&
            text.codeUnitAt(i + 6) == 0x5c &&
            (text.codeUnitAt(i + 7) == 0x75 ||
                text.codeUnitAt(i + 7) == 0x55)) {
          var low = 0;
          var lowOk = true;
          for (var k = i + 8; k < i + 12; k++) {
            final d = _hexDigit(text.codeUnitAt(k));
            if (d < 0) {
              lowOk = false;
              break;
            }
            low = low * 16 + d;
          }
          if (lowOk && low >= 0xdc00 && low <= 0xdfff) {
            out.write(_codePointText(
                0x10000 + ((value - 0xd800) << 10) + (low - 0xdc00)));
            i += 12;
            continue;
          }
        }
        out.write(_codePointText(value));
        i += 6;
        continue;
      }
    }
    if (next == 0x78) {
      if (i + 2 < n && text.codeUnitAt(i + 2) == 0x7b) {
        var j = i + 3;
        var value = 0;
        var digits = 0;
        while (j < n && digits < 6 && _hexDigit(text.codeUnitAt(j)) >= 0) {
          value = value * 16 + _hexDigit(text.codeUnitAt(j));
          digits++;
          j++;
        }
        if (digits > 0 && j < n && text.codeUnitAt(j) == 0x7d) {
          out.write(_codePointText(value));
          i = j + 1;
          continue;
        }
      }
      final h1 = _hexAt(text, i + 2);
      final h2 = _hexAt(text, i + 3);
      if (h1 >= 0 && h2 >= 0) {
        out.writeCharCode(h1 * 16 + h2);
        i += 4;
        continue;
      }
    }
    if (next >= 0x30 && next <= 0x37) {
      bool octal(int at) =>
          at < n && text.codeUnitAt(at) >= 0x30 && text.codeUnitAt(at) <= 0x37;
      var value = next - 0x30;
      var len = 2;
      if (next <= 0x33 && octal(i + 2)) {
        value = value * 8 + text.codeUnitAt(i + 2) - 0x30;
        len = 3;
        if (octal(i + 3)) {
          value = value * 8 + text.codeUnitAt(i + 3) - 0x30;
          len = 4;
        }
      } else if (octal(i + 2)) {
        value = value * 8 + text.codeUnitAt(i + 2) - 0x30;
        len = 3;
      }
      out.writeCharCode(value);
      i += len;
      continue;
    }
    out.writeCharCode(c);
    i++;
  }
  return out.toString();
}

const _htmlEntities = {
  'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'",
  'nbsp': '\u00a0', //
};
final _entityName = RegExp(r'^[A-Za-z][A-Za-z0-9]*');

/// Named and numeric HTML entities (`&#39`, `&APOS;`, `&#x27;`).
String _htmlUnescaped(String text) {
  if (!text.contains('&')) return text;
  final out = StringBuffer();
  var i = 0;
  final n = text.length;
  while (i < n) {
    if (text.codeUnitAt(i) != 0x26) {
      out.writeCharCode(text.codeUnitAt(i));
      i++;
      continue;
    }
    if (i + 1 < n && text.codeUnitAt(i + 1) == 0x23) {
      var radix = 10;
      var at = i + 2;
      if (at < n &&
          (text.codeUnitAt(at) == 0x78 || text.codeUnitAt(at) == 0x58)) {
        radix = 16;
        at++;
      }
      final start = at;
      while (at < n &&
          (radix == 10
              ? (text.codeUnitAt(at) >= 0x30 && text.codeUnitAt(at) <= 0x39)
              : _hexDigit(text.codeUnitAt(at)) >= 0)) {
        at++;
      }
      if (at > start) {
        final digits = text.substring(start, at);
        final value = digits.length > 8 ? -1 : int.parse(digits, radix: radix);
        out.write(_codePointText(value));
        i = (at < n && text.codeUnitAt(at) == 0x3b) ? at + 1 : at;
        continue;
      }
    }
    final match = _entityName
        .firstMatch(text.substring(i + 1, i + 1 + 16 > n ? n : i + 17));
    if (match != null) {
      final name = match[0]!;
      final decoded = _htmlEntities[name.toLowerCase()];
      if (decoded != null) {
        final semi = i + 1 + name.length < n &&
            text.codeUnitAt(i + 1 + name.length) == 0x3b;
        out.write(decoded);
        i += 1 + name.length + (semi ? 1 : 0);
        continue;
      }
    }
    out.write('&');
    i++;
  }
  return out.toString();
}

final _hexByteEscape = RegExp(r'\\[xX]([0-9A-Fa-f]{2})');

/// Backslash-quote, `\xHH` byte escapes and HTML entities.
String _quoteDecoded(String text) =>
    _htmlUnescaped(text.replaceAll(r"\'", "'").replaceAllMapped(_hexByteEscape,
        (m) => String.fromCharCode(int.parse(m[1]!, radix: 16))));

final List<String Function(String)> _decoders = [
  _percentDecoded,
  (t) => _percentDecoded(t.replaceAll('+', ' ')),
  _percentLatin1,
  (t) => _percentLatin1(t.replaceAll('+', ' ')),
  _jsonUnescaped,
  (t) => _latin1RunsAsUtf8(_jsonUnescaped(t)),
  _quoteDecoded,
];

/// The text and every view of it reached by up to four decodings, in any order.
Set<String> _decodedViews(String text) {
  final views = <String>{text};
  var layer = [text];
  for (var depth = 0; depth < _decodeLayers; depth++) {
    final next = <String>[];
    for (final view in layer) {
      for (final decode in _decoders) {
        final decoded = decode(view);
        if (views.add(decoded)) next.add(decoded);
      }
    }
    layer = next;
  }
  return views;
}

/// Whether any decoded view of [text] still contains one of the [secrets],
/// exactly or case-insensitively.
bool holdsSecret(String text, List<String> secrets) {
  final present = secrets.where((s) => s.isNotEmpty).toList();
  if (present.isEmpty) return false;
  final folded = [for (final s in present) _simpleFold(s)];
  for (final view in _decodedViews(text)) {
    if (present.any(view.contains)) return true;
    final foldedView = _simpleFold(view);
    if (folded.any((s) => s.isNotEmpty && foldedView.contains(s))) return true;
  }
  return false;
}

int _utf8Length(String text) {
  var total = 0;
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (c < 0x80) {
      total += 1;
    } else if (c < 0x800) {
      total += 2;
    } else if (c >= 0xd800 &&
        c <= 0xdbff &&
        i + 1 < text.length &&
        (text.codeUnitAt(i + 1) & 0xfc00) == 0xdc00) {
      total += 4;
      i++;
    } else {
      total += 3;
    }
  }
  return total;
}

final _keyInQuery =
    RegExp(r'''([?&](?:api_key|API-Key)=)[^&\s"']+''', caseSensitive: false);

/// Replaces every form a secret could take in [text] with `***`, then decodes
/// what is left (URL, "+", JSON, quotes, HTML; up to four layers in any
/// order). If a view still holds a secret, the whole text is replaced by
/// [credentialOmittedMessage].
String redactSecrets(String text, List<String> secrets) {
  var value = text;
  if (value.length > maxRedactedLength ~/ 3 &&
      _utf8Length(value) > maxRedactedLength) {
    return textTooLongMessage;
  }
  for (final secret in secrets) {
    if (secret.isEmpty) continue;
    for (final form in secretForms(secret)) {
      value = value.replaceAll(form, '***');
    }
  }
  value = _maskFolded(value, secrets);
  value = value.replaceAllMapped(_keyInQuery, (m) => '${m[1]}***');
  return holdsSecret(value, secrets) ? credentialOmittedMessage : value;
}
