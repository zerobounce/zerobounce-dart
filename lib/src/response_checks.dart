import 'dart:convert';

/// Deeper JSON than any ZeroBounce answer; a body nested past it is refused
/// unparsed.
const maxJsonDepth = 512;

const unexpectedShapeMessage =
    'ZeroBounce returned JSON of an unexpected shape for this call.';
const nestedTooDeepMessage =
    'ZeroBounce returned a response nested too deeply to read.';
const notJsonMessage = 'ZeroBounce returned a response that is not valid JSON.';
const redirectMessage =
    'ZeroBounce returned a redirect, which this client does not follow.';
const htmlDownloadMessage =
    'ZeroBounce returned an HTML page (text/html) instead of a file.';
const htmlPageDownloadMessage =
    'ZeroBounce returned an HTML page instead of a file.';

/// The keys a message-only body is made of.
const messageKeys = {
  'error',
  'message',
  'error_message',
  'Message',
  'Error',
  'detail'
};

/// Whether the JSON text nests arrays or objects deeper than the limit.
bool jsonNestedTooDeep(String text, [int limit = maxJsonDepth]) {
  var depth = 0;
  var inString = false;
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (inString) {
      if (c == 0x5c) {
        i++;
      } else if (c == 0x22) {
        inString = false;
      }
    } else if (c == 0x22) {
      inString = true;
    } else if (c == 0x5b || c == 0x7b) {
      depth++;
      if (depth > limit) return true;
    } else if (c == 0x5d || c == 0x7d) {
      depth--;
    }
  }
  return false;
}

/// Whether a media type is JSON: application/json or any `+json` type.
bool isJsonContentType(String contentType) {
  final media = contentType.split(';').first.trim().toLowerCase();
  return media == 'application/json' || media.endsWith('+json');
}

/// Whether a body is a JSON object or array (or tries to be one).
bool looksLikeJson(String body) {
  final trimmed = body.trim();
  return trimmed.startsWith('{') || trimmed.startsWith('[');
}

/// The index of the first character after a BOM and HTML whitespace (space,
/// tab, CR, LF, VT, FF, NBSP).
int _contentStart(String text) {
  var i = 0;
  if (text.isNotEmpty && text.codeUnitAt(0) == 0xfeff) i = 1;
  while (i < text.length) {
    final c = text.codeUnitAt(i);
    if (c == 0x20 ||
        c == 0x09 ||
        c == 0x0a ||
        c == 0x0d ||
        c == 0x0b ||
        c == 0x0c ||
        c == 0xa0) {
      i++;
      continue;
    }
    break;
  }
  return i;
}

const _htmlProbeChars = 2000;
const _htmlTags = ['<!doctype html', '<html', '<head', '<body'];
const _tagEnders = {'>', '/', ' ', '\t', '\n', '\r', '\u000b', '\f'};

bool _hasWholeTag(String text, String tag, String? following) {
  var from = 0;
  for (;;) {
    final at = text.indexOf(tag, from);
    if (at < 0) return false;
    final end = at + tag.length;
    final next = end < text.length ? text[end] : following;
    if (next == null || _tagEnders.contains(next)) return true;
    from = at + 1;
  }
}

/// Whether a body is an HTML page: not JSON, and a whole `<!doctype html`,
/// `<html`, `<head` or `<body` tag in its first 2000 characters, any case.
bool looksLikeHtml(String body) {
  final start = _contentStart(body);
  if (start < body.length) {
    final first = body[start];
    if (first == '{' || first == '[') return false;
  }
  final endWindow = start + _htmlProbeChars + 1 > body.length
      ? body.length
      : start + _htmlProbeChars + 1;
  final window = body.substring(start, endWindow).toLowerCase();
  final head = window.length > _htmlProbeChars
      ? window.substring(0, _htmlProbeChars)
      : window;
  final following =
      window.length > _htmlProbeChars ? window[_htmlProbeChars] : null;
  return _htmlTags.any((tag) => _hasWholeTag(head, tag, following));
}

/// Whether a file download is an HTML page by its body: it starts with `<`
/// after its padding (a CSV never does).
bool looksLikeHtmlDownload(String body) {
  final start = _contentStart(body);
  return start < body.length && body[start] == '<';
}

/// The fixed text for a download that is not a file because it looks like
/// HTML, or null when the body should speak for itself (an HTML page with a
/// title, a JSON body, or a plain-text message on an error status).
String? htmlDownloadText(String body, String contentType, int status) {
  if (body.trim().isEmpty || looksLikeHtml(body) || looksLikeJson(body)) {
    return null;
  }
  final start = _contentStart(body);
  if (status >= 400 && (start >= body.length || body[start] != '<')) {
    return null;
  }
  return contentType.contains('text/html')
      ? htmlDownloadMessage
      : htmlPageDownloadMessage;
}

const _htmlTitleWindow = 65536;
const _htmlTitleMax = 1000;

int _indexOfAsciiCaseless(String text, String needle, int from) {
  for (var at = text.indexOf('<', from);
      at >= 0;
      at = text.indexOf('<', at + 1)) {
    if (at + needle.length > text.length) return -1;
    var same = true;
    for (var k = 1; k < needle.length; k++) {
      var code = text.codeUnitAt(at + k);
      if (code >= 0x41 && code <= 0x5a) code += 32;
      if (code != needle.codeUnitAt(k)) {
        same = false;
        break;
      }
    }
    if (same) return at;
  }
  return -1;
}

final _whitespaceRun = RegExp(r'\s+');

/// The page's `<title>` text, or "" when there is none or it is too long.
String htmlTitle(String body) {
  final text = body.length > _htmlTitleWindow
      ? body.substring(0, _htmlTitleWindow)
      : body;
  var from = 0;
  for (;;) {
    final open = _indexOfAsciiCaseless(text, '<title', from);
    if (open < 0) return '';
    final next = open + 6 < text.length ? text[open + 6] : null;
    if (next != null && _tagEnders.contains(next)) {
      final tagEnd = text.indexOf('>', open);
      if (tagEnd < 0) return '';
      final close = _indexOfAsciiCaseless(text, '</title', tagEnd);
      if (close < 0) return '';
      if (close - tagEnd - 1 > _htmlTitleMax) return '';
      final title = text
          .substring(tagEnd + 1, close)
          .replaceAll(_whitespaceRun, ' ')
          .trim();
      return title.length > _htmlTitleMax ? '' : title;
    }
    from = open + 1;
  }
}

String stripErrorPrefix(String message) {
  var value = message.trim();
  for (;;) {
    if (value.startsWith('Error:')) {
      value = value.substring(6).trim();
      continue;
    }
    if (value.startsWith('[Error]:')) {
      value = value.substring(8).trim();
      continue;
    }
    return value;
  }
}

final _accountLevelText = RegExp(
    r'invalid api key|api_key is invalid|ran out of credits|out of credits',
    caseSensitive: false);

/// A readable message from a parsed error body, or null.
String? readableJsonMessage(Object? parsed) {
  if (parsed is List) {
    for (final item in parsed) {
      if (item is String && item.trim().isNotEmpty) return item.trim();
    }
    return null;
  }
  if (parsed is! Map) return null;
  for (final key in const [
    'error',
    'message',
    'error_message',
    'Message',
    'Error',
    'detail'
  ]) {
    final value = parsed[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is List && value.isNotEmpty) {
      final strings =
          value.whereType<String>().where((s) => s.trim().isNotEmpty).toList();
      if (strings.isNotEmpty) return strings.join('\n');
      final first = value.first;
      if (first is Map &&
          first['msg'] != null &&
          first['msg'] != false &&
          first['msg'] != '') {
        final loc = first['loc'];
        final where = loc is List ? loc.skip(1).join('.') : '';
        return where.isNotEmpty ? '$where: ${first['msg']}' : '${first['msg']}';
      }
    }
  }
  return null;
}

/// What a body's own top-level "success" field says, read from the raw text
/// (jsonDecode keeps only the last of duplicate keys): absent, notflag, true or
/// false. Any real false among duplicates is false.
enum SuccessState { absent, notflag, isTrue, isFalse }

final _jsonNumber = RegExp(r'^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$');

SuccessState successFlagOfBody(String text) {
  bool isWs(int c) => c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d;
  final n = text.length;
  var i = 0;
  while (i < n && (isWs(text.codeUnitAt(i)) || text.codeUnitAt(i) == 0xfeff)) {
    i++;
  }
  if (i >= n || text.codeUnitAt(i) != 0x7b) return SuccessState.absent;
  var result = SuccessState.absent;
  var depth = 0;
  int stringEnd(int from) {
    var j = from + 1;
    while (j < n) {
      final c = text.codeUnitAt(j);
      if (c == 0x5c) {
        j += 2;
      } else if (c == 0x22) {
        return j;
      } else {
        j++;
      }
    }
    return n;
  }

  SuccessState classify(String token, bool isString) {
    final t = token.trim().toLowerCase();
    if (t == 'true' || (isString && t == '1')) return SuccessState.isTrue;
    if (t == 'false' || (isString && t == '0')) return SuccessState.isFalse;
    if (!isString && _jsonNumber.hasMatch(t)) {
      final number = double.tryParse(t);
      if (number != null && number.isFinite && number == 1) {
        return SuccessState.isTrue;
      }
      if (number != null && number.isFinite && number == 0) {
        return SuccessState.isFalse;
      }
    }
    return SuccessState.notflag;
  }

  String? decodeString(int start, int end) {
    if (end >= n) return null;
    try {
      final value = jsonDecode(text.substring(start, end + 1));
      return value is String ? value : null;
    } on FormatException {
      return null;
    }
  }

  while (i < n) {
    final c = text.codeUnitAt(i);
    if (c == 0x7b || c == 0x5b) {
      depth++;
    } else if (c == 0x7d || c == 0x5d) {
      depth--;
    } else if (c == 0x22) {
      final close = stringEnd(i);
      var after = close + 1;
      while (after < n && isWs(text.codeUnitAt(after))) {
        after++;
      }
      if (depth == 1 && after < n && text.codeUnitAt(after) == 0x3a) {
        final key = decodeString(i, close) ?? '';
        if (key == 'success') {
          after++;
          while (after < n && isWs(text.codeUnitAt(after))) {
            after++;
          }
          SuccessState one;
          if (after < n && text.codeUnitAt(after) == 0x22) {
            final end = stringEnd(after);
            one = classify(decodeString(after, end) ?? '\u0000', true);
          } else {
            var end = after;
            while (end < n) {
              final e = text.codeUnitAt(end);
              if (isWs(e) || e == 0x2c || e == 0x7d || e == 0x5d) break;
              end++;
            }
            final token = text.substring(after, end);
            one = (token.startsWith('{') || token.startsWith('['))
                ? SuccessState.notflag
                : classify(token, false);
          }
          if (one == SuccessState.isFalse) return SuccessState.isFalse;
          if (one == SuccessState.isTrue || result == SuccessState.absent) {
            result = one;
          }
        }
      }
      i = close;
    }
    i++;
  }
  return result;
}

/// Whether `success` is a flag: a boolean, 0 or 1, or the text true/false/0/1.
bool isSuccessFlag(Object? value) {
  if (value is bool) return true;
  if (value is num) return value == 0 || value == 1;
  if (value is String) {
    final t = value.trim().toLowerCase();
    return t == 'true' || t == 'false' || t == '0' || t == '1';
  }
  return false;
}

/// The false values of a real `success` flag.
bool isSuccessFailure(Object? value) {
  if (value == false) return true;
  if (value is num) return value == 0;
  if (value is String) {
    final t = value.trim().toLowerCase();
    return t == 'false' || t == '0';
  }
  return false;
}

/// The account-level failure text of a 200 body (an invalid key, no credits,
/// the batch `"all"` error), or null.
String? accountLevelMessage(Object? parsed, SuccessState success) {
  if (parsed is! Map) return null;
  final errors = parsed['errors'];
  if (errors is List) {
    for (final item in errors) {
      if (item is Map &&
          '${item['email_address'] ?? ''}'.toLowerCase() == 'all') {
        final error = item['error'];
        final text = error is String ? error.trim() : '';
        return stripErrorPrefix(text.isNotEmpty
            ? text
            : 'Invalid API Key or your account ran out of credits');
      }
    }
  }
  // An invalid or drained key answers with {"error": "..."} (validate,
  // activity, getapiusage) or {"Error": "..."} (filters) on an HTTP 200 with
  // no "success" field: any non-empty error string is then a failure. With a
  // "success" flag, only the key / credits wording is.
  final noSuccess =
      success == SuccessState.absent || success == SuccessState.notflag;
  for (final key in const ['error', 'error_message', 'Error']) {
    final value = parsed[key];
    if (value is! String || value.trim().isEmpty) continue;
    if (noSuccess ||
        (key != 'error_message' && _accountLevelText.hasMatch(value))) {
      final stripped = stripErrorPrefix(value.trim());
      return stripped.isNotEmpty ? stripped : value.trim();
    }
  }
  return null;
}

String? _cloudflareTitle(Object? parsed) {
  if (parsed is! Map) return null;
  final title = parsed['title'];
  if (title is! String) return null;
  final denied = title.contains('Access denied') || title.contains('1020');
  return denied && parsed['cloudflare_error'] == true ? title : null;
}

/// A short message for a failed response body: never raw HTML, a megabyte of
/// text or a parser error.
String messageFromBody(String body, int status) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return 'Empty response from ZeroBounce (HTTP $status)';
  if (looksLikeHtml(body)) {
    final title = htmlTitle(body);
    if (title.isEmpty) {
      return 'ZeroBounce returned an HTML error page instead of an API response.';
    }
    return 'ZeroBounce returned an HTML error page ("$title") instead of an API response.';
  }
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    if (jsonNestedTooDeep(trimmed)) return nestedTooDeepMessage;
    Object? parsed;
    try {
      parsed = jsonDecode(trimmed);
    } on FormatException {
      return notJsonMessage;
    }
    final title = _cloudflareTitle(parsed);
    if (title != null) return title;
    final account = accountLevelMessage(parsed, successFlagOfBody(trimmed));
    if (account != null) return account;
    final readable = readableJsonMessage(parsed);
    if (readable != null) return stripErrorPrefix(readable);
    return 'ZeroBounce returned an unexpected response.';
  }
  if (trimmed.length > 1000) return notJsonMessage;
  final message = stripErrorPrefix(trimmed);
  return message.isNotEmpty
      ? message
      : 'Empty response from ZeroBounce (HTTP $status)';
}

/// validate's one message-only exemption: a body whose only key is "Message"
/// holding text (the greylist answer).
bool isGreylistAnswer(Map<String, Object?> object) =>
    object.length == 1 &&
    object['Message'] is String &&
    (object['Message'] as String).trim().isNotEmpty;

const fileStatusKnownFields = {
  'file_status',
  'file_id',
  'file_name',
  'upload_date',
  'file_phase_2_status',
  'complete_percentage',
  'error_reason',
  'return_url',
};

/// Whether a file status answer has a real `success` or any known field.
bool hasKnownFileStatusField(Map<String, Object?> parsed) {
  if (parsed.containsKey('success')) {
    final flag = parsed['success'];
    if (isSuccessFlag(flag) && !isSuccessFailure(flag)) return true;
  }
  for (final key in fileStatusKnownFields) {
    final value = parsed[key];
    if (value == null) continue;
    if (value is String && value.trim().isEmpty) continue;
    return true;
  }
  return false;
}
