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
my @all_tags = qw(ONE_SOA_MNAME
                  NO_RESPONSE
                  NO_RESPONSE_SOA_QUERY
                  MULTIPLE_SOA_MNAMES);

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

# Scenarios ONE-SOA-MNAME-4 and NO-RESPONSE cannot be tested due to a bug in the implementation. See
# https://github.com/zonemaster/zonemaster-engine/issues/1300

###########
my %subtests = (
    'ONE-SOA-MNAME-1' => [
        1,
        q(one-soa-mname-1.consistency06.xa),
        [ qw(ONE_SOA_MNAME) ],
        undef,
        [],
        []
    ],
    'ONE-SOA-MNAME-2' => [
        1,
        q(one-soa-mname-2.consistency06.xa),
        [ qw(ONE_SOA_MNAME NO_RESPONSE) ],
        undef,
        [],
        []
    ],
    'ONE-SOA-MNAME-3' => [
        1,
        q(one-soa-mname-3.consistency06.xa),
        [ qw(ONE_SOA_MNAME NO_RESPONSE_SOA_QUERY) ],
        undef,
        [],
        []
    ],
    'ONE-SOA-MNAME-4' => [
        0,
        q(one-soa-mname-4.consistency06.xa),
        [ qw(ONE_SOA_MNAME NO_RESPONSE) ],
        undef,
        [],
        []
    ],
    'MULTIPLE-SOA-MNAMES-1' => [
        1,
        q(multiple-soa-mnames-1.consistency06.xa),
        [ qw(MULTIPLE_SOA_MNAMES) ],
        undef,
        [],
        []
    ],
    'MULTIPLE-SOA-MNAMES-2' => [
        1,
        q(multiple-soa-mnames-2.consistency06.xa),
        [ qw(MULTIPLE_SOA_MNAMES NO_RESPONSE) ],
        undef,
        [],
        []
    ],
    'MULT-SOA-MNAMES-NO-DEL-UNDEL-1' => [
        1,
        q(mult-soa-mnames-no-del-undel-1.consistency06.xa),
        [ qw(MULTIPLE_SOA_MNAMES) ],
        undef,
        [ qw(ns1.mult-soa-mnames-no-del-undel-1.consistency06.xa/127.14.6.31 ns1.mult-soa-mnames-no-del-undel-1.consistency06.xa/fda1:b2:c3:0:127:14:6:31 ns2.mult-soa-mnames-no-del-undel-1.consistency06.xa/127.14.6.32 ns2.mult-soa-mnames-no-del-undel-1.consistency06.xa/fda1:b2:c3:0:127:14:6:32) ],
        []
    ],
    'MULT-SOA-MNAMES-NO-DEL-UNDEL-2' => [
        0,
        q(mult-soa-mnames-no-del-undel-2.consistency06.xa),
        [ qw(MULTIPLE_SOA_MNAMES) ],
        undef,
        [ qw(ns3.mult-soa-mnames-no-del-undel-2.consistency06.xb ns3.mult-soa-mnames-no-del-undel-2.consistency06.xb) ],
        []
    ],
    'NO-RESPONSE' => [
        0,
        q(no-response.consistency06.xa),
        [ qw(NO_RESPONSE) ],
        undef,
        [],
        []
    ],
);

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
