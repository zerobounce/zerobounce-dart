import 'dart:convert';

import 'package:zerobounce_sdk/zerobounce_sdk.dart';

/// One public request method, called with valid arguments, with the request
/// it must send and an answer it must accept.
class ApiCall {
  const ApiCall(this.name, this.method, this.url, this.invoke, this.ok,
      {this.download = false});

  /// The method's name on [ZeroBounceSDK].
  final String name;
  final String method;

  /// The request URL without its query string.
  final String url;
  final Future<Object?> Function(ZeroBounceSDK sdk) invoke;

  /// A success answer (a JSON value, or CSV text for a download).
  final Object? ok;
  final bool download;
}

final csv = utf8.encode('email\nsomeone@example.com\n');

const _api = 'https://api.zerobounce.net/v2';
const _bulk = 'https://bulkapi.zerobounce.net/v2';
const _root = 'https://bulkapi.zerobounce.net';
const _ipt = 'https://bulkapi.zerobounce.net/api/ipt';
const _finder = 'https://bulkapi.zerobounce.net/email-finder';
const _domain = 'https://bulkapi.zerobounce.net/domain-search';
const _evaluator = 'https://bulkapi.zerobounce.net/v2/listevaluator';

const _sent = {
  'success': true,
  'message': 'File Accepted',
  'file_name': 'a.csv',
  'file_id': 'f1'
};
const _status = {'success': true, 'file_id': 'f1', 'file_status': 'Complete'};
const _deleted = {
  'success': true,
  'message': 'File Deleted',
  'file_name': 'a.csv',
  'file_id': 'f1'
};
const _job = {'success': true, 'message': 'Job accepted'};
const _validated = {'address': 'someone@example.com', 'status': 'valid'};

/// Every public request method of [ZeroBounceSDK]. `security_test.dart`
/// fails when a public method is missing here, so sweeps over this list are
/// complete by construction.
final apiCalls = <ApiCall>[
  ApiCall('getCredits', 'GET', '$_api/getcredits', (z) => z.getCredits(),
      {'Credits': '42'}),
  ApiCall(
      'getApiUsage',
      'GET',
      '$_api/getapiusage',
      (z) => z.getApiUsage(DateTime(2026, 1, 2), DateTime(2026, 2, 3)),
      {'total': 3}),
  ApiCall('validateEmail', 'GET', '$_api/validate',
      (z) => z.validateEmail('someone@example.com'), _validated),
  ApiCall('validateBatch', 'POST', '$_api/validatebatch',
      (z) => z.validateBatch([const ZBBatchEmail('someone@example.com')]), {
    'email_batch': [_validated],
    'errors': <Object>[]
  }),
  ApiCall(
      'getEmailActivity',
      'GET',
      '$_api/activity',
      (z) => z.getEmailActivity('someone@example.com'),
      {'found': true, 'active_in_days': '30'}),
  ApiCall(
      'scoreEmail',
      'GET',
      '$_api/scoring',
      (z) => z.scoreEmail('someone@example.com'),
      {'email': 'someone@example.com', 'score': 9}),
  ApiCall(
      'sendFile',
      'POST',
      '$_bulk/sendfile',
      (z) => z.sendFile(
          file: csv,
          fileName: 'a.csv',
          emailAddressColumn: 1,
          hasHeaderRow: true),
      _sent),
  ApiCall(
      'sendScoringFile',
      'POST',
      '$_bulk/scoring/sendfile',
      (z) => z.sendScoringFile(
          file: csv,
          fileName: 'a.csv',
          emailAddressColumn: 1,
          hasHeaderRow: true),
      _sent),
  ApiCall('getFileStatus', 'GET', '$_bulk/filestatus',
      (z) => z.getFileStatus('f1'), _status),
  ApiCall('getScoringFileStatus', 'GET', '$_bulk/scoring/filestatus',
      (z) => z.getScoringFileStatus('f1'), _status),
  ApiCall('getFile', 'GET', '$_bulk/getfile', (z) => z.getFile('f1'),
      'email,status\n',
      download: true),
  ApiCall('getScoringFile', 'GET', '$_bulk/scoring/getfile',
      (z) => z.getScoringFile('f1'), 'email,score\n',
      download: true),
  ApiCall('deleteFile', 'GET', '$_bulk/deletefile', (z) => z.deleteFile('f1'),
      _deleted),
  ApiCall('deleteScoringFile', 'GET', '$_bulk/scoring/deletefile',
      (z) => z.deleteScoringFile('f1'), _deleted),
  ApiCall(
      'sendEmailFinderFile',
      'POST',
      '$_finder/sendfile',
      (z) => z.sendEmailFinderFile(
          file: csv,
          fileName: 'a.csv',
          domainColumn: 1,
          firstNameColumn: 2,
          hasHeaderRow: true),
      _sent),
  ApiCall('getEmailFinderFileStatus', 'GET', '$_finder/filestatus',
      (z) => z.getEmailFinderFileStatus('f1'), _status),
  ApiCall('getEmailFinderFile', 'GET', '$_finder/getfile',
      (z) => z.getEmailFinderFile('f1'), 'domain,email\n',
      download: true),
  ApiCall('deleteEmailFinderFile', 'GET', '$_finder/deletefile',
      (z) => z.deleteEmailFinderFile('f1'), _deleted),
  ApiCall(
      'sendDomainSearchFile',
      'POST',
      '$_domain/sendfile',
      (z) => z.sendDomainSearchFile(
          file: csv, fileName: 'a.csv', domainColumn: 1, hasHeaderRow: false),
      _sent),
  ApiCall('getDomainSearchFileStatus', 'GET', '$_domain/filestatus',
      (z) => z.getDomainSearchFileStatus('f1'), _status),
  ApiCall('getDomainSearchFile', 'GET', '$_domain/getfile',
      (z) => z.getDomainSearchFile('f1'), 'domain,format\n',
      download: true),
  ApiCall('deleteDomainSearchFile', 'GET', '$_domain/deletefile',
      (z) => z.deleteDomainSearchFile('f1'), _deleted),
  ApiCall(
      'sendListEvaluatorFile',
      'POST',
      '$_evaluator/',
      (z) => z.sendListEvaluatorFile(
          file: csv, fileName: 'a.csv', emailAddressColumn: 1),
      {'success': true, 'file_id': 'e1', 'message': 'ok'}),
  ApiCall('getListEvaluatorResult', 'GET', '$_evaluator/e1/',
      (z) => z.getListEvaluatorResult('e1'), {'file_status': 'Complete'}),
  ApiCall('sendEvaluatedFile', 'POST', '$_bulk/send-evaluated-file/',
      (z) => z.sendEvaluatedFile('e1'), {'success': true, 'file_id': 'f2'}),
  ApiCall(
      'addFilter',
      'POST',
      '$_api/filters/add',
      (z) => z.addFilter(
          rule: ZBFilterRule.allow,
          target: ZBFilterTarget.domain,
          value: 'example.com'),
      {'Message': 'Filter has been added.'}),
  ApiCall(
      'deleteFilter',
      'POST',
      '$_api/filters/delete',
      (z) => z.deleteFilter(
          rule: ZBFilterRule.block,
          target: ZBFilterTarget.email,
          value: 'a@example.com'),
      {'Message': 'Filter has been deleted.'}),
  ApiCall('listFilters', 'GET', '$_api/filters/list', (z) => z.listFilters(), [
    {'rule': 'allow', 'target': 'domain', 'value': 'example.com'},
  ]),
  ApiCall('listS3Files', 'GET', '$_root/listS3files', (z) => z.listS3Files(), [
    {'name': 'in/a.csv', 'size': 12, 'last_modified': '2026-01-01T00:00:00Z'},
  ]),
  for (final (name, path) in [
    ('validateS3File', 'validateS3file'),
    ('scoreS3File', 'scoreS3file'),
    ('emailFinderS3File', 'emailFinderS3file'),
    ('domainSearchS3File', 'domainSearchS3file'),
    ('validateSftpFile', 'validateSFTPfile'),
    ('scoreSftpFile', 'scoreSFTPfile'),
    ('emailFinderSftpFile', 'emailFinderSFTPfile'),
    ('domainSearchSftpFile', 'domainSearchSFTPfile'),
  ])
    ApiCall(name, 'POST', '$_root/$path', (z) => fileJob(z, name), _job),
  ApiCall('exportS3File', 'POST', '$_root/exportS3file',
      (z) => z.exportS3File(fileId: 'f1'), _job),
  ApiCall('exportSftpFile', 'POST', '$_root/exportSFTPfile',
      (z) => z.exportSftpFile(fileId: 'f1'), _job),
  ApiCall(
      'findEmailByDomain',
      'GET',
      '$_api/guessformat',
      (z) => z.findEmailByDomain(domain: 'example.com', firstName: 'Ann'),
      {'email': 'ann@example.com'}),
  ApiCall(
      'findEmailByCompanyName',
      'GET',
      '$_api/guessformat',
      (z) => z.findEmailByCompanyName(companyName: 'Example', firstName: 'Ann'),
      {'email': 'ann@example.com'}),
  ApiCall(
      'findEmailFormatByDomain',
      'GET',
      '$_api/guessformat',
      (z) => z.findEmailFormatByDomain('example.com'),
      {'domain': 'example.com', 'format': 'first'}),
  ApiCall('findEmailFormatByCompanyName', 'GET', '$_api/guessformat',
      (z) => z.findEmailFormatByCompanyName('Example'), {'format': 'first'}),
  ApiCall('getInboxPlacementProviders', 'GET', '$_ipt/providers',
      (z) => z.getInboxPlacementProviders(), {
    'emailProviders': {'items': <Object>[]}
  }),
  ApiCall('getInboxPlacementTestTypes', 'GET', '$_ipt/test-types',
      (z) => z.getInboxPlacementTestTypes(), [
    {'id': 1, 'name': 'Email'},
  ]),
  ApiCall(
      'createInboxPlacementTest',
      'POST',
      '$_ipt/test',
      (z) => z.createInboxPlacementTest(name: 'launch'),
      {'id': 't1', 'identifier': 'zb-1'}),
  ApiCall(
      'getInboxPlacementTest',
      'GET',
      '$_ipt/test/t1',
      (z) => z.getInboxPlacementTest('t1'),
      {'id': 't1', 'status': 'Completed'}),
  ApiCall('listInboxPlacementTests', 'GET', '$_ipt/tests',
      (z) => z.listInboxPlacementTests(), {'results': <Object>[]}),
  ApiCall(
      'deleteInboxPlacementTest',
      'DELETE',
      '$_ipt/test/t1',
      (z) => z.deleteInboxPlacementTest('t1'),
      {'id': 't1', 'status': 'Deleted'}),
  ApiCall(
      'getInboxPlacementWebhook',
      'GET',
      '$_ipt/webhook',
      (z) => z.getInboxPlacementWebhook(),
      {'webhookUrl': 'https://example.com/hook'}),
  ApiCall(
      'setInboxPlacementWebhook',
      'PUT',
      '$_ipt/webhook',
      (z) => z.setInboxPlacementWebhook('https://example.com/hook'),
      {'webhookUrl': 'https://example.com/hook'}),
];

/// Calls one of the eight S3 / SFTP file jobs by name with valid arguments.
Future<ZBFileJobResult> fileJob(ZeroBounceSDK z, String name,
    {String fileName = 'in/a.csv',
    bool hasHeaderRow = true,
    String returnUrl = 'https://example.com/done',
    bool? removeDuplicates}) {
  final job = switch (name) {
    'validateS3File' => z.validateS3File,
    'scoreS3File' => z.scoreS3File,
    'emailFinderS3File' => z.emailFinderS3File,
    'domainSearchS3File' => z.domainSearchS3File,
    'validateSftpFile' => z.validateSftpFile,
    'scoreSftpFile' => z.scoreSftpFile,
    'emailFinderSftpFile' => z.emailFinderSftpFile,
    'domainSearchSftpFile' => z.domainSearchSftpFile,
    _ => throw ArgumentError(name),
  };
  return job(
      fileName: fileName,
      hasHeaderRow: hasHeaderRow,
      returnUrl: returnUrl,
      removeDuplicates: removeDuplicates);
}
