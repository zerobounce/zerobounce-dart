// Results are built from answers whose field types have already been checked
// (see field_types.dart), so every read below is of the declared type or null.
// A field the API leaves out reads exactly like a null one.

import 'dart:collection';

import 'constants.dart';

typedef _Json = Map<String, Object?>;

String _describe(String type, Map<String, Object?> fields) =>
    '$type(${fields.entries.map((e) => '${e.key}: ${e.value}').join(', ')})';

Map<String, Object?> _frozen(_Json json) => UnmodifiableMapView(Map.of(json));

String? _text(_Json json, String key) => json[key] as String?;
bool? _flag(_Json json, String key) => json[key] as bool?;
int? _int(_Json json, String key) => (json[key] as num?)?.toInt();

/// One address for `validateBatch`.
class ZBBatchEmail {
  /// An address, with the IP it signed up from when known.
  const ZBBatchEmail(this.emailAddress, {this.ipAddress});

  final String emailAddress;
  final String? ipAddress;

  Map<String, Object?> toJson() => {
        'email_address': emailAddress,
        if (ipAddress != null) 'ip_address': ipAddress,
      };

  @override
  String toString() => _describe(
      'ZBBatchEmail', {'emailAddress': emailAddress, 'ipAddress': ipAddress});
}

/// A seed provider for `createInboxPlacementTest`, optionally capped at
/// [maxSeeds] seed mailboxes.
class ZBInboxPlacementProvider {
  const ZBInboxPlacementProvider(this.id, {this.maxSeeds});

  final int id;
  final int? maxSeeds;

  Map<String, Object?> toJson() =>
      {'id': id, if (maxSeeds != null) 'maxSeeds': maxSeeds};

  @override
  String toString() =>
      _describe('ZBInboxPlacementProvider', {'id': id, 'maxSeeds': maxSeeds});
}

/// The `getcredits` answer. [credits] is `-1` for an invalid key, which the
/// API documents as a result, not an error.
class ZBCredits {
  ZBCredits.fromJson(Map<String, Object?> json)
      : credits = json['Credits'] is String
            ? int.parse(json['Credits']! as String)
            : json['Credits']! as int,
        raw = _frozen(json);

  final int credits;

  /// The answer as received.
  final Map<String, Object?> raw;

  @override
  String toString() => _describe('ZBCredits', {'credits': credits});
}

/// One validated address (`validate`, and each `validatebatch` row).
///
/// A pending greylist request answers with only a message: then [address] and
/// [status] are null and [message] holds the API's text.
class ZBValidateResult {
  ZBValidateResult.fromJson(Map<String, Object?> json)
      : address = _text(json, 'address'),
        status = _text(json, 'status'),
        subStatus = _text(json, 'sub_status'),
        freeEmail = _flag(json, 'free_email'),
        didYouMean = _text(json, 'did_you_mean'),
        account = _text(json, 'account'),
        domain = _text(json, 'domain'),
        domainAgeDays = _text(json, 'domain_age_days'),
        activeInDays = _text(json, 'active_in_days'),
        activeFirstSeen = _text(json, 'active_first_seen'),
        smtpProvider = _text(json, 'smtp_provider'),
        catchallDomain = _flag(json, 'catchall_domain'),
        mxFound = json['mx_found'] is bool
            ? '${json['mx_found']}'
            : _text(json, 'mx_found'),
        mxRecord = _text(json, 'mx_record'),
        firstname = _text(json, 'firstname'),
        lastname = _text(json, 'lastname'),
        gender = _text(json, 'gender'),
        country = _text(json, 'country'),
        region = _text(json, 'region'),
        city = _text(json, 'city'),
        zipcode = _text(json, 'zipcode'),
        processedAt = _text(json, 'processed_at'),
        domainWebsiteExists = _text(json, 'domain_website_exists'),
        domainRegistrantCompanyName =
            _text(json, 'domain_registrant_company_name'),
        message = _text(json, 'Message') ?? _text(json, 'message'),
        raw = _frozen(json);

  /// See [ZBValidateStatus] for the documented values.
  final String? address;
  final String? status;

  /// See [ZBValidateSubStatus] for the documented values.
  final String? subStatus;
  final bool? freeEmail;
  final String? didYouMean;
  final String? account;
  final String? domain;
  final String? domainAgeDays;
  final String? activeInDays;
  final String? activeFirstSeen;
  final String? smtpProvider;
  final bool? catchallDomain;

  /// "true" or "false". The API sends a string; a JSON boolean is given as the
  /// same text.
  final String? mxFound;
  final String? mxRecord;
  final String? firstname;
  final String? lastname;
  final String? gender;
  final String? country;
  final String? region;
  final String? city;
  final String? zipcode;
  final String? processedAt;
  final String? domainWebsiteExists;
  final String? domainRegistrantCompanyName;

  /// The greylist answer's text (`Message`), when the API sent one.
  final String? message;

  /// The answer as received, for fields this version does not model.
  final Map<String, Object?> raw;

  @override
  String toString() => _describe('ZBValidateResult', {
        'address': address,
        'status': status,
        'subStatus': subStatus,
        'freeEmail': freeEmail,
        'didYouMean': didYouMean,
        'account': account,
        'domain': domain,
        'domainAgeDays': domainAgeDays,
        'activeInDays': activeInDays,
        'activeFirstSeen': activeFirstSeen,
        'smtpProvider': smtpProvider,
        'catchallDomain': catchallDomain,
        'mxFound': mxFound,
        'mxRecord': mxRecord,
        'firstname': firstname,
        'lastname': lastname,
        'gender': gender,
        'country': country,
        'region': region,
        'city': city,
        'zipcode': zipcode,
        'processedAt': processedAt,
        'domainWebsiteExists': domainWebsiteExists,
        'domainRegistrantCompanyName': domainRegistrantCompanyName,
        'message': message,
      });
}

/// The `validatebatch` answer. A per-address error stays in [errors]; an
/// account-level error (`email_address: "all"`) is thrown instead.
class ZBBatchResult {
  ZBBatchResult.fromJson(Map<String, Object?> json)
      : emailBatch = List.unmodifiable([
          for (final row in (json['email_batch'] as List?) ?? const [])
            ZBValidateResult.fromJson(row as _Json),
        ]),
        errors = List.unmodifiable((json['errors'] as List?) ?? const []),
        raw = _frozen(json);

  final List<ZBValidateResult> emailBatch;

  /// Per-address errors, as received (`{"error": ..., "email_address": ...}`).
  final List<Object?> errors;
  final Map<String, Object?> raw;

  @override
  String toString() =>
      _describe('ZBBatchResult', {'emailBatch': emailBatch, 'errors': errors});
}

/// The `getapiusage` answer: counts for the requested dates.
class ZBApiUsage {
  ZBApiUsage.fromJson(Map<String, Object?> json)
      : total = _int(json, 'total'),
        statusValid = _int(json, 'status_valid'),
        statusInvalid = _int(json, 'status_invalid'),
        statusCatchAll = _int(json, 'status_catch_all'),
        statusDoNotMail = _int(json, 'status_do_not_mail'),
        statusSpamtrap = _int(json, 'status_spamtrap'),
        statusUnknown = _int(json, 'status_unknown'),
        subStatusToxic = _int(json, 'sub_status_toxic'),
        subStatusDisposable = _int(json, 'sub_status_disposable'),
        subStatusRoleBased = _int(json, 'sub_status_role_based'),
        subStatusPossibleTrap = _int(json, 'sub_status_possible_trap'),
        subStatusGlobalSuppression =
            _int(json, 'sub_status_global_suppression'),
        subStatusTimeoutExceeded = _int(json, 'sub_status_timeout_exceeded'),
        subStatusMailServerTemporaryError =
            _int(json, 'sub_status_mail_server_temporary_error'),
        subStatusMailServerDidNotRespond =
            _int(json, 'sub_status_mail_server_did_not_respond'),
        subStatusGreylisted = _int(json, 'sub_status_greylisted'),
        subStatusAntispamSystem = _int(json, 'sub_status_antispam_system'),
        subStatusDoesNotAcceptMail =
            _int(json, 'sub_status_does_not_accept_mail'),
        subStatusExceptionOccurred =
            _int(json, 'sub_status_exception_occurred'),
        subStatusFailedSyntaxCheck =
            _int(json, 'sub_status_failed_syntax_check'),
        subStatusMailboxNotFound = _int(json, 'sub_status_mailbox_not_found'),
        subStatusUnroutableIpAddress =
            _int(json, 'sub_status_unroutable_ip_address'),
        subStatusPossibleTypo = _int(json, 'sub_status_possible_typo'),
        subStatusNoDnsEntries = _int(json, 'sub_status_no_dns_entries'),
        subStatusRoleBasedCatchAll =
            _int(json, 'sub_status_role_based_catch_all'),
        subStatusMailboxQuotaExceeded =
            _int(json, 'sub_status_mailbox_quota_exceeded'),
        subStatusForcibleDisconnect =
            _int(json, 'sub_status_forcible_disconnect'),
        subStatusFailedSmtpConnection =
            _int(json, 'sub_status_failed_smtp_connection'),
        subStatusAcceptAll = _int(json, 'sub_status_accept_all'),
        subStatusMxForward = _int(json, 'sub_status_mx_forward'),
        subStatusAlternate = _int(json, 'sub_status_alternate'),
        subStatusAllowed = _int(json, 'sub_status_allowed'),
        subStatusBlocked = _int(json, 'sub_status_blocked'),
        subStatusGold = _int(json, 'sub_status_gold'),
        subStatusRoleBasedAcceptAll =
            _int(json, 'sub_status_role_based_accept_all'),
        startDate = _text(json, 'start_date'),
        endDate = _text(json, 'end_date'),
        raw = _frozen(json);

  final int? total;
  final int? statusValid;
  final int? statusInvalid;
  final int? statusCatchAll;
  final int? statusDoNotMail;
  final int? statusSpamtrap;
  final int? statusUnknown;
  final int? subStatusToxic;
  final int? subStatusDisposable;
  final int? subStatusRoleBased;
  final int? subStatusPossibleTrap;
  final int? subStatusGlobalSuppression;
  final int? subStatusTimeoutExceeded;
  final int? subStatusMailServerTemporaryError;
  final int? subStatusMailServerDidNotRespond;
  final int? subStatusGreylisted;
  final int? subStatusAntispamSystem;
  final int? subStatusDoesNotAcceptMail;
  final int? subStatusExceptionOccurred;
  final int? subStatusFailedSyntaxCheck;
  final int? subStatusMailboxNotFound;
  final int? subStatusUnroutableIpAddress;
  final int? subStatusPossibleTypo;
  final int? subStatusNoDnsEntries;
  final int? subStatusRoleBasedCatchAll;
  final int? subStatusMailboxQuotaExceeded;
  final int? subStatusForcibleDisconnect;
  final int? subStatusFailedSmtpConnection;
  final int? subStatusAcceptAll;
  final int? subStatusMxForward;
  final int? subStatusAlternate;
  final int? subStatusAllowed;
  final int? subStatusBlocked;
  final int? subStatusGold;
  final int? subStatusRoleBasedAcceptAll;
  final String? startDate;
  final String? endDate;
  final Map<String, Object?> raw;

  @override
  String toString() => _describe('ZBApiUsage', {
        'total': total,
        'statusValid': statusValid,
        'statusInvalid': statusInvalid,
        'statusCatchAll': statusCatchAll,
        'statusDoNotMail': statusDoNotMail,
        'statusSpamtrap': statusSpamtrap,
        'statusUnknown': statusUnknown,
        'subStatusToxic': subStatusToxic,
        'subStatusDisposable': subStatusDisposable,
        'subStatusRoleBased': subStatusRoleBased,
        'subStatusPossibleTrap': subStatusPossibleTrap,
        'subStatusGlobalSuppression': subStatusGlobalSuppression,
        'subStatusTimeoutExceeded': subStatusTimeoutExceeded,
        'subStatusMailServerTemporaryError': subStatusMailServerTemporaryError,
        'subStatusMailServerDidNotRespond': subStatusMailServerDidNotRespond,
        'subStatusGreylisted': subStatusGreylisted,
        'subStatusAntispamSystem': subStatusAntispamSystem,
        'subStatusDoesNotAcceptMail': subStatusDoesNotAcceptMail,
        'subStatusExceptionOccurred': subStatusExceptionOccurred,
        'subStatusFailedSyntaxCheck': subStatusFailedSyntaxCheck,
        'subStatusMailboxNotFound': subStatusMailboxNotFound,
        'subStatusUnroutableIpAddress': subStatusUnroutableIpAddress,
        'subStatusPossibleTypo': subStatusPossibleTypo,
        'subStatusNoDnsEntries': subStatusNoDnsEntries,
        'subStatusRoleBasedCatchAll': subStatusRoleBasedCatchAll,
        'subStatusMailboxQuotaExceeded': subStatusMailboxQuotaExceeded,
        'subStatusForcibleDisconnect': subStatusForcibleDisconnect,
        'subStatusFailedSmtpConnection': subStatusFailedSmtpConnection,
        'subStatusAcceptAll': subStatusAcceptAll,
        'subStatusMxForward': subStatusMxForward,
        'subStatusAlternate': subStatusAlternate,
        'subStatusAllowed': subStatusAllowed,
        'subStatusBlocked': subStatusBlocked,
        'subStatusGold': subStatusGold,
        'subStatusRoleBasedAcceptAll': subStatusRoleBasedAcceptAll,
        'startDate': startDate,
        'endDate': endDate,
      });
}

/// The `activity` answer.
class ZBActivity {
  ZBActivity.fromJson(Map<String, Object?> json)
      : found = _flag(json, 'found'),
        activeInDays = _text(json, 'active_in_days'),
        raw = _frozen(json);

  final bool? found;
  final String? activeInDays;
  final Map<String, Object?> raw;

  @override
  String toString() =>
      _describe('ZBActivity', {'found': found, 'activeInDays': activeInDays});
}

/// The real-time AI `scoring` answer.
class ZBScoreResult {
  ZBScoreResult.fromJson(Map<String, Object?> json)
      : email = _text(json, 'email'),
        score = _int(json, 'score'),
        raw = _frozen(json);

  final String? email;
  final int? score;
  final Map<String, Object?> raw;

  @override
  String toString() =>
      _describe('ZBScoreResult', {'email': email, 'score': score});
}

/// The answer of a bulk `sendfile` (validation, scoring, email finder, domain
/// search). A list of message strings is joined with "\n".
class ZBSendFileResult {
  ZBSendFileResult.fromJson(Map<String, Object?> json)
      : success = _flag(json, 'success'),
        message = _text(json, 'message'),
        fileName = _text(json, 'file_name'),
        fileId = _text(json, 'file_id'),
        raw = _frozen(json);

  final bool? success;
  final String? message;
  final String? fileName;
  final String? fileId;
  final Map<String, Object?> raw;

  @override
  String toString() => _describe('ZBSendFileResult', {
        'success': success,
        'message': message,
        'fileName': fileName,
        'fileId': fileId
      });
}

/// The answer of a bulk `filestatus`. [filePhase2Status] and [errorReason]
/// are validation-only fields.
class ZBFileStatus {
  ZBFileStatus.fromJson(Map<String, Object?> json)
      : success = _flag(json, 'success'),
        fileId = _text(json, 'file_id'),
        fileName = _text(json, 'file_name'),
        uploadDate = _text(json, 'upload_date'),
        fileStatus = _text(json, 'file_status'),
        filePhase2Status = _text(json, 'file_phase_2_status'),
        completePercentage = _text(json, 'complete_percentage'),
        errorReason = _text(json, 'error_reason'),
        returnUrl = _text(json, 'return_url'),
        message = _text(json, 'message'),
        raw = _frozen(json);

  final bool? success;
  final String? fileId;
  final String? fileName;
  final String? uploadDate;
  final String? fileStatus;
  final String? filePhase2Status;
  final String? completePercentage;
  final String? errorReason;
  final String? returnUrl;
  final String? message;
  final Map<String, Object?> raw;

  @override
  String toString() => _describe('ZBFileStatus', {
        'success': success,
        'fileId': fileId,
        'fileName': fileName,
        'uploadDate': uploadDate,
        'fileStatus': fileStatus,
        'filePhase2Status': filePhase2Status,
        'completePercentage': completePercentage,
        'errorReason': errorReason,
        'returnUrl': returnUrl,
        'message': message,
      });
}

/// The answer of a bulk `deletefile`.
class ZBDeleteFileResult {
  ZBDeleteFileResult.fromJson(Map<String, Object?> json)
      : success = _flag(json, 'success'),
        message = _text(json, 'message'),
        fileName = _text(json, 'file_name'),
        fileId = _text(json, 'file_id'),
        raw = _frozen(json);

  final bool? success;
  final String? message;
  final String? fileName;
  final String? fileId;
  final Map<String, Object?> raw;

  @override
  String toString() => _describe('ZBDeleteFileResult', {
        'success': success,
        'message': message,
        'fileName': fileName,
        'fileId': fileId
      });
}

/// The email finder answer (`guessformat` with a name).
class ZBFindEmailResult {
  ZBFindEmailResult.fromJson(Map<String, Object?> json)
      : email = _text(json, 'email'),
        emailConfidence = _text(json, 'email_confidence'),
        domain = _text(json, 'domain'),
        companyName = _text(json, 'company_name'),
        didYouMean = _text(json, 'did_you_mean'),
        failureReason = _text(json, 'failure_reason'),
        raw = _frozen(json);

  final String? email;
  final String? emailConfidence;
  final String? domain;
  final String? companyName;
  final String? didYouMean;
  final String? failureReason;
  final Map<String, Object?> raw;

  @override
  String toString() => _describe('ZBFindEmailResult', {
        'email': email,
        'emailConfidence': emailConfidence,
        'domain': domain,
        'companyName': companyName,
        'didYouMean': didYouMean,
        'failureReason': failureReason,
      });
}

/// The domain search answer (`guessformat` without a name).
class ZBDomainFormatResult {
  ZBDomainFormatResult.fromJson(Map<String, Object?> json)
      : domain = _text(json, 'domain'),
        companyName = _text(json, 'company_name'),
        format = _text(json, 'format'),
        confidence = _text(json, 'confidence'),
        didYouMean = _text(json, 'did_you_mean'),
        failureReason = _text(json, 'failure_reason'),
        otherDomainFormats = List.unmodifiable(
            (json['other_domain_formats'] as List?) ?? const []),
        raw = _frozen(json);

  final String? domain;
  final String? companyName;
  final String? format;
  final String? confidence;
  final String? didYouMean;
  final String? failureReason;

  /// Other formats, as received (`{"format": ..., "confidence": ...}`).
  final List<Object?> otherDomainFormats;
  final Map<String, Object?> raw;

  @override
  String toString() => _describe('ZBDomainFormatResult', {
        'domain': domain,
        'companyName': companyName,
        'format': format,
        'confidence': confidence,
        'didYouMean': didYouMean,
        'failureReason': failureReason,
        'otherDomainFormats': otherDomainFormats,
      });
}

/// The answer of a list evaluator submission or of `sendEvaluatedFile`.
class ZBListEvaluatorSubmitResult {
  ZBListEvaluatorSubmitResult.fromJson(Map<String, Object?> json)
      : fileId = _text(json, 'file_id'),
        message = _text(json, 'message'),
        success = _flag(json, 'success'),
        raw = _frozen(json);

  final String? fileId;
  final String? message;
  final bool? success;
  final Map<String, Object?> raw;

  @override
  String toString() => _describe('ZBListEvaluatorSubmitResult',
      {'fileId': fileId, 'message': message, 'success': success});
}

/// One allow or block filter.
class ZBFilter {
  ZBFilter.fromJson(Map<String, Object?> json)
      : rule = _text(json, 'rule'),
        target = _text(json, 'target'),
        value = _text(json, 'value');

  final String? rule;
  final String? target;
  final String? value;

  @override
  String toString() =>
      _describe('ZBFilter', {'rule': rule, 'target': target, 'value': value});
}

/// The `filters/list` answer: the filters, or the API's message when it
/// answered with one instead of a list.
class ZBFilterList {
  ZBFilterList(this.filters, this.message);

  final List<ZBFilter> filters;
  final String? message;

  @override
  String toString() =>
      _describe('ZBFilterList', {'filters': filters, 'message': message});
}

/// One file in your Amazon S3 bucket (`listS3files`).
class ZBS3File {
  ZBS3File.fromJson(Map<String, Object?> json)
      : name = _text(json, 'name'),
        size = _int(json, 'size'),
        lastModified = _text(json, 'last_modified'),
        raw = _frozen(json);

  final String? name;
  final int? size;
  final String? lastModified;
  final Map<String, Object?> raw;

  @override
  String toString() => _describe(
      'ZBS3File', {'name': name, 'size': size, 'lastModified': lastModified});
}

/// The answer of an Amazon S3 or SFTP file job.
class ZBFileJobResult {
  ZBFileJobResult.fromJson(Map<String, Object?> json)
      : success = _flag(json, 'success'),
        message = _text(json, 'message'),
        fileId = _text(json, 'file_id'),
        exportPath = _text(json, 'export_path'),
        raw = _frozen(json);

  final bool? success;
  final String? message;
  final String? fileId;
  final String? exportPath;
  final Map<String, Object?> raw;

  @override
  String toString() => _describe('ZBFileJobResult', {
        'success': success,
        'message': message,
        'fileId': fileId,
        'exportPath': exportPath
      });
}
