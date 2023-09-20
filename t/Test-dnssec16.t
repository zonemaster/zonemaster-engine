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
# dnssec16
my $test_module = q{DNSSEC};
my $test_case = 'dnssec16';

# Common hint file (test-zone-data/COMMON/hintfile)
Zonemaster::Engine::Recursor->remove_fake_addresses( '.' );
Zonemaster::Engine::Recursor->add_fake_addresses( '.',
    { 'ns1' => [ '127.1.0.1', 'fda1:b2:c3::127:1:0:1' ],
      'ns2' => [ '127.1.0.2', 'fda1:b2:c3::127:1:0:2' ],
    }
);

# Test zone scenarios
my %subtests = (
    'CDS-INVALID-RRSIG' => {
        zone => q(cds-invalid-rrsig.dnssec16.xa),
        mandatory => [ qw(DS16_CDS_INVALID_RRSIG) ],
        forbidden => [ qw(DS16_CDS_MATCHES_NON_SEP_DNSKEY DS16_CDS_MATCHES_NON_ZONE_DNSKEY DS16_CDS_MATCHES_NO_DNSKEY DS16_CDS_NOT_SIGNED_BY_CDS DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY DS16_CDS_UNSIGNED DS16_CDS_WITHOUT_DNSKEY DS16_DELETE_CDS DS16_DNSKEY_NOT_SIGNED_BY_CDS DS16_MIXED_DELETE_CD) ],
        testable => 1
    },
    'CDS-MATCHES-NO-DNSKEY' => {
        zone => q(cds-matches-no-dnskey.dnssec16.xa),
        mandatory => [ qw(DS16_CDS_MATCHES_NO_DNSKEY) ],
        forbidden => [ qw(DS16_CDS_INVALID_RRSIG DS16_CDS_MATCHES_NON_SEP_DNSKEY DS16_CDS_MATCHES_NON_ZONE_DNSKEY DS16_CDS_NOT_SIGNED_BY_CDS DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY DS16_CDS_UNSIGNED DS16_CDS_WITHOUT_DNSKEY DS16_DELETE_CDS DS16_DNSKEY_NOT_SIGNED_BY_CDS DS16_MIXED_DELETE_CDS) ],
        testable => 1
    },
    'CDS-MATCHES-NON-SEP-DNSKEY' => {
        zone => q(cds-matches-non-sep-dnskey.dnssec16.xa),
        mandatory => [ qw(DS16_CDS_MATCHES_NON_SEP_DNSKEY) ],
        forbidden => [ qw(DS16_CDS_INVALID_RRSIG DS16_CDS_MATCHES_NON_ZONE_DNSKEY DS16_CDS_MATCHES_NO_DNSKEY DS16_CDS_NOT_SIGNED_BY_CDS DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY DS16_CDS_UNSIGNED DS16_CDS_WITHOUT_DNSKEY DS16_DELETE_CDS DS16_DNSKEY_NOT_SIGNED_BY_CDS DS16_MIXED_DELETE_CDS) ],
        testable => 1
    },
    'CDS-MATCHES-NON-ZONE-DNSKEY' => {
        zone => q(cds-matches-non-zone-dnskey.dnssec16.xa),
        mandatory => [ qw(DS16_CDS_MATCHES_NON_ZONE_DNSKEY) ],
        forbidden => [ qw(DS16_CDS_INVALID_RRSIG DS16_CDS_MATCHES_NON_SEP_DNSKEY DS16_CDS_MATCHES_NO_DNSKEY DS16_CDS_NOT_SIGNED_BY_CDS DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY DS16_CDS_UNSIGNED DS16_CDS_WITHOUT_DNSKEY DS16_DELETE_CDS DS16_DNSKEY_NOT_SIGNED_BY_CDS DS16_MIXED_DELETE_CDS) ],
        testable => 1
    },
    'CDS-NOT-SIGNED-BY-CDS' => {
        zone => q(cds-not-signed-by-cds.dnssec16.xa),
        mandatory => [ qw(DS16_CDS_NOT_SIGNED_BY_CDS) ],
        forbidden => [ qw(DS16_CDS_INVALID_RRSIG DS16_CDS_MATCHES_NON_SEP_DNSKEY DS16_CDS_MATCHES_NON_ZONE_DNSKEY DS16_CDS_MATCHES_NO_DNSKEY DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY DS16_CDS_UNSIGNED DS16_CDS_WITHOUT_DNSKEY DS16_DELETE_CDS DS16_DNSKEY_NOT_SIGNED_BY_CDS DS16_MIXED_DELETE_CDS) ],
        testable => 1
    },
    'CDS-SIGNED-BY-UNKNOWN-DNSKEY' => {
        zone => q(cds-signed-by-unknown-dnskey.dnssec16.xa),
        mandatory => [ qw(DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY) ],
        forbidden => [ qw(DS16_CDS_INVALID_RRSIG DS16_CDS_MATCHES_NON_SEP_DNSKEY DS16_CDS_MATCHES_NON_ZONE_DNSKEY DS16_CDS_MATCHES_NO_DNSKEY DS16_CDS_NOT_SIGNED_BY_CDS DS16_CDS_UNSIGNED DS16_CDS_WITHOUT_DNSKEY DS16_DELETE_CDS DS16_DNSKEY_NOT_SIGNED_BY_CDS DS16_MIXED_DELETE_CDS) ],
        testable => 1
    },
    'CDS-UNSIGNED' => {
        zone => q(cds-unsigned.dnssec16.xa),
        mandatory => [ qw(DS16_CDS_UNSIGNED DS16_CDS_NOT_SIGNED_BY_CDS) ],
        forbidden => [ qw(DS16_CDS_INVALID_RRSIG DS16_CDS_MATCHES_NON_SEP_DNSKEY DS16_CDS_MATCHES_NON_ZONE_DNSKEY DS16_CDS_MATCHES_NO_DNSKEY DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY DS16_CDS_WITHOUT_DNSKEY DS16_DELETE_CDS DS16_DNSKEY_NOT_SIGNED_BY_CDS DS16_MIXED_DELETE_CDS) ],
        testable => 1
    },
    'CDS-WITHOUT-DNSKEY' => {
        zone => q(cds-without-dnskey.dnssec16.xa),
        mandatory => [ qw(DS16_CDS_WITHOUT_DNSKEY) ],
        forbidden => [ qw(DS16_CDS_INVALID_RRSIG DS16_CDS_MATCHES_NON_SEP_DNSKEY DS16_CDS_MATCHES_NON_ZONE_DNSKEY DS16_CDS_MATCHES_NO_DNSKEY DS16_CDS_NOT_SIGNED_BY_CDS DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY DS16_CDS_UNSIGNED DS16_DELETE_CDS DS16_DNSKEY_NOT_SIGNED_BY_CDS DS16_MIXED_DELETE_CDS) ],
        testable => 1
    },
    'DELETE-CDS' => {
        zone => q(delete-cds.dnssec16.xa),
        mandatory => [ qw(DS16_DELETE_CDS) ],
        forbidden => [ qw(DS16_CDS_INVALID_RRSIG DS16_CDS_MATCHES_NON_SEP_DNSKEY DS16_CDS_MATCHES_NON_ZONE_DNSKEY DS16_CDS_MATCHES_NO_DNSKEY DS16_CDS_NOT_SIGNED_BY_CDS DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY DS16_CDS_UNSIGNED DS16_CDS_WITHOUT_DNSKEY DS16_DNSKEY_NOT_SIGNED_BY_CDS DS16_MIXED_DELETE_CDS) ],
        testable => 1
    },
    'DNSKEY-NOT-SIGNED-BY-CDS' => {
        zone => q(dnskey-not-signed-by-cds.dnssec16.xa),
        mandatory => [ qw(DS16_DNSKEY_NOT_SIGNED_BY_CDS) ],
        forbidden => [ qw(DS16_CDS_INVALID_RRSIG DS16_CDS_MATCHES_NON_SEP_DNSKEY DS16_CDS_MATCHES_NON_ZONE_DNSKEY DS16_CDS_MATCHES_NO_DNSKEY DS16_CDS_NOT_SIGNED_BY_CDS DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY DS16_CDS_UNSIGNED DS16_CDS_WITHOUT_DNSKEY DS16_DELETE_CDS DS16_MIXED_DELETE_CDS) ],
        testable => 1
    },
    'MIXED-DELETE-CDS' => {
        zone => q(mixed-delete-cds.dnssec16.xa),
        mandatory => [ qw(DS16_MIXED_DELETE_CDS) ],
        forbidden => [ qw(DS16_CDS_INVALID_RRSIG DS16_CDS_MATCHES_NON_SEP_DNSKEY DS16_CDS_MATCHES_NON_ZONE_DNSKEY DS16_CDS_MATCHES_NO_DNSKEY DS16_CDS_NOT_SIGNED_BY_CDS DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY DS16_CDS_UNSIGNED DS16_CDS_WITHOUT_DNSKEY DS16_DELETE_CDS DS16_DNSKEY_NOT_SIGNED_BY_CDS) ],
        testable => 1
    },
    'NO-CDS' => {
        zone => q(no-cds.dnssec16.xa),
        mandatory => [],
        forbidden => [ qw(DS16_CDS_INVALID_RRSIG DS16_CDS_MATCHES_NON_SEP_DNSKEY DS16_CDS_MATCHES_NON_ZONE_DNSKEY DS16_CDS_MATCHES_NO_DNSKEY DS16_CDS_NOT_SIGNED_BY_CDS DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY DS16_CDS_UNSIGNED DS16_CDS_WITHOUT_DNSKEY DS16_DELETE_CDS DS16_DNSKEY_NOT_SIGNED_BY_CDS DS16_MIXED_DELETE_CDS) ],
        testable => 1
    },
    'NOT-AA' => {
        zone => q(not-aa.dnssec16.xa),
        mandatory => [],
        forbidden => [ qw(DS16_CDS_INVALID_RRSIG DS16_CDS_MATCHES_NON_SEP_DNSKEY DS16_CDS_MATCHES_NON_ZONE_DNSKEY DS16_CDS_MATCHES_NO_DNSKEY DS16_CDS_NOT_SIGNED_BY_CDS DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY DS16_CDS_UNSIGNED DS16_CDS_WITHOUT_DNSKEY DS16_DELETE_CDS DS16_DNSKEY_NOT_SIGNED_BY_CDS DS16_MIXED_DELETE_CDS) ],
        testable => 1
    },
    'VALID-CDS' => {
        zone => q(valid-cds.dnssec16.xa),
        mandatory => [],
        forbidden => [ qw(DS16_CDS_INVALID_RRSIG DS16_CDS_MATCHES_NON_SEP_DNSKEY DS16_CDS_MATCHES_NON_ZONE_DNSKEY DS16_CDS_MATCHES_NO_DNSKEY DS16_CDS_NOT_SIGNED_BY_CDS DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY DS16_CDS_UNSIGNED DS16_CDS_WITHOUT_DNSKEY DS16_DELETE_CDS DS16_DNSKEY_NOT_SIGNED_BY_CDS DS16_MIXED_DELETE_CDS) ],
        testable => 1
    }
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
