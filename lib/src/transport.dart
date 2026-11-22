import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'errors.dart';
import 'field_types.dart';
import 'guards.dart';
import 'redaction.dart';
import 'response_checks.dart';

/// One request to a ZeroBounce API. Exactly one body kind is set, or none.
class ApiRequest {
  ApiRequest(
    this.method,
    this.base,
    this.path, {
    this.query = const {},
    this.form,
    this.multipartFields,
    this.fileBytes,
    this.fileName,
    this.json,
    this.bearer,
  });

  final String method;
  final String base;
  final String path;
  final Map<String, String> query;
  final Map<String, String>? form;
  final Map<String, String>? multipartFields;
  final List<int>? fileBytes;
  final String? fileName;
  final Object? json;
  final String? bearer;
}

/// A response read in full.
class RawResponse {
  RawResponse(this.status, this.bytes, this.contentType);

  final int status;
  final List<int> bytes;
  final String contentType;
}

/// What a JSON call expects of its answer.
class JsonSpec {
  const JsonSpec({
    this.fields,
    this.shape = Shape.object,
    this.messageOnlyExempt = false,
    this.messageFirst = false,
    this.requireFileStatusKnownField = false,
    this.emptyIsSuccess = false,
  });

  /// The result types the answer's fields are checked against.
  final List<String>? fields;
  final Shape shape;

  /// A message-only body is a result here (raw-JSON calls, the Inbox
  /// Placement Tester, the list-evaluator result).
  final bool messageOnlyExempt;

  /// A message-only body is the API's text, reported before a missing field.
  final bool messageFirst;
  final bool requireFileStatusKnownField;

  /// An empty 2xx is a success (Inbox Placement delete only).
  final bool emptyIsSuccess;
}

/// The JSON kind a call's answer must be.
enum Shape { object, array, objectOrArray, json }

final _lineBreakOrNul = RegExp('[\r\n\u0000]');

String _encodeQuery(Map<String, String> query) => query.entries
    .map((e) =>
        '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
    .join('&');

String _durationText(Duration d) => d.inMilliseconds % 1000 == 0
    ? '${d.inSeconds} seconds'
    : '${d.inMilliseconds} ms';

/// Sends requests and turns every failure into a redacted [ZBException].
class Transport {
  Transport(this._client, this._timeout, this._secret);

  final http.Client _client;
  final Duration _timeout;
  final String _secret;

  List<String> get _secrets => [_secret];

  /// An error whose message is redacted against the key.
  ZBException fail(String message, int status) =>
      ZBException(redactSecrets(message, _secrets), status);

  ZBException _transportError(Object error) {
    var reason = error is http.ClientException
        ? 'ClientException: ${error.message}'
        : error.toString();
    reason = redactSecrets(reason, _secrets);
    if (reason.length > 300) {
      reason =
          '${redactSecrets(error.runtimeType.toString(), _secrets)}: details omitted: too long';
    }
    // The original error is never attached: its text and URL can carry the key.
    return ZBException('ZeroBounce: the request failed ($reason).');
  }

  /// Sends [request] and reads the whole answer. A redirect, a timeout, a
  /// transport failure or a body shorter or longer than its declared length is
  /// an error.
  Future<RawResponse> send(ApiRequest request) async {
    final query =
        request.query.isEmpty ? '' : '?${_encodeQuery(request.query)}';
    final urlText = '${request.base}${request.path}$query';
    checkTransportUrl(urlText, 'request URL', isBase: false);
    final fields = request.multipartFields;
    if (fields != null) {
      for (final entry in fields.entries) {
        if (_lineBreakOrNul.hasMatch(entry.value)) {
          throw ZBException(
              'ZeroBounce: the form field "${entry.key}" must not contain '
              'a line break or a NUL character.');
        }
      }
      if (request.fileName != null &&
          _lineBreakOrNul.hasMatch(request.fileName!)) {
        throw const ZBException(
            'ZeroBounce: the file name must not contain a line break or a NUL character.');
      }
    }
    final uri = Uri.parse(urlText);
    final abort = Completer<void>();
    final http.BaseRequest httpRequest;
    if (fields != null) {
      final multipart = http.AbortableMultipartRequest(request.method, uri,
          abortTrigger: abort.future)
        ..fields.addAll(fields);
      if (request.fileBytes != null) {
        multipart.files.add(http.MultipartFile.fromBytes(
            'file', request.fileBytes!,
            filename: request.fileName));
      }
      httpRequest = multipart;
    } else {
      final plain = http.AbortableRequest(request.method, uri,
          abortTrigger: abort.future);
      if (request.form != null) {
        plain.bodyFields = request.form!;
      } else if (request.json != null) {
        plain.headers['Content-Type'] = 'application/json';
        plain.body = jsonEncode(request.json);
      }
      httpRequest = plain;
    }
    httpRequest
      ..followRedirects = false
      ..headers['Accept'] = '*/*';
    if (request.bearer != null) {
      httpRequest.headers['Authorization'] = 'Bearer ${request.bearer}';
    }

    Future<RawResponse> exchange() async {
      final streamed = await _client.send(httpRequest);
      final status = streamed.statusCode;
      if (status >= 300 && status < 400) {
        unawaited(streamed.stream.listen(null).cancel());
        throw ZBException(redirectMessage, status);
      }
      final bytes = await streamed.stream.toBytes();
      final declared = streamed.contentLength;
      if (declared != null && bytes.length != declared) {
        throw ZBException(
            'ZeroBounce: the response body was cut short or overran its '
            'declared length (${bytes.length} of $declared bytes).');
      }
      return RawResponse(status, bytes, streamed.headers['content-type'] ?? '');
    }

    try {
      return await exchange().timeout(_timeout, onTimeout: () {
        if (!abort.isCompleted) abort.complete();
        throw ZBException(
            'ZeroBounce: the request timed out after ${_durationText(_timeout)}.');
      });
    } on ZBException catch (error) {
      throw ZBException(
          redactSecrets(error.message, _secrets), error.statusCode);
    } catch (error) {
      throw _transportError(error);
    }
  }

  /// The parsed JSON answer of a typed call, after every check the shared
  /// standard asks for.
  Object? json(RawResponse response, JsonSpec spec) {
    final status = response.status;
    var validUtf8 = true;
    String text;
    try {
      text = utf8.decode(response.bytes);
    } on FormatException {
      text = utf8.decode(response.bytes, allowMalformed: true);
      validUtf8 = false;
    }
    if (spec.emptyIsSuccess &&
        status >= 200 &&
        status < 300 &&
        response.bytes.isEmpty) {
      return <String, Object?>{};
    }
    final contentType = response.contentType.toLowerCase();
    if (looksLikeHtml(text) ||
        contentType.contains('text/html') ||
        status >= 400 ||
        status < 200 ||
        text.trim().isEmpty) {
      throw fail(messageFromBody(text, status), status);
    }
    if (!validUtf8) throw ZBException(notJsonMessage, status);
    // A byte order mark is not JSON (RFC 8259); the decoder would drop it.
    final bytes = response.bytes;
    if (bytes.length >= 3 &&
        bytes[0] == 0xef &&
        bytes[1] == 0xbb &&
        bytes[2] == 0xbf) {
      throw ZBException(notJsonMessage, status);
    }
    if (jsonNestedTooDeep(text)) {
      throw ZBException(nestedTooDeepMessage, status);
    }
    Object? parsed;
    try {
      parsed = jsonDecode(text);
    } on FormatException {
      throw fail(messageFromBody(text, status), status);
    }
    final success = successFlagOfBody(text);
    final account = accountLevelMessage(parsed, success);
    if (account != null) throw fail(account, status);
    final fields = spec.fields;
    final greylistExempt = fields != null &&
        fields.contains('EmailValidationResult') &&
        parsed is Map<String, Object?> &&
        isGreylistAnswer(parsed);
    if (success == SuccessState.isFalse) {
      throw fail(messageFromBody(text, status), status);
    }
    if (!_hasShape(parsed, spec.shape)) {
      throw ZBException(unexpectedShapeMessage, status);
    }
    final hasMessageKey =
        parsed is Map && parsed.keys.any(messageKeys.contains);
    bool messageOnlyNow() =>
        fields != null &&
        !greylistExempt &&
        _messageOnlyBody(parsed, fields, success);
    if (success == SuccessState.notflag &&
        hasMessageKey &&
        !spec.messageOnlyExempt &&
        messageOnlyNow()) {
      throw fail(messageFromBody(text, status), status);
    }
    if (spec.messageFirst && hasMessageKey && messageOnlyNow()) {
      throw fail(messageFromBody(text, status), status);
    }
    if (fields != null) {
      parsed = _joinFileJobMessage(_normalizeSuccessFlag(parsed), fields);
      final field = responseFieldMismatch(parsed, fields);
      if (field != null) {
        throw ZBException(
            field.isNotEmpty
                ? '$unexpectedFieldTypeMessage (${redactSecrets(field, _secrets)}).'
                : '$unexpectedFieldTypeMessage.',
            status);
      }
    }
    if (!spec.messageOnlyExempt && messageOnlyNow()) {
      throw fail(messageFromBody(text, status), status);
    }
    if (spec.requireFileStatusKnownField &&
        parsed is Map<String, Object?> &&
        !hasKnownFileStatusField(parsed)) {
      throw fail(messageFromBody(text, status), status);
    }
    return parsed;
  }

  /// The text of a file download. A JSON body or content type, an HTML page,
  /// an empty body and any non-2xx status are errors with the status.
  String download(RawResponse response) {
    final status = response.status;
    final contentType = response.contentType.toLowerCase();
    final text = utf8.decode(response.bytes, allowMalformed: true);
    final htmlish =
        looksLikeHtmlDownload(text) || contentType.contains('text/html');
    if (htmlish || status >= 400 || status < 200) {
      final fixed =
          htmlish ? htmlDownloadText(text, contentType, status) : null;
      throw fail(fixed ?? messageFromBody(text, status), status);
    }
    if (text.trim().isEmpty) {
      throw ZBException(
          'Empty response from ZeroBounce (HTTP $status)', status);
    }
    if (isJsonContentType(contentType) || looksLikeJson(text)) {
      throw fail(messageFromBody(text, status), status);
    }
    return text;
  }
}

bool _hasShape(Object? parsed, Shape shape) => switch (shape) {
      Shape.json => true,
      Shape.array => parsed is List,
      Shape.objectOrArray => parsed is List || parsed is Map,
      Shape.object => parsed is Map,
    };

Object? _normalizeSuccessFlag(Object? parsed) {
  if (parsed is! Map<String, Object?> || !parsed.containsKey('success')) {
    return parsed;
  }
  final flag = parsed['success'];
  if (flag == true || !isSuccessFlag(flag) || isSuccessFailure(flag)) {
    return parsed;
  }
  return {...parsed, 'success': true};
}

Object? _joinFileJobMessage(Object? parsed, List<String> types) {
  if (parsed is! Map<String, Object?>) return parsed;
  final message = parsed['message'];
  if (message is! List || !message.every((line) => line is String)) {
    return parsed;
  }
  if (!types.any(fileJobMessageResults.contains)) return parsed;
  return {...parsed, 'message': message.join('\n')};
}

bool _messageOnlyBody(
    Object? parsed, List<String> types, SuccessState success) {
  if (parsed is! Map<String, Object?>) return false;
  Map<String, Object?> object = parsed;
  if (parsed.containsKey('success')) {
    if (success != SuccessState.notflag) return false;
    object = Map.of(parsed)..remove('success');
  }
  if (object.isEmpty) return true;
  if (object.keys.every(messageKeys.contains)) return true;
  final declared = declaredFieldNames(types);
  if (declared.isEmpty || !object.keys.any(messageKeys.contains)) return false;
  return object.entries.every((e) =>
      messageKeys.contains(e.key) ||
      (declared.contains(e.key) && e.value == null));
}
