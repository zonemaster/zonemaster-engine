use strict;
use warnings;

use Test::More;
use File::Basename;
use File::Spec::Functions qw( rel2abs );
use lib dirname( rel2abs( $0 ) );

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Nameserver} );
    use_ok( q{Zonemaster::Engine::Test::Address} );
    use_ok( q{TestUtil}, qw( perform_testcase_testing ) );
}

###########
# address01 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/Address-TP/address01.md
my $test_module = 'Address';
my $test_case = 'address01';
my @all_tags = qw(A01_ADDR_NOT_GLOBALLY_REACHABLE
                  A01_DOCUMENTATION_ADDR
                  A01_GLOBALLY_REACHABLE_ADDR
                  A01_LOCAL_USE_ADDR
                  A01_NO_GLOBALLY_REACHABLE_ADDR
                  A01_NO_NAME_SERVERS_FOUND);

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

my %subtests = (
    'GOOD-1' => [
        1,
        q(good-1.address01.xa),
        [ qw(A01_GLOBALLY_REACHABLE_ADDR) ],
        undef,
        [],
        [],
    ],
    'ALL-NON-REACHABLE' => [
        1,
        q(all-non-reachable.address01.xa),
        [ qw(A01_ADDR_NOT_GLOBALLY_REACHABLE A01_LOCAL_USE_ADDR A01_DOCUMENTATION_ADDR A01_NO_GLOBALLY_REACHABLE_ADDR) ],
        undef,
        [],
        [],
    ],
    'MIXED-LOCAL-DOC-1' => [
        1,
        q(mixed-local-doc-1.address01.xa),
        [ qw(A01_LOCAL_USE_ADDR A01_DOCUMENTATION_ADDR A01_GLOBALLY_REACHABLE_ADDR) ],
        undef,
        [],
        [],
    ],
    'MIXED-LOCAL-DOC-2' => [
        1,
        q(mixed-local-doc-2.address01.xa),
        [ qw(A01_LOCAL_USE_ADDR A01_DOCUMENTATION_ADDR A01_GLOBALLY_REACHABLE_ADDR) ],
        undef,
        [],
        [],
    ],
    'MIXED-LOCAL-OTHER-1' => [
        1,
        q(mixed-local-other-1.address01.xa),
        [ qw(A01_LOCAL_USE_ADDR A01_ADDR_NOT_GLOBALLY_REACHABLE A01_GLOBALLY_REACHABLE_ADDR) ],
        undef,
        [],
        [],
    ],
    'MIXED-LOCAL-OTHER-2' => [
        1,
        q(mixed-local-other-2.address01.xa),
        [ qw(A01_LOCAL_USE_ADDR A01_ADDR_NOT_GLOBALLY_REACHABLE A01_GLOBALLY_REACHABLE_ADDR) ],
        undef,
        [],
        [],
    ],
    'MIXED-DOC-OTHER-1' => [
        1,
        q(mixed-doc-other-1.address01.xa),
        [ qw(A01_DOCUMENTATION_ADDR A01_ADDR_NOT_GLOBALLY_REACHABLE A01_GLOBALLY_REACHABLE_ADDR) ],
        undef,
        [],
        [],
    ],
    'MIXED-DOC-OTHER-2' => [
        1,
        q(mixed-doc-other-2.address01.xa),
        [ qw(A01_DOCUMENTATION_ADDR A01_ADDR_NOT_GLOBALLY_REACHABLE A01_GLOBALLY_REACHABLE_ADDR) ],
        undef,
        [],
        [],
    ],
    'MIXED-ALL-1' => [
        1,
        q(mixed-all-1.address01.xa),
        [ qw(A01_ADDR_NOT_GLOBALLY_REACHABLE A01_DOCUMENTATION_ADDR A01_LOCAL_USE_ADDR A01_GLOBALLY_REACHABLE_ADDR) ],
        undef,
        [],
        [],
    ],
    'MIXED-ALL-2' => [
        1,
        q(mixed-all-2.address01.xa),
        [ qw(A01_ADDR_NOT_GLOBALLY_REACHABLE A01_DOCUMENTATION_ADDR A01_LOCAL_USE_ADDR A01_GLOBALLY_REACHABLE_ADDR) ],
        undef,
        [],
        [],
    ],
    'NO-NAME-SERVERS' => [
        1,
        q(no-name-servers.address01.xa),
        [ qw(A01_NO_NAME_SERVERS_FOUND) ],
        undef,
        [],
        [],
    ]
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
