import 'package:http/http.dart' as http;

import 'constants.dart';
import 'default_client_stub.dart' if (dart.library.io) 'default_client_io.dart';
import 'errors.dart';
import 'guards.dart';
import 'models.dart';
import 'transport.dart';

typedef _Json = Map<String, Object?>;

/// The ZeroBounce API client.
///
/// Construct one per API key; the key is kept in a private field and never
/// appears in `toString`, an error message or a log. Every method returns a
/// [Future] that completes with a typed result or with a [ZBException].
///
/// ```dart
/// final zb = ZeroBounceSDK('<your API key>');
/// final result = await zb.validateEmail('someone@example.com');
/// print(result.status);
/// zb.close();
/// ```
class ZeroBounceSDK {
  /// Creates a client for [apiKey].
  ///
  /// [baseUrl] picks the main API host ([ZBApiUrl.defaultUrl], [ZBApiUrl.usa]
  /// or [ZBApiUrl.eu]). The bulk, list evaluator, Inbox Placement Tester, bulk
  /// email finder and bulk domain search APIs have their own base URLs, which
  /// default to `bulkapi.zerobounce.net` (there is no regional bulk host).
  ///
  /// Every base URL must be `https://` (plain `http://` only to 127.0.0.1,
  /// localhost or [::1], for tests) and must not carry a username, password,
  /// query string or fragment; trailing slashes are dropped. All arguments are
  /// checked before the client exists, so a constructor that throws leaves
  /// nothing half set up.
  ///
  /// Pass [httpClient] to use your own `package:http` client (a test fake, a
  /// retrying client); the SDK then leaves closing it to you. Requests time out
  /// after [timeout] (120 seconds by default), connection and body included,
  /// and redirects are never followed.
  ZeroBounceSDK(
    String apiKey, {
    String baseUrl = ZBApiUrl.defaultUrl,
    String bulkBaseUrl = ZBApiUrl.bulk,
    String bulkRootBaseUrl = ZBApiUrl.bulkRoot,
    String listEvaluatorBaseUrl = ZBApiUrl.listEvaluator,
    String inboxPlacementBaseUrl = ZBApiUrl.inboxPlacement,
    String emailFinderBaseUrl = ZBApiUrl.emailFinder,
    String domainSearchBaseUrl = ZBApiUrl.domainSearch,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 120),
  })  : _apiKey = checkApiKey(apiKey),
        _baseUrl = normalizeBaseUrl(baseUrl, 'baseUrl'),
        _bulkBaseUrl = normalizeBaseUrl(bulkBaseUrl, 'bulkBaseUrl'),
        _bulkRootBaseUrl = normalizeBaseUrl(bulkRootBaseUrl, 'bulkRootBaseUrl'),
        _listEvaluatorBaseUrl =
            normalizeBaseUrl(listEvaluatorBaseUrl, 'listEvaluatorBaseUrl'),
        _inboxPlacementBaseUrl =
            normalizeBaseUrl(inboxPlacementBaseUrl, 'inboxPlacementBaseUrl'),
        _emailFinderBaseUrl =
            normalizeBaseUrl(emailFinderBaseUrl, 'emailFinderBaseUrl'),
        _domainSearchBaseUrl =
            normalizeBaseUrl(domainSearchBaseUrl, 'domainSearchBaseUrl'),
        _timeout = _checkTimeout(timeout),
        _ownsClient = httpClient == null,
        _client = httpClient ?? createDefaultClient(timeout) {
    _transport = Transport(_client, _timeout, _apiKey);
  }

  static Duration _checkTimeout(Duration timeout) {
    if (timeout <= Duration.zero) {
      throw const ZBException(
          'ZeroBounce: timeout parameter is invalid. Must be positive.');
    }
    return timeout;
  }

  final String _apiKey;
  final String _baseUrl;
  final String _bulkBaseUrl;
  final String _bulkRootBaseUrl;
  final String _listEvaluatorBaseUrl;
  final String _inboxPlacementBaseUrl;
  final String _emailFinderBaseUrl;
  final String _domainSearchBaseUrl;
  final Duration _timeout;
  final bool _ownsClient;
  final http.Client _client;
  late final Transport _transport;

  /// Closes the HTTP client the SDK created. A client passed as `httpClient`
  /// is left open.
  void close() {
    if (_ownsClient) _client.close();
  }

  @override
  String toString() => 'ZeroBounceSDK(apiKey: ***, baseUrl: $_baseUrl, '
      'bulkBaseUrl: $_bulkBaseUrl, bulkRootBaseUrl: $_bulkRootBaseUrl, '
      'listEvaluatorBaseUrl: $_listEvaluatorBaseUrl, '
      'inboxPlacementBaseUrl: $_inboxPlacementBaseUrl, '
      'emailFinderBaseUrl: $_emailFinderBaseUrl, '
      'domainSearchBaseUrl: $_domainSearchBaseUrl, timeout: $_timeout)';

  // -------------------------------------------------------------------------
  // Plumbing.

  Future<Object?> _json(ApiRequest request, JsonSpec spec) async =>
      _transport.json(await _transport.send(request), spec);

  Future<_Json> _object(ApiRequest request, String type,
          {bool messageOnlyExempt = false,
          bool messageFirst = false,
          bool requireFileStatusKnownField = false}) async =>
      (await _json(
          request,
          JsonSpec(
            fields: [type],
            messageOnlyExempt: messageOnlyExempt,
            messageFirst: messageFirst,
            requireFileStatusKnownField: requireFileStatusKnownField,
          ))) as _Json;

  ApiRequest _get(String base, String path, Map<String, String> query) =>
      ApiRequest('GET', base, path, query: {'api_key': _apiKey, ...query});

  ApiRequest _postForm(String base, String path, Map<String, String> form) =>
      ApiRequest('POST', base, path, form: {'api_key': _apiKey, ...form});

  ApiRequest _upload(String base, String path, List<int> file, String fileName,
      Map<String, String> fields) {
    if (file.isEmpty) parameterIsMissing('file', 'The file has no bytes.');
    requireText(fileName, 'fileName');
    return ApiRequest('POST', base, path,
        multipartFields: {...fields, 'api_key': _apiKey},
        fileBytes: file,
        fileName: fileName);
  }

  static String _bool(bool value) => value ? 'true' : 'false';

  static String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // -------------------------------------------------------------------------
  // Account.

  /// The credits left on the account (`GET /getcredits`). `-1` means the key
  /// is invalid, as the API documents it.
  Future<ZBCredits> getCredits() async => ZBCredits.fromJson(await _object(
      _get(_baseUrl, '/getcredits', const {}), 'GetCreditsResponse',
      messageFirst: true));

  /// Usage counts between two dates (`GET /getapiusage`). The dates are sent
  /// as YYYY-MM-DD, read from the [DateTime]'s own year, month and day.
  Future<ZBApiUsage> getApiUsage(DateTime startDate, DateTime endDate) async =>
      ZBApiUsage.fromJson(await _object(
          _get(_baseUrl, '/getapiusage',
              {'start_date': _date(startDate), 'end_date': _date(endDate)}),
          'ApiUsageResponse'));

  // -------------------------------------------------------------------------
  // Validation.

  /// Validates one address (`/validate`).
  ///
  /// Optional settings are sent only when set: [ipAddress], [timeout] (3 to 60
  /// seconds; when met the API answers unknown/greylisted), [activityData],
  /// [verifyPlus], [domainInfo], [greylistProcessing] and [callbackUrl] (which
  /// needs `greylistProcessing: true`). [usePost] sends a form-encoded POST
  /// instead of a GET.
  Future<ZBValidateResult> validateEmail(
    String email, {
    String? ipAddress,
    int? timeout,
    bool? activityData,
    bool? verifyPlus,
    bool? domainInfo,
    bool? greylistProcessing,
    String? callbackUrl,
    bool usePost = false,
  }) async {
    requireText(email, 'Email');
    if (timeout != null && (timeout < 3 || timeout > 60)) {
      parameterIsInvalid(
          'timeout', 'Must be a whole number between 3 and 60 seconds.');
    }
    if (callbackUrl != null && greylistProcessing != true) {
      parameterIsInvalid('callbackUrl', 'Requires greylistProcessing: true.');
    }
    if (callbackUrl != null && callbackUrl.trim().isEmpty) {
      parameterIsMissing('callbackUrl');
    }
    final params = {
      'email': email,
      if (ipAddress != null) 'ip_address': ipAddress,
      if (timeout != null) 'timeout': '$timeout',
      if (activityData != null) 'activity_data': _bool(activityData),
      if (verifyPlus != null) 'verify_plus': _bool(verifyPlus),
      if (domainInfo != null) 'domain_info': _bool(domainInfo),
      if (greylistProcessing != null)
        'greylist_processing': _bool(greylistProcessing),
      if (callbackUrl != null) 'callback_url': callbackUrl,
    };
    final request = usePost
        ? _postForm(_baseUrl, '/validate', params)
        : _get(_baseUrl, '/validate', params);
    return ZBValidateResult.fromJson(
        await _object(request, 'EmailValidationResult'));
  }

  /// Validates up to 200 addresses in one call (`POST /validatebatch`, JSON).
  ///
  /// [timeout] is 10 to 120 seconds. A per-address error stays on the result;
  /// an account-level error (an invalid key, no credits) is thrown.
  Future<ZBBatchResult> validateBatch(
    List<ZBBatchEmail> emails, {
    int? timeout,
    bool? activityData,
    bool? verifyPlus,
  }) async {
    if (emails.isEmpty) parameterIsMissing('Email list');
    for (final email in emails) {
      requireText(email.emailAddress, 'email_address');
    }
    if (timeout != null && (timeout < 10 || timeout > 120)) {
      parameterIsInvalid(
          'timeout', 'Must be a whole number between 10 and 120 seconds.');
    }
    // The API requires timeout as a JSON string ("30"); the flags stay booleans.
    final body = {
      'api_key': _apiKey,
      'email_batch': [for (final email in emails) email.toJson()],
      if (timeout != null) 'timeout': '$timeout',
      if (activityData != null) 'activity_data': activityData,
      if (verifyPlus != null) 'verify_plus': verifyPlus,
    };
    return ZBBatchResult.fromJson(await _object(
        ApiRequest('POST', _baseUrl, '/validatebatch', json: body),
        'ValidateBatchResponse'));
  }

  /// When the address was last seen active (`GET /activity`).
  Future<ZBActivity> getEmailActivity(String email) async {
    requireText(email, 'Email');
    return ZBActivity.fromJson(await _object(
        _get(_baseUrl, '/activity', {'email': email}),
        'EmailActivityResponse'));
  }

  // -------------------------------------------------------------------------
  // AI scoring.

  /// Real-time AI scoring of one address (`/scoring`). [usePost] sends a
  /// form-encoded POST instead of a GET.
  Future<ZBScoreResult> scoreEmail(String email, {bool usePost = false}) async {
    requireText(email, 'Email');
    final params = {'email': email};
    final request = usePost
        ? _postForm(_baseUrl, '/scoring', params)
        : _get(_baseUrl, '/scoring', params);
    return ZBScoreResult.fromJson(await _object(request, 'EmailScoringResult'));
  }

  // -------------------------------------------------------------------------
  // Bulk validation and scoring files.

  /// Submits a CSV or TXT file for bulk validation (`POST /v2/sendfile`).
  ///
  /// Columns are 1-based. Optional columns, [returnUrl], [removeDuplicate]
  /// (the API removes duplicates when it is not sent) and [allowPhase2] are
  /// sent only when set.
  Future<ZBSendFileResult> sendFile({
    required List<int> file,
    required String fileName,
    required int emailAddressColumn,
    required bool hasHeaderRow,
    String? returnUrl,
    int? firstNameColumn,
    int? lastNameColumn,
    int? genderColumn,
    int? ipAddressColumn,
    bool? removeDuplicate,
    bool? allowPhase2,
  }) async {
    final fields = {
      'email_address_column':
          '${checkColumn(emailAddressColumn, 'email_address_column')}',
      'has_header_row': _bool(hasHeaderRow),
      if (returnUrl != null) 'return_url': requireText(returnUrl, 'return_url'),
      if (firstNameColumn != null)
        'first_name_column':
            '${checkColumn(firstNameColumn, 'first_name_column')}',
      if (lastNameColumn != null)
        'last_name_column':
            '${checkColumn(lastNameColumn, 'last_name_column')}',
      if (genderColumn != null)
        'gender_column': '${checkColumn(genderColumn, 'gender_column')}',
      if (ipAddressColumn != null)
        'ip_address_column':
            '${checkColumn(ipAddressColumn, 'ip_address_column')}',
      if (removeDuplicate != null) 'remove_duplicate': _bool(removeDuplicate),
      if (allowPhase2 != null) 'allow_phase_2': _bool(allowPhase2),
    };
    return ZBSendFileResult.fromJson(await _object(
        _upload(_bulkBaseUrl, '/sendfile', file, fileName, fields),
        'BulkSendFileResponse'));
  }

  /// Submits a file for bulk AI scoring (`POST /v2/scoring/sendfile`).
  Future<ZBSendFileResult> sendScoringFile({
    required List<int> file,
    required String fileName,
    required int emailAddressColumn,
    required bool hasHeaderRow,
    String? returnUrl,
    bool? removeDuplicate,
  }) async {
    final fields = {
      'email_address_column':
          '${checkColumn(emailAddressColumn, 'email_address_column')}',
      'has_header_row': _bool(hasHeaderRow),
      if (returnUrl != null) 'return_url': requireText(returnUrl, 'return_url'),
      if (removeDuplicate != null) 'remove_duplicate': _bool(removeDuplicate),
    };
    return ZBSendFileResult.fromJson(await _object(
        _upload(_bulkBaseUrl, '/scoring/sendfile', file, fileName, fields),
        'BulkSendFileResponse'));
  }

  Future<ZBFileStatus> _fileStatus(
      String base, String path, String fileId, String type) async {
    requireText(fileId, 'File id');
    return ZBFileStatus.fromJson(await _object(
        _get(base, path, {'file_id': fileId}), type,
        requireFileStatusKnownField: true));
  }

  Future<String> _getFile(String base, String path, String fileId,
      [Map<String, String> extra = const {}]) async {
    requireText(fileId, 'File id');
    final response =
        await _transport.send(_get(base, path, {'file_id': fileId, ...extra}));
    return _transport.download(response);
  }

  Future<ZBDeleteFileResult> _deleteFile(
      String base, String path, String fileId) async {
    requireText(fileId, 'File id');
    return ZBDeleteFileResult.fromJson(await _object(
        _get(base, path, {'file_id': fileId}), 'BulkFileDeletedResponse'));
  }

  /// The status of a bulk validation file (`GET /v2/filestatus`).
  Future<ZBFileStatus> getFileStatus(String fileId) async => _fileStatus(
      _bulkBaseUrl, '/filestatus', fileId, 'ValidationFileStatusResponse');

  /// The status of a bulk scoring file (`GET /v2/scoring/filestatus`).
  Future<ZBFileStatus> getScoringFileStatus(String fileId) async => _fileStatus(
      _bulkBaseUrl, '/scoring/filestatus', fileId, 'ScoringFileStatusResponse');

  /// The results of a bulk validation file as CSV text (`GET /v2/getfile`).
  /// [downloadType] and [activityData] are sent only when set.
  Future<String> getFile(String fileId,
          {ZBDownloadType? downloadType, bool? activityData}) async =>
      _getFile(_bulkBaseUrl, '/getfile', fileId, {
        if (downloadType != null) 'download_type': downloadType.value,
        if (activityData != null) 'activity_data': _bool(activityData),
      });

  /// The results of a bulk scoring file as CSV text (`GET /v2/scoring/getfile`).
  Future<String> getScoringFile(String fileId,
          {ZBDownloadType? downloadType}) async =>
      _getFile(_bulkBaseUrl, '/scoring/getfile', fileId, {
        if (downloadType != null) 'download_type': downloadType.value,
      });

  /// Deletes a bulk validation file (`GET /v2/deletefile`).
  Future<ZBDeleteFileResult> deleteFile(String fileId) async =>
      _deleteFile(_bulkBaseUrl, '/deletefile', fileId);

  /// Deletes a bulk scoring file (`GET /v2/scoring/deletefile`).
  Future<ZBDeleteFileResult> deleteScoringFile(String fileId) async =>
      _deleteFile(_bulkBaseUrl, '/scoring/deletefile', fileId);

  // -------------------------------------------------------------------------
  // Bulk email finder and bulk domain search.

  /// Submits a file to the bulk email finder (`POST /email-finder/sendfile`).
  /// The API needs a name to work from: [firstNameColumn] or
  /// [fullNameColumn].
  Future<ZBSendFileResult> sendEmailFinderFile({
    required List<int> file,
    required String fileName,
    required int domainColumn,
    required bool hasHeaderRow,
    int? firstNameColumn,
    int? lastNameColumn,
    int? middleNameColumn,
    int? fullNameColumn,
  }) async {
    if (firstNameColumn == null && fullNameColumn == null) {
      parameterIsMissing(
          'first_name_column', 'Send first_name_column or full_name_column.');
    }
    final fields = {
      'domain_column': '${checkColumn(domainColumn, 'domain_column')}',
      if (firstNameColumn != null)
        'first_name_column':
            '${checkColumn(firstNameColumn, 'first_name_column')}',
      if (lastNameColumn != null)
        'last_name_column':
            '${checkColumn(lastNameColumn, 'last_name_column')}',
      if (middleNameColumn != null)
        'middle_name_column':
            '${checkColumn(middleNameColumn, 'middle_name_column')}',
      if (fullNameColumn != null)
        'full_name_column':
            '${checkColumn(fullNameColumn, 'full_name_column')}',
      'has_header_row': _bool(hasHeaderRow),
    };
    return ZBSendFileResult.fromJson(await _object(
        _upload(_emailFinderBaseUrl, '/sendfile', file, fileName, fields),
        'BulkSendFileResponse'));
  }

  /// The status of a bulk email finder file.
  Future<ZBFileStatus> getEmailFinderFileStatus(String fileId) async =>
      _fileStatus(_emailFinderBaseUrl, '/filestatus', fileId,
          'ValidationFileStatusResponse');

  /// The results of a bulk email finder file as CSV text.
  Future<String> getEmailFinderFile(String fileId) async =>
      _getFile(_emailFinderBaseUrl, '/getfile', fileId);

  /// Deletes a bulk email finder file.
  Future<ZBDeleteFileResult> deleteEmailFinderFile(String fileId) async =>
      _deleteFile(_emailFinderBaseUrl, '/deletefile', fileId);

  /// Submits a file to bulk domain search (`POST /domain-search/sendfile`).
  Future<ZBSendFileResult> sendDomainSearchFile({
    required List<int> file,
    required String fileName,
    required int domainColumn,
    required bool hasHeaderRow,
  }) async {
    final fields = {
      'domain_column': '${checkColumn(domainColumn, 'domain_column')}',
      'has_header_row': _bool(hasHeaderRow),
    };
    return ZBSendFileResult.fromJson(await _object(
        _upload(_domainSearchBaseUrl, '/sendfile', file, fileName, fields),
        'BulkSendFileResponse'));
  }

  /// The status of a bulk domain search file.
  Future<ZBFileStatus> getDomainSearchFileStatus(String fileId) async =>
      _fileStatus(_domainSearchBaseUrl, '/filestatus', fileId,
          'ValidationFileStatusResponse');

  /// The results of a bulk domain search file as CSV text.
  Future<String> getDomainSearchFile(String fileId) async =>
      _getFile(_domainSearchBaseUrl, '/getfile', fileId);

  /// Deletes a bulk domain search file.
  Future<ZBDeleteFileResult> deleteDomainSearchFile(String fileId) async =>
      _deleteFile(_domainSearchBaseUrl, '/deletefile', fileId);

  // -------------------------------------------------------------------------
  // List evaluator.

  /// Submits a file to the list evaluator (`POST /v2/listevaluator/`).
  Future<ZBListEvaluatorSubmitResult> sendListEvaluatorFile({
    required List<int> file,
    required String fileName,
    required int emailAddressColumn,
  }) async {
    final fields = {
      'email_address_column':
          '${checkColumn(emailAddressColumn, 'email_address_column')}',
    };
    return ZBListEvaluatorSubmitResult.fromJson(await _object(
        _upload(_listEvaluatorBaseUrl, '/', file, fileName, fields),
        'ListEvaluatorSubmitResponse'));
  }

  /// The list evaluator's result for a file (`GET /v2/listevaluator/{id}/`),
  /// as the decoded JSON object. Its documented success can be a message, so
  /// a message-only answer is returned, not thrown.
  Future<Map<String, Object?>> getListEvaluatorResult(String fileId) async {
    final segment = pathSegment(fileId, 'File id');
    return _object(_get(_listEvaluatorBaseUrl, '/$segment/', const {}),
        'ListEvaluatorResultResponse',
        messageOnlyExempt: true);
  }

  /// Submits a finished evaluation for validation
  /// (`POST /v2/send-evaluated-file/`). The API takes the list evaluator's
  /// file id as a form field and answers with a new validation file id.
  Future<ZBListEvaluatorSubmitResult> sendEvaluatedFile(String fileId) async {
    requireText(fileId, 'File id');
    return ZBListEvaluatorSubmitResult.fromJson(await _object(
        ApiRequest('POST', _bulkBaseUrl, '/send-evaluated-file/',
            multipartFields: {'api_key': _apiKey, 'file_id': fileId}),
        'ListEvaluatorSubmitResponse'));
  }

  // -------------------------------------------------------------------------
  // Allow and block filters.

  /// Adds an allow or block filter (`POST /v2/filters/add`). Returns the
  /// decoded answer, documented as `{"Message": "Filter has been added."}`.
  Future<Map<String, Object?>> addFilter({
    required ZBFilterRule rule,
    required ZBFilterTarget target,
    required String value,
  }) async {
    requireText(value, 'value');
    return _object(
        _postForm(_baseUrl, '/filters/add',
            {'rule': rule.value, 'target': target.value, 'value': value}),
        'FilterMessageResponse',
        messageOnlyExempt: true);
  }

  /// Deletes an allow or block filter (`POST /v2/filters/delete`).
  Future<Map<String, Object?>> deleteFilter({
    required ZBFilterRule rule,
    required ZBFilterTarget target,
    required String value,
  }) async {
    requireText(value, 'value');
    return _object(
        _postForm(_baseUrl, '/filters/delete',
            {'rule': rule.value, 'target': target.value, 'value': value}),
        'FilterMessageResponse',
        messageOnlyExempt: true);
  }

  /// The account's filters (`/v2/filters/list`). [usePost] sends a POST.
  Future<ZBFilterList> listFilters({bool usePost = false}) async {
    final request = usePost
        ? _postForm(_baseUrl, '/filters/list', const {})
        : _get(_baseUrl, '/filters/list', const {});
    final parsed = await _json(
        request,
        const JsonSpec(
          fields: ['FilterListItem[]', 'FilterMessageResponse'],
          shape: Shape.objectOrArray,
          messageOnlyExempt: true,
        ));
    if (parsed is List) {
      return ZBFilterList(
          List.unmodifiable(
              [for (final item in parsed) ZBFilter.fromJson(item as _Json)]),
          null);
    }
    return ZBFilterList(const [], (parsed as _Json)['Message'] as String?);
  }

  // -------------------------------------------------------------------------
  // Amazon S3 and SFTP file jobs (bulk host root).

  /// The files in your Amazon S3 bucket (`GET /listS3files`). [bucket] and
  /// [search] are sent only when set.
  Future<List<ZBS3File>> listS3Files({String? bucket, String? search}) async {
    final parsed = await _json(
        _get(_bulkRootBaseUrl, '/listS3files', {
          if (bucket != null) 'bucket': bucket,
          if (search != null) 'search': search,
        }),
        const JsonSpec(fields: ['S3ListFileEntry[]'], shape: Shape.array));
    return List.unmodifiable(
        [for (final item in parsed! as List) ZBS3File.fromJson(item as _Json)]);
  }

  Future<ZBFileJobResult> _fileJob(String path, String? fileName,
      bool? hasHeaderRow, bool? removeDuplicates, String? returnUrl) async {
    // The API rejects a job without file_name or return_url, although the docs
    // mark them optional, so neither goes out missing.
    requireText(fileName, 'file_name');
    if (hasHeaderRow == null) parameterIsMissing('has_header_row');
    requireText(returnUrl, 'return_url', 'The API rejects a job without it.');
    return ZBFileJobResult.fromJson(await _object(
        _postForm(_bulkRootBaseUrl, path, {
          'file_name': fileName!,
          'has_header_row': _bool(hasHeaderRow),
          'return_url': returnUrl!,
          if (removeDuplicates != null)
            'remove_duplicates': _bool(removeDuplicates),
        }),
        'S3BulkJobResponse'));
  }

  Future<ZBFileJobResult> _exportJob(
      String path, String fileId, String key, String? value) async {
    requireText(fileId, 'file_id');
    if (value != null) requireText(value, key);
    return ZBFileJobResult.fromJson(await _object(
        _postForm(_bulkRootBaseUrl, path,
            {'file_id': fileId, if (value != null) key: value}),
        'S3BulkJobResponse'));
  }

  /// Validates a file in your Amazon S3 bucket (`POST /validateS3file`).
  Future<ZBFileJobResult> validateS3File(
          {required String fileName,
          required bool hasHeaderRow,
          required String returnUrl,
          bool? removeDuplicates}) async =>
      _fileJob('/validateS3file', fileName, hasHeaderRow, removeDuplicates,
          returnUrl);

  /// Scores a file in your Amazon S3 bucket (`POST /scoreS3file`).
  Future<ZBFileJobResult> scoreS3File(
          {required String fileName,
          required bool hasHeaderRow,
          required String returnUrl,
          bool? removeDuplicates}) async =>
      _fileJob(
          '/scoreS3file', fileName, hasHeaderRow, removeDuplicates, returnUrl);

  /// Runs the email finder on a file in your Amazon S3 bucket
  /// (`POST /emailFinderS3file`).
  Future<ZBFileJobResult> emailFinderS3File(
          {required String fileName,
          required bool hasHeaderRow,
          required String returnUrl,
          bool? removeDuplicates}) async =>
      _fileJob('/emailFinderS3file', fileName, hasHeaderRow, removeDuplicates,
          returnUrl);

  /// Runs domain search on a file in your Amazon S3 bucket
  /// (`POST /domainSearchS3file`).
  Future<ZBFileJobResult> domainSearchS3File(
          {required String fileName,
          required bool hasHeaderRow,
          required String returnUrl,
          bool? removeDuplicates}) async =>
      _fileJob('/domainSearchS3file', fileName, hasHeaderRow, removeDuplicates,
          returnUrl);

  /// Exports a validated or scored file to Amazon S3 (`POST /exportS3file`).
  /// Without [exportBucket] the output bucket from your settings is used.
  Future<ZBFileJobResult> exportS3File(
          {required String fileId, String? exportBucket}) async =>
      _exportJob('/exportS3file', fileId, 'export_bucket', exportBucket);

  /// Validates a file from your SFTP/FTP server (`POST /validateSFTPfile`).
  /// The server, path and protocol come from your ZeroBounce settings.
  Future<ZBFileJobResult> validateSftpFile(
          {required String fileName,
          required bool hasHeaderRow,
          required String returnUrl,
          bool? removeDuplicates}) async =>
      _fileJob('/validateSFTPfile', fileName, hasHeaderRow, removeDuplicates,
          returnUrl);

  /// Scores a file from your SFTP/FTP server (`POST /scoreSFTPfile`).
  Future<ZBFileJobResult> scoreSftpFile(
          {required String fileName,
          required bool hasHeaderRow,
          required String returnUrl,
          bool? removeDuplicates}) async =>
      _fileJob('/scoreSFTPfile', fileName, hasHeaderRow, removeDuplicates,
          returnUrl);

  /// Runs the email finder on a file from your SFTP/FTP server
  /// (`POST /emailFinderSFTPfile`).
  Future<ZBFileJobResult> emailFinderSftpFile(
          {required String fileName,
          required bool hasHeaderRow,
          required String returnUrl,
          bool? removeDuplicates}) async =>
      _fileJob('/emailFinderSFTPfile', fileName, hasHeaderRow, removeDuplicates,
          returnUrl);

  /// Runs domain search on a file from your SFTP/FTP server
  /// (`POST /domainSearchSFTPfile`).
  Future<ZBFileJobResult> domainSearchSftpFile(
          {required String fileName,
          required bool hasHeaderRow,
          required String returnUrl,
          bool? removeDuplicates}) async =>
      _fileJob('/domainSearchSFTPfile', fileName, hasHeaderRow,
          removeDuplicates, returnUrl);

  /// Exports a validated or scored file to your SFTP/FTP server
  /// (`POST /exportSFTPfile`). Without [exportPath] the path from your
  /// settings is used.
  Future<ZBFileJobResult> exportSftpFile(
          {required String fileId, String? exportPath}) async =>
      _exportJob('/exportSFTPfile', fileId, 'export_path', exportPath);

  // -------------------------------------------------------------------------
  // Email finder and domain search (single).

  /// Finds a person's address at a domain (`GET /v2/guessformat`). The names
  /// are optional and sent only when set.
  Future<ZBFindEmailResult> findEmailByDomain({
    required String domain,
    String? firstName,
    String? middleName,
    String? lastName,
  }) async =>
      _findEmail({'domain': requireText(domain, 'domain')}, firstName,
          middleName, lastName);

  /// Finds a person's address at a company (`GET /v2/guessformat`).
  Future<ZBFindEmailResult> findEmailByCompanyName({
    required String companyName,
    String? firstName,
    String? middleName,
    String? lastName,
  }) async =>
      _findEmail({'company_name': requireText(companyName, 'company_name')},
          firstName, middleName, lastName);

  Future<ZBFindEmailResult> _findEmail(Map<String, String> target,
      String? firstName, String? middleName, String? lastName) async {
    final params = {
      if (!isMissing(firstName)) 'first_name': firstName!,
      if (!isMissing(middleName)) 'middle_name': middleName!,
      if (!isMissing(lastName)) 'last_name': lastName!,
      ...target,
    };
    return ZBFindEmailResult.fromJson(await _object(
        _get(_baseUrl, '/guessformat', params), 'EmailFinderResponse'));
  }

  /// The address format used at a domain (`GET /v2/guessformat`).
  Future<ZBDomainFormatResult> findEmailFormatByDomain(String domain) async =>
      ZBDomainFormatResult.fromJson(await _object(
          _get(_baseUrl, '/guessformat',
              {'domain': requireText(domain, 'domain')}),
          'DomainFormatResponse'));

  /// The address format used at a company (`GET /v2/guessformat`).
  Future<ZBDomainFormatResult> findEmailFormatByCompanyName(
          String companyName) async =>
      ZBDomainFormatResult.fromJson(await _object(
          _get(_baseUrl, '/guessformat',
              {'company_name': requireText(companyName, 'company_name')}),
          'DomainFormatResponse'));

  // -------------------------------------------------------------------------
  // Inbox Placement Tester. The key goes in an Authorization: Bearer header,
  // bodies are JSON with camelCase fields, and answers are returned as the
  // decoded JSON (field types checked where they are documented).

  Future<Object?> _ipt(String method, String path,
          {Map<String, String> query = const {},
          Object? json,
          String? type,
          Shape shape = Shape.object,
          bool emptyIsSuccess = false}) =>
      _json(
          ApiRequest(method, _inboxPlacementBaseUrl, path,
              query: query, json: json, bearer: _apiKey),
          JsonSpec(
            fields: type == null ? null : [type],
            shape: shape,
            messageOnlyExempt: true,
            emptyIsSuccess: emptyIsSuccess,
          ));

  /// The seed providers available for new tests (`GET /providers`).
  Future<Map<String, Object?>> getInboxPlacementProviders() async =>
      (await _ipt('GET', '/providers', type: 'InboxPlacementProvidersResponse'))
          as _Json;

  /// The supported test types and the default one (`GET /test-types`), as any
  /// JSON value.
  Future<Object?> getInboxPlacementTestTypes() async =>
      _ipt('GET', '/test-types', shape: Shape.json);

  /// Creates an inbox placement test (`POST /test`).
  ///
  /// [name] is at most 64 characters. [testType] is 1 (Email, needs
  /// [senderEmail]), 2 (Unique ID) or 3 (Auto Alias). Choose seeds with
  /// [providerIds], [seedIds] or [providers] (each capped at `maxSeeds`).
  /// Only the fields you set are sent.
  Future<Map<String, Object?>> createInboxPlacementTest({
    required String name,
    int? testType,
    String? senderEmail,
    List<int>? providerIds,
    List<int>? seedIds,
    List<ZBInboxPlacementProvider>? providers,
    String? webhookUrl,
  }) async {
    requireText(name, 'name');
    if (name.length > 64) {
      parameterIsInvalid('name', 'Must be at most 64 characters.');
    }
    if (testType != null && (testType < 1 || testType > 3)) {
      parameterIsInvalid('testType', 'Must be 1, 2 or 3.');
    }
    if (testType == 1 && isMissing(senderEmail)) {
      parameterIsMissing('senderEmail', 'Required when testType is 1.');
    }
    for (final provider in providers ?? const <ZBInboxPlacementProvider>[]) {
      if (provider.maxSeeds != null && provider.maxSeeds! < 1) {
        parameterIsInvalid('providers', 'maxSeeds must be at least 1.');
      }
    }
    final body = {
      'name': name,
      if (testType != null) 'testType': testType,
      if (senderEmail != null) 'senderEmail': senderEmail,
      if (providerIds != null) 'providerIds': providerIds,
      if (seedIds != null) 'seedIds': seedIds,
      if (providers != null)
        'providers': [for (final p in providers) p.toJson()],
      if (webhookUrl != null) 'webhookUrl': webhookUrl,
    };
    return (await _ipt('POST', '/test',
        json: body, type: 'InboxPlacementTestCreated')) as _Json;
  }

  /// A test and its placement results (`GET /test/{id}`).
  Future<Map<String, Object?>> getInboxPlacementTest(String testId) async =>
      (await _ipt('GET', '/test/${pathSegment(testId, 'testId')}',
          type: 'InboxPlacementTestResult')) as _Json;

  /// Lists tests, newest first (`GET /tests`), as any JSON value.
  /// [createdAfter] and [createdBefore] are ISO 8601 dates or date-times;
  /// [page] starts at 1 and [pageSize] is 1 to 100.
  Future<Object?> listInboxPlacementTests({
    ZBInboxPlacementTestStatus? status,
    String? createdAfter,
    String? createdBefore,
    int? page,
    int? pageSize,
  }) async {
    if (page != null && page < 1) {
      parameterIsInvalid('page', 'Must be at least 1.');
    }
    if (pageSize != null && (pageSize < 1 || pageSize > 100)) {
      parameterIsInvalid('pageSize', 'Must be between 1 and 100.');
    }
    return _ipt('GET', '/tests', shape: Shape.json, query: {
      if (status != null) 'status': status.value,
      if (createdAfter != null) 'createdAfter': createdAfter,
      if (createdBefore != null) 'createdBefore': createdBefore,
      if (page != null) 'page': '$page',
      if (pageSize != null) 'page_size': '$pageSize',
    });
  }

  /// Deletes a finished test (`DELETE /test/{id}`). An empty answer (204 No
  /// Content) completes with an empty map.
  Future<Map<String, Object?>> deleteInboxPlacementTest(String testId) async =>
      (await _ipt('DELETE', '/test/${pathSegment(testId, 'testId')}',
          type: 'InboxPlacementTestDeleted', emptyIsSuccess: true)) as _Json;

  /// The webhook URL saved on this API key (`GET /webhook`).
  Future<Map<String, Object?>> getInboxPlacementWebhook() async =>
      (await _ipt('GET', '/webhook', type: 'InboxPlacementWebhookResponse'))
          as _Json;

  /// Saves the URL finished results are posted to (`PUT /webhook`), and
  /// returns the answer as any JSON value.
  Future<Object?> setInboxPlacementWebhook(String webhookUrl) async {
    requireText(webhookUrl, 'webhookUrl');
    return _ipt('PUT', '/webhook',
        json: {'webhookUrl': webhookUrl}, shape: Shape.json);
  }
}
