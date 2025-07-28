use strict;
use warnings;

use File::Basename;
use File::Spec::Functions qw( rel2abs );
use lib dirname( rel2abs( $0 ) );
use TestUtil::DSL;

###########
# basic02 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/Basic-TP/basic02.md
testing_test_case 'Basic', 'basic02';

all_tags qw(B02_AUTH_RESPONSE_SOA
            B02_NO_DELEGATION
            B02_NO_WORKING_NS
            B02_NS_BROKEN
            B02_NS_NOT_AUTH
            B02_NS_NO_IP_ADDR
            B02_NS_NO_RESPONSE
            B02_UNEXPECTED_RCODE);

# Specific hint file (test-zone-data/Basic-TP/basic02/hintfile.zone)
root_hints 'root-ns1.xa' => [ qw(127.12.2.23 fda1:b2:c3::127:12:2:23) ],
           'root-ns2.xa' => [ qw(127.12.2.24 fda1:b2:c3::127:12:2:24) ];

zone_name_template '{SCENARIO}.{TESTCASE}.xa';

scenario 'GOOD-{1..2}' => sub {
    expect 'B02_AUTH_RESPONSE_SOA';
    forbid_others;
};

scenario 'GOOD-UNDEL-1' => sub {
    fake_ns 'ns1.good-undel-1.basic02.xa' => '127.12.2.31', 'fda1:b2:c3:0:127:12:2:31';
    fake_ns 'ns2.good-undel-1.basic02.xa' => '127.12.2.32', 'fda1:b2:c3:0:127:12:2:32';
    expect 'B02_AUTH_RESPONSE_SOA';
    forbid_others;
};

scenario 'GOOD-UNDEL-2' => sub {
    fake_ns 'ns1.good-undel-2.basic02.xb';
    fake_ns 'ns2.good-undel-2.basic02.xb';
    expect 'B02_AUTH_RESPONSE_SOA';
    forbid_others;
};

scenario 'GOOD-UNDEL-3' => sub {
    fake_ns 'ns3.good-undel-3.basic02.xb';
    fake_ns 'ns4.good-undel-3.basic02.xb';
    expect 'B02_AUTH_RESPONSE_SOA';
    forbid_others;
};

scenario 'GOOD-UNDEL-4' => sub {
    fake_ns 'ns1.good-undel-4.basic02.xb';
    fake_ns 'ns2.good-undel-4.basic02.xb';
    expect 'B02_AUTH_RESPONSE_SOA';
    forbid_others;
};

scenario 'GOOD-UNDEL-5' => sub {
    fake_ns 'ns1.good-undel-5.basic02.xa' => '127.12.2.31', 'fda1:b2:c3:0:127:12:2:31';
    fake_ns 'ns2.good-undel-5.basic02.xa' => '127.12.2.32', 'fda1:b2:c3:0:127:12:2:32';
    expect 'B02_AUTH_RESPONSE_SOA';
    forbid_others;
};

scenario 'GOOD-UNDEL-6' => sub {
    fake_ns 'ns3.good-undel-6.basic02.xa' => '127.12.2.33', 'fda1:b2:c3:0:127:12:2:33';
    fake_ns 'ns4.good-undel-6.basic02.xa' => '127.12.2.34', 'fda1:b2:c3:0:127:12:2:34';
    expect 'B02_AUTH_RESPONSE_SOA';
    forbid_others;
};

scenario 'GOOD-UNDEL-7' => sub {
    fake_ns 'ns3.good-undel-7.basic02.xb' => '127.12.2.33', 'fda1:b2:c3:0:127:12:2:33';
    fake_ns 'ns4.good-undel-7.basic02.xb' => '127.12.2.34';
    fake_ns 'ns5.good-undel-7.basic02.xb' => 'fda1:b2:c3:0:127:12:2:34';
    expect 'B02_AUTH_RESPONSE_SOA';
    forbid_others;
};

scenario 'GOOD-UNDEL-8' => sub {
    fake_ns 'dns1.good-undel-8.basic02.xa' => '127.12.2.33', 'fda1:b2:c3:0:127:12:2:33';
    fake_ns 'dns2.good-undel-8.basic02.xa' => '127.12.2.34', 'fda1:b2:c3:0:127:12:2:34';
    expect 'B02_AUTH_RESPONSE_SOA';
    forbid_others;
};

scenario 'GOOD-UNDEL-9' => sub {
    fake_ns 'dns1.good-undel-9.basic02.xb' => '127.12.2.33', 'fda1:b2:c3:0:127:12:2:33';
    fake_ns 'dns2.good-undel-9.basic02.xb' => '127.12.2.34', 'fda1:b2:c3:0:127:12:2:34';
    expect 'B02_AUTH_RESPONSE_SOA';
    forbid_others;
};

scenario 'GOOD-UNDEL-10' => sub {
    fake_ns 'ns3.good-undel-10.basic02.xb' => '127.12.2.33', 'fda1:b2:c3:0:127:12:2:33';
    fake_ns 'ns4.good-undel-10.basic02.xb' => '127.12.2.34', 'fda1:b2:c3:0:127:12:2:34';
    expect 'B02_AUTH_RESPONSE_SOA';
    forbid_others;
};

scenario 'GOOD-UNDEL-11' => sub {
    fake_ns 'ns3.good-undel-11.basic02.xb';
    fake_ns 'ns4.good-undel-11.basic02.xb';
    expect 'B02_AUTH_RESPONSE_SOA';
    forbid_others;
};

scenario 'MIXED-1' => sub {
    expect 'B02_AUTH_RESPONSE_SOA';
    forbid_others;
};

scenario 'NO-DELEGATION-1' => sub {
    zone 'no-delegation.{TESTCASE}.xa';
    expect 'B02_NO_DELEGATION';
    forbid_others;
};

scenario 'NS-BROKEN-1' => sub {
    expect qw(B02_NS_BROKEN B02_NO_WORKING_NS);
    forbid_others;
};

scenario 'NS-NOT-AUTH-1' => sub {
    expect qw(B02_NS_NOT_AUTH B02_NO_WORKING_NS);
    forbid_others;
};

scenario 'NS-NO-IP-{1..3}' => sub {
    expect qw(B02_NS_NO_IP_ADDR B02_NO_WORKING_NS);
    forbid_others;
};

scenario 'NS-NO-IP-UNDEL-1' => sub {
    fake_ns 'ns1.ns-no-ip-undel-1.basic02.xa';
    fake_ns 'ns2.ns-no-ip-undel-1.basic02.xa';
    expect qw(B02_NS_NO_IP_ADDR B02_NO_WORKING_NS);
    forbid_others;
};

scenario 'NS-NO-IP-UNDEL-2' => sub {
    fake_ns 'ns1.ns-no-ip-undel-2.basic02.xb';
    fake_ns 'ns2.ns-no-ip-undel-2.basic02.xb';
    expect qw(B02_NS_NO_IP_ADDR B02_NO_WORKING_NS);
    forbid_others;
};

scenario 'NS-NO-RESPONSE-1' => sub {
    expect qw(B02_NS_NO_RESPONSE B02_NO_WORKING_NS);
    forbid_others;
};

scenario 'UNEXPECTED-RCODE-1' => sub {
    expect qw(B02_UNEXPECTED_RCODE B02_NO_WORKING_NS);
    forbid_others;
};

no_more_scenarios;
