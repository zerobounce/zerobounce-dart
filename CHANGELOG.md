# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/), and the project
adheres to [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - Unreleased

The first release of the ZeroBounce Dart SDK (`zerobounce_sdk` on pub.dev).
Pure Dart on `package:http`: Flutter (mobile, desktop, web), the server and the
browser. Requires Dart 3.4 or later.

### Added

- `ZeroBounceSDK`, one client per API key, with every documented endpoint:
  - Account: `getCredits`, `getApiUsage`.
  - Validation: `validateEmail` (GET, or form POST with `usePost`; `ipAddress`,
    `timeout` 3-60, `activityData`, `verifyPlus`, `domainInfo`,
    `greylistProcessing`, `callbackUrl`), `validateBatch` (JSON body, `timeout`
    10-120, `activityData`, `verifyPlus`), `getEmailActivity`.
  - AI scoring: `scoreEmail`.
  - Bulk validation and scoring files: `sendFile`, `getFileStatus`, `getFile`
    (`downloadType`, `activityData`), `deleteFile`, `sendScoringFile`,
    `getScoringFileStatus`, `getScoringFile`, `deleteScoringFile`.
  - Bulk email finder and bulk domain search files: `sendEmailFinderFile`,
    `getEmailFinderFileStatus`, `getEmailFinderFile`, `deleteEmailFinderFile`,
    `sendDomainSearchFile`, `getDomainSearchFileStatus`, `getDomainSearchFile`,
    `deleteDomainSearchFile`.
  - Email finder and domain search: `findEmailByDomain`,
    `findEmailByCompanyName`, `findEmailFormatByDomain`,
    `findEmailFormatByCompanyName`.
  - List evaluator: `sendListEvaluatorFile`, `getListEvaluatorResult`,
    `sendEvaluatedFile`.
  - Allow and block filters: `addFilter`, `listFilters`, `deleteFilter`.
  - Amazon S3 and SFTP file jobs: `listS3Files`, `validateS3File`,
    `scoreS3File`, `emailFinderS3File`, `domainSearchS3File`, `exportS3File`,
    `validateSftpFile`, `scoreSftpFile`, `emailFinderSftpFile`,
    `domainSearchSftpFile`, `exportSftpFile`.
  - Inbox Placement Tester: `getInboxPlacementProviders`,
    `getInboxPlacementTestTypes`, `createInboxPlacementTest`,
    `getInboxPlacementTest`, `listInboxPlacementTests`,
    `deleteInboxPlacementTest`, `getInboxPlacementWebhook`,
    `setInboxPlacementWebhook` (key in an `Authorization: Bearer` header).
- Typed results (`ZBValidateResult`, `ZBFileStatus`, ...) whose `toString`
  names the type and every field, each with the answer as received in `raw`.
- `ZBException`, the one error type, with the HTTP `statusCode` (`0` when there
  was no answer) and a short message that never contains the API key.
- Base URLs: `ZBApiUrl.defaultUrl`, `ZBApiUrl.usa`, `ZBApiUrl.eu`, and separate
  base URL arguments for the bulk, bulk root, list evaluator, Inbox Placement
  Tester, bulk email finder and bulk domain search APIs.

### Security

- Every base URL must be `https://` (loopback `http://` for tests only) without
  user information, a query string or a fragment; the error does not quote it.
- Redirects are never followed; a 3xx answer is an error with its status.
- Requests time out after 120 seconds by default and are aborted.
- The key is redacted from every error in every spelling the SDK sends or a
  server can echo; a message whose decoded text still holds it is replaced.

[1.0.0]: https://github.com/zerobounce/zerobounce-dart/releases/tag/v1.0.0
