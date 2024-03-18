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

# Common hint file (test-zone-data/COMMON/hintfile)
Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
Zonemaster::Engine::Recursor->add_fake_addresses( '.',
    { 'ns1' => [ '127.1.0.1', 'fda1:b2:c3::127:1:0:1' ],
      'ns2' => [ '127.1.0.2', 'fda1:b2:c3::127:1:0:2' ],
    }
);

# Test scenarios
# - Documentation: L<TestUtil/perform_testcase_testing()>
# - Format: { SCENARIO_NAME => [ zone_name, [ MANDATORY_MESSAGE_TAGS ], [ FORBIDDEN_MESSAGE_TAGS ], testable ] }
#
# Scenarios CHILD-ZONE-LAME-1 and IB-ADDR-MISMATCH-3 cannot be tested due to a bug in the implementation. See
# https://github.com/zonemaster/zonemaster-engine/issues/1301
#
my %subtests = (
    'ADDRESSES-MATCH-4' => [
        q(addresses-match-4.consistency05.xa),
        [ qw(ADDRESSES_MATCH CHILD_NS_FAILED) ],
        [ qw(IN_BAILIWICK_ADDR_MISMATCH OUT_OF_BAILIWICK_ADDR_MISMATCH EXTRA_ADDRESS_CHILD CHILD_ZONE_LAME NO_RESPONSE) ],
        1,
    ],
    'CHILD-ZONE-LAME-1' => [
        q(child-zone-lame-1.consistency05.xa),
        [ qw(CHILD_ZONE_LAME NO_RESPONSE) ],
        [ qw(IN_BAILIWICK_ADDR_MISMATCH OUT_OF_BAILIWICK_ADDR_MISMATCH EXTRA_ADDRESS_CHILD CHILD_NS_FAILED ADDRESSES_MATCH) ],
        0,
    ],
    'ADDRESSES-MATCH-1' => [
        q(addresses-match-1.consistency05.xa),
        [ qw(ADDRESSES_MATCH) ],
        [ qw(IN_BAILIWICK_ADDR_MISMATCH OUT_OF_BAILIWICK_ADDR_MISMATCH EXTRA_ADDRESS_CHILD CHILD_ZONE_LAME CHILD_NS_FAILED NO_RESPONSE) ],
        1,
    ],
    'IB-ADDR-MISMATCH-2' => [
        q(ib-addr-mismatch-2.consistency05.xa),
        [ qw(IN_BAILIWICK_ADDR_MISMATCH) ],
        [ qw(OUT_OF_BAILIWICK_ADDR_MISMATCH EXTRA_ADDRESS_CHILD CHILD_ZONE_LAME CHILD_NS_FAILED NO_RESPONSE ADDRESSES_MATCH) ],
        1,
    ],
    'ADDRESSES-MATCH-5' => [
        q(addresses-match-5.consistency05.xa),
        [ qw(ADDRESSES_MATCH NO_RESPONSE) ],
        [ qw(IN_BAILIWICK_ADDR_MISMATCH OUT_OF_BAILIWICK_ADDR_MISMATCH EXTRA_ADDRESS_CHILD CHILD_ZONE_LAME CHILD_NS_FAILED) ],
        1,
    ],
    'IB-ADDR-MISMATCH-1' => [
        q(ib-addr-mismatch-1.consistency05.xa),
        [ qw(IN_BAILIWICK_ADDR_MISMATCH EXTRA_ADDRESS_CHILD) ],
        [ qw(OUT_OF_BAILIWICK_ADDR_MISMATCH CHILD_ZONE_LAME CHILD_NS_FAILED NO_RESPONSE ADDRESSES_MATCH) ],
        1,
    ],
    'CHILD-ZONE-LAME-2' => [
        q(child-zone-lame-2.consistency05.xa),
        [ qw(CHILD_ZONE_LAME CHILD_NS_FAILED) ],
        [ qw(IN_BAILIWICK_ADDR_MISMATCH OUT_OF_BAILIWICK_ADDR_MISMATCH EXTRA_ADDRESS_CHILD ADDRESSES_MATCH NO_RESPONSE) ],
        1,
    ],
    'ADDRESSES-MATCH-6' => [
        q(child.addresses-match-6.consistency05.xa),
        [ qw(ADDRESSES_MATCH) ],
        [ qw(IN_BAILIWICK_ADDR_MISMATCH OUT_OF_BAILIWICK_ADDR_MISMATCH EXTRA_ADDRESS_CHILD CHILD_ZONE_LAME CHILD_NS_FAILED NO_RESPONSE) ],
        1,
    ],
    'ADDRESSES-MATCH-2' => [
        q(addresses-match-2.consistency05.xa),
        [ qw(ADDRESSES_MATCH) ],
        [ qw(IN_BAILIWICK_ADDR_MISMATCH OUT_OF_BAILIWICK_ADDR_MISMATCH EXTRA_ADDRESS_CHILD CHILD_ZONE_LAME CHILD_NS_FAILED NO_RESPONSE) ],
        1,
    ],
    'IB-ADDR-MISMATCH-3' => [
        q(ib-addr-mismatch-3.consistency05.xa),
        [ qw(IN_BAILIWICK_ADDR_MISMATCH NO_RESPONSE) ],
        [ qw(OUT_OF_BAILIWICK_ADDR_MISMATCH EXTRA_ADDRESS_CHILD CHILD_ZONE_LAME CHILD_NS_FAILED NO_RESPONSE ADDRESSES_MATCH) ],
        0,
    ],
    'ADDRESSES-MATCH-7' => [
        q(addresses-match-7.consistency05.xa),
        [ qw(ADDRESSES_MATCH) ],
        [ qw(IN_BAILIWICK_ADDR_MISMATCH OUT_OF_BAILIWICK_ADDR_MISMATCH EXTRA_ADDRESS_CHILD CHILD_ZONE_LAME CHILD_NS_FAILED NO_RESPONSE) ],
        1,
    ],
    'EXTRA-ADDRESS-CHILD' => [
        q(extra-address-child.consistency05.xa),
        [ qw(EXTRA_ADDRESS_CHILD) ],
        [ qw(IN_BAILIWICK_ADDR_MISMATCH OUT_OF_BAILIWICK_ADDR_MISMATCH CHILD_ZONE_LAME CHILD_NS_FAILED NO_RESPONSE ADDRESSES_MATCH) ],
        1,
    ],
    'OOB-ADDR-MISMATCH' => [
        q(child.oob-addr-mismatch.consistency05.xa),
        [ qw(OUT_OF_BAILIWICK_ADDR_MISMATCH) ],
        [ qw(IN_BAILIWICK_ADDR_MISMATCH EXTRA_ADDRESS_CHILD CHILD_ZONE_LAME CHILD_NS_FAILED NO_RESPONSE ADDRESSES_MATCH) ],
        1,
    ],
    'ADDRESSES-MATCH-3' => [
        q(addresses-match-3.consistency05.xa),
        [ qw(ADDRESSES_MATCH CHILD_NS_FAILED) ],
        [ qw(IN_BAILIWICK_ADDR_MISMATCH OUT_OF_BAILIWICK_ADDR_MISMATCH EXTRA_ADDRESS_CHILD CHILD_ZONE_LAME NO_RESPONSE) ],
        1,
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

perform_testcase_testing( $test_case, $test_module, %subtests );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
