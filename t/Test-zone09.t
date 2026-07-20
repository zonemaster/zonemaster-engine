use strict;
use warnings;

use File::Basename qw( dirname );
use File::Spec::Functions qw( rel2abs );
use lib dirname( rel2abs( $0 ) );
use TestUtil::DSL;

testing_test_case 'Zone', 'zone09';

all_tags qw(Z09_ARPA_EMAIL_DOMAIN
            Z09_INCONSISTENT_MX
            Z09_INCONSISTENT_MX_DATA
            Z09_MISSING_MAIL_EXCHANGE
            Z09_MX_DATA
            Z09_MX_FOUND
            Z09_NON_AUTH_MX_RESPONSE
            Z09_NO_MX_FOUND
            Z09_NO_MX_FOUND_OR_EXPECTED
            Z09_NO_SERVERS_MX_RESPONSE
            Z09_NO_RESPONSE_MX_QUERY
            Z09_NULL_MX_NON_ZERO_PREF
            Z09_NULL_MX_WITH_OTHER_MX
            Z09_ROOT_EMAIL_DOMAIN
            Z09_TLD_EMAIL_DOMAIN
            Z09_UNEXPECTED_RCODE_MX
            Z09_VALID_NULL_MX);

root_hints 'ns1' => [ qw(127.19.9.61 fda1:b2:c3::127:19:9:61) ],
           'ns2' => [ qw(127.19.9.62 fda1:b2:c3::127:19:9:62) ];
zone_name_template '{SCENARIO}.{TESTCASE}.xa';

scenario 'NO-RESPONSE-MX-QUERY-1' => sub {
    expect Z09_NO_RESPONSE_MX_QUERY => {
        ns_list => 'ns2.no-response-mx-query-1.zone09.xa/127.19.9.32;'
                 . 'ns2.no-response-mx-query-1.zone09.xa/fda1:b2:c3:0:127:19:9:32'
    };
    expect Z09_MX_DATA => {
        mxrdata_list => '10 mail.no-response-mx-query-1.zone09.xa.',
        ns_list => 'ns1.no-response-mx-query-1.zone09.xa/127.19.9.31;'
                 . 'ns1.no-response-mx-query-1.zone09.xa/fda1:b2:c3:0:127:19:9:31'
    };
    forbid_others;
};

scenario 'NO-RESPONSE-MX-QUERY-2' => sub {
    expect Z09_NO_RESPONSE_MX_QUERY => {
        ns_list => 'ns1.no-response-mx-query-2.zone09.xa/127.19.9.31;'
                 . 'ns1.no-response-mx-query-2.zone09.xa/fda1:b2:c3:0:127:19:9:31;'
                 . 'ns2.no-response-mx-query-2.zone09.xa/127.19.9.32;'
                 . 'ns2.no-response-mx-query-2.zone09.xa/fda1:b2:c3:0:127:19:9:32'
    };
    expect 'Z09_NO_SERVERS_MX_RESPONSE';
    forbid_others;
};

scenario 'UNEXPECTED-RCODE-MX' => sub {
    expect Z09_UNEXPECTED_RCODE_MX => {
        rcode => 'NOTIMPL',
        ns_list => 'ns1.unexpected-rcode-mx.zone09.xa/127.19.9.31;'
                 . 'ns1.unexpected-rcode-mx.zone09.xa/fda1:b2:c3:0:127:19:9:31'
    };
    expect 'Z09_MISSING_MAIL_EXCHANGE';
    forbid_others;
};

scenario 'NON-AUTH-MX-RESPONSE' => sub {
    not_testable 'see https://github.com/zonemaster/zonemaster/pull/1517#discussion_r3595385839';

    expect Z09_NON_AUTH_MX_RESPONSE => {
        ns_list => 'ns4.non-auth-mx-response.zone09.xa/127.19.9.34;'
                 . 'ns4.non-auth-mx-response.zone09.xa/fda1:b2:c3:0:127:19:9:34'
    };
    expect Z09_MX_DATA => {
        mxrdata_list => '10 mail.non-auth-mx-response.zone09.xa.',
        ns_list => sub { split(/;/, $_->{args}{ns_list}) == 4 }
    };
    forbid_others;
};

scenario 'INCONSISTENT-MX' => sub {
    expect 'Z09_INCONSISTENT_MX';
    expect Z09_MX_FOUND => {
        ns_list => 'ns1.inconsistent-mx.zone09.xa/127.19.9.31;'
                 . 'ns1.inconsistent-mx.zone09.xa/fda1:b2:c3:0:127:19:9:31'
    };
    expect Z09_NO_MX_FOUND => {
        ns_list => 'ns2.inconsistent-mx.zone09.xa/127.19.9.32;'
                 . 'ns2.inconsistent-mx.zone09.xa/fda1:b2:c3:0:127:19:9:32'
    };
    expect Z09_MX_DATA => {
        ns_list => 'ns1.inconsistent-mx.zone09.xa/127.19.9.31;'
                 . 'ns1.inconsistent-mx.zone09.xa/fda1:b2:c3:0:127:19:9:31',
        mxrdata_list => '10 mail.inconsistent-mx.zone09.xa.'
    };

    forbid_others;
};

scenario 'INCONSISTENT-MX-DATA-1' => sub {
    expect 'Z09_INCONSISTENT_MX_DATA';
    expect Z09_MX_DATA => {
        ns_list => 'ns1.inconsistent-mx-data-1.zone09.xa/127.19.9.31;'
                 . 'ns1.inconsistent-mx-data-1.zone09.xa/fda1:b2:c3:0:127:19:9:31',
        mxrdata_list => '10 mail.inconsistent-mx-data-1.zone09.xa.;'
                      . '10 mail2.inconsistent-mx-data-1.zone09.xa.'
    };
    expect Z09_MX_DATA => {
        ns_list => 'ns2.inconsistent-mx-data-1.zone09.xa/127.19.9.32;'
                 . 'ns2.inconsistent-mx-data-1.zone09.xa/fda1:b2:c3:0:127:19:9:32',
        mxrdata_list => '10 mail2.inconsistent-mx-data-1.zone09.xa.'
    };
    forbid_others;
};

scenario 'INCONSISTENT-MX-DATA-2' => sub {
    expect 'Z09_INCONSISTENT_MX_DATA';
    expect Z09_MX_DATA => {
        ns_list => 'ns1.inconsistent-mx-data-2.zone09.xa/127.19.9.31;'
                 . 'ns1.inconsistent-mx-data-2.zone09.xa/fda1:b2:c3:0:127:19:9:31',
        mxrdata_list => '20 mail2.inconsistent-mx-data-2.zone09.xa.'
    };
    expect Z09_MX_DATA => {
        ns_list => 'ns2.inconsistent-mx-data-2.zone09.xa/127.19.9.32;'
                 . 'ns2.inconsistent-mx-data-2.zone09.xa/fda1:b2:c3:0:127:19:9:32',
        mxrdata_list => '10 mail2.inconsistent-mx-data-2.zone09.xa.'
    };
    forbid_others;
};

scenario 'INCONSISTENT-MX-DATA-3' => sub {
    expect 'Z09_INCONSISTENT_MX_DATA';
    expect Z09_MX_DATA => {
        ns_list => 'ns1.inconsistent-mx-data-3.zone09.xa/127.19.9.31;'
                 . 'ns1.inconsistent-mx-data-3.zone09.xa/fda1:b2:c3:0:127:19:9:31',
        mxrdata_list => '10 mail.inconsistent-mx-data-3.zone09.xa.;'
                      . '20 mail2.inconsistent-mx-data-3.zone09.xa.'
    };
    expect Z09_MX_DATA => {
        ns_list => 'ns2.inconsistent-mx-data-3.zone09.xa/127.19.9.32;'
                 . 'ns2.inconsistent-mx-data-3.zone09.xa/fda1:b2:c3:0:127:19:9:32',
        mxrdata_list => '10 mail2.inconsistent-mx-data-3.zone09.xa.;'
                      . '20 mail.inconsistent-mx-data-3.zone09.xa.'
    };
    forbid_others;
};

scenario 'MIXED-TTL-{1..2}' => sub {
    expect 'Z09_MX_DATA';
    forbid_others;
};

scenario 'NULL-MX-WITH-OTHER-MX' => sub {
    expect 'Z09_NULL_MX_WITH_OTHER_MX';
    expect 'Z09_MX_DATA';
    forbid_others;
};

scenario 'NULL-MX-NON-ZERO-PREF' => sub {
    expect 'Z09_NULL_MX_NON_ZERO_PREF';
    expect 'Z09_MX_DATA';
    forbid_others;
};

scenario 'MX-DATA' => sub {
    expect 'Z09_MX_DATA';
    forbid_others;
};

scenario 'NULL-MX-SLD' => sub {
    expect 'Z09_VALID_NULL_MX';
    expect Z09_MX_DATA => { mxrdata_list => '0 .', ns_list => sub { 1 } };
    forbid_others;
};

scenario 'NO-MX-SLD' => sub {
    expect 'Z09_MISSING_MAIL_EXCHANGE';
    forbid_others;
};

###
### Special cases
###

# Scenarios that need to test a TLD

zone_name_template '{SCENARIO}-{TESTCASE}';

scenario 'TLD-EMAIL-DOMAIN' => sub {
    expect qw(Z09_TLD_EMAIL_DOMAIN Z09_MX_DATA);
    forbid_others;
};

scenario 'NULL-MX-TLD' => sub {
    expect 'Z09_VALID_NULL_MX';
    expect Z09_MX_DATA => { mxrdata_list => '0 .', ns_list => sub { 1 } };
    forbid_others;
};

scenario 'NO-MX-TLD' => sub {
    expect 'Z09_NO_MX_FOUND_OR_EXPECTED';
    forbid_others;
};

# Scenarios that need to test a zone in .ARPA

zone_name_template '{SCENARIO}.{TESTCASE}.arpa';

scenario 'ARPA-EMAIL-DOMAIN' => sub {
    expect 'Z09_ARPA_EMAIL_DOMAIN';
    expect 'Z09_MX_DATA';
    forbid_others;
};

scenario 'NULL-MX-ARPA' => sub {
    expect 'Z09_VALID_NULL_MX';
    expect Z09_MX_DATA => { mxrdata_list => '0 .', ns_list => sub { 1 } };
    forbid_others;
};

scenario 'NO-MX-ARPA' => sub {
    expect 'Z09_NO_MX_FOUND_OR_EXPECTED';
    forbid_others;
};

# Scenarios that need to test the root zone (with different root hints for
# each scenario)

zone_name_template '.';

scenario 'NO-MX-ROOT' => sub {
    expect 'Z09_NO_MX_FOUND_OR_EXPECTED';
    forbid_others;
};

# Override root hints for scenario ROOT-EMAIL-DOMAIN

root_hints 'ns1' => [ qw(127.19.9.63 fda1:b2:c3::127:19:9:63) ],
           'ns2' => [ qw(127.19.9.64 fda1:b2:c3::127:19:9:64) ];

scenario 'ROOT-EMAIL-DOMAIN' => sub {
    expect 'Z09_ROOT_EMAIL_DOMAIN';
    expect 'Z09_MX_DATA';
    forbid_others;
};

# Override root hints for scenario NULL-MX-ROOT

root_hints 'ns1' => [ qw(127.19.9.65 fda1:b2:c3::127:19:9:65) ],
           'ns2' => [ qw(127.19.9.66 fda1:b2:c3::127:19:9:66) ];

scenario 'NULL-MX-ROOT' => sub {
    expect 'Z09_VALID_NULL_MX';
    expect Z09_MX_DATA => { mxrdata_list => '0 .', ns_list => sub { 1 } };
    forbid_others;
};


no_more_scenarios;
