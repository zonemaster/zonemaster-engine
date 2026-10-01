use strict;
use warnings;

use File::Basename;
use File::Spec::Functions qw( rel2abs );
use lib dirname( rel2abs( $0 ) );
use TestUtil::DSL;

###########
# consistency05 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/Consistency-TP/consistency05.md

testing_test_case 'Consistency', 'consistency05';

all_tags qw( CS05_CHILD_ZONE_LAME
             CS05_DELEGATION
             CS05_EXTRA_ADDR_CHILD
             CS05_ID_ADDR_MISMATCH
             CS05_ID_ADDR_MISSING
             CS05_INCONSISTENT_DELEGATION
             CS05_MISSING_GLUE_FOR_NS
             CS05_MISSING_GLUE_FOR_NS_UNDEL
             CS05_MISSING_GLUE_FOR_ROOT_NS
             CS05_NO_MISMATCH_GLUE_ZONE
             CS05_NO_NS_ADDR_CHILD
             CS05_OOD_ADDR_MISMATCH );

# General Consistency05 hintfile (test-zone-data/Consistency-TP/consistency05/hintfile.zone)
root_hints 'ns1' => [ qw(127.14.5.61 fda1:b2:c3:0:127:14:5:61) ],
           'ns2' => [ qw(127.14.5.62 fda1:b2:c3:0:127:14:5:62) ];

# Test zone scenarios
zone_name_template '{SCENARIO}.{TESTCASE}.xa';

scenario 'ADDR-MATCH-DEL-UNDEL-1' => sub {
    fake_ns 'ns3.addr-match-del-undel-1.consistency05.xa' => '127.14.5.33', 'fda1:b2:c3:0:127:14:5:33';
    fake_ns 'ns4.addr-match-del-undel-1.consistency05.xa' => '127.14.5.34', 'fda1:b2:c3:0:127:14:5:34';

    expect 'CS05_NO_MISMATCH_GLUE_ZONE';
    forbid_others;
};

scenario 'ADDR-MATCH-DEL-UNDEL-2' => sub {
    fake_ns 'ns3.addr-match-del-undel-2.consistency05.xb';
    fake_ns 'ns4.addr-match-del-undel-2.consistency05.xb';

    expect 'CS05_NO_MISMATCH_GLUE_ZONE';
    forbid_others;
};

scenario 'ADDR-MATCH-NO-DEL-UNDEL-1' => sub {
    fake_ns 'ns1.addr-match-no-del-undel-1.consistency05.xa' => '127.14.5.31', 'fda1:b2:c3:0:127:14:5:31';
    fake_ns 'ns2.addr-match-no-del-undel-1.consistency05.xa' => '127.14.5.32', 'fda1:b2:c3:0:127:14:5:32';

    expect 'CS05_NO_MISMATCH_GLUE_ZONE';
    forbid_others;
};

scenario 'ADDR-MATCH-NO-DEL-UNDEL-2' => sub {
    fake_ns 'ns3.addr-match-no-del-undel-2.consistency05.xb';
    fake_ns 'ns4.addr-match-no-del-undel-2.consistency05.xb';

    expect 'CS05_NO_MISMATCH_GLUE_ZONE';
    forbid_others;
};

scenario 'ADDRESSES-MATCH-{1..5}' => sub {
    expect 'CS05_NO_MISMATCH_GLUE_ZONE';
    forbid_others;
};

scenario 'ADDRESSES-MATCH-6' => sub {
    zone 'child.{SCENARIO}.{TESTCASE}.xa';

    expect 'CS05_NO_MISMATCH_GLUE_ZONE';
    forbid_others;
};

scenario 'ADDRESSES-MATCH-7' => sub {
    expect 'CS05_NO_MISMATCH_GLUE_ZONE';
    forbid_others;
};

scenario 'ADDRESSES-MATCH-8' => sub {
    zone 'child.a.b.{SCENARIO}.{TESTCASE}.xa';

    expect 'CS05_NO_MISMATCH_GLUE_ZONE';
    forbid_others;
};

scenario 'ADDRESSES-MATCH-9' => sub {
    zone 'child.{SCENARIO}.{TESTCASE}.xa';

    expect 'CS05_NO_MISMATCH_GLUE_ZONE';
    forbid_others;
};

scenario 'CHILD-ZONE-LAME-{1..3}' => sub {
    expect 'CS05_CHILD_ZONE_LAME';
    forbid_others;
};

scenario 'EXTRA-ADDRESS-CHILD' => sub {
    expect 'CS05_EXTRA_ADDR_CHILD';
    forbid_others;
};

scenario 'ID-ADDR-MISMATCH-1' => sub {
    expect 'CS05_ID_ADDR_MISMATCH';
    forbid_others;
};

scenario 'ID-ADDR-MISSING-{1..2}' => sub {
    expect 'CS05_ID_ADDR_MISSING';
    forbid_others;
};

scenario 'INCONSISTENT-DELEGATION-{1..2}' => sub {
    zone 'child.{SCENARIO}.{TESTCASE}.xa';

    expect 'CS05_INCONSISTENT_DELEGATION';
    expect 'CS05_DELEGATION';
    forbid_others;
};

scenario 'MISSING-GLUE-FOR-NS-1' => sub {
    zone 'child.{SCENARIO}.{TESTCASE}.xa';

    expect 'CS05_MISSING_GLUE_FOR_NS';
    forbid_others;
};

scenario 'MISSING-GLUE-FOR-NS-2' => sub {
    fake_ns 'ns1.missing-glue-for-ns-2.consistency05.xa';
    fake_ns 'ns2.missing-glue-for-ns-2.consistency05.xa' => '127.14.5.32', 'fda1:b2:c3:0:127:14:5:32';
    
    expect 'CS05_MISSING_GLUE_FOR_NS_UNDEL';
    forbid_others;
};

scenario 'NO-NS-ADDR-CHILD-1' => sub {
    zone 'child.{SCENARIO}.{TESTCASE}.xa';

    expect 'CS05_NO_NS_ADDR_CHILD';
    expect 'CS05_MISSING_GLUE_FOR_NS';
    forbid_others;
};

scenario 'NO-NS-ADDR-CHILD-2' => sub {
    zone 'child.{SCENARIO}.{TESTCASE}.xa';

    expect 'CS05_NO_NS_ADDR_CHILD';
    forbid_others;
};

scenario 'OOD-ADDR-MISMATCH' => sub {
    zone 'child.{SCENARIO}.{TESTCASE}.xa';

    expect 'CS05_OOD_ADDR_MISMATCH';
    forbid_others;
};

scenario 'ROOT-MATCH-1' => sub {
    zone '.';
    
    expect 'CS05_NO_MISMATCH_GLUE_ZONE';
    forbid_others;
};

scenario 'ROOT-MISSING-GLUE-UNDEL-1' => sub {
    zone '.';

    fake_ns 'ns1';
    fake_ns 'ns2' => '127.14.5.66', 'fda1:b2:c3:0:127:14:5:66';
    
    expect 'CS05_MISSING_GLUE_FOR_ROOT_NS';
    forbid_others;
};

# Specific hintfile (test-zone-data/Consistency-TP/consistency05/Z-ROOT-MATCH-1-hintfile.zone)
root_hints 'ns1' => [ qw(127.14.5.63 fda1:b2:c3:0:127:14:5:63) ],
           'ns2' => [ qw(127.14.5.64 fda1:b2:c3:0:127:14:5:64) ];

scenario 'Z-ROOT-MATCH-1' => sub {
    zone '.';

    fake_ns 'ns1' => '127.14.5.61', 'fda1:b2:c3:0:127:14:5:61';
    fake_ns 'ns2' => '127.14.5.62', 'fda1:b2:c3:0:127:14:5:62';
    
    expect 'CS05_NO_MISMATCH_GLUE_ZONE';
    forbid_others;
};

# Specific hintfile (test-zone-data/Consistency-TP/consistency05/Z-ROOT-INCOMPLETE-HINT-hintfile.zone)
root_hints 'ns1' => [ ],
           'ns2' => [ qw(127.14.5.62 fda1:b2:c3:0:127:14:5:62) ];

scenario 'Z-ROOT-INCOMPLETE-HINT' => sub {
    zone '.';
    
    expect 'CS05_MISSING_GLUE_FOR_ROOT_NS';
    forbid_others;
};

no_more_scenarios;
