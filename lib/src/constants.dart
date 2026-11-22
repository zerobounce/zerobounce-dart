/// Base URLs of the ZeroBounce APIs.
///
/// The main API has a default, a US and an EU host. ZeroBounce documents no
/// regional host for the bulk, list evaluator, Inbox Placement Tester, bulk
/// email finder or bulk domain search APIs, so those always default to
/// `bulkapi.zerobounce.net`, whichever main host is chosen.
abstract final class ZBApiUrl {
  /// The main API (`https://api.zerobounce.net/v2`).
  static const String defaultUrl = 'https://api.zerobounce.net/v2';

  /// The main API, US host.
  static const String usa = 'https://api-us.zerobounce.net/v2';

  /// The main API, EU host.
  static const String eu = 'https://api-eu.zerobounce.net/v2';

  /// Bulk validation and scoring files (`/sendfile`, `/scoring/...`).
  static const String bulk = 'https://bulkapi.zerobounce.net/v2';

  /// The bulk host root: Amazon S3 and SFTP file jobs.
  static const String bulkRoot = 'https://bulkapi.zerobounce.net';

  /// The list evaluator API.
  static const String listEvaluator =
      'https://bulkapi.zerobounce.net/v2/listevaluator';

  /// The Inbox Placement Tester API.
  static const String inboxPlacement = 'https://bulkapi.zerobounce.net/api/ipt';

  /// The bulk email finder API.
  static const String emailFinder =
      'https://bulkapi.zerobounce.net/email-finder';

  /// The bulk domain search API.
  static const String domainSearch =
      'https://bulkapi.zerobounce.net/domain-search';
}

/// The documented values of a validation `status`.
///
/// The API may add values; an unknown one is kept as the string it sent, so
/// compare against these constants rather than switching exhaustively.
abstract final class ZBValidateStatus {
  static const String valid = 'valid';
  static const String invalid = 'invalid';
  static const String catchAll = 'catch-all';
  static const String unknown = 'unknown';
  static const String spamtrap = 'spamtrap';
  static const String abuse = 'abuse';
  static const String doNotMail = 'do_not_mail';
}

/// The documented values of a validation `sub_status`.
///
/// The API may add values; an unknown one is kept as the string it sent.
abstract final class ZBValidateSubStatus {
  static const String none = '';
  static const String antispamSystem = 'antispam_system';
  static const String greylisted = 'greylisted';
  static const String mailServerTemporaryError = 'mail_server_temporary_error';
  static const String forcibleDisconnect = 'forcible_disconnect';
  static const String mailServerDidNotRespond = 'mail_server_did_not_respond';
  static const String timeoutExceeded = 'timeout_exceeded';
  static const String failedSmtpConnection = 'failed_smtp_connection';
  static const String mailboxQuotaExceeded = 'mailbox_quota_exceeded';
  static const String exceptionOccurred = 'exception_occurred';
  static const String possibleTrap = 'possible_trap';
  static const String roleBased = 'role_based';
  static const String globalSuppression = 'global_suppression';
  static const String mailboxNotFound = 'mailbox_not_found';
  static const String noDnsEntries = 'no_dns_entries';
  static const String failedSyntaxCheck = 'failed_syntax_check';
  static const String possibleTypo = 'possible_typo';
  static const String unroutableIpAddress = 'unroutable_ip_address';
  static const String leadingPeriodRemoved = 'leading_period_removed';
  static const String doesNotAcceptMail = 'does_not_accept_mail';
  static const String aliasAddress = 'alias_address';
  static const String roleBasedCatchAll = 'role_based_catch_all';
  static const String disposable = 'disposable';
  static const String toxic = 'toxic';
  static const String alternate = 'alternate';
  static const String mxForward = 'mx_forward';
  static const String blocked = 'blocked';
  static const String allowed = 'allowed';
  static const String acceptAll = 'accept_all';
  static const String roleBasedAcceptAll = 'role_based_accept_all';
  static const String gold = 'gold';
  static const String aiAgentMailbox = 'ai_agent_mailbox';
}

/// The `download_type` of a bulk validation or scoring `getfile`.
enum ZBDownloadType {
  phase1('phase_1'),
  phase2('phase_2'),
  combined('combined');

  const ZBDownloadType(this.value);

  /// The value sent to the API.
  final String value;
}

/// The `rule` of an allow or block filter.
enum ZBFilterRule {
  allow('allow'),
  block('block');

  const ZBFilterRule(this.value);

  /// The value sent to the API.
  final String value;
}

/// The `target` of an allow or block filter.
enum ZBFilterTarget {
  email('email'),
  domain('domain'),
  mx('mx'),
  tld('tld');

  const ZBFilterTarget(this.value);

  /// The value sent to the API.
  final String value;
}

/// The `status` filter of `ZeroBounceSDK.listInboxPlacementTests`.
enum ZBInboxPlacementTestStatus {
  running('running'),
  finished('finished');

  const ZBInboxPlacementTestStatus(this.value);

  /// The value sent to the API.
  final String value;
}
