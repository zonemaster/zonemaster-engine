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
# DNSSEC05 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/DNSSEC-TP/dnssec05.md
my $test_module = 'DNSSEC';
my $test_case = 'dnssec05';
my @all_tags = qw(
                DS05_ALGO_DEPRECATED
                DS05_ALGO_NOT_RECOMMENDED
                DS05_ALGO_NOT_ZONE_SIGN
                DS05_ALGO_OK
                DS05_ALGO_PRIVATE
                DS05_ALGO_RESERVED
                DS05_ALGO_UNASSIGNED
                DS05_NO_RESPONSE
                DS05_SERVER_NO_DNSSEC
                DS05_ZONE_NO_DNSSEC
            );

# Specific hint file (https://github.com/zonemaster/zonemaster/blob/master/test-zone-data/DNSSEC-TP/dnssec05/hintfile.zone)
Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
Zonemaster::Engine::Recursor->add_fake_addresses( '.',
    { 'root-ns1.xa' => [ '127.15.5.27', 'fda1:b2:c3::127:15:5:27' ],
      'root-ns2.xa' => [ '127.15.5.28', 'fda1:b2:c3::127:15:5:28' ],
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
        q(algo-deprecated-1.dnssec05.xa),
        [ qw( DS05_ALGO_DEPRECATED ) ],
        undef,
        [],
        [],
    ],
    'ALGO-DEPRECATED-3' => [
        1,
        q(algo-deprecated-3.dnssec05.xa),
        [ qw( DS05_ALGO_DEPRECATED ) ],
        undef,
        [],
        [],
    ],
    'ALGO-DEPRECATED-5' => [
        1,
        q(algo-deprecated-5.dnssec05.xa),
        [ qw( DS05_ALGO_DEPRECATED ) ],
        undef,
        [],
        [],
    ],
    'ALGO-DEPRECATED-6' => [
        1,
        q(algo-deprecated-6.dnssec05.xa),
        [ qw( DS05_ALGO_DEPRECATED ) ],
        undef,
        [],
        [],
    ],
    'ALGO-DEPRECATED-7' => [
        1,
        q(algo-deprecated-7.dnssec05.xa),
        [ qw( DS05_ALGO_DEPRECATED ) ],
        undef,
        [],
        [],
    ],
    'ALGO-DEPRECATED-12' => [
        1,
        q(algo-deprecated-12.dnssec05.xa),
        [ qw( DS05_ALGO_DEPRECATED ) ],
        undef,
        [],
        [],
    ],
    'ALGO-NOT-RECOMMENDED-10' => [
        1,
        q(algo-not-recommended-10.dnssec05.xa),
        [ qw( DS05_ALGO_NOT_RECOMMENDED ) ],
        undef,
        [],
        [],
    ],
    'ALGO-NOT-ZONE-SIGN-0' => [
        1,
        q(algo-not-zone-sign-0.dnssec05.xa),
        [ qw( DS05_ALGO_NOT_ZONE_SIGN ) ],
        undef,
        [],
        [],
    ],
    'ALGO-NOT-ZONE-SIGN-2' => [
        1,
        q(algo-not-zone-sign-2.dnssec05.xa),
        [ qw( DS05_ALGO_NOT_ZONE_SIGN ) ],
        undef,
        [],
        [],
    ],
    'ALGO-NOT-ZONE-SIGN-252' => [
        1,
        q(algo-not-zone-sign-252.dnssec05.xa),
        [ qw( DS05_ALGO_NOT_ZONE_SIGN ) ],
        undef,
        [],
        [],
    ],
    'ALGO-OK-8' => [
        1,
        q(algo-ok-8.dnssec05.xa),
        [ qw( DS05_ALGO_OK ) ],
        undef,
        [],
        [],
    ],
    'ALGO-OK-13' => [
        1,
        q(algo-ok-13.dnssec05.xa),
        [ qw( DS05_ALGO_OK ) ],
        undef,
        [],
        [],
    ],
    'ALGO-OK-14' => [
        1,
        q(algo-ok-14.dnssec05.xa),
        [ qw( DS05_ALGO_OK ) ],
        undef,
        [],
        [],
    ],
    'ALGO-OK-15' => [
        1,
        q(algo-ok-15.dnssec05.xa),
        [ qw( DS05_ALGO_OK ) ],
        undef,
        [],
        [],
    ],
    'ALGO-OK-16' => [
        1,
        q(algo-ok-16.dnssec05.xa),
        [ qw( DS05_ALGO_OK ) ],
        undef,
        [],
        [],
    ],
    'ALGO-OK-17' => [
        1,
        q(algo-ok-17.dnssec05.xa),
        [ qw( DS05_ALGO_OK ) ],
        undef,
        [],
        [],
    ],
    'ALGO-OK-23' => [
        1,
        q(algo-ok-23.dnssec05.xa),
        [ qw( DS05_ALGO_OK ) ],
        undef,
        [],
        [],
    ],
    'ALGO-PRIVATE-253' => [
        1,
        q(algo-private-253.dnssec05.xa),
        [ qw( DS05_ALGO_PRIVATE ) ],
        undef,
        [],
        [],
    ],
    'ALGO-PRIVATE-254' => [
        1,
        q(algo-private-254.dnssec05.xa),
        [ qw( DS05_ALGO_PRIVATE ) ],
        undef,
        [],
        [],
    ],
    'ALGO-RESERVED-4' => [
        1,
        q(algo-reserved-4.dnssec05.xa),
        [ qw( DS05_ALGO_RESERVED ) ],
        undef,
        [],
        [],
    ],
    'ALGO-RESERVED-9' => [
        1,
        q(algo-reserved-9.dnssec05.xa),
        [ qw( DS05_ALGO_RESERVED ) ],
        undef,
        [],
        [],
    ],
    'ALGO-RESERVED-11' => [
        1,
        q(algo-reserved-11.dnssec05.xa),
        [ qw( DS05_ALGO_RESERVED ) ],
        undef,
        [],
        [],
    ],
    'ALGO-RESERVED-123' => [
        1,
        q(algo-reserved-123.dnssec05.xa),
        [ qw( DS05_ALGO_RESERVED ) ],
        undef,
        [],
        [],
    ],
    'ALGO-RESERVED-251' => [
        1,
        q(algo-reserved-251.dnssec05.xa),
        [ qw( DS05_ALGO_RESERVED ) ],
        undef,
        [],
        [],
    ],
    'ALGO-RESERVED-255' => [
        1,
        q(algo-reserved-255.dnssec05.xa),
        [ qw( DS05_ALGO_RESERVED ) ],
        undef,
        [],
        [],
    ],
    'ALGO-UNASSIGNED-20' => [
        1,
        q(algo-unassigned-20.dnssec05.xa),
        [ qw( DS05_ALGO_UNASSIGNED ) ],
        undef,
        [],
        [],
    ],
    'ALGO-UNASSIGNED-122' => [
        1,
        q(algo-unassigned-122.dnssec05.xa),
        [ qw( DS05_ALGO_UNASSIGNED ) ],
        undef,
        [],
        [],
    ],
    'MIXED-ALGO-1' => [
        1,
        q(mixed-algo-1.dnssec05.xa),
        [ qw( DS05_ALGO_DEPRECATED DS05_ALGO_NOT_RECOMMENDED DS05_ALGO_OK ) ],
        undef,
        [],
        [],
    ],
    'NO-RESPONSE-1' => [
        1,
        q(no-response-1.dnssec05.xa),
        [ qw( DS05_NO_RESPONSE ) ],
        undef,
        [],
        [],
    ],
    'NO-RESPONSE-2' => [
        1,
        q(no-response-2.dnssec05.xa),
        [ qw( DS05_NO_RESPONSE ) ],
        undef,
        [],
        [],
    ],
    'SERVER-NO-DNSSEC-1' => [
        1,
        q(server-no-dnssec-1.dnssec05.xa),
        [ qw( DS05_SERVER_NO_DNSSEC DS05_ALGO_OK ) ],
        undef,
        [],
        [],
    ],
    'SHARED-IP-1' => [
        1,
        q(shared-ip-1.dnssec05.xa),
        [ qw( DS05_ALGO_OK ) ],
        undef,
        [],
        [],
    ],
    'ZONE-NO-DNSSEC-1' => [
        1,
        q(zone-no-dnssec-1.dnssec05.xa),
        [ qw( DS05_ZONE_NO_DNSSEC ) ],
        undef,
        [],
        [],
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
