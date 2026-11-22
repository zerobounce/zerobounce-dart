/// The JSON type of every field the typed calls read. A field that arrives
/// with another JSON type makes the answer a `ZBException` with status 200,
/// never a value coerced or defaulted to the declared type. `null` is accepted
/// for every field except a required one.
///
/// A type is `string`, `number`, `integer` (a JSON integer within ±2^53-1),
/// `integerString` (an integer sent as a JSON string such as "-1", or as a
/// JSON integer), `boolean`, `array`, `object`, `any`, the name of another
/// entry, or a name or primitive followed by `[]`. A list is a union.
library;

const Map<String, Map<String, Object>> responseFields = {
  'GetCreditsResponse': {'Credits': 'integerString'},
  'EmailValidationResult': {
    'address': 'string',
    'status': 'string',
    'sub_status': 'string',
    'free_email': 'boolean',
    'did_you_mean': 'string',
    'account': 'string',
    'domain': 'string',
    'domain_age_days': 'string',
    'active_in_days': 'string',
    'active_first_seen': 'string',
    'smtp_provider': 'string',
    'catchall_domain': 'boolean',
    'mx_found': ['string', 'boolean'],
    'mx_record': 'string',
    'firstname': 'string',
    'lastname': 'string',
    'gender': 'string',
    'country': 'string',
    'region': 'string',
    'city': 'string',
    'zipcode': 'string',
    'processed_at': 'string',
    'domain_website_exists': 'string',
    'domain_registrant_company_name': 'string',
    'message': 'string',
    'Message': 'string',
  },
  'ValidateBatchResponse': {
    'email_batch': 'EmailValidationResult[]',
    'errors': 'array',
  },
  'ApiUsageResponse': {
    'total': 'integer',
    'status_valid': 'integer',
    'status_invalid': 'integer',
    'status_catch_all': 'integer',
    'status_do_not_mail': 'integer',
    'status_spamtrap': 'integer',
    'status_unknown': 'integer',
    'sub_status_toxic': 'integer',
    'sub_status_disposable': 'integer',
    'sub_status_role_based': 'integer',
    'sub_status_possible_trap': 'integer',
    'sub_status_global_suppression': 'integer',
    'sub_status_timeout_exceeded': 'integer',
    'sub_status_mail_server_temporary_error': 'integer',
    'sub_status_mail_server_did_not_respond': 'integer',
    'sub_status_greylisted': 'integer',
    'sub_status_antispam_system': 'integer',
    'sub_status_does_not_accept_mail': 'integer',
    'sub_status_exception_occurred': 'integer',
    'sub_status_failed_syntax_check': 'integer',
    'sub_status_mailbox_not_found': 'integer',
    'sub_status_unroutable_ip_address': 'integer',
    'sub_status_possible_typo': 'integer',
    'sub_status_no_dns_entries': 'integer',
    'sub_status_role_based_catch_all': 'integer',
    'sub_status_mailbox_quota_exceeded': 'integer',
    'sub_status_forcible_disconnect': 'integer',
    'sub_status_failed_smtp_connection': 'integer',
    'sub_status_accept_all': 'integer',
    'sub_status_mx_forward': 'integer',
    'sub_status_alternate': 'integer',
    'sub_status_allowed': 'integer',
    'sub_status_blocked': 'integer',
    'sub_status_gold': 'integer',
    'sub_status_role_based_accept_all': 'integer',
    'start_date': 'string',
    'end_date': 'string',
  },
  'EmailActivityResponse': {'found': 'boolean', 'active_in_days': 'string'},
  'EmailScoringResult': {'email': 'string', 'score': 'integer'},
  'BulkSendFileResponse': {
    'success': 'boolean',
    'message': 'string',
    'file_name': 'string',
    'file_id': 'string',
  },
  'ValidationFileStatusResponse': {
    'success': 'boolean',
    'file_id': 'string',
    'file_name': 'string',
    'upload_date': 'string',
    'file_status': 'string',
    'file_phase_2_status': 'string',
    'complete_percentage': 'string',
    'error_reason': 'string',
    'return_url': 'string',
    'message': 'string',
  },
  'ScoringFileStatusResponse': {
    'success': 'boolean',
    'file_id': 'string',
    'file_name': 'string',
    'upload_date': 'string',
    'file_status': 'string',
    'complete_percentage': 'string',
    'return_url': 'string',
    'message': 'string',
  },
  'BulkFileDeletedResponse': {
    'success': 'boolean',
    'message': 'string',
    'file_name': 'string',
    'file_id': 'string',
  },
  'EmailFinderResponse': {
    'email': 'string',
    'email_confidence': 'string',
    'domain': 'string',
    'company_name': 'string',
    'did_you_mean': 'string',
    'failure_reason': 'string',
  },
  'DomainFormatResponse': {
    'domain': 'string',
    'company_name': 'string',
    'format': 'string',
    'confidence': 'string',
    'did_you_mean': 'string',
    'failure_reason': 'string',
    'other_domain_formats': 'array',
  },
  'ListEvaluatorSubmitResponse': {
    'file_id': 'string',
    'message': 'string',
    'success': 'boolean',
  },
  'ListEvaluatorResultResponse': {
    'file_status': 'string',
    'success': 'boolean',
    'message': 'string',
  },
  'FilterListItem': {'rule': 'string', 'target': 'string', 'value': 'string'},
  'FilterMessageResponse': {'Message': 'string', 'Error': 'string'},
  'S3ListFileEntry': {
    'name': 'string',
    'size': 'integer',
    'last_modified': 'string',
  },
  'S3BulkJobResponse': {
    'success': 'boolean',
    'message': 'string',
    'file_id': 'string',
    'export_path': 'string',
  },
  'InboxPlacementProvider': {
    'id': 'number',
    'name': 'string',
    'location': 'string',
    'seedCount': 'number',
    'seedIds': 'number[]',
  },
  'InboxPlacementProviderGroup': {'items': 'InboxPlacementProvider[]'},
  'InboxPlacementProvidersResponse': {
    'emailProviders': 'InboxPlacementProviderGroup',
    'gatewayProviders': 'InboxPlacementProviderGroup',
  },
  'InboxPlacementTestCreated': {
    'id': 'string',
    'identifier': 'string',
    'testType': 'string',
    'emailAddressList': 'string[]',
  },
  'InboxPlacementCounts': {
    'inboxCount': 'number',
    'spamCount': 'number',
    'otherCount': 'number',
    'notDeliveredCount': 'number',
    'pendingCount': 'number',
    'percentages': 'any',
  },
  'InboxPlacementTestResult': {
    'inboxCount': 'number',
    'spamCount': 'number',
    'otherCount': 'number',
    'notDeliveredCount': 'number',
    'pendingCount': 'number',
    'percentages': 'any',
    'id': 'string',
    'testName': 'string',
    'testType': 'string',
    'identifier': 'string',
    'status': 'string',
    'counts': 'InboxPlacementCounts',
    'results': 'any',
    'seeds': 'array',
  },
  'InboxPlacementTestDeleted': {'id': 'string', 'status': 'string'},
  'InboxPlacementWebhookResponse': {'webhookUrl': 'string'},
};

/// Fields a call cannot answer without: present and not null. Validate's
/// greylist answer (only a Message string) is a result without them; a
/// validatebatch row is not.
const Map<String, List<String>> requiredFields = {
  'GetCreditsResponse': ['Credits'],
  'EmailValidationResult': ['address', 'status'],
};

const unexpectedFieldTypeMessage =
    'ZeroBounce returned a response field of an unexpected type for this call';

/// The file-job answers whose `message` is one string; a list of strings there
/// is joined with "\n".
const fileJobMessageResults = {
  'BulkSendFileResponse',
  'BulkFileDeletedResponse',
  'ValidationFileStatusResponse',
  'ScoringFileStatusResponse',
};

const _maxSafeInteger = 9007199254740991;
final _integerText = RegExp(r'^-?[0-9]+$');

List<String> _types(Object type) =>
    type is List ? [for (final t in type) t as String] : [type as String];

bool _isGreylistMessage(Map<Object?, Object?> object) =>
    object['address'] == null &&
    object['status'] == null &&
    ['Message', 'message'].any((key) {
      final value = object[key];
      return value is String && value.trim().isNotEmpty;
    });

bool _fits(Object? value, String type) {
  switch (type) {
    case 'any':
      return true;
    case 'string':
      return value is String;
    case 'integerString':
      if (value is String) {
        return _integerText.hasMatch(value) && int.tryParse(value) != null;
      }
      return value is int && value.abs() <= _maxSafeInteger;
    case 'number':
      return value is num;
    case 'integer':
      return value is int && value.abs() <= _maxSafeInteger;
    case 'boolean':
      return value is bool;
    case 'object':
      return value is Map;
    case 'array':
      return value is List;
  }
  return false;
}

String? _mismatch(Object? value, List<String> types, String path) {
  for (final type in types) {
    if (_fits(value, type)) return null;
  }
  if (value is List) {
    final elementTypes = [
      for (final t in types)
        if (t.endsWith('[]')) t.substring(0, t.length - 2),
    ];
    if (elementTypes.isEmpty) return path;
    for (var i = 0; i < value.length; i++) {
      final found = _mismatch(value[i], elementTypes, '$path[$i]');
      if (found != null) return found;
    }
    return null;
  }
  final names = types.where(responseFields.containsKey).toList();
  if (value is! Map || names.isEmpty) return path;
  final prefix = path.isEmpty ? '' : '$path.';
  final greylist = path.isEmpty &&
      names.contains('EmailValidationResult') &&
      _isGreylistMessage(value);
  if (!greylist) {
    for (final name in names) {
      for (final key in requiredFields[name] ?? const <String>[]) {
        if (value[key] == null) return '$prefix$key';
      }
    }
  }
  final fieldTypes = <String, List<String>>{};
  for (final name in names) {
    responseFields[name]!.forEach((key, type) {
      (fieldTypes[key] ??= []).addAll(_types(type));
    });
  }
  for (final entry in fieldTypes.entries) {
    final field = value[entry.key];
    if (field == null) continue;
    final found = _mismatch(field, entry.value, '$prefix${entry.key}');
    if (found != null) return found;
  }
  return null;
}

/// The path of the first field of [parsed] that does not have the type the
/// result [types] declare, "" when the whole value is the wrong kind, or null
/// when it all fits.
String? responseFieldMismatch(Object? parsed, List<String> types) =>
    _mismatch(parsed, types, '');

/// The declared field names of the result [types].
Set<String> declaredFieldNames(List<String> types) => {
      for (final name in types) ...?responseFields[name]?.keys,
    };
