use strict;
use warnings;

use File::Basename;
use File::Spec::Functions qw( rel2abs );
use lib dirname( rel2abs( $0 ) );
use TestUtil::DSL;

###########
# consistency05 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/Consistency-TP/consistency05.md

testing_test_case 'Consistency', 'consistency05';

all_tags qw(ADDRESSES_MATCH
            IN_BAILIWICK_ADDR_MISMATCH
            OUT_OF_BAILIWICK_ADDR_MISMATCH
            EXTRA_ADDRESS_CHILD
            CHILD_ZONE_LAME
            CHILD_NS_FAILED
            NO_RESPONSE);

# Common hint file (test-zone-data/COMMON/hintfile)
root_hints 'ns1' => [ qw(127.1.0.1 fda1:b2:c3::127:1:0:1) ],
           'ns2' => [ qw(127.1.0.2 fda1:b2:c3::127:1:0:2) ];

# Test zone scenarios
zone_name_template '{SCENARIO}.{TESTCASE}.xa';

scenario 'ADDRESSES-MATCH-{1..2}' => sub {
    expect 'ADDRESSES_MATCH';
    forbid_others;
};

scenario 'ADDRESSES-MATCH-{3..4}' => sub {
    expect qw(ADDRESSES_MATCH CHILD_NS_FAILED);
    forbid_others;
};

scenario 'ADDRESSES-MATCH-5' => sub {
    expect qw(ADDRESSES_MATCH NO_RESPONSE);
    forbid_others;
};

scenario 'ADDRESSES-MATCH-6' => sub {
    zone 'child.{SCENARIO}.{TESTCASE}.xa';
    expect 'ADDRESSES_MATCH';
    forbid_others;
};

scenario 'ADDRESSES-MATCH-7' => sub {
    expect 'ADDRESSES_MATCH';
    forbid_others;
};

scenario 'ADDR-MATCH-DEL-UNDEL-1' => sub {
    fake_ns 'ns3.addr-match-del-undel-1.consistency05.xa' => '127.14.5.33', 'fda1:b2:c3:0:127:14:5:33';
    fake_ns 'ns4.addr-match-del-undel-1.consistency05.xa' => '127.14.5.34', 'fda1:b2:c3:0:127:14:5:34';
    expect 'ADDRESSES_MATCH';
    forbid_others;
};

scenario 'ADDR-MATCH-DEL-UNDEL-2' => sub {
    fake_ns 'ns3.addr-match-del-undel-2.consistency05.xb';
    fake_ns 'ns4.addr-match-del-undel-2.consistency05.xb';
    expect 'ADDRESSES_MATCH';
    forbid_others;
};

scenario 'ADDR-MATCH-NO-DEL-UNDEL-1' => sub {
    fake_ns 'ns1.addr-match-no-del-undel-1.consistency05.xa' => '127.14.5.31', 'fda1:b2:c3:0:127:14:5:31';
    fake_ns 'ns2.addr-match-no-del-undel-1.consistency05.xa' => '127.14.5.32', 'fda1:b2:c3:0:127:14:5:32';
    expect 'ADDRESSES_MATCH';
    forbid_others;
};

scenario 'ADDR-MATCH-NO-DEL-UNDEL-2' => sub {
    fake_ns 'ns3.addr-match-no-del-undel-2.consistency05.xb';
    fake_ns 'ns4.addr-match-no-del-undel-2.consistency05.xb';
    expect 'ADDRESSES_MATCH';
    forbid_others;
};

scenario 'CHILD-ZONE-LAME-1' => sub {
    todo 'see https://github.com/zonemaster/zonemaster-engine/issues/1301';

    expect qw(CHILD_ZONE_LAME NO_RESPONSE);
    forbid_others;
};

scenario 'CHILD-ZONE-LAME-2' => sub {
    expect qw(CHILD_ZONE_LAME CHILD_NS_FAILED);
    forbid_others;
};

scenario 'IB-ADDR-MISMATCH-1' => sub {
    expect qw(IN_BAILIWICK_ADDR_MISMATCH EXTRA_ADDRESS_CHILD);
    forbid_others;
};

scenario 'IB-ADDR-MISMATCH-2' => sub {
    expect 'IN_BAILIWICK_ADDR_MISMATCH';
    forbid_others;
};

scenario 'IB-ADDR-MISMATCH-3' => sub {
    todo 'see https://github.com/zonemaster/zonemaster-engine/issues/1301';

    expect qw(IN_BAILIWICK_ADDR_MISMATCH NO_RESPONSE);
    forbid_others;
};

scenario 'IB-ADDR-MISMATCH-4' => sub {
    todo 'see https://github.com/zonemaster/zonemaster-engine/issues/1349';

    expect 'IN_BAILIWICK_ADDR_MISMATCH';
    forbid_others;
};

scenario 'OOB-ADDR-MISMATCH' => sub {
    zone 'child.{SCENARIO}.{TESTCASE}.xa';
    expect 'OUT_OF_BAILIWICK_ADDR_MISMATCH';
    forbid_others;
};

scenario 'EXTRA-ADDRESS-CHILD' => sub {
    expect 'EXTRA_ADDRESS_CHILD';
    forbid_others;
};

no_more_scenarios;
