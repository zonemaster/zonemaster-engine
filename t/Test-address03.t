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

my $test_module = q{Address};
my $test_case = q{address03};
my @all_tags = qw(NAMESERVER_IP_PTR_MATCH
                  NAMESERVER_IP_PTR_MISMATCH
                  NAMESERVER_IP_WITHOUT_REVERSE
                  NO_RESPONSE_PTR_QUERY);

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
    'ALL-NS-HAVE-PTR-1' => [
        1,
        q(all-ns-have-ptr-1.address03.xa),
        [ qw(NAMESERVER_IP_PTR_MATCH) ],
        undef,
        [],
        []
    ],
    'ALL-NS-HAVE-PTR-2' => [
        1,
        q(all-ns-have-ptr-2.address03.xa),
        [ qw(NAMESERVER_IP_PTR_MATCH) ],
        undef,
        [],
        []
    ],
    'NO-NS-HAVE-PTR' => [
        1,
        q(no-ns-have-ptr.address03.xa),
        [ qw(NAMESERVER_IP_WITHOUT_REVERSE) ],
        undef,
        [],
        []
    ],
    'INCOMPLETE-PTR-1' => [
        1,
        q(incomplete-ptr-1.address03.xa),
        [ qw(NAMESERVER_IP_WITHOUT_REVERSE) ],
        undef,
        [],
        []
    ],
    'INCOMPLETE-PTR-2' => [
        1,
        q(incomplete-ptr-2.address03.xa),
        [ qw(NAMESERVER_IP_WITHOUT_REVERSE) ],
        undef,
        [],
        []
    ],
    'NON-MATCHING-NAMES' => [
        1,
        q(non-matching-names.address03.xa),
        [ qw(NAMESERVER_IP_PTR_MISMATCH) ],
        undef,
        [],
        []
    ],
    'PTR-IS-GOOD-CNAME-1' => [
        1,
        q(ptr-is-good-cname-1.address03.xa),
        [ qw(NAMESERVER_IP_PTR_MATCH) ],
        undef,
        [],
        []
    ],
    'PTR-IS-GOOD-CNAME-2' => [
        1,
        q(ptr-is-good-cname-2.address03.xa),
        [ qw(NAMESERVER_IP_PTR_MATCH) ],
        undef,
        [],
        []
    ],
    'PTR-IS-DANGLING-CNAME' => [
        1,
        q(ptr-is-dangling-cname.address03.xa),
        [ qw(NAMESERVER_IP_WITHOUT_REVERSE) ],
        undef,
        [],
        []
    ],
    'PTR-IS-ILLEGAL-CNAME' => [
        1,
        q(ptr-is-illegal-cname.address03.xa),
        [ qw(NAMESERVER_IP_WITHOUT_REVERSE) ],
        [ qw(NAMESERVER_IP_PTR_MATCH) ],
        [],
        []
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
