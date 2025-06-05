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
# DNSSEC10 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/DNSSEC-TP/dnssec10.md
my $test_module = 'DNSSEC';
my $test_case = 'dnssec10';
my @all_tags = qw(
                   DS10_ALGO_NOT_SUPPORTED_BY_ZM
                   DS10_ERR_MULT_NSEC
                   DS10_ERR_MULT_NSEC3
                   DS10_ERR_MULT_NSEC3PARAM
                   DS10_EXPECTED_NSEC_NSEC3_MISSING
                   DS10_HAS_NSEC
                   DS10_HAS_NSEC3
                   DS10_INCONSISTENT_NSEC
                   DS10_INCONSISTENT_NSEC3
                   DS10_INCONSISTENT_NSEC_NSEC3
                   DS10_MIXED_NSEC_NSEC3
                   DS10_NSEC3PARAM_GIVES_ERR_ANSWER
                   DS10_NSEC3PARAM_MISMATCHES_APEX
                   DS10_NSEC3PARAM_QUERY_RESPONSE_ERR
                   DS10_NSEC3_ERR_TYPE_LIST
                   DS10_NSEC3_MISMATCHES_APEX
                   DS10_NSEC3_MISSING_SIGNATURE
                   DS10_NSEC3_NODATA_MISSING_SOA
                   DS10_NSEC3_NODATA_WRONG_SOA
                   DS10_NSEC3_NO_VERIFIED_SIGNATURE
                   DS10_NSEC3_RRSIG_EXPIRED
                   DS10_NSEC3_RRSIG_NOT_YET_VALID
                   DS10_NSEC3_RRSIG_NO_DNSKEY
                   DS10_NSEC3_RRSIG_VERIFY_ERROR
                   DS10_NSEC_ERR_TYPE_LIST
                   DS10_NSEC_GIVES_ERR_ANSWER
                   DS10_NSEC_MISMATCHES_APEX
                   DS10_NSEC_MISSING_SIGNATURE
                   DS10_NSEC_NODATA_MISSING_SOA
                   DS10_NSEC_NODATA_WRONG_SOA
                   DS10_NSEC_NO_VERIFIED_SIGNATURE
                   DS10_NSEC_QUERY_RESPONSE_ERR
                   DS10_NSEC_RRSIG_EXPIRED
                   DS10_NSEC_RRSIG_NOT_YET_VALID
                   DS10_NSEC_RRSIG_NO_DNSKEY
                   DS10_NSEC_RRSIG_VERIFY_ERROR
                   DS10_SERVER_NO_DNSSEC
                   DS10_ZONE_NO_DNSSEC
                 );

# Common hint file (https://github.com/zonemaster/zonemaster/blob/master/test-zone-data/COMMON/hintfile.zone)
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
    'GOOD-NSEC-1' => [
        1,
        q(good-nsec-1.dnssec10.xa),
        [ qw( DS10_HAS_NSEC ) ],
        undef,
        [],
        [],
    ],
    'GOOD-NSEC-2' => [
        1,
        q(good-nsec-2.dnssec10.xa),
        [ qw( DS10_HAS_NSEC ) ],
        undef,
        [],
        [],
    ],
    'GOOD-NSEC-3' => [
        1,
        q(good-nsec-3.dnssec10.xa),
        [ qw( DS10_HAS_NSEC ) ],
        undef,
        [],
        [],
    ],
    'GOOD-NSEC3-1' => [
        1,
        q(good-nsec3-1.dnssec10.xa),
        [ qw( DS10_HAS_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'GOOD-NSEC3-2' => [
        1,
        q(good-nsec3-2.dnssec10.xa),
        [ qw( DS10_HAS_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'GOOD-NSEC3-3' => [
        1,
        q(good-nsec3-3.dnssec10.xa),
        [ qw( DS10_HAS_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'ALGO-NOT-SUPP-BY-ZM-1' => [
        1,
        q(algo-not-supp-by-zm-1.dnssec10.xa),
        [ qw( DS10_ALGO_NOT_SUPPORTED_BY_ZM DS10_HAS_NSEC ) ],
        undef,
        [],
        [],
    ],
    'ALGO-NOT-SUPP-BY-ZM-2' => [
        1,
        q(algo-not-supp-by-zm-2.dnssec10.xa),
        [ qw( DS10_ALGO_NOT_SUPPORTED_BY_ZM DS10_HAS_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'BAD-SERVERS-BUT-GOOD-NSEC-1' => [
        1,
        q(bad-servers-but-good-nsec-1.dnssec10.xa),
        [ qw( DS10_HAS_NSEC ) ],
        undef,
        [],
        [],
    ],
    'ERR-MULT-NSEC-1' => [
        1,
        q(err-mult-nsec-1.dnssec10.xa),
        [ qw( DS10_ERR_MULT_NSEC DS10_HAS_NSEC ) ],
        undef,
        [],
        [],
    ],
    'ERR-MULT-NSEC-2' => [
        1,
        q(err-mult-nsec-2.dnssec10.xa),
        [ qw( DS10_ERR_MULT_NSEC DS10_HAS_NSEC ) ],
        undef,
        [],
        [],
    ],
    'ERR-MULT-NSEC3-1' => [
        1,
        q(err-mult-nsec3-1.dnssec10.xa),
        [ qw( DS10_ERR_MULT_NSEC3 DS10_HAS_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'ERR-MULT-NSEC3PARAM-1' => [
        1,
        q(err-mult-nsec3param-1.dnssec10.xa),
        [ qw( DS10_ERR_MULT_NSEC3PARAM DS10_HAS_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'EXP-NSEC-NSEC3-MISS-1' => [
        1,
        q(exp-nsec-nsec3-miss-1.dnssec10.xa),
        [ qw( DS10_EXPECTED_NSEC_NSEC3_MISSING ) ],
        undef,
        [],
        [],
    ],
    'INCONSISTENT-NSEC-1' => [
        1,
        q(inconsistent-nsec-1.dnssec10.xa),
        [ qw( DS10_INCONSISTENT_NSEC DS10_HAS_NSEC ) ],
        undef,
        [],
        [],
    ],
    'INCONSISTENT-NSEC3-1' => [
        1,
        q(inconsistent-nsec3-1.dnssec10.xa),
        [ qw( DS10_INCONSISTENT_NSEC3 DS10_HAS_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'INCONSIST-NSEC-NSEC3-1' => [
        1,
        q(inconsist-nsec-nsec3-1.dnssec10.xa),
        [ qw( DS10_INCONSISTENT_NSEC_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'INCONSIST-NSEC-NSEC3-2' => [
        1,
        q(inconsist-nsec-nsec3-2.dnssec10.xa),
        [ qw( DS10_INCONSISTENT_NSEC_NSEC3 DS10_INCONSISTENT_NSEC DS10_INCONSISTENT_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'MIXED-NSEC-NSEC3-1' => [
        1,
        q(mixed-nsec-nsec3-1.dnssec10.xa),
        [ qw( DS10_MIXED_NSEC_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'MIXED-NSEC-NSEC3-2' => [
        1,
        q(mixed-nsec-nsec3-2.dnssec10.xa),
        [ qw( DS10_MIXED_NSEC_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'NSEC3PARAM-GIVES-ERR-ANSWER-1' => [
        1,
        q(nsec3param-gives-err-answer-1.dnssec10.xa),
        [ qw( DS10_NSEC3PARAM_GIVES_ERR_ANSWER DS10_HAS_NSEC3 DS10_INCONSISTENT_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'NSEC3PARAM-GIVES-ERR-ANSWER-2' => [
        1,
        q(nsec3param-gives-err-answer-2.dnssec10.xa),
        [ qw( DS10_NSEC3PARAM_GIVES_ERR_ANSWER DS10_EXPECTED_NSEC_NSEC3_MISSING DS10_INCONSISTENT_NSEC3 DS10_HAS_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'NSEC3PARAM-MISMATCHES-APEX-1' => [
        1,
        q(nsec3param-mismatches-apex-1.dnssec10.xa),
        [ qw( DS10_NSEC3PARAM_MISMATCHES_APEX DS10_HAS_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'NSEC3PARAM-Q-RESPONSE-ERR-1' => [
        1,
        q(nsec3param-q-response-err-1.dnssec10.xa),
        [ qw( DS10_NSEC3PARAM_QUERY_RESPONSE_ERR DS10_HAS_NSEC3 DS10_INCONSISTENT_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'NSEC3PARAM-Q-RESPONSE-ERR-2' => [
        1,
        q(nsec3param-q-response-err-2.dnssec10.xa),
        [ qw( DS10_NSEC3PARAM_QUERY_RESPONSE_ERR DS10_HAS_NSEC3 DS10_INCONSISTENT_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'NSEC3PARAM-Q-RESPONSE-ERR-3' => [
        0,
        q(nsec3param-q-response-err-3.dnssec10.xa),
        [ qw( DS10_NSEC3PARAM_QUERY_RESPONSE_ERR DS10_EXPECTED_NSEC_NSEC3_MISSING DS10_INCONSISTENT_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'NSEC3-ERR-TYPE-LIST-1' => [
        1,
        q(nsec3-err-type-list-1.dnssec10.xa),
        [ qw( DS10_NSEC3_ERR_TYPE_LIST DS10_HAS_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'NSEC3-ERR-TYPE-LIST-2' => [
        1,
        q(nsec3-err-type-list-2.dnssec10.xa),
        [ qw( DS10_NSEC3_ERR_TYPE_LIST DS10_HAS_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'NSEC3-MISMATCHES-APEX-1' => [
        1,
        q(nsec3-mismatches-apex-1.dnssec10.xa),
        [ qw( DS10_NSEC3_MISMATCHES_APEX DS10_HAS_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'NSEC3-MISSING-SIGNATURE-1' => [
        1,
        q(nsec3-missing-signature-1.dnssec10.xa),
        [ qw( DS10_NSEC3_MISSING_SIGNATURE DS10_HAS_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'NSEC3-NODATA-MISSING-SOA-1' => [
        1,
        q(nsec3-nodata-missing-soa-1.dnssec10.xa),
        [ qw( DS10_NSEC3_NODATA_MISSING_SOA DS10_HAS_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'NSEC3-NODATA-WRONG-SOA-1' => [
        1,
        q(nsec3-nodata-wrong-soa-1.dnssec10.xa),
        [ qw( DS10_NSEC3_NODATA_WRONG_SOA DS10_HAS_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'NSEC3-NO-VERIFIED-SIGNATURE-1' => [
        1,
        q(nsec3-no-verified-signature-1.dnssec10.xa),
        [ qw( DS10_NSEC3_NO_VERIFIED_SIGNATURE DS10_HAS_NSEC3 DS10_NSEC3_RRSIG_NO_DNSKEY ) ],
        undef,
        [],
        [],
    ],
    'NSEC3-NO-VERIFIED-SIGNATURE-2' => [
        1,
        q(nsec3-no-verified-signature-2.dnssec10.xa),
        [ qw( DS10_NSEC3_NO_VERIFIED_SIGNATURE DS10_HAS_NSEC3 DS10_NSEC3_RRSIG_EXPIRED ) ],
        undef,
        [],
        [],
    ],
    'NSEC3-NO-VERIFIED-SIGNATURE-3' => [
        1,
        q(nsec3-no-verified-signature-3.dnssec10.xa),
        [ qw( DS10_NSEC3_NO_VERIFIED_SIGNATURE DS10_HAS_NSEC3 DS10_NSEC3_RRSIG_NOT_YET_VALID ) ],
        undef,
        [],
        [],
    ],
    'NSEC3-NO-VERIFIED-SIGNATURE-4' => [
        1,
        q(nsec3-no-verified-signature-4.dnssec10.xa),
        [ qw( DS10_NSEC3_NO_VERIFIED_SIGNATURE DS10_HAS_NSEC3 DS10_NSEC3_RRSIG_VERIFY_ERROR ) ],
        undef,
        [],
        [],
    ],
    'NSEC-ERR-TYPE-LIST-1' => [
        1,
        q(nsec-err-type-list-1.dnssec10.xa),
        [ qw( DS10_NSEC_ERR_TYPE_LIST DS10_HAS_NSEC ) ],
        undef,
        [],
        [],
    ],
    'NSEC-ERR-TYPE-LIST-2' => [
        1,
        q(nsec-err-type-list-2.dnssec10.xa),
        [ qw( DS10_NSEC_ERR_TYPE_LIST DS10_HAS_NSEC ) ],
        undef,
        [],
        [],
    ],
    'NSEC-GIVES-ERR-ANSWER-1' => [
        1,
        q(nsec-gives-err-answer-1.dnssec10.xa),
        [ qw( DS10_NSEC_GIVES_ERR_ANSWER DS10_HAS_NSEC DS10_INCONSISTENT_NSEC ) ],
        undef,
        [],
        [],
    ],
    'NSEC-GIVES-ERR-ANSWER-2' => [
        1,
        q(nsec-gives-err-answer-2.dnssec10.xa),
        [ qw( DS10_NSEC_GIVES_ERR_ANSWER DS10_EXPECTED_NSEC_NSEC3_MISSING DS10_INCONSISTENT_NSEC DS10_HAS_NSEC ) ],
        undef,
        [],
        [],
    ],
    'NSEC-MISMATCHES-APEX-1' => [
        1,
        q(nsec-mismatches-apex-1.dnssec10.xa),
        [ qw( DS10_NSEC_MISMATCHES_APEX DS10_HAS_NSEC ) ],
        undef,
        [],
        [],
    ],
    'NSEC-MISMATCHES-APEX-2' => [
        1,
        q(nsec-mismatches-apex-2.dnssec10.xa),
        [ qw( DS10_NSEC_MISMATCHES_APEX DS10_HAS_NSEC ) ],
        undef,
        [],
        [],
    ],
    'NSEC-MISSING-SIGNATURE-1' => [
        1,
        q(nsec-missing-signature-1.dnssec10.xa),
        [ qw( DS10_NSEC_MISSING_SIGNATURE DS10_HAS_NSEC ) ],
        undef,
        [],
        [],
    ],
    'NSEC-NODATA-MISSING-SOA-1' => [
        1,
        q(nsec-nodata-missing-soa-1.dnssec10.xa),
        [ qw( DS10_NSEC_NODATA_MISSING_SOA DS10_HAS_NSEC ) ],
        undef,
        [],
        [],
    ],
    'NSEC-NODATA-WRONG-SOA-1' => [
        1,
        q(nsec-nodata-wrong-soa-1.dnssec10.xa),
        [ qw( DS10_NSEC_NODATA_WRONG_SOA DS10_HAS_NSEC ) ],
        undef,
        [],
        [],
    ],
    'NSEC-NO-VERIFIED-SIGNATURE-1' => [
        1,
        q(nsec-no-verified-signature-1.dnssec10.xa),
        [ qw( DS10_NSEC_NO_VERIFIED_SIGNATURE DS10_HAS_NSEC DS10_NSEC_RRSIG_NO_DNSKEY ) ],
        undef,
        [],
        [],
    ],
    'NSEC-NO-VERIFIED-SIGNATURE-2' => [
        1,
        q(nsec-no-verified-signature-2.dnssec10.xa),
        [ qw( DS10_NSEC_NO_VERIFIED_SIGNATURE DS10_HAS_NSEC DS10_NSEC_RRSIG_EXPIRED ) ],
        undef,
        [],
        [],
    ],
    'NSEC-NO-VERIFIED-SIGNATURE-3' => [
        1,
        q(nsec-no-verified-signature-3.dnssec10.xa),
        [ qw( DS10_NSEC_NO_VERIFIED_SIGNATURE DS10_HAS_NSEC DS10_NSEC_RRSIG_NOT_YET_VALID ) ],
        undef,
        [],
        [],
    ],
    'NSEC-NO-VERIFIED-SIGNATURE-4' => [
        1,
        q(nsec-no-verified-signature-4.dnssec10.xa),
        [ qw( DS10_NSEC_NO_VERIFIED_SIGNATURE DS10_HAS_NSEC DS10_NSEC_RRSIG_VERIFY_ERROR ) ],
        undef,
        [],
        [],
    ],
    'NSEC-QUERY-RESPONSE-ERR-1' => [
        1,
        q(nsec-query-response-err-1.dnssec10.xa),
        [ qw( DS10_NSEC_QUERY_RESPONSE_ERR DS10_HAS_NSEC DS10_INCONSISTENT_NSEC ) ],
        undef,
        [],
        [],
    ],
    'NSEC-QUERY-RESPONSE-ERR-2' => [
        1,
        q(nsec-query-response-err-2.dnssec10.xa),
        [ qw( DS10_NSEC_QUERY_RESPONSE_ERR DS10_HAS_NSEC DS10_INCONSISTENT_NSEC ) ],
        undef,
        [],
        [],
    ],
    'NSEC-QUERY-RESPONSE-ERR-3' => [
        0,
        q(nsec-query-response-err-3.dnssec10.xa),
        [ qw( DS10_NSEC_QUERY_RESPONSE_ERR DS10_EXPECTED_NSEC_NSEC3_MISSING DS10_INCONSISTENT_NSEC ) ],
        undef,
        [],
        [],
    ],
    'SERVER-NO-DNSSEC-1' => [
        1,
        q(server-no-dnssec-1.dnssec10.xa),
        [ qw( DS10_SERVER_NO_DNSSEC DS10_HAS_NSEC ) ],
        undef,
        [],
        [],
    ],
    'SERVER-NO-DNSSEC-2' => [
        1,
        q(server-no-dnssec-2.dnssec10.xa),
        [ qw( DS10_SERVER_NO_DNSSEC DS10_HAS_NSEC3 ) ],
        undef,
        [],
        [],
    ],
    'ZONE-NO-DNSSEC-1' => [
        1,
        q(zone-no-dnssec-1.dnssec10.xa),
        [ qw( DS10_ZONE_NO_DNSSEC ) ],
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
