use strict;
use warnings;

use Test::More;
use File::Basename;
use File::Spec::Functions qw( rel2abs );
use lib dirname( rel2abs( $0 ) );

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::DNSSEC} );
    use_ok( q{TestUtil}, qw( perform_testcase_testing ) );
}

###########
# DNSSEC01 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/DNSSEC-TP/dnssec01.md
my $test_module = 'DNSSEC';
my $test_case = 'dnssec01';
my @all_tags = qw(
                    DS01_DS_ALGO_2_MISSING
                    DS01_DS_ALGO_DEPRECATED
                    DS01_DS_ALGO_NOT_DS
                    DS01_DS_ALGO_OK
                    DS01_DS_ALGO_PRIVATE
                    DS01_DS_ALGO_RESERVED
                    DS01_DS_ALGO_UNASSIGNED
                    DS01_NO_RESPONSE
                    DS01_PARENT_SERVER_NO_DS
                    DS01_PARENT_ZONE_NO_DS
                    DS01_ROOT_N_NO_UNDEL_DS
                    DS01_UNDEL_N_NO_UNDEL_DS
                );

# Specific hint file (https://github.com/zonemaster/zonemaster/blob/master/test-zone-data/DNSSEC-TP/dnssec01/hintfile.zone)
Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
Zonemaster::Engine::Recursor->add_fake_addresses( '.',
    { 'root-ns1.xa' => [ '127.15.1.27', 'fda1:b2:c3::127:15:1:27' ],
      'root-ns2.xa' => [ '127.15.1.28', 'fda1:b2:c3::127:15:1:28' ],
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

my %subtests = (
    'ALGO-DEPRECATED-1' => [
        1,
        q(algo-deprecated-1.dnssec01.xa),
        [ qw( DS01_DS_ALGO_DEPRECATED DS01_DS_ALGO_2_MISSING ) ],
        undef,
        [],
        [],
    ],
    'ALGO-DEPRECATED-3' => [
        1,
        q(algo-deprecated-3.dnssec01.xa),
        [ qw( DS01_DS_ALGO_DEPRECATED DS01_DS_ALGO_2_MISSING ) ],
        undef,
        [],
        [],
    ],
    'ALGO-NOT-DS-0' => [
        1,
        q(algo-not-ds-0.dnssec01.xa),
        [ qw( DS01_DS_ALGO_NOT_DS DS01_DS_ALGO_2_MISSING ) ],
        undef,
        [],
        [],
    ],
    'ALGO-OK-2' => [
        1,
        q(algo-ok-2.dnssec01.xa),
        [ qw( DS01_DS_ALGO_OK ) ],
        undef,
        [],
        [],
    ],
    'ALGO-OK-4' => [
        1,
        q(algo-ok-4.dnssec01.xa),
        [ qw( DS01_DS_ALGO_OK DS01_DS_ALGO_2_MISSING ) ],
        undef,
        [],
        [],
    ],
    'ALGO-OK-5' => [
        1,
        q(algo-ok-5.dnssec01.xa),
        [ qw( DS01_DS_ALGO_OK DS01_DS_ALGO_2_MISSING ) ],
        undef,
        [],
        [],
    ],
    'ALGO-OK-6' => [
        1,
        q(algo-ok-6.dnssec01.xa),
        [ qw( DS01_DS_ALGO_OK DS01_DS_ALGO_2_MISSING ) ],
        undef,
        [],
        [],
    ],
    'ALGO-PRIVATE-253' => [
        1,
        q(algo-private-253.dnssec01.xa),
        [ qw( DS01_DS_ALGO_PRIVATE DS01_DS_ALGO_2_MISSING ) ],
        undef,
        [],
        [],
    ],
    'ALGO-PRIVATE-254' => [
        1,
        q(algo-private-254.dnssec01.xa),
        [ qw( DS01_DS_ALGO_PRIVATE DS01_DS_ALGO_2_MISSING ) ],
        undef,
        [],
        [],
    ],
    'ALGO-RESERVED-128' => [
        1,
        q(algo-reserved-128.dnssec01.xa),
        [ qw( DS01_DS_ALGO_RESERVED DS01_DS_ALGO_2_MISSING ) ],
        undef,
        [],
        [],
    ],
    'ALGO-RESERVED-188' => [
        1,
        q(algo-reserved-188.dnssec01.xa),
        [ qw( DS01_DS_ALGO_RESERVED DS01_DS_ALGO_2_MISSING ) ],
        undef,
        [],
        [],
    ],
    'ALGO-RESERVED-252' => [
        1,
        q(algo-reserved-252.dnssec01.xa),
        [ qw( DS01_DS_ALGO_RESERVED DS01_DS_ALGO_2_MISSING ) ],
        undef,
        [],
        [],
    ],
    'ALGO-UNASSIGNED-7' => [
        1,
        q(algo-unassigned-7.dnssec01.xa),
        [ qw( DS01_DS_ALGO_UNASSIGNED DS01_DS_ALGO_2_MISSING ) ],
        undef,
        [],
        [],
    ],
    'ALGO-UNASSIGNED-67' => [
        1,
        q(algo-unassigned-67.dnssec01.xa),
        [ qw( DS01_DS_ALGO_UNASSIGNED DS01_DS_ALGO_2_MISSING ) ],
        undef,
        [],
        [],
    ],
    'ALGO-UNASSIGNED-127' => [
        1,
        q(algo-unassigned-127.dnssec01.xa),
        [ qw( DS01_DS_ALGO_UNASSIGNED DS01_DS_ALGO_2_MISSING ) ],
        undef,
        [],
        [],
    ],
    'MIXED-ALGO-1' => [
        1,
        q(mixed-algo-1.dnssec01.xa),
        [ qw( DS01_DS_ALGO_DEPRECATED DS01_DS_ALGO_PRIVATE DS01_DS_ALGO_OK ) ],
        undef,
        [],
        [],
    ],
    'SHARED-IP-1' => [
        1,
        q(child.shared-ip-1.dnssec01.xa),
        [ qw( DS01_DS_ALGO_OK ) ],
        undef,
        [],
        [],
    ],
    'SHARED-IP-2' => [
        1,
        q(child.shared-ip-2.dnssec01.xa),
        [ qw( DS01_DS_ALGO_OK ) ],
        undef,
        [],
        [],
    ],
    'NO-RESPONSE-1' => [
        1,
        q(child.no-response-1.dnssec01.xa),
        [ qw( DS01_NO_RESPONSE ) ],
        undef,
        [],
        [],
    ],
    'NO-VALID-RESPONSE-1' => [
        1,
        q(child.no-valid-response-1.dnssec01.xa),
        [ qw( DS01_NO_RESPONSE ) ],
        undef,
        [],
        [],
    ],
    'PARENT-SERVER-NO-DS-1' => [
        1,
        q(child.parent-server-no-ds-1.dnssec01.xa),
        [ qw( DS01_PARENT_SERVER_NO_DS DS01_DS_ALGO_OK ) ],
        undef,
        [],
        [],
    ],
    'PARENT-ZONE-NO-DS-1' => [
        1,
        q(parent-zone-no-ds-1.dnssec01.xa),
        [ qw( DS01_PARENT_ZONE_NO_DS ) ],
        undef,
        [],
        [],
    ],
    'UNDEL-NO-UNDEL-DS-1' => [
        1,
        q(undel-no-undel-ds-1.dnssec01.xa),
        [ qw( DS01_UNDEL_N_NO_UNDEL_DS ) ],
        undef,
        [ qw( ns1.undel-no-undel-ds-1.dnssec01.xa/127.15.1.41 ns1.undel-no-undel-ds-1.dnssec01.xa/fda1:b2:c3:0:127:15:1:41 ns2.undel-no-undel-ds-1.dnssec01.xa/127.15.1.42 ns2.undel-no-undel-ds-1.dnssec01.xa/fda1:b2:c3:0:127:15:1:42 ) ],
        [],
    ],
    'UNDEL-WITH-UNDEL-DS-1' => [
        1,
        q(undel-with-undel-ds-1.dnssec01.xa),
        [ qw( DS01_DS_ALGO_OK ) ],
        undef,
        [],
        [ '42581,13,2,F28391C1ED4DC0F151EDD251A3103DCE0B9A5A251ACF6E24073771D71F3C40F9' ],
    ],
    'ROOT-NO-UNDEL-DS-1' => [
        1,
        q(.),
        [ qw( DS01_ROOT_N_NO_UNDEL_DS ) ],
        undef,
        [],
        [],
    ],
    'ROOT-WITH-UNDEL-DS-1' => [
        1,
        q(.),
        [ qw( DS01_DS_ALGO_OK ) ],
        undef,
        [],
        [ '42581,13,2,F28391C1ED4DC0F151EDD251A3103DCE0B9A5A251ACF6E24073771D71F3C40F9' ],
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
