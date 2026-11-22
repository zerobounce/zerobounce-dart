# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project

`zerobounce_sdk` is the ZeroBounce Dart SDK, published on pub.dev under the `zerobounce.net` verified publisher. Callers construct `ZeroBounceSDK(apiKey, ...)` and `await` its methods. It is pure Dart on `package:http` (Flutter, server, web); `dart:io` is only reached through a conditional import for the default client. Releases are git tags; the Publish workflow ships a pushed tag to pub.dev. The behaviour follows the shared ZeroBounce SDK standard and is modelled on the JavaScript SDK.

## Layout

- `lib/zerobounce_sdk.dart`: the public library (exports only).
- `lib/src/client.dart`: `ZeroBounceSDK`, every endpoint. The API key is the private `_apiKey` field.
- `lib/src/transport.dart`: building and sending requests (timeout with abort, no redirects, Content-Length check) and the response pipeline (`json`, `download`).
- `lib/src/response_checks.dart`: HTML detection, the raw `success` flag scan, error message extraction.
- `lib/src/field_types.dart`: the declared JSON type of every response field and the checker.
- `lib/src/redaction.dart`: key redaction (every spelling, then a decode check).
- `lib/src/guards.dart`: base URL, key and argument checks.
- `lib/src/models.dart`: typed results. `lib/src/constants.dart`: base URLs, status values, parameter enums.
- `lib/src/default_client_io.dart` / `default_client_stub.dart`: the default `http.Client` per platform.
- `test/`: the offline suite. `test/support/calls.dart` lists every public request method for the sweeps; `test/support/network_guard.dart` is the network guard; `test/fixtures/strict-json-corpus.tsv` is the shared corpus.
- `example/example.dart`: the pub.dev example.

## Commands

```bash
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
dart pub publish --dry-run
```

CI (`.github/workflows/sdk_ci.yml`) runs these on Dart 3.4.0 (the floor, after `dart pub downgrade http`) and on the latest stable, and builds a consumer outside the checkout (native and JavaScript). There is no local Dart on the maintainers' Mac: run the commands in the official `dart` image, pinned by digest, with the repository mounted from under `$HOME`.

## Conventions

- **Exactly the documented fields, no more and no fewer.** The eight S3 / SFTP file jobs send `file_name`, `has_header_row`, `remove_duplicates` (when set) and `return_url`; the API requires `file_name` and `return_url` although the docs mark them optional.
- **Only endpoints documented at https://www.zerobounce.net/docs/.** No deprecated aliases: this SDK starts without `guessFormat` (use `findEmail*` / `findEmailFormat*`). There is no Warmup client yet.
- **Optional parameters are omitted when unset** (null). Booleans are Dart `bool`s, sent as `true` / `false` on query, form and multipart bodies and as JSON booleans in `validateBatch`; `validateBatch`'s `timeout` is a JSON string. `has_header_row` is a required argument wherever the API needs it, so no default is invented. `remove_duplicate` is sent only when set (the API defaults it to true).
- **Columns are 1-based** and checked (`< 1` is refused before sending).
- **Separate base URLs** for the list evaluator, the Inbox Placement Tester, the bulk email finder and bulk domain search, plus `bulkBaseUrl` and `bulkRootBaseUrl`. `sendEvaluatedFile` uses the bulk `/v2` base. `validateBatch` uses the main API host.
- **The Inbox Placement Tester** takes the key as `Authorization: Bearer`, JSON bodies with camelCase fields, and returns decoded JSON. Its calls, the list evaluator result and the filter add/delete answers are exempt from the message-only rule.
- **Every failure is a `ZBException`** completing the `Future` (never a synchronous throw: every public method is `async`). `statusCode` is the HTTP status, including the 200-status failures (dead key, `success: false`, message-only, not strict JSON, HTML, wrong field type, empty body); `0` before or without a response. Messages are short: no raw HTML, megabyte bodies or parser text.
- **No error carries the key.** `Transport.fail` and the transport error redact every message; the original exception is never attached. The key must be printable ASCII, which keeps every spelling redaction covers in ASCII.
- **https only, no redirects, 120 s timeout.** Base URLs are checked as raw text before `Uri.parse`; the request URL is checked again on every request. `followRedirects` is false and a 3xx is an error. The timeout covers connection and body and aborts the request.
- **The constructor is all or nothing**: every argument is checked in the initializer list before the object exists.
- **The test suite is offline**, and every test file calls `installNetworkGuard()`. Sweeps iterate `apiCalls`; a test reads `lib/src/client.dart` and fails when a public method is missing from that list. Add every new method there with a valid call and a success answer.
- **Do not edit `test/fixtures/strict-json-corpus.tsv`**: it is a byte copy of the sdk-docs skill's `references/strict-json-corpus.tsv`.
- Write `\uXXXX` escapes, never the literal invisible character, in Dart sources.

## Changelog

`CHANGELOG.md` follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/), and the project adheres to [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).

- Add every user-visible change to the top section in the same commit as the change (`## [Unreleased]`, created after the first release).
- Group entries under `Breaking`, `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`, in that order, omitting empty ones.
- Write for SDK users: name the method, option or behaviour and say what changed. Leave out CI-only changes and fixes to code that was never released.

## Releasing

Publishing and pushing tags need a maintainer's explicit approval. Do not bump the version, tag or publish unless they asked.

**This repository differs from the other SDKs.** pub.dev's GitHub Actions publishing accepts only a workflow started by a pushed tag, so `publish.yml` runs `on: push: tags: ['v[0-9]+.[0-9]+.[0-9]+']`, not `workflow_dispatch`: pushing the tag starts the publish. Keep the two approvals by pushing the release commit first (approval 1), waiting for CI to pass on it, then pushing the tag (approval 2). The publish job still waits for a reviewer in the `release` environment.

1. Rename the top CHANGELOG section to `## [x.y.z] - YYYY-MM-DD` (the UTC date), add an empty `## [Unreleased]` above it, and update the compare links at the bottom.
2. Set `version: x.y.z` in `pubspec.yaml` (the only version field; there is no version constant in the code).
3. Run the commands above.
4. Push the commit to `main`, wait for CI, then tag `vx.y.z` on it and push the tag. The workflow checks that the tagged commit is on `main` and that `pubspec.yaml` and `CHANGELOG.md` name the tag's version, runs the tests, publishes after approval, and creates the GitHub release.

The 1.0.0 upload was the one manual publish (pub.dev enables automated publishing only for an existing package). If a tag's version is already on pub.dev, the publish job says so and skips the upload, and the release job still runs.
