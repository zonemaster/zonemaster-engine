use strict;
use warnings;

use File::Basename;
use File::Spec::Functions qw( rel2abs );
use lib dirname( rel2abs( $0 ) );
use TestUtil::DSL;

###########
# consistency06 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/Consistency-TP/consistency06.md

testing_test_case 'Consistency', 'consistency06';

all_tags qw(ONE_SOA_MNAME
            NO_RESPONSE
            NO_RESPONSE_SOA_QUERY
            MULTIPLE_SOA_MNAMES);

# Common hint file (test-zone-data/COMMON/hintfile)
root_hints 'ns1' => [ qw(127.1.0.1 fda1:b2:c3::127:1:0:1) ],
           'ns2' => [ qw(127.1.0.2 fda1:b2:c3::127:1:0:2) ];

zone_name_template '{SCENARIO}.{TESTCASE}.xa';

scenario 'ONE-SOA-MNAME-1' => sub {
    expect 'ONE_SOA_MNAME';
    forbid_others;
};

scenario 'ONE-SOA-MNAME-2' => sub {
    expect qw(ONE_SOA_MNAME NO_RESPONSE);
    forbid_others;
};

scenario 'ONE-SOA-MNAME-3' => sub {
    expect qw(ONE_SOA_MNAME NO_RESPONSE_SOA_QUERY);
    forbid_others;
};

scenario 'ONE-SOA-MNAME-4' => sub {
    todo 'see https://github.com/zonemaster/zonemaster-engine/issues/1300';

    expect qw(ONE_SOA_MNAME NO_RESPONSE);
    forbid_others;
};

scenario 'MULTIPLE-SOA-MNAMES-1' => sub {
    expect 'MULTIPLE_SOA_MNAMES';
    forbid_others;
};

scenario 'MULTIPLE-SOA-MNAMES-2' => sub {
    expect qw(MULTIPLE_SOA_MNAMES NO_RESPONSE);
    forbid_others;
};

scenario 'MULT-SOA-MNAMES-NO-DEL-UNDEL-1' => sub {
    fake_ns 'ns1.mult-soa-mnames-no-del-undel-1.consistency06.xa' => '127.14.6.31', 'fda1:b2:c3:0:127:14:6:31';
    fake_ns 'ns2.mult-soa-mnames-no-del-undel-1.consistency06.xa' => '127.14.6.32', 'fda1:b2:c3:0:127:14:6:32';

    expect 'MULTIPLE_SOA_MNAMES';
    forbid_others;
};

scenario 'MULT-SOA-MNAMES-NO-DEL-UNDEL-2' => sub {
    fake_ns 'ns3.mult-soa-mnames-no-del-undel-2.consistency06.xb';
    fake_ns 'ns4.mult-soa-mnames-no-del-undel-2.consistency06.xb';

    expect 'MULTIPLE_SOA_MNAMES';
    forbid_others;
};

scenario 'NO-RESPONSE' => sub {
    todo 'see https://github.com/zonemaster/zonemaster-engine/issues/1300';

    expect 'NO_RESPONSE';
    forbid_others;
};

no_more_scenarios;
