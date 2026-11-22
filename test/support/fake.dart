import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:zerobounce_sdk/zerobounce_sdk.dart';

/// A key shaped like a real one. Security tests use [specialKey].
const testKey = '0123456789abcdef0123456789abcdef';

/// A key whose URL, form and JSON spellings all differ from the raw text.
const specialKey = r'Zb/Key+1&2=3"4\5 6%7';

/// Answers a request; may throw, or return a future that never completes.
typedef Handler = FutureOr<http.StreamedResponse> Function(
    http.BaseRequest request);

/// A `package:http` client that records every request and answers from
/// [handler] without touching the network.
class FakeClient extends http.BaseClient {
  FakeClient(this.handler);

  Handler handler;
  final requests = <http.BaseRequest>[];
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    return handler(request);
  }

  @override
  void close() => closed = true;

  http.BaseRequest get last => requests.last;
}

/// An answer with [body] (a String, bytes, or any JSON value).
http.StreamedResponse answer(
  Object? body, {
  int status = 200,
  String? contentType = 'application/json',
  Map<String, String> headers = const {},
  int? contentLength,
}) {
  final List<int> bytes = body is String
      ? utf8.encode(body)
      : body is List<int>
          ? body
          : utf8.encode(jsonEncode(body));
  return http.StreamedResponse(
    Stream.value(bytes),
    status,
    contentLength: contentLength ?? bytes.length,
    headers: {if (contentType != null) 'content-type': contentType, ...headers},
  );
}

/// A client wired to a fake that always answers [body].
(ZeroBounceSDK, FakeClient) sdkAnswering(Object? body,
    {int status = 200,
    String? contentType = 'application/json',
    String key = testKey,
    Duration timeout = const Duration(seconds: 120)}) {
  final fake =
      FakeClient((_) => answer(body, status: status, contentType: contentType));
  return (ZeroBounceSDK(key, httpClient: fake, timeout: timeout), fake);
}

/// The request's query parameters.
Map<String, String> queryOf(http.BaseRequest request) =>
    request.url.queryParameters;

/// The form fields of a form-encoded POST.
Map<String, String> formOf(http.BaseRequest request) =>
    (request as http.Request).bodyFields;

/// The text fields of a multipart POST.
Map<String, String> multipartOf(http.BaseRequest request) =>
    (request as http.MultipartRequest).fields;

/// The decoded JSON body.
Object? jsonOf(http.BaseRequest request) =>
    jsonDecode((request as http.Request).body);

/// Matches a [ZBException] with [statusCode] (and, optionally, a message).
Matcher throwsZB(int statusCode, [Object? message]) =>
    throwsA(isA<ZBException>()
        .having((e) => e.statusCode, 'statusCode', statusCode)
        .having((e) => e.message, 'message', message ?? anything));
