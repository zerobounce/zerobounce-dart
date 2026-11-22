# Contributing to the ZeroBounce Dart SDK

Thank you for your interest in contributing. This document explains how to get set up and submit changes.

## Code of Conduct

By participating in this project, you agree to uphold our [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting Started

You need Dart 3.4 or later (or Flutter 3.22 or later). Then:

```bash
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
dart pub publish --dry-run
```

These are the steps CI runs, on Dart 3.4.0 (the declared minimum, with `dart pub downgrade http` so the lowest allowed `package:http` is tested too) and on the latest stable Dart.

### Offline and live tests

`dart test` is offline and needs no API key: tests answer through a fake `package:http` client or real loopback sockets, and `test/support/network_guard.dart` makes any connection to a host other than 127.0.0.1, localhost or [::1] fail. Every test file calls `installNetworkGuard()`, and a test checks that it does. Do not call the live API from the test suite.

To try the SDK against the real API, run the example with your own key:

```bash
dart run --define=ZEROBOUNCE_API_KEY=<your key> example/example.dart
```

Keep keys in your shell or a gitignored `.env` file. Never commit a key.

## How to Contribute

### Reporting Bugs

Open an [issue](https://github.com/zerobounce/zerobounce-dart/issues) and include:

* Environment details (Dart or Flutter version, platform)
* Steps to reproduce
* Expected vs actual behavior
* Relevant code or error messages

### Suggesting Changes

* Check existing issues and pull requests first.
* Open an issue to discuss larger changes or API design before coding.

### Submitting Changes

1. **Fork** the repository and create a branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** and add or update tests where relevant. Add a line to `CHANGELOG.md` for every change a user of the package can see.

3. **Run the steps above** before submitting.

4. **Commit** with a clear message (e.g. `Add X`, `Fix Y`).

5. **Push** your branch and open a **Pull Request** against `main`.

6. In the PR description, briefly explain what changed and why. Link any related issues.

Maintainers will review and may request changes. Once approved, your PR can be merged.

## Releases

Releases are published to pub.dev by the Publish workflow (`.github/workflows/publish.yml`) when a maintainer pushes a `vX.Y.Z` tag. It checks the tag against `pubspec.yaml`, runs the tests, waits for approval in the `release` environment, then publishes with pub.dev's GitHub Actions trusted publishing and creates the GitHub release.

## Questions

* [ZeroBounce API docs](https://www.zerobounce.net/docs/)
* [Project homepage](https://zerobounce.net)
* Contact: **integrations@zerobounce.net**

Thanks for contributing.
