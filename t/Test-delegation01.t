use strict;
use warnings;

use File::Basename;
use File::Spec::Functions qw( rel2abs );
use lib dirname( rel2abs( $0 ) );
use TestUtil::DSL;

###########
# Delegation01 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/Delegation-TP/delegation01.md
testing_test_case 'Delegation', 'delegation01';

all_tags qw(ENOUGH_IPV4_NS_CHILD
            ENOUGH_IPV4_NS_DEL
            ENOUGH_IPV6_NS_CHILD
            ENOUGH_IPV6_NS_DEL
            ENOUGH_NS_CHILD
            ENOUGH_NS_DEL
            NOT_ENOUGH_IPV4_NS_CHILD
            NOT_ENOUGH_IPV4_NS_DEL
            NOT_ENOUGH_IPV6_NS_CHILD
            NOT_ENOUGH_IPV6_NS_DEL
            NOT_ENOUGH_NS_CHILD
            NOT_ENOUGH_NS_DEL
            NO_IPV4_NS_CHILD
            NO_IPV4_NS_DEL
            NO_IPV6_NS_CHILD
            NO_IPV6_NS_DEL);

# Specific hint file (https://github.com/zonemaster/zonemaster/blob/master/test-zone-data/Delegation-TP/delegation01/hintfile.zone)
root_hints 'root-ns1.xa' => [ qw(127.16.1.27 fda1:b2:c3::127:16:1:27) ],
           'root-ns2.xa' => [ qw(127.16.1.28 fda1:b2:c3::127:16:1:28) ];

zone_name_template '{SCENARIO}.{TESTCASE}.xa';

# Test zone scenarios
scenario 'ENOUGH-{1..3}' => sub {
    expect qw(ENOUGH_IPV4_NS_CHILD
              ENOUGH_IPV4_NS_DEL
              ENOUGH_IPV6_NS_CHILD
              ENOUGH_IPV6_NS_DEL
              ENOUGH_NS_CHILD
              ENOUGH_NS_DEL);
    forbid_others;
};

scenario 'ENOUGH-DEL-NOT-CHILD' => sub {
    todo; # FIXME: why?

    expect qw(ENOUGH_IPV4_NS_DEL
              ENOUGH_IPV6_NS_DEL
              ENOUGH_NS_DEL
              NOT_ENOUGH_IPV4_NS_CHILD
              NOT_ENOUGH_IPV6_NS_CHILD
              NOT_ENOUGH_NS_CHILD);
    forbid_others;
};

scenario 'ENOUGH-CHILD-NOT-DEL' => sub {
    expect qw(ENOUGH_IPV4_NS_CHILD
              ENOUGH_IPV6_NS_CHILD
              ENOUGH_NS_CHILD
              NOT_ENOUGH_IPV4_NS_DEL
              NOT_ENOUGH_IPV6_NS_DEL
              NOT_ENOUGH_NS_DEL);
    forbid_others;
};

scenario 'IPV6-AND-DEL-OK-NO-IPV4-CHILD' => sub {
    todo; # FIXME: why?

    expect qw(ENOUGH_IPV4_NS_DEL
              ENOUGH_IPV6_NS_CHILD
              ENOUGH_IPV6_NS_DEL
              ENOUGH_NS_CHILD
              ENOUGH_NS_DEL
              NO_IPV4_NS_CHILD);
    forbid_others;
};

scenario 'IPV4-AND-DEL-OK-NO-IPV6-CHILD' => sub {
    todo; # FIXME: why?
    
    expect qw(ENOUGH_IPV4_NS_DEL
              ENOUGH_IPV4_NS_CHILD
              ENOUGH_IPV6_NS_DEL
              ENOUGH_NS_CHILD
              ENOUGH_NS_DEL
              NO_IPV6_NS_CHILD);
    forbid_others;
};

scenario 'NO-IPV4-{1..3}' => sub {
    expect qw(ENOUGH_IPV6_NS_CHILD
              ENOUGH_IPV6_NS_DEL
              ENOUGH_NS_CHILD
              ENOUGH_NS_DEL
              NO_IPV4_NS_CHILD
              NO_IPV4_NS_DEL);
    forbid_others;
};

scenario 'NO-IPV6-{1..3}' => sub {
    expect qw(ENOUGH_IPV4_NS_CHILD
              ENOUGH_IPV4_NS_DEL
              ENOUGH_NS_CHILD
              ENOUGH_NS_DEL
              NO_IPV6_NS_CHILD
              NO_IPV6_NS_DEL);
    forbid_others;
};

scenario 'MISMATCH-DELEGATION-CHILD-1' => sub {
    todo; # FIXME: why?

    expect qw(ENOUGH_IPV4_NS_CHILD
              NOT_ENOUGH_IPV4_NS_DEL
              ENOUGH_IPV6_NS_CHILD
              NOT_ENOUGH_IPV6_NS_DEL
              ENOUGH_NS_CHILD
              ENOUGH_NS_DEL);
    forbid_others;
};

scenario 'MISMATCH-DELEGATION-CHILD-2' => sub {
    todo; # FIXME: why?

    expect qw(NOT_ENOUGH_IPV4_NS_CHILD
              ENOUGH_IPV4_NS_DEL
              NOT_ENOUGH_IPV6_NS_CHILD
              ENOUGH_IPV6_NS_DEL
              ENOUGH_NS_CHILD
              ENOUGH_NS_DEL);
    forbid_others;
};

no_more_scenarios;
