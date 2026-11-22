// Documented example responses: the success samples of each response page of
// https://www.zerobounce.net/docs/, as the raw text the page shows (recorded
// verbatim from the docs in the JavaScript SDK's tests/field-types.test.js).
// Each must still parse.

const documentedExamples = <String, List<String>>{
  'getCredits': [
    r'''{"Credits":2375323}''',
  ],
  'validateEmail': [
    r'''{
      "address": "john.doe@zerobounce.net",
      "status": "valid",
      "sub_status": "",
      "free_email": false,
      "catchall_domain": true,
      "did_you_mean": null,
      "account": "johndoe",
      "domain": "zerobounce.net",
      "domain_age_days": "3431",
      "active_in_days": "30",
      "active_first_seen": "2026-02-25",
      "smtp_provider": "g-suite",
      "mx_found": "true",
      "mx_record": "aspmx.l.google.com",
      "firstname": "dan",
      "lastname": "cotet",
      "gender": "male",
      "country": null,
      "region": null,
      "city": null,
      "zipcode": null,
      "processed_at": "2026-06-18 07:05:00.033"
  }''',
  ],
  'sendFile': [
    r'''{
      "success": true,
      "message": "File Accepted",
      "file_name": "Your file name.csv",
      "file_id": "aaaaaaaa-zzzz-xxxx-yyyy-5003727fffff"
    }''',
  ],
  'getFileStatus': [
    r'''{
    "success": true,
    "file_id": "aaaaaaaa-zzzz-xxxx-yyyy-5003727fffff",
    "file_name": "Your file name.csv",
    "upload_date": "2023-04-28T15:25:41Z",
    "file_status": "Complete",
    "file_phase_2_status": "N/A",
    "complete_percentage": "100%",
    "return_url": "Your return URL if provided when calling sendfile API"
  }''',
    r'''{
    "success": true,
    "file_id": "aaaaaaaa-zzzz-xxxx-yyyy-5003727fffff",
    "file_name": "Your file name.csv",
    "upload_date": "2023-04-28T15:25:41Z",
    "file_status": "Complete",
    "file_phase_2_status": "Complete",
    "complete_percentage": "100%",
    "return_url": "Your return URL if provided when calling sendfile API"
  }''',
  ],
  'deleteFile': [
    r'''{
    "success": true,
    "message": "File Deleted",
    "file_name": "test2",
    "file_id": "b222a0fd-90d5-416c-8f1a-9cc3851fc823"
  }''',
  ],
  'sendScoringFile': [
    r'''{
          "success": true,
          "message": "File Accepted",
          "file_name": "Your file name.csv",
          "file_id": "aaaaaaaa-zzzz-xxxx-yyyy-5003727fffff"
      }''',
  ],
  'getScoringFileStatus': [
    r'''{
          "success": true,
          "file_id": "aaaaaaaa-zzzz-xxxx-yyyy-5003727fffff",
          "file_name": "Your file name.csv",
          "upload_date": "2023-04-28T15:25:41Z",
          "file_status": "Complete",
          "complete_percentage": "100%",
          "return_url": "Your return URL if provided when calling sendfile API"
      }''',
  ],
  'deleteScoringFile': [
    r'''{
        "success": true,
        "message": "File Deleted",
        "file_name": "test2",
        "file_id": "b222a0fd-90d5-416c-8f1a-9cc3851fc823"
    }''',
  ],
  'validateBatch': [
    r'''{
      "email_batch": [
          {
              "address": "john.doe@zerobounce.net",
              "status": "valid",
              "sub_status": "",
              "free_email": false,
              "catchall_domain": true,
              "did_you_mean": null,
              "account": "johndoe",
              "domain": "zerobounce.net",
              "domain_age_days": "3431",
              "active_in_days": "30",
              "active_first_seen": "2026-02-25",
              "smtp_provider": "g-suite",
              "mx_found": "true",
              "mx_record": "aspmx.l.google.com",
              "firstname": "dan",
              "lastname": "cotet",
              "gender": "male",
              "country": null,
              "region": null,
              "city": null,
              "zipcode": null,
              "processed_at": "2026-06-18 07:05:00.033"
          },
          {
              "address": "invalid@example.com",
              "status": "invalid",
              "sub_status": "mailbox_not_found",
              "free_email": false,
              "did_you_mean": null,
              "account": null,
              "domain": null,
              "domain_age_days": "9692",
              "active_in_days": "365",
              "active_first_seen": "2026-02-25",
              "smtp_provider": "example",
              "mx_found": "true",
              "mx_record": "mx.example.com",
              "catchall_domain": false,
              "firstname": "zero",
              "lastname": "bounce",
              "gender": "male",
              "country": null,
              "region": null,
              "city": null,
              "zipcode": null,
              "processed_at": "2020-09-17 17:43:11.830"
          },
          {
              "address": "disposable@example.com",
              "status": "do_not_mail",
              "sub_status": "disposable",
              "free_email": false,
              "did_you_mean": null,
              "account": null,
              "domain": null,
              "domain_age_days": "9692",
              "active_in_days": "365",
              "active_first_seen": "2026-02-25",
              "smtp_provider": "example",
              "mx_found": "true",
              "mx_record": "mx.example.com",
              "catchall_domain": false,
              "firstname": "zero",
              "lastname": "bounce",
              "gender": "male",
              "country": null,
              "region": null,
              "city": null,
              "zipcode": null,
              "processed_at": "2020-09-17 17:43:11.830"
          }
      ],
      "errors": []
  }''',
  ],
  'getApiUsage': [
    r'''{
      "total": 120,
      "status_valid": 17,
      "status_invalid": 69,
      "status_catch_all": 9,
      "status_do_not_mail": 16,
      "status_spamtrap": 0,
      "status_unknown": 6,
      "sub_status_toxic": 0,
      "sub_status_disposable": 1,
      "sub_status_role_based": 1,
      "sub_status_possible_trap": 0,
      "sub_status_global_suppression": 14,
      "sub_status_timeout_exceeded": 0,
      "sub_status_mail_server_temporary_error": 0,
      "sub_status_mail_server_did_not_respond": 0,
      "sub_status_greylisted": 6,
      "sub_status_antispam_system": 0,
      "sub_status_does_not_accept_mail": 27,
      "sub_status_exception_occurred": 0,
      "sub_status_failed_syntax_check": 20,
      "sub_status_mailbox_not_found": 12,
      "sub_status_unroutable_ip_address": 0,
      "sub_status_possible_typo": 0,
      "sub_status_no_dns_entries": 10,
      "sub_status_role_based_catch_all": 0,
      "sub_status_mailbox_quota_exceeded": 0,
      "sub_status_forcible_disconnect": 0,
      "sub_status_failed_smtp_connection": 0,
      "sub_status_leading_period_removed": 0,
      "sub_status_alias_address": 2,
      "sub_status_mx_forward": 0,
      "sub_status_alternate": 0,
      "sub_status_blocked": 0,
      "sub_status_allowed": 0,
      "start_date": "1/1/2023",
      "end_date": "1/30/2024"
    }''',
  ],
};
