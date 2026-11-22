import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:zerobounce_sdk/zerobounce_sdk.dart';

import 'support/calls.dart';
import 'support/fake.dart';
import 'support/network_guard.dart';

const validated = {'address': 'someone@example.com', 'status': 'valid'};
const sent = {'success': true, 'file_id': 'f1'};
const job = {'success': true, 'message': 'ok'};

void main() {
  installNetworkGuard();

  group('validateEmail', () {
    test('sends only the email and the key when nothing else is set', () async {
      final (sdk, fake) = sdkAnswering(validated);
      await sdk.validateEmail('someone@example.com');
      expect(queryOf(fake.last),
          {'api_key': testKey, 'email': 'someone@example.com'});
    });

    test('sends every option that is set, false included', () async {
      final (sdk, fake) = sdkAnswering(validated);
      await sdk.validateEmail('someone@example.com',
          ipAddress: '1.2.3.4',
          timeout: 10,
          activityData: false,
          verifyPlus: true,
          domainInfo: false,
          greylistProcessing: true,
          callbackUrl: 'https://example.com/cb');
      expect(queryOf(fake.last), {
        'api_key': testKey,
        'email': 'someone@example.com',
        'ip_address': '1.2.3.4',
        'timeout': '10',
        'activity_data': 'false',
        'verify_plus': 'true',
        'domain_info': 'false',
        'greylist_processing': 'true',
        'callback_url': 'https://example.com/cb',
      });
    });

    test('sends a form-encoded POST when asked', () async {
      final (sdk, fake) = sdkAnswering(validated);
      await sdk.validateEmail('a b@example.com',
          usePost: true, verifyPlus: false);
      expect(fake.last.method, 'POST');
      expect(fake.last.url.query, isEmpty);
      expect(fake.last.headers['content-type'],
          startsWith('application/x-www-form-urlencoded'));
      expect(formOf(fake.last), {
        'api_key': testKey,
        'email': 'a b@example.com',
        'verify_plus': 'false'
      });
    });

    test('checks its arguments before sending', () async {
      final (sdk, fake) = sdkAnswering(validated);
      await expectLater(sdk.validateEmail(' '),
          throwsZB(0, contains('Email parameter is missing')));
      await expectLater(sdk.validateEmail('a@b.c', timeout: 2),
          throwsZB(0, contains('timeout')));
      await expectLater(sdk.validateEmail('a@b.c', timeout: 61),
          throwsZB(0, contains('timeout')));
      await expectLater(
          sdk.validateEmail('a@b.c', callbackUrl: 'https://x.example'),
          throwsZB(0, contains('greylistProcessing')));
      await expectLater(
          sdk.validateEmail('a@b.c',
              greylistProcessing: true, callbackUrl: ' '),
          throwsZB(0, contains('callbackUrl')));
      expect(fake.requests, isEmpty);
    });
  });

  group('validateBatch', () {
    test('sends a JSON body with only the fields that are set', () async {
      final (sdk, fake) = sdkAnswering({
        'email_batch': [validated],
        'errors': <Object>[]
      });
      await sdk.validateBatch([
        const ZBBatchEmail('a@example.com', ipAddress: '1.1.1.1'),
        const ZBBatchEmail('b@example.com'),
      ]);
      expect(fake.last.headers['content-type'], startsWith('application/json'));
      expect(jsonOf(fake.last), {
        'api_key': testKey,
        'email_batch': [
          {'email_address': 'a@example.com', 'ip_address': '1.1.1.1'},
          {'email_address': 'b@example.com'},
        ],
      });
    });

    test('sends timeout as a JSON string and the flags as JSON booleans',
        () async {
      final (sdk, fake) = sdkAnswering({
        'email_batch': [validated],
        'errors': <Object>[]
      });
      await sdk.validateBatch([const ZBBatchEmail('a@example.com')],
          timeout: 30, activityData: false, verifyPlus: true);
      final body = jsonOf(fake.last)! as Map;
      expect(body['timeout'], '30');
      expect(body['activity_data'], false);
      expect(body['verify_plus'], true);
    });

    test('checks its arguments before sending', () async {
      final (sdk, fake) = sdkAnswering({});
      await expectLater(
          sdk.validateBatch([]), throwsZB(0, contains('Email list')));
      await expectLater(sdk.validateBatch([const ZBBatchEmail(' ')]),
          throwsZB(0, contains('email_address')));
      await expectLater(
          sdk.validateBatch([const ZBBatchEmail('a@b.c')], timeout: 9),
          throwsZB(0, contains('timeout')));
      await expectLater(
          sdk.validateBatch([const ZBBatchEmail('a@b.c')], timeout: 121),
          throwsZB(0, contains('timeout')));
      expect(fake.requests, isEmpty);
    });
  });

  test('getApiUsage sends the dates as YYYY-MM-DD', () async {
    final (sdk, fake) = sdkAnswering({'total': 1});
    await sdk.getApiUsage(
        DateTime(2026, 3, 4, 23, 59), DateTime.utc(999, 12, 31));
    expect(queryOf(fake.last), {
      'api_key': testKey,
      'start_date': '2026-03-04',
      'end_date': '0999-12-31'
    });
  });

  test('scoreEmail sends GET by default and a form POST when asked', () async {
    final (sdk, fake) = sdkAnswering({'email': 'a@b.c', 'score': 5});
    await sdk.scoreEmail('a@b.c');
    expect(queryOf(fake.last), {'api_key': testKey, 'email': 'a@b.c'});
    await sdk.scoreEmail('a@b.c', usePost: true);
    expect(formOf(fake.last), {'api_key': testKey, 'email': 'a@b.c'});
  });

  group('bulk files', () {
    test(
        'sendFile sends the required fields and only the optional ones that are set',
        () async {
      final (sdk, fake) = sdkAnswering(sent);
      await sdk.sendFile(
          file: csv,
          fileName: 'list.csv',
          emailAddressColumn: 1,
          hasHeaderRow: false);
      final request = fake.last as http.MultipartRequest;
      expect(request.fields, {
        'email_address_column': '1',
        'has_header_row': 'false',
        'api_key': testKey
      });
      expect(request.files.single.field, 'file');
      expect(request.files.single.filename, 'list.csv');
      expect(request.files.single.length, csv.length);
    });

    test('sendFile sends every optional field that is set', () async {
      final (sdk, fake) = sdkAnswering(sent);
      await sdk.sendFile(
          file: csv,
          fileName: 'list.csv',
          emailAddressColumn: 3,
          hasHeaderRow: true,
          returnUrl: 'https://example.com/done',
          firstNameColumn: 1,
          lastNameColumn: 2,
          genderColumn: 4,
          ipAddressColumn: 5,
          removeDuplicate: false,
          allowPhase2: true);
      expect(multipartOf(fake.last), {
        'email_address_column': '3',
        'has_header_row': 'true',
        'return_url': 'https://example.com/done',
        'first_name_column': '1',
        'last_name_column': '2',
        'gender_column': '4',
        'ip_address_column': '5',
        'remove_duplicate': 'false',
        'allow_phase_2': 'true',
        'api_key': testKey,
      });
    });

    test('sendScoringFile never sends allow_phase_2', () async {
      final (sdk, fake) = sdkAnswering(sent);
      await sdk.sendScoringFile(
          file: csv,
          fileName: 'a.csv',
          emailAddressColumn: 2,
          hasHeaderRow: true,
          removeDuplicate: true);
      expect(multipartOf(fake.last), {
        'email_address_column': '2',
        'has_header_row': 'true',
        'remove_duplicate': 'true',
        'api_key': testKey,
      });
    });

    test('uploads check the file, its name and the columns before sending',
        () async {
      final (sdk, fake) = sdkAnswering(sent);
      await expectLater(
          sdk.sendFile(
              file: const [],
              fileName: 'a.csv',
              emailAddressColumn: 1,
              hasHeaderRow: true),
          throwsZB(0, contains('file')));
      await expectLater(
          sdk.sendFile(
              file: csv,
              fileName: ' ',
              emailAddressColumn: 1,
              hasHeaderRow: true),
          throwsZB(0, contains('fileName')));
      await expectLater(
          sdk.sendFile(
              file: csv,
              fileName: 'a.csv',
              emailAddressColumn: 0,
              hasHeaderRow: true),
          throwsZB(0, contains('email_address_column')));
      await expectLater(
          sdk.sendFile(
              file: csv,
              fileName: 'a.csv',
              emailAddressColumn: 1,
              hasHeaderRow: true,
              genderColumn: -1),
          throwsZB(0, contains('gender_column')));
      await expectLater(
          sdk.sendFile(
              file: csv,
              fileName: 'a\r\n.csv',
              emailAddressColumn: 1,
              hasHeaderRow: true),
          throwsZB(0, contains('line break')));
      await expectLater(
          sdk.sendFile(
              file: csv,
              fileName: 'a.csv',
              emailAddressColumn: 1,
              hasHeaderRow: true,
              returnUrl: 'https://x.example/\r\nX-Injected: 1'),
          throwsZB(0, contains('line break')));
      expect(fake.requests, isEmpty);
    });

    test('getFile sends download_type and activity_data only when set',
        () async {
      final (sdk, fake) = sdkAnswering('a,b\n', contentType: 'text/csv');
      expect(await sdk.getFile('f1'), 'a,b\n');
      expect(queryOf(fake.last), {'api_key': testKey, 'file_id': 'f1'});
      await sdk.getFile('f1',
          downloadType: ZBDownloadType.phase2, activityData: false);
      expect(queryOf(fake.last), {
        'api_key': testKey,
        'file_id': 'f1',
        'download_type': 'phase_2',
        'activity_data': 'false'
      });
      await sdk.getScoringFile('f1', downloadType: ZBDownloadType.combined);
      expect(queryOf(fake.last),
          {'api_key': testKey, 'file_id': 'f1', 'download_type': 'combined'});
    });

    test('file id calls refuse a missing id', () async {
      final (sdk, fake) = sdkAnswering(sent);
      for (final call in [
        () => sdk.getFileStatus(''),
        () => sdk.getScoringFileStatus(' '),
        () => sdk.getFile(''),
        () => sdk.getScoringFile(''),
        () => sdk.deleteFile(''),
        () => sdk.deleteScoringFile(''),
        () => sdk.getEmailFinderFileStatus(''),
        () => sdk.getEmailFinderFile(''),
        () => sdk.deleteEmailFinderFile(''),
        () => sdk.getDomainSearchFileStatus(''),
        () => sdk.getDomainSearchFile(''),
        () => sdk.deleteDomainSearchFile(''),
        () => sdk.getListEvaluatorResult(''),
        () => sdk.sendEvaluatedFile(''),
      ]) {
        await expectLater(
            call(), throwsZB(0, contains('File id parameter is missing')));
      }
      expect(fake.requests, isEmpty);
    });
  });

  group('bulk email finder and domain search', () {
    test('sendEmailFinderFile sends only the columns that are set', () async {
      final (sdk, fake) = sdkAnswering(sent);
      await sdk.sendEmailFinderFile(
          file: csv,
          fileName: 'a.csv',
          domainColumn: 3,
          fullNameColumn: 1,
          hasHeaderRow: false);
      expect(multipartOf(fake.last), {
        'domain_column': '3',
        'full_name_column': '1',
        'has_header_row': 'false',
        'api_key': testKey,
      });
      expect(fake.last.url.toString(),
          'https://bulkapi.zerobounce.net/email-finder/sendfile');
    });

    test('sendEmailFinderFile needs a first name or full name column',
        () async {
      final (sdk, fake) = sdkAnswering(sent);
      await expectLater(
          sdk.sendEmailFinderFile(
              file: csv,
              fileName: 'a.csv',
              domainColumn: 1,
              lastNameColumn: 2,
              hasHeaderRow: true),
          throwsZB(0, contains('first_name_column')));
      expect(fake.requests, isEmpty);
    });

    test('sendDomainSearchFile sends the domain column and header flag',
        () async {
      final (sdk, fake) = sdkAnswering(sent);
      await sdk.sendDomainSearchFile(
          file: csv, fileName: 'a.csv', domainColumn: 2, hasHeaderRow: true);
      expect(multipartOf(fake.last),
          {'domain_column': '2', 'has_header_row': 'true', 'api_key': testKey});
    });

    test('the finder and domain search use their own overridable base URLs',
        () async {
      final fake = FakeClient((_) => answer(sent));
      final sdk = ZeroBounceSDK(testKey,
          httpClient: fake,
          emailFinderBaseUrl: 'https://finder.example/ef/',
          domainSearchBaseUrl: 'https://domains.example/ds');
      await sdk.getEmailFinderFileStatus('f1');
      expect(fake.last.url.replace(query: '').toString(),
          'https://finder.example/ef/filestatus?');
      await sdk.getDomainSearchFileStatus('f1');
      expect(fake.last.url.host, 'domains.example');
      expect(fake.last.url.path, '/ds/filestatus');
    });
  });

  group('list evaluator', () {
    test('submits to its own base URL and reads the result by id', () async {
      final (sdk, fake) = sdkAnswering({'success': true, 'file_id': 'e1'});
      await sdk.sendListEvaluatorFile(
          file: csv, fileName: 'a.csv', emailAddressColumn: 1);
      expect(fake.last.url.toString(),
          'https://bulkapi.zerobounce.net/v2/listevaluator/');
      expect(multipartOf(fake.last),
          {'email_address_column': '1', 'api_key': testKey});
      await sdk.getListEvaluatorResult(' a/b ');
      expect(fake.last.url.path, '/v2/listevaluator/a%2Fb/');
      expect(queryOf(fake.last), {'api_key': testKey});
      await expectLater(
          sdk.getListEvaluatorResult('..'), throwsZB(0, contains('invalid')));
    });

    test('sendEvaluatedFile sends the id as a form field on the bulk base',
        () async {
      final (sdk, fake) = sdkAnswering({'success': true, 'file_id': 'f2'});
      await sdk.sendEvaluatedFile('e1');
      expect(fake.last.url.toString(),
          'https://bulkapi.zerobounce.net/v2/send-evaluated-file/');
      expect(multipartOf(fake.last), {'api_key': testKey, 'file_id': 'e1'});
      expect((fake.last as http.MultipartRequest).files, isEmpty);
    });
  });

  group('filters', () {
    test('add and delete send rule, target and value as a form', () async {
      final (sdk, fake) = sdkAnswering({'Message': 'ok'});
      await sdk.addFilter(
          rule: ZBFilterRule.block, target: ZBFilterTarget.tld, value: 'xyz');
      expect(formOf(fake.last), {
        'api_key': testKey,
        'rule': 'block',
        'target': 'tld',
        'value': 'xyz'
      });
      await sdk.deleteFilter(
          rule: ZBFilterRule.allow,
          target: ZBFilterTarget.mx,
          value: 'mx.example');
      expect(fake.last.url.path, '/v2/filters/delete');
      expect(formOf(fake.last), {
        'api_key': testKey,
        'rule': 'allow',
        'target': 'mx',
        'value': 'mx.example'
      });
      await expectLater(
          sdk.addFilter(
              rule: ZBFilterRule.allow,
              target: ZBFilterTarget.email,
              value: ''),
          throwsZB(0, contains('value')));
    });

    test('listFilters can POST', () async {
      final (sdk, fake) = sdkAnswering(<Object>[]);
      await sdk.listFilters(usePost: true);
      expect(fake.last.method, 'POST');
      expect(formOf(fake.last), {'api_key': testKey});
    });
  });

  group('Amazon S3 and SFTP', () {
    test('listS3Files sends bucket and search only when set', () async {
      final (sdk, fake) = sdkAnswering(<Object>[]);
      await sdk.listS3Files();
      expect(queryOf(fake.last), {'api_key': testKey});
      await sdk.listS3Files(bucket: 'b', search: 'in/');
      expect(queryOf(fake.last),
          {'api_key': testKey, 'bucket': 'b', 'search': 'in/'});
    });

    for (final name in [
      'validateS3File',
      'scoreS3File',
      'emailFinderS3File',
      'domainSearchS3File',
      'validateSftpFile',
      'scoreSftpFile',
      'emailFinderSftpFile',
      'domainSearchSftpFile',
    ]) {
      test('$name sends exactly the documented fields', () async {
        final (sdk, fake) = sdkAnswering(job);
        await fileJob(sdk, name, hasHeaderRow: false);
        expect(formOf(fake.last), {
          'api_key': testKey,
          'file_name': 'in/a.csv',
          'has_header_row': 'false',
          'return_url': 'https://example.com/done',
        });
        await fileJob(sdk, name, removeDuplicates: false);
        expect(formOf(fake.last)['remove_duplicates'], 'false');
        await expectLater(fileJob(sdk, name, fileName: ' '),
            throwsZB(0, contains('file_name')));
        await expectLater(fileJob(sdk, name, returnUrl: ''),
            throwsZB(0, contains('return_url')));
        expect(fake.requests, hasLength(2));
      });
    }

    test('exports send the optional destination only when set', () async {
      final (sdk, fake) = sdkAnswering(job);
      await sdk.exportS3File(fileId: 'f1');
      expect(formOf(fake.last), {'api_key': testKey, 'file_id': 'f1'});
      await sdk.exportS3File(fileId: 'f1', exportBucket: 'out');
      expect(formOf(fake.last),
          {'api_key': testKey, 'file_id': 'f1', 'export_bucket': 'out'});
      await sdk.exportSftpFile(fileId: 'f1', exportPath: '/out');
      expect(formOf(fake.last),
          {'api_key': testKey, 'file_id': 'f1', 'export_path': '/out'});
      await expectLater(sdk.exportSftpFile(fileId: 'f1', exportPath: ' '),
          throwsZB(0, contains('export_path')));
      await expectLater(
          sdk.exportS3File(fileId: ''), throwsZB(0, contains('file_id')));
    });
  });

  group('email finder and domain search', () {
    test('findEmailByDomain sends the names that are set', () async {
      final (sdk, fake) = sdkAnswering({'email': 'a@example.com'});
      await sdk.findEmailByDomain(
          domain: 'example.com', firstName: 'Ann', lastName: ' ');
      expect(queryOf(fake.last),
          {'api_key': testKey, 'first_name': 'Ann', 'domain': 'example.com'});
      await sdk.findEmailByCompanyName(
          companyName: 'Example Inc',
          firstName: 'Ann',
          middleName: 'B',
          lastName: 'C');
      expect(queryOf(fake.last), {
        'api_key': testKey,
        'first_name': 'Ann',
        'middle_name': 'B',
        'last_name': 'C',
        'company_name': 'Example Inc',
      });
      await expectLater(
          sdk.findEmailByDomain(domain: ''), throwsZB(0, contains('domain')));
    });

    test('findEmailFormat sends only the domain or company', () async {
      final (sdk, fake) = sdkAnswering({'format': 'first'});
      await sdk.findEmailFormatByDomain('example.com');
      expect(queryOf(fake.last), {'api_key': testKey, 'domain': 'example.com'});
      await sdk.findEmailFormatByCompanyName('Example');
      expect(
          queryOf(fake.last), {'api_key': testKey, 'company_name': 'Example'});
      await expectLater(sdk.findEmailFormatByCompanyName(' '),
          throwsZB(0, contains('company_name')));
    });
  });

  group('Inbox Placement Tester', () {
    test('sends the key as a Bearer header, never as a query parameter',
        () async {
      final (sdk, fake) = sdkAnswering({'webhookUrl': null});
      await sdk.getInboxPlacementWebhook();
      expect(fake.last.headers['Authorization'], 'Bearer $testKey');
      expect(fake.last.url.query, isEmpty);
    });

    test(
        'createInboxPlacementTest sends only the fields that are set, in camelCase',
        () async {
      final (sdk, fake) = sdkAnswering({'id': 't1'});
      await sdk.createInboxPlacementTest(name: 'launch');
      expect(jsonOf(fake.last), {'name': 'launch'});
      await sdk.createInboxPlacementTest(
          name: 'launch',
          testType: 1,
          senderEmail: 'me@example.com',
          providerIds: [1, 2],
          seedIds: [7],
          providers: [
            const ZBInboxPlacementProvider(3, maxSeeds: 2),
            const ZBInboxPlacementProvider(4)
          ],
          webhookUrl: 'https://example.com/hook');
      expect(jsonOf(fake.last), {
        'name': 'launch',
        'testType': 1,
        'senderEmail': 'me@example.com',
        'providerIds': [1, 2],
        'seedIds': [7],
        'providers': [
          {'id': 3, 'maxSeeds': 2},
          {'id': 4},
        ],
        'webhookUrl': 'https://example.com/hook',
      });
    });

    test('createInboxPlacementTest checks its arguments before sending',
        () async {
      final (sdk, fake) = sdkAnswering({'id': 't1'});
      await expectLater(sdk.createInboxPlacementTest(name: ''),
          throwsZB(0, contains('name')));
      await expectLater(sdk.createInboxPlacementTest(name: 'x' * 65),
          throwsZB(0, contains('64')));
      await expectLater(sdk.createInboxPlacementTest(name: 'x', testType: 4),
          throwsZB(0, contains('testType')));
      await expectLater(sdk.createInboxPlacementTest(name: 'x', testType: 1),
          throwsZB(0, contains('senderEmail')));
      await expectLater(
          sdk.createInboxPlacementTest(
              name: 'x',
              providers: [const ZBInboxPlacementProvider(1, maxSeeds: 0)]),
          throwsZB(0, contains('maxSeeds')));
      expect(fake.requests, isEmpty);
    });

    test('listInboxPlacementTests sends only the filters that are set',
        () async {
      final (sdk, fake) = sdkAnswering({'results': <Object>[]});
      await sdk.listInboxPlacementTests();
      expect(fake.last.url.query, isEmpty);
      await sdk.listInboxPlacementTests(
          status: ZBInboxPlacementTestStatus.finished,
          createdAfter: '2026-01-01',
          createdBefore: '2026-02-01',
          page: 2,
          pageSize: 50);
      expect(queryOf(fake.last), {
        'status': 'finished',
        'createdAfter': '2026-01-01',
        'createdBefore': '2026-02-01',
        'page': '2',
        'page_size': '50',
      });
      await expectLater(
          sdk.listInboxPlacementTests(page: 0), throwsZB(0, contains('page')));
      await expectLater(sdk.listInboxPlacementTests(pageSize: 101),
          throwsZB(0, contains('pageSize')));
    });

    test('test ids are one encoded path segment', () async {
      final (sdk, fake) = sdkAnswering({'id': 'a'});
      await sdk.getInboxPlacementTest(' a/b?c ');
      expect(fake.last.url.path, '/api/ipt/test/a%2Fb%3Fc');
      await expectLater(
          sdk.deleteInboxPlacementTest('.'), throwsZB(0, contains('invalid')));
      await expectLater(
          sdk.getInboxPlacementTest(''), throwsZB(0, contains('testId')));
    });

    test('setInboxPlacementWebhook sends the URL as JSON with PUT', () async {
      final (sdk, fake) = sdkAnswering({'webhookUrl': 'https://example.com/h'});
      await sdk.setInboxPlacementWebhook('https://example.com/h');
      expect(fake.last.method, 'PUT');
      expect(jsonOf(fake.last), {'webhookUrl': 'https://example.com/h'});
      await expectLater(sdk.setInboxPlacementWebhook(' '),
          throwsZB(0, contains('webhookUrl')));
    });
  });

  test('regional main hosts leave the bulk hosts alone', () async {
    final fake = FakeClient((_) => answer(validated));
    final sdk = ZeroBounceSDK(testKey, baseUrl: ZBApiUrl.eu, httpClient: fake);
    await sdk.validateEmail('a@b.c');
    expect(fake.last.url.host, 'api-eu.zerobounce.net');
    fake.handler = (_) =>
        answer({'success': true, 'file_id': 'f1', 'file_status': 'Complete'});
    await sdk.getFileStatus('f1');
    expect(fake.last.url.host, 'bulkapi.zerobounce.net');
  });

  test('a separate client per key keeps concurrent requests apart', () async {
    final fake = FakeClient((_) => answer({'Credits': '1'}));
    await Future.wait([
      ZeroBounceSDK('key-one', httpClient: fake).getCredits(),
      ZeroBounceSDK('key-two', httpClient: fake).getCredits(),
    ]);
    expect(fake.requests.map((r) => r.url.queryParameters['api_key']).toSet(),
        {'key-one', 'key-two'});
  });
}
