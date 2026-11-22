import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// The client used when none is injected, on `dart:io` platforms (Flutter
/// mobile and desktop, the server): an [HttpClient] whose connection attempt
/// is bounded by the request timeout too.
http.Client createDefaultClient(Duration timeout) =>
    IOClient(HttpClient()..connectionTimeout = timeout);
