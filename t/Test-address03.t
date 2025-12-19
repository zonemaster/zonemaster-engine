use strict;
use warnings;

use File::Basename;
use File::Spec::Functions qw( rel2abs );
use lib dirname( rel2abs( $0 ) );
use TestUtil::DSL;

testing_test_case 'Address', 'address03';

all_tags qw(NAMESERVER_IP_PTR_MATCH
            NAMESERVER_IP_PTR_MISMATCH
            NAMESERVER_IP_WITHOUT_REVERSE
            NO_RESPONSE_PTR_QUERY);

# Common hint file (test-zone-data/COMMON/hintfile)
root_hints 'ns1' => [ qw(127.1.0.1 fda1:b2:c3::127:1:0:1) ],
           'ns2' => [ qw(127.1.0.2 fda1:b2:c3::127:1:0:2) ];

zone_name_template '{SCENARIO}.{TESTCASE}.xa';

# Test zone scenarios
scenario 'ALL-NS-HAVE-PTR-{1..2}' => sub {
    expect 'NAMESERVER_IP_PTR_MATCH';
    forbid_others;
};

scenario 'NO-NS-HAVE-PTR' => sub {
    expect 'NAMESERVER_IP_WITHOUT_REVERSE';
    forbid_others;
};

scenario 'INCOMPLETE-PTR-{1..2}' => sub {
    expect 'NAMESERVER_IP_WITHOUT_REVERSE';
    forbid_others;
};

scenario 'NON-MATCHING-NAMES' => sub {
    expect 'NAMESERVER_IP_PTR_MISMATCH';
    forbid_others;
};

scenario 'PTR-IS-GOOD-CNAME-{1..2}' => sub {
    expect 'NAMESERVER_IP_PTR_MATCH';
    forbid_others;
};

scenario 'PTR-IS-DANGLING-CNAME' => sub {
    expect 'NAMESERVER_IP_WITHOUT_REVERSE';
    forbid_others;
};

scenario 'PTR-IS-ILLEGAL-CNAME' => sub {
    expect 'NAMESERVER_IP_WITHOUT_REVERSE';
    forbid 'NAMESERVER_IP_PTR_MATCH';
};

no_more_scenarios;
