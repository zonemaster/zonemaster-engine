use strict;
use warnings;

use File::Basename;
use File::Spec::Functions qw( rel2abs );
use lib dirname( rel2abs( $0 ) );
use TestUtil::DSL;

###########
# connectivity04 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/Connectivity-TP/connectivity04.md
testing_test_case 'Connectivity', 'connectivity04';

all_tags qw(CN04_EMPTY_PREFIX_SET
            CN04_ERROR_PREFIX_DATABASE
            CN04_IPV4_DIFFERENT_PREFIX
            CN04_IPV4_SAME_PREFIX
            CN04_IPV4_SINGLE_PREFIX
            CN04_IPV6_DIFFERENT_PREFIX
            CN04_IPV6_SAME_PREFIX
            CN04_IPV6_SINGLE_PREFIX);

# Specific hint file (https://github.com/zonemaster/zonemaster/blob/master/test-zone-data/Connectivity-TP/connectivity04/hintfile.zone)
root_hints 'root-ns1.xa' => [ qw(127.13.4.23 fda1:b2:c3::127:13:4:23) ],
           'root-ns2.xa' => [ qw(127.13.4.24 fda1:b2:c3::127:13:4:24) ];

# Test zone scenarios
zone_name_template '{SCENARIO}.{TESTCASE}.xa';

scenario 'GOOD-1' => sub {
    expect qw(CN04_IPV4_DIFFERENT_PREFIX CN04_IPV6_DIFFERENT_PREFIX);
    forbid_others;
};

scenario 'GOOD-2' => sub {
    expect qw(CN04_IPV4_DIFFERENT_PREFIX);
    forbid_others;
};

scenario 'GOOD-3' => sub {
    expect qw(CN04_IPV6_DIFFERENT_PREFIX);
    forbid_others;
};

scenario 'EMPTY-PREFIX-SET-{1..2}' => sub {
    expect qw(CN04_EMPTY_PREFIX_SET);
    forbid_others;
};

scenario 'ERROR-PREFIX-DATABASE-{1..2}' => sub {
    expect qw(CN04_ERROR_PREFIX_DATABASE);
    forbid_others;
};

# scenario 'ERROR-PREFIX-DATABASE-3' => tested out of order; see end of file.

# scenario 'ERROR-PREFIX-DATABASE-{4..5}' => do not exist

scenario 'ERROR-PREFIX-DATABASE-6' => sub {
    expect qw(CN04_IPV4_DIFFERENT_PREFIX CN04_IPV6_DIFFERENT_PREFIX CN04_ERROR_PREFIX_DATABASE);
    forbid_others;
};

scenario 'ERROR-PREFIX-DATABASE-{7..8}' => sub {
    expect qw(CN04_ERROR_PREFIX_DATABASE);
    forbid_others;
};

scenario 'HAS-NON-ASN-TXT-1' => sub {
    expect qw(CN04_IPV4_DIFFERENT_PREFIX CN04_IPV6_DIFFERENT_PREFIX);
    forbid_others;
};

scenario 'HAS-NON-ASN-TXT-2' => sub {
    expect qw(CN04_EMPTY_PREFIX_SET);
    forbid_others;
};

scenario 'IPV4-ONE-PREFIX-1' => sub {
    expect qw(CN04_IPV4_SAME_PREFIX CN04_IPV4_SINGLE_PREFIX);
    forbid_others;
};

scenario 'IPV4-TWO-PREFIXES-1' => sub {
    expect qw(CN04_IPV4_SAME_PREFIX CN04_IPV4_DIFFERENT_PREFIX);
    forbid_others;
};

scenario 'IPV6-ONE-PREFIX-1' => sub {
    expect qw(CN04_IPV6_SAME_PREFIX CN04_IPV6_SINGLE_PREFIX);
    forbid_others;
};

scenario 'IPV6-TWO-PREFIXES-1' => sub {
    expect qw(CN04_IPV6_SAME_PREFIX CN04_IPV6_DIFFERENT_PREFIX);
    forbid_others;
};

scenario 'IPV4-SINGLE-NS-1' => sub {
    expect qw(CN04_IPV4_SINGLE_PREFIX CN04_IPV4_DIFFERENT_PREFIX);
    forbid_others;
};

scenario 'IPV6-SINGLE-NS-1' => sub {
    expect qw(CN04_IPV6_SINGLE_PREFIX CN04_IPV6_DIFFERENT_PREFIX);
    forbid_others;
};

scenario 'DOUBLE-PREFIX-1' => sub {
    expect qw(CN04_IPV4_DIFFERENT_PREFIX CN04_IPV6_DIFFERENT_PREFIX);
    forbid_others;
};

scenario 'DOUBLE-PREFIX-2' => sub {
    expect qw(CN04_IPV4_DIFFERENT_PREFIX CN04_IPV6_DIFFERENT_PREFIX);
    forbid_others;
};

# The scenario below needs to be tested out of order, and with an empty cache,
# because a previously cached non-response from the ASN lookup zone (which was
# intentional) causes negative side effects when testing this scenario.

clear_cache;

scenario 'ERROR-PREFIX-DATABASE-3' => sub {
    expect qw(CN04_ERROR_PREFIX_DATABASE);
    forbid_others;
};

no_more_scenarios;
