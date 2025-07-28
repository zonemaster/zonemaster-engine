use strict;
use warnings;

use File::Basename;
use File::Spec::Functions qw( rel2abs );
use lib dirname( rel2abs( $0 ) );
use TestUtil::DSL;

###########
# basic01 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/Basic-TP/basic01.md
testing_test_case 'Basic', 'basic01';

all_tags qw(B01_CHILD_IS_ALIAS
            B01_CHILD_FOUND
            B01_INCONSISTENT_ALIAS
            B01_INCONSISTENT_DELEGATION
            B01_NO_CHILD
            B01_PARENT_DISREGARDED
            B01_PARENT_FOUND
            B01_PARENT_NOT_FOUND
            B01_PARENT_UNDETERMINED
            B01_ROOT_HAS_NO_PARENT
            B01_SERVER_ZONE_ERROR);

# Common hint file (test-zone-data/COMMON/hintfile)
root_hints 'ns1' => [ qw(127.1.0.1 fda1:b2:c3::127:1:0:1) ],
           'ns2' => [ qw(127.1.0.2 fda1:b2:c3::127:1:0:2) ];

# Test zone scenarios
zone_name_template 'child.parent.{SCENARIO}.{TESTCASE}.xa';

scenario qw(GOOD-1 GOOD-MIXED-{1..2} GOOD-PARENT-HOST-1 GOOD-GRANDPARENT-HOST-1) => sub {
    expect qw(B01_CHILD_FOUND B01_PARENT_FOUND);
    forbid_others;
};

scenario qw(GOOD-UNDEL-1 GOOD-MIXED-UNDEL-{1..2} NO-DEL-UNDEL-1 NO-DEL-MIXED-UNDEL-1) => sub {
    fake_ns 'ns3-undelegated-child.basic01.xa';
    fake_ns 'ns4-undelegated-child.basic01.xa';
    expect qw(B01_CHILD_FOUND B01_PARENT_DISREGARDED);
    forbid_others;
};

scenario 'NO-DEL-MIXED-UNDEL-2' => sub {
    zone 'child.w.x.parent.y.z.{SCENARIO}.{TESTCASE}.xa';
    fake_ns 'ns3-undelegated-child.basic01.xa';
    fake_ns 'ns4-undelegated-child.basic01.xa';
    expect qw(B01_CHILD_FOUND B01_PARENT_DISREGARDED);
    forbid_others;
};

scenario 'NO-CHILD-{1..2}' => sub {
    expect qw(B01_NO_CHILD B01_PARENT_FOUND);
    forbid_others;
};

scenario 'NO-CHLD-PAR-UNDETER-1' => sub {
    expect qw(B01_NO_CHILD B01_PARENT_FOUND B01_PARENT_UNDETERMINED);
    forbid_others;
};

scenario 'CHLD-FOUND-PAR-UNDET-1' => sub {
    expect qw(B01_CHILD_FOUND B01_PARENT_FOUND B01_PARENT_UNDETERMINED);
    forbid_others;
};

scenario 'CHLD-FOUND-INCONSIST-{1..3}' => sub {
    expect qw(B01_CHILD_FOUND B01_INCONSISTENT_DELEGATION B01_PARENT_FOUND);
    forbid_others;
};

scenario 'CHLD-FOUND-INCONSIST-4' => sub {
    expect qw(B01_CHILD_IS_ALIAS B01_CHILD_FOUND B01_INCONSISTENT_DELEGATION B01_PARENT_FOUND);
    forbid_others;
};

scenario 'CHLD-FOUND-INCONSIST-{5..8}' => sub {
    expect qw(B01_CHILD_FOUND B01_INCONSISTENT_DELEGATION B01_PARENT_FOUND);
    forbid_others;
};

scenario 'CHLD-FOUND-INCONSIST-9' => sub {
    expect qw(B01_CHILD_IS_ALIAS B01_CHILD_FOUND B01_INCONSISTENT_DELEGATION B01_PARENT_FOUND);
    forbid_others;
};

scenario 'CHLD-FOUND-INCONSIST-10' => sub {
    expect qw(B01_CHILD_FOUND B01_INCONSISTENT_DELEGATION B01_PARENT_FOUND);
    forbid_others;
};

scenario qw(NO-DEL-UNDEL-NO-PAR-1 NO-DEL-UNDEL-PAR-UND-1) => sub {
    fake_ns 'ns3-undelegated-child.basic01.xa';
    fake_ns 'ns4-undelegated-child.basic01.xa';
    expect qw(B01_CHILD_FOUND B01_PARENT_DISREGARDED);
    forbid_others;
};

scenario 'NO-CHLD-NO-PAR-1' => sub {
    expect qw(B01_NO_CHILD B01_PARENT_NOT_FOUND B01_SERVER_ZONE_ERROR);
    forbid_others;
};

scenario 'CHILD-ALIAS-1' => sub {
    expect qw(B01_CHILD_IS_ALIAS B01_NO_CHILD B01_PARENT_FOUND);
    forbid_others;
};

scenario 'CHILD-ALIAS-2' => sub {
    expect qw(B01_CHILD_IS_ALIAS B01_NO_CHILD B01_INCONSISTENT_ALIAS
              B01_PARENT_FOUND);
    forbid_others;
};

scenario 'ZONE-ERR-GRANDPARENT-{1..3}' => sub {
    expect qw(B01_CHILD_FOUND B01_PARENT_FOUND B01_SERVER_ZONE_ERROR);
    forbid_others;
};

scenario 'ROOT-ZONE' => sub {
    zone '.';
    expect qw(B01_CHILD_FOUND B01_ROOT_HAS_NO_PARENT);
    forbid_others;
};

no_more_scenarios;
