# ZeroBounce Dart SDK

The official [ZeroBounce](https://www.zerobounce.net) SDK for Dart and Flutter:
email validation, AI scoring, bulk files, email finder and domain search, the
list evaluator, the Inbox Placement Tester, allow/block filters and Amazon S3 /
SFTP file jobs. Pure Dart on [`package:http`](https://pub.dev/packages/http), so
it runs on Flutter (mobile, desktop, web), on the server and in the browser.

API reference: https://www.zerobounce.net/docs/

## Security

- Keep API keys on a trusted server. A key embedded in a mobile app or a web
  page can be read by anyone who has the app. For Flutter apps, call ZeroBounce
  from your own backend rather than from the device.
- Every base URL must be `https://` (plain `http://` only to 127.0.0.1,
  localhost or [::1], for tests), without a username, password, query string or
  fragment. The error for a refused URL does not include the URL.
- Most calls carry the key as the `api_key` query parameter or form field (the
  ZeroBounce API contract); the Inbox Placement Tester sends it in an
  `Authorization: Bearer` header. Do not log full request URLs.
- Errors never contain the key, in any encoding, and the client's `toString`
  shows it as `***`. Redirects are never followed, so the key is never sent on
  to another host.

## Requirements

- Dart 3.4 or later (Flutter 3.22 or later).
- `package:http` 1.5 or later (installed with the SDK).

## Installation

```bash
dart pub add zerobounce_sdk
```

or, in a Flutter project:

```bash
flutter pub add zerobounce_sdk
```

## Usage

```dart
import 'package:zerobounce_sdk/zerobounce_sdk.dart';

Future<void> main() async {
  final zb = ZeroBounceSDK('<your API key>');
  try {
    final result = await zb.validateEmail('someone@example.com');
    print('${result.address}: ${result.status} ${result.subStatus}');
  } on ZBException catch (error) {
    print('ZeroBounce error ${error.statusCode}: ${error.message}');
  } finally {
    zb.close();
  }
}
```

Construct one `ZeroBounceSDK` per API key and reuse it; `close()` releases the
HTTP client it created.

### Errors

Every failure completes the `Future` with a `ZBException`:

- `statusCode` is the HTTP status of the answer, including the HTTP 200 answers
  that are still failures: an invalid key or no credits (`{"error": ...}`), a
  `"success": false` body, an answer that is only a message, a body that is not
  strict JSON or HTML, or a field of an unexpected type.
- `statusCode` is `0` when there was no answer: a bad argument (checked before
  anything is sent), a refused base URL, a connection failure, a body cut short
  or a timeout.
- `message` is short: never raw HTML, a megabyte body, a parser error or the key.

`getCredits` answering `-1` is the API's documented answer for an invalid key,
not an error. A pending greylist validation answers with only a message: the
result then has `address` and `status` null and the text in `message`.

### Configuration

```dart
final zb = ZeroBounceSDK(
  '<your API key>',
  baseUrl: ZBApiUrl.eu, // or ZBApiUrl.usa; ZBApiUrl.defaultUrl by default
  timeout: const Duration(seconds: 60), // 120 seconds by default
);
```

Requests time out after 120 seconds by default, connection and body included,
and are aborted when they do. The bulk, list evaluator, Inbox Placement Tester,
bulk email finder and bulk domain search APIs live on `bulkapi.zerobounce.net`,
which has no regional variant; each has its own base URL argument
(`bulkBaseUrl`, `bulkRootBaseUrl`, `listEvaluatorBaseUrl`,
`inboxPlacementBaseUrl`, `emailFinderBaseUrl`, `domainSearchBaseUrl`).

Pass your own `package:http` client with `httpClient:` (a retrying client, or a
fake in your tests); the SDK leaves closing it to you.

Optional parameters are sent only when you set them; the SDK adds no defaults
of its own. Columns in bulk files are 1-based.

## Examples

The examples assume `final zb = ZeroBounceSDK('<your API key>');` inside an
`async` function.

### Account

```dart
final credits = await zb.getCredits();
print(credits.credits);

final usage = await zb.getApiUsage(DateTime(2026, 1, 1), DateTime(2026, 1, 31));
print('${usage.total} validations, ${usage.statusValid} valid');
```

### Validation

```dart
final result = await zb.validateEmail(
  'someone@example.com',
  ipAddress: '99.110.204.1', // optional
  timeout: 10, // optional, 3-60 seconds
  activityData: true, // optional
);
if (result.status == ZBValidateStatus.valid) print('deliverable');

final batch = await zb.validateBatch([
  const ZBBatchEmail('someone@example.com', ipAddress: '99.110.204.1'),
  const ZBBatchEmail('someone.else@example.com'),
]);
for (final row in batch.emailBatch) {
  print('${row.address}: ${row.status}');
}

final activity = await zb.getEmailActivity('someone@example.com');
print(activity.activeInDays);
```

### AI scoring

```dart
final score = await zb.scoreEmail('someone@example.com');
print(score.score);
```

### Bulk validation and scoring files

```dart
final csv = 'email\nsomeone@example.com\n'.codeUnits;
final sent = await zb.sendFile(
  file: csv,
  fileName: 'emails.csv',
  emailAddressColumn: 1,
  hasHeaderRow: true,
  returnUrl: 'https://example.com/zerobounce-callback', // optional
);
final status = await zb.getFileStatus(sent.fileId!);
print('${status.fileStatus} ${status.completePercentage}');
final results = await zb.getFile(sent.fileId!); // the results as CSV text
print(results.length);
await zb.deleteFile(sent.fileId!);

final scoring = await zb.sendScoringFile(
    file: csv, fileName: 'emails.csv', emailAddressColumn: 1, hasHeaderRow: true);
print((await zb.getScoringFileStatus(scoring.fileId!)).fileStatus);
```

On Flutter mobile, desktop or the server, read a file with
`await File(path).readAsBytes()` from `dart:io` and pass the bytes as `file`.

### Email finder and domain search

```dart
final found = await zb.findEmailByDomain(
    domain: 'example.com', firstName: 'John', lastName: 'Doe');
print('${found.email} (${found.emailConfidence})');

final format = await zb.findEmailFormatByDomain('example.com');
print(format.format);

final finderJob = await zb.sendEmailFinderFile(
  file: 'domain,first,last\nexample.com,John,Doe\n'.codeUnits,
  fileName: 'people.csv',
  domainColumn: 1,
  firstNameColumn: 2,
  lastNameColumn: 3,
  hasHeaderRow: true,
);
print(await zb.getEmailFinderFileStatus(finderJob.fileId!));

final domainJob = await zb.sendDomainSearchFile(
    file: 'domain\nexample.com\n'.codeUnits,
    fileName: 'domains.csv',
    domainColumn: 1,
    hasHeaderRow: true);
print(await zb.getDomainSearchFileStatus(domainJob.fileId!));
```

### List evaluator

```dart
final evaluation = await zb.sendListEvaluatorFile(
    file: 'email\nsomeone@example.com\n'.codeUnits,
    fileName: 'list.csv',
    emailAddressColumn: 1);
print(await zb.getListEvaluatorResult(evaluation.fileId!));
// Then validate the evaluated list:
final validation = await zb.sendEvaluatedFile(evaluation.fileId!);
print(validation.fileId);
```

### Allow and block filters

```dart
await zb.addFilter(
    rule: ZBFilterRule.block, target: ZBFilterTarget.domain, value: 'example.com');
final filters = await zb.listFilters();
for (final filter in filters.filters) {
  print('${filter.rule} ${filter.target} ${filter.value}');
}
await zb.deleteFilter(
    rule: ZBFilterRule.block, target: ZBFilterTarget.domain, value: 'example.com');
```

### Amazon S3 and SFTP file jobs

```dart
final s3Files = await zb.listS3Files(bucket: 'my-bucket');
print(s3Files.map((f) => f.name));
await zb.validateS3File(
    fileName: 'in/list.csv',
    hasHeaderRow: true,
    returnUrl: 'https://example.com/zerobounce-callback');
await zb.exportS3File(fileId: '<file id>');

await zb.validateSftpFile(
    fileName: 'list.csv',
    hasHeaderRow: true,
    returnUrl: 'https://example.com/zerobounce-callback');
await zb.exportSftpFile(fileId: '<file id>', exportPath: '/results');
```

The API requires `fileName` and `returnUrl` on every S3 and SFTP job, although
the documentation marks them optional.

### Inbox Placement Tester

The Inbox Placement Tester answers are returned as decoded JSON
(`Map<String, Object?>` or any JSON value).

```dart
final providers = await zb.getInboxPlacementProviders();
print(providers['emailProviders']);
final created = await zb.createInboxPlacementTest(
    name: 'Launch campaign', testType: 3, providerIds: [1, 2]);
final test = await zb.getInboxPlacementTest(created['id']! as String);
print(test['status']);
print(await zb.listInboxPlacementTests(status: ZBInboxPlacementTestStatus.finished));
await zb.setInboxPlacementWebhook('https://example.com/ipt-webhook');
```

## Development

The test suite is offline: it uses a fake `package:http` client and real
loopback sockets, and a network guard fails any test that tries to reach a host
other than 127.0.0.1, localhost or [::1]. No API key is needed.

```bash
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
dart pub publish --dry-run
```

Without a local Dart SDK, run the same commands in the official image:

```bash
docker run --rm -v "$PWD":/work -w /work dart:stable sh -c 'dart pub get && dart test'
```

See [CONTRIBUTING.md](CONTRIBUTING.md). Releases are published to pub.dev by
the Publish workflow from a pushed `vX.Y.Z` tag (see [AGENTS.md](AGENTS.md)).

## License

MIT. See [LICENSE](LICENSE).
