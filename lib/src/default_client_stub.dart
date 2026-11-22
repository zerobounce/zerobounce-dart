import 'package:http/http.dart' as http;

/// The client used when none is injected, where `dart:io` is not available
/// (the web): the platform's own [http.Client].
http.Client createDefaultClient(Duration timeout) => http.Client();
