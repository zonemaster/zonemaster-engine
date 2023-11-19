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
# consistency06 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/Consistency-TP/consistency06.md
# (when https://github.com/zonemaster/zonemaster/pull/1213 is merged)

my $test_module = q{Consistency};
my $test_case = 'consistency06';

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
# Scenarios ONE-SOA-MNAME-4 and NO-RESPONSE cannot be tested due to a bug in the implementation. See
# https://github.com/zonemaster/zonemaster-engine/issues/1300
#

###########
my %subtests = (
    'ONE-SOA-MNAME-2' => [
        q(one-soa-mname-2.consistency06.xa),
        [ qw(ONE_SOA_MNAME NO_RESPONSE) ],
        [ qw(NO_RESPONSE_SOA_QUERY MULTIPLE_SOA_MNAMES) ],
        1,
    ],
    'ONE-SOA-MNAME-1' => [
        q(one-soa-mname-1.consistency06.xa),
        [ qw(ONE_SOA_MNAME) ],
        [ qw(NO_RESPONSE NO_RESPONSE_SOA_QUERY MULTIPLE_SOA_MNAMES) ],
        1,
    ],
    'NO-RESPONSE' => [
        q(no-response.consistency06.xa),
        [ qw(NO_RESPONSE) ],
        [ qw(NO_RESPONSE_SOA_QUERY MULTIPLE_SOA_MNAMES ONE_SOA_MNAME) ],
        0,
    ],
    'MULTIPLE-SOA-MNAMES-1' => [
        q(multiple-soa-mnames-1.consistency06.xa),
        [ qw(MULTIPLE_SOA_MNAMES) ],
        [ qw(NO_RESPONSE NO_RESPONSE_SOA_QUERY ONE_SOA_MNAME) ],
        1,
    ],
    'ONE-SOA-MNAME-3' => [
        q(one-soa-mname-3.consistency06.xa),
        [ qw(ONE_SOA_MNAME NO_RESPONSE_SOA_QUERY) ],
        [ qw(NO_RESPONSE MULTIPLE_SOA_MNAMES) ],
        1,
    ],
    'ONE-SOA-MNAME-4' => [
        q(one-soa-mname-4.consistency06.xa),
        [ qw(ONE_SOA_MNAME NO_RESPONSE) ],
        [ qw(NO_RESPONSE_SOA_QUERY MULTIPLE_SOA_MNAMES) ],
        0,
    ],
    'MULTIPLE-SOA-MNAMES-2' => [
        q(multiple-soa-mnames-2.consistency06.xa),
        [ qw(MULTIPLE_SOA_MNAMES NO_RESPONSE) ],
        [ qw(NO_RESPONSE_SOA_QUERY ONE_SOA_MNAME) ],
        1,
    ],
);

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
