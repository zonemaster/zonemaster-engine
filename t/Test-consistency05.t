use strict;
use warnings;

use Test::More;
use File::Basename;
use File::Spec::Functions qw( rel2abs );
use lib dirname( rel2abs( $0 ) );

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Nameserver} );
    use_ok( q{Zonemaster::Engine::Test::Consistency} );
    use_ok( q{TestUtil}, qw( perform_testcase_testing ) );
}

###########
# consistency05 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/Consistency-TP/consistency05.md
# (when https://github.com/zonemaster/zonemaster/pull/1213 is merged)

my $test_module = q{Consistency};
my $test_case = 'consistency05';
my @all_tags = qw(ADDRESSES_MATCH
                  IN_BAILIWICK_ADDR_MISMATCH
                  OUT_OF_BAILIWICK_ADDR_MISMATCH
                  EXTRA_ADDRESS_CHILD
                  CHILD_ZONE_LAME
                  CHILD_NS_FAILED
                  NO_RESPONSE);

# Common hint file (test-zone-data/COMMON/hintfile)
Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
Zonemaster::Engine::Recursor->add_fake_addresses( '.',
    { 'ns1' => [ '127.1.0.1', 'fda1:b2:c3::127:1:0:1' ],
      'ns2' => [ '127.1.0.2', 'fda1:b2:c3::127:1:0:2' ],
    }
);

# Test zone scenarios
# - Documentation: L<TestUtil/perform_testcase_testing()>
# - Format: { SCENARIO_NAME => [
#     testable,
#     zone_name,
#     [ MANDATORY_MESSAGE_TAGS ],
#     [ FORBIDDEN_MESSAGE_TAGS ],
#     [ UNDELEGATED_NS ],
#     [ UNDELEGATED_DS ],
#   ] }
#
# - One of MANDATORY_MESSAGE_TAGS and FORBIDDEN_MESSAGE_TAGS may be undefined.
#   See documentation for the meaning of that.

# Scenarios CHILD-ZONE-LAME-1 and IB-ADDR-MISMATCH-3 cannot be tested due to a bug in the implementation. See
# https://github.com/zonemaster/zonemaster-engine/issues/1301

# Scenario IB-ADDR-MISMATCH-4 cannot be tested, see
# https://github.com/zonemaster/zonemaster-engine/issues/1349


my %subtests = (
    'ADDRESSES-MATCH-1' => [
        1,
        q(addresses-match-1.consistency05.xa),
        [ qw(ADDRESSES_MATCH) ],
        undef,
        [],
        []
    ],
    'ADDRESSES-MATCH-2' => [
        1,
        q(addresses-match-2.consistency05.xa),
        [ qw(ADDRESSES_MATCH) ],
        undef,
        [],
        []
    ],
    'ADDRESSES-MATCH-3' => [
        1,
        q(addresses-match-3.consistency05.xa),
        [ qw(ADDRESSES_MATCH CHILD_NS_FAILED) ],
        undef,
        [],
        []
    ],
    'ADDRESSES-MATCH-4' => [
        1,
        q(addresses-match-4.consistency05.xa),
        [ qw(ADDRESSES_MATCH CHILD_NS_FAILED) ],
        undef,
        [],
        []
    ],
    'ADDRESSES-MATCH-5' => [
        1,
        q(addresses-match-5.consistency05.xa),
        [ qw(ADDRESSES_MATCH NO_RESPONSE) ],
        undef,
        [],
        []
    ],
    'ADDRESSES-MATCH-6' => [
        1,
        q(child.addresses-match-6.consistency05.xa),
        [ qw(ADDRESSES_MATCH) ],
        undef,
        [],
        []
    ],
    'ADDRESSES-MATCH-7' => [
        1,
        q(addresses-match-7.consistency05.xa),
        [ qw(ADDRESSES_MATCH) ],
        undef,
        [],
        []
    ],
    'ADDR-MATCH-DEL-UNDEL-1' => [
        1,
        q(addr-match-del-undel-1.consistency05.xa),
        [ qw(ADDRESSES_MATCH) ],
        undef,
        [ qw(ns3.addr-match-del-undel-1.consistency05.xa/127.14.5.33 ns3.addr-match-del-undel-1.consistency05.xa/fda1:b2:c3:0:127:14:5:33 ns4.addr-match-del-undel-1.consistency05.xa/127.14.5.34 ns4.addr-match-del-undel-1.consistency05.xa/fda1:b2:c3:0:127:14:5:34) ],
        []
    ],
    'ADDR-MATCH-DEL-UNDEL-2' => [
        1,
        q(addr-match-del-undel-2.consistency05.xa),
        [ qw(ADDRESSES_MATCH) ],
        undef,
        [ qw(ns3.addr-match-del-undel-2.consistency05.xb ns4.addr-match-del-undel-2.consistency05.xb) ],
        []
    ],
    'ADDR-MATCH-NO-DEL-UNDEL-1' => [
        1,
        q(addr-match-no-del-undel-1.consistency05.xa),
        [ qw(ADDRESSES_MATCH) ],
        undef,
        [ qw(ns1.addr-match-no-del-undel-1.consistency05.xa/127.14.5.31 ns1.addr-match-no-del-undel-1.consistency05.xa/fda1:b2:c3:0:127:14:5:31 ns2.addr-match-no-del-undel-1.consistency05.xa/127.14.5.32 ns2.addr-match-no-del-undel-1.consistency05.xa/fda1:b2:c3:0:127:14:5:32) ],
        []
    ],
    'ADDR-MATCH-NO-DEL-UNDEL-2' => [
        1,
        q(addr-match-no-del-undel-2.consistency05.xa),
        [ qw(ADDRESSES_MATCH) ],
        undef,
        [ qw(ns3.addr-match-no-del-undel-2.consistency05.xb ns4.addr-match-no-del-undel-2.consistency05.xb) ],
        []
    ],
    'CHILD-ZONE-LAME-1' => [
        0,
        q(child-zone-lame-1.consistency05.xa),
        [ qw(CHILD_ZONE_LAME NO_RESPONSE) ],
        undef,
        [],
        []
    ],
    'CHILD-ZONE-LAME-2' => [
        1,
        q(child-zone-lame-2.consistency05.xa),
        [ qw(CHILD_ZONE_LAME CHILD_NS_FAILED) ],
        undef,
        [],
        []
    ],
    'IB-ADDR-MISMATCH-1' => [
        1,
        q(ib-addr-mismatch-1.consistency05.xa),
        [ qw(IN_BAILIWICK_ADDR_MISMATCH EXTRA_ADDRESS_CHILD) ],
        undef,
        [],
        []
    ],
    'IB-ADDR-MISMATCH-2' => [
        1,
        q(ib-addr-mismatch-2.consistency05.xa),
        [ qw(IN_BAILIWICK_ADDR_MISMATCH) ],
        undef,
        [],
        []
    ],
    'IB-ADDR-MISMATCH-3' => [
        0,
        q(ib-addr-mismatch-3.consistency05.xa),
        [ qw(IN_BAILIWICK_ADDR_MISMATCH NO_RESPONSE) ],
        undef,
        [],
        []
    ],
    'IB-ADDR-MISMATCH-4' => [
        0,
        q(ib-addr-mismatch-4.consistency05.xa),
        [ qw(IN_BAILIWICK_ADDR_MISMATCH) ],
        undef,
        [],
        []
    ],
    'OOB-ADDR-MISMATCH' => [
        1,
        q(child.oob-addr-mismatch.consistency05.xa),
        [ qw(OUT_OF_BAILIWICK_ADDR_MISMATCH) ],
        undef,
        [],
        []
    ],
    'EXTRA-ADDRESS-CHILD' => [
        1,
        q(extra-address-child.consistency05.xa),
        [ qw(EXTRA_ADDRESS_CHILD) ],
        undef,
        [],
        []
    ],
);

###########

my $datafile = 't/' . basename ($0, '.t') . '.data';

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

Zonemaster::Engine::Profile->effective->merge( Zonemaster::Engine::Profile->from_json( qq({ "test_cases": [ "$test_case" ] }) ) );

perform_testcase_testing( $test_case, $test_module, \@all_tags, \%subtests, $ENV{ZONEMASTER_SELECTED_SCENARIOS}, $ENV{ZONEMASTER_DISABLED_SCENARIOS} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
