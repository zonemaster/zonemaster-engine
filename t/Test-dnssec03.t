use strict;
use warnings;

use Test::More;
use File::Basename;
use File::Spec::Functions qw( rel2abs );
use lib dirname( rel2abs( $0 ) );

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Nameserver} );
    use_ok( q{Zonemaster::Engine::Test::DNSSEC} );
    use_ok( q{TestUtil}, qw( perform_testcase_testing ) );
}

###########
# dnssec03 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/DNSSEC-TP/dnssec03.md
my $test_module = q{DNSSEC};
my $test_case = 'dnssec03';
my @all_tags = qw(DS03_NO_DNSSEC_SUPPORT
                  DS03_ERR_MULT_NSEC3
                  DS03_ILLEGAL_HASH_ALGO
                  DS03_ILLEGAL_ITERATION_VALUE
                  DS03_ILLEGAL_SALT_LENGTH
                  DS03_INCONSISTENT_HASH_ALGO
                  DS03_INCONSISTENT_ITERATION
                  DS03_INCONSISTENT_NSEC3_FLAGS
                  DS03_INCONSISTENT_SALT_LENGTH
                  DS03_LEGAL_EMPTY_SALT
                  DS03_LEGAL_HASH_ALGO
                  DS03_LEGAL_ITERATION_VALUE
                  DS03_NO_NSEC3
                  DS03_NSEC3_OPT_OUT_DISABLED
                  DS03_NSEC3_OPT_OUT_ENABLED_NON_TLD
                  DS03_NSEC3_OPT_OUT_ENABLED_TLD
                  DS03_SERVER_NO_DNSSEC_SUPPORT
                  DS03_SERVER_NO_NSEC3
                  DS03_UNASSIGNED_FLAG_USED
                  DS03_ERROR_RESPONSE_NSEC_QUERY
                  DS03_NO_RESPONSE_NSEC_QUERY);

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
    'NO-DNSSEC-SUPPORT' => [
        1,
        q(no-dnssec-support.dnssec03.xa),
        [ qw(DS03_NO_DNSSEC_SUPPORT) ],
        undef,
        [],
        []
    ],
    'NO-NSEC3' => [
        1,
        q(no-nsec3.dnssec03.xa),
        [ qw(DS03_NO_NSEC3) ],
        undef,
        [],
        []
    ],
    'GOOD-VALUES' => [
        1,
        q(good-values.dnssec03.xa),
        [ qw(DS03_LEGAL_EMPTY_SALT DS03_LEGAL_HASH_ALGO DS03_LEGAL_ITERATION_VALUE DS03_NSEC3_OPT_OUT_DISABLED) ],
        undef,
        [],
        []
    ],
    'ERR-MULT-NSEC3' => [
        1,
        q(err-mult-nsec3.dnssec03.xa),
        [ qw(DS03_ERR_MULT_NSEC3 DS03_LEGAL_EMPTY_SALT DS03_LEGAL_HASH_ALGO DS03_LEGAL_ITERATION_VALUE DS03_NSEC3_OPT_OUT_DISABLED) ],
        undef,
        [],
        []
    ],
    'BAD-VALUES' => [
        1,
        q(bad-values.dnssec03.xa),
        [ qw(DS03_ILLEGAL_HASH_ALGO DS03_ILLEGAL_ITERATION_VALUE DS03_ILLEGAL_SALT_LENGTH DS03_NSEC3_OPT_OUT_ENABLED_NON_TLD) ],
        undef,
        [],
        []
    ],
    'INCONSISTENT-VALUES' => [
        1,
        q(inconsistent-values.dnssec03.xa),
        undef,
        [ qw(DS03_ERR_MULT_NSEC3 DS03_NO_DNSSEC_SUPPORT DS03_NO_NSEC3 DS03_NSEC3_OPT_OUT_ENABLED_TLD DS03_SERVER_NO_DNSSEC_SUPPORT DS03_SERVER_NO_NSEC3 DS03_UNASSIGNED_FLAG_USED DS03_ERROR_RESPONSE_NSEC_QUERY DS03_NO_RESPONSE_NSEC_QUERY) ],
        [],
        []
    ],
    'NSEC3-OPT-OUT-ENABLED-TLD' => [
        1,
        q(nsec3-opt-out-enabled-tld-dnssec03),
        [ qw(DS03_NSEC3_OPT_OUT_ENABLED_TLD DS03_LEGAL_EMPTY_SALT DS03_LEGAL_HASH_ALGO DS03_LEGAL_ITERATION_VALUE) ],
        undef,
        [],
        []
    ],
    'SERVER-NO-DNSSEC-SUPPORT' => [
        1,
        q(server-no-dnssec-support.dnssec03.xa),
        [ qw(DS03_SERVER_NO_DNSSEC_SUPPORT DS03_LEGAL_EMPTY_SALT DS03_LEGAL_HASH_ALGO DS03_LEGAL_ITERATION_VALUE DS03_NSEC3_OPT_OUT_DISABLED) ],
        undef,
        [],
        []
    ],
    'SERVER-NO-NSEC3' => [
        1,
        q(server-no-nsec3.dnssec03.xa),
        [ qw(DS03_SERVER_NO_NSEC3 DS03_LEGAL_EMPTY_SALT DS03_LEGAL_HASH_ALGO DS03_LEGAL_ITERATION_VALUE DS03_NSEC3_OPT_OUT_DISABLED) ],
        undef,
        [],
        []
    ],
    'UNASSIGNED-FLAG-USED' => [
        1,
        q(unassigned-flag-used.dnssec03.xa),
        [ qw(DS03_UNASSIGNED_FLAG_USED DS03_LEGAL_EMPTY_SALT DS03_LEGAL_HASH_ALGO DS03_LEGAL_ITERATION_VALUE DS03_NSEC3_OPT_OUT_DISABLED) ],
        undef,
        [],
        []
    ],
    'ERROR-RESPONSE-NSEC-QUERY' => [
        1,
        q(error-response-nsec-query.dnssec03.xa),
        [ qw(DS03_LEGAL_EMPTY_SALT DS03_LEGAL_HASH_ALGO DS03_LEGAL_ITERATION_VALUE DS03_NSEC3_OPT_OUT_DISABLED DS03_ERROR_RESPONSE_NSEC_QUERY) ],
        undef,
        [],
        []
    ],
    'NO-RESPONSE-NSEC-QUERY' => [
        1,
        q(no-response-nsec-query.dnssec03.xa),
        [ qw(DS03_LEGAL_EMPTY_SALT DS03_LEGAL_HASH_ALGO DS03_LEGAL_ITERATION_VALUE DS03_NSEC3_OPT_OUT_DISABLED DS03_NO_RESPONSE_NSEC_QUERY) ],
        undef,
        [],
        []
    ],
    'ERROR-NSEC-QUERY' => [
        1,
        q(error-nsec-query.dnssec03.xa),
        [ qw(DS03_ERROR_RESPONSE_NSEC_QUERY DS03_NO_RESPONSE_NSEC_QUERY) ],
        undef,
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
