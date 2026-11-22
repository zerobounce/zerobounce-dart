// Validates one address and prints the account's credits.
//
//   dart run --define=ZEROBOUNCE_API_KEY=<your key> example/example.dart
//
// Keep the key out of source code and out of apps you ship to users.
import 'package:zerobounce_sdk/zerobounce_sdk.dart';

Future<void> main() async {
  const apiKey = String.fromEnvironment('ZEROBOUNCE_API_KEY');
  if (apiKey.isEmpty) {
    print('Pass your key with --define=ZEROBOUNCE_API_KEY=<your key>.');
    return;
  }
  final zb = ZeroBounceSDK(apiKey);
  try {
    final credits = await zb.getCredits();
    print('Credits: ${credits.credits}');
    final result = await zb.validateEmail('valid@example.com');
    print('${result.address}: ${result.status} (${result.subStatus})');
  } on ZBException catch (error) {
    print('ZeroBounce error ${error.statusCode}: ${error.message}');
  } finally {
    zb.close();
  }
}
