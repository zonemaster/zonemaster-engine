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
# dnssec16 - https://github.com/zonemaster/zonemaster/blob/master/docs/public/specifications/test-zones/DNSSEC-TP/dnssec16.md
my $test_module = q{DNSSEC};
my $test_case = 'dnssec16';
my @all_tags = qw(DS16_CDS_INVALID_RRSIG
                  DS16_CDS_MATCHES_NON_SEP_DNSKEY
                  DS16_CDS_MATCHES_NON_ZONE_DNSKEY
                  DS16_CDS_MATCHES_NO_DNSKEY
                  DS16_CDS_NOT_SIGNED_BY_CDS
                  DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY
                  DS16_CDS_UNSIGNED
                  DS16_CDS_WITHOUT_DNSKEY
                  DS16_DELETE_CDS
                  DS16_DNSKEY_NOT_SIGNED_BY_CDS
                  DS16_MIXED_DELETE_CDS);

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
    'CDS-INVALID-RRSIG' => [
        1,
        q(cds-invalid-rrsig.dnssec16.xa),
        [ qw(DS16_CDS_INVALID_RRSIG) ],
        undef,
        [],
        []
    ],
    'CDS-MATCHES-NO-DNSKEY' => [
        1,
        q(cds-matches-no-dnskey.dnssec16.xa),
        [ qw(DS16_CDS_MATCHES_NO_DNSKEY) ],
        undef,
        [],
        []
    ],
    'CDS-MATCHES-NON-SEP-DNSKEY' => [
        1,
        q(cds-matches-non-sep-dnskey.dnssec16.xa),
        [ qw(DS16_CDS_MATCHES_NON_SEP_DNSKEY) ],
        undef,
        [],
        []
    ],
    'CDS-MATCHES-NON-ZONE-DNSKEY' => [
        1,
        q(cds-matches-non-zone-dnskey.dnssec16.xa),
        [ qw(DS16_CDS_MATCHES_NON_ZONE_DNSKEY) ],
        undef,
        [],
        []
    ],
    'CDS-NOT-SIGNED-BY-CDS' => [
        1,
        q(cds-not-signed-by-cds.dnssec16.xa),
        [ qw(DS16_CDS_NOT_SIGNED_BY_CDS) ],
        undef,
        [],
        []
    ],
    'CDS-SIGNED-BY-UNKNOWN-DNSKEY' => [
        1,
        q(cds-signed-by-unknown-dnskey.dnssec16.xa),
        [ qw(DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY) ],
        undef,
        [],
        []
    ],
    'CDS-UNSIGNED' => [
        1,
        q(cds-unsigned.dnssec16.xa),
        [ qw(DS16_CDS_UNSIGNED DS16_CDS_NOT_SIGNED_BY_CDS) ],
        undef,
        [],
        []
    ],
    'CDS-WITHOUT-DNSKEY' => [
        1,
        q(cds-without-dnskey.dnssec16.xa),
        [ qw(DS16_CDS_WITHOUT_DNSKEY) ],
        undef,
        [],
        []
    ],
    'DELETE-CDS' => [
        1,
        q(delete-cds.dnssec16.xa),
        [ qw(DS16_DELETE_CDS) ],
        undef,
        [],
        []
    ],
    'DNSKEY-NOT-SIGNED-BY-CDS' => [
        1,
        q(dnskey-not-signed-by-cds.dnssec16.xa),
        [ qw(DS16_DNSKEY_NOT_SIGNED_BY_CDS) ],
        undef,
        [],
        []
    ],
    'MIXED-DELETE-CDS' => [
        1,
        q(mixed-delete-cds.dnssec16.xa),
        [ qw(DS16_MIXED_DELETE_CDS) ],
        undef,
        [],
        []
    ],
    'NO-CDS' => [
        1,
        q(no-cds.dnssec16.xa),
        [],
        undef,
        [],
        []
    ],
    'NOT-AA' => [
        1,
        q(not-aa.dnssec16.xa),
        [],
        undef,
        [],
        []
    ],
    'VALID-CDS' => [
        1,
        q(valid-cds.dnssec16.xa),
        [],
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
