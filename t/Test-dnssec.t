use Test::More;
use Test::Differences;
use File::Slurp;

use List::MoreUtils qw[uniq none any];

use Zonemaster::Engine;
use Zonemaster::Engine::Nameserver;
use Zonemaster::Engine::Profile;

use strict;

BEGIN {
    use_ok( 'Zonemaster::Engine' );
    use_ok( 'Zonemaster::Engine::Test::DNSSEC' );
}

my $checking_module = q{DNSSEC};

use Data::Dumper;

sub zone_gives {
    my ( $test, $zone, $gives_ref ) = @_;

    Zonemaster::Engine->logger->clear_history();
    my @res = grep { $_->tag !~ /^TEST_CASE_(END|START)$/ } Zonemaster::Engine->test_method( $checking_module, $test, $zone );
    foreach my $gives ( @{$gives_ref} ) {
        ok( ( grep { $_->tag eq $gives } @res ), $zone->name->string . " gives $gives" );
    }
    return scalar( @res );
}

sub zone_gives_not {
    my ( $test, $zone, $gives_ref ) = @_;

    Zonemaster::Engine->logger->clear_history();
    my @res = grep { $_->tag !~ /^TEST_CASE_(END|START)$/ } Zonemaster::Engine->test_method( $checking_module, $test, $zone );
    foreach my $gives ( @{$gives_ref} ) {
        ok( !( grep { $_->tag eq $gives } @res ), $zone->name->string . " does not give $gives" );
    }
    return scalar( @res );
}

my $datafile = 't/Test-dnssec.data';
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die "Stored data file missing" if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine->profile->set( q{no_network}, 1 );
}

# Find a way for dnssec06 which has a dependence...
my ($json, $profile_test);
foreach my $testcase ( qw{dnssec01 dnssec02 dnssec04 dnssec05 dnssec07 dnssec08 dnssec09 dnssec10 dnssec11 dnssec13 dnssec14 dnssec15 dnssec17 dnssec18} ) {
    $json         = read_file( 't/profiles/Test-'.$testcase.'-only.json' );
    $profile_test = Zonemaster::Engine::Profile->from_json( $json );
    Zonemaster::Engine::Profile->effective->merge( $profile_test );
    my %testcases;
    Zonemaster::Engine->logger->clear_history();
    foreach my $result ( Zonemaster::Engine->test_module( q{dnssec}, q{se} ) ) {
        if ( $result->testcase && $result->testcase ne 'Unspecified' ) {
            $testcases{$result->testcase} = 1;
        }
    }
    eq_or_diff( [ map { lc $_ } keys %testcases ], [ $testcase ], 'expected test-case ('. $testcase .')' );
}

$json         = read_file( 't/profiles/Test-dnssec-all.json' );
$profile_test = Zonemaster::Engine::Profile->from_json( $json );
Zonemaster::Engine::Profile->effective->merge( $profile_test );

my $zone = Zonemaster::Engine->zone( 'nic.se' );

my @res = Zonemaster::Engine->test_method( 'DNSSEC', 'dnssec04', $zone );
my %tag = map { $_->tag => 1 } @res;
ok( ( $tag{DURATION_OK} || $tag{REMAINING_SHORT} || $tag{RRSIG_EXPIRED} ), 'DURATION_OK (sort of)' );

my $zone4 = Zonemaster::Engine->zone( 'nic.fr' );
zone_gives( 'dnssec05', $zone4, [q{ALGORITHM_OK}] );

zone_gives( 'dnssec06', $zone, [q{EXTRA_PROCESSING_OK}] );

zone_gives( 'dnssec07', $zone, [q{DNSKEY_AND_DS}] );
zone_gives_not( 'dnssec07', $zone, [qw{NEITHER_DNSKEY_NOR_DS DNSKEY_BUT_NOT_DS DS_BUT_NOT_DNSKEY}] );

###########
# dnssec01
###########
$zone = Zonemaster::Engine->zone( 'dnssec01-ds-algorithm-ok.zut-root.rd.nic.fr' );
zone_gives_not( 'dnssec01', $zone, [qw{DS01_DS_ALGO_DEPRECATED DS01_DS_ALGO_RESERVED DS01_DS_ALGO_NOT_DS DS01_DS_ALGO_2_MISSING DS01_DIGEST_NOT_SUPPORTED_BY_ZM}] );

$zone = Zonemaster::Engine->zone( 'dnssec01-nxdomain.zut-root.rd.nic.fr' );
zone_gives_not( 'dnssec01', $zone, [qw{DS01_DS_ALGO_DEPRECATED DS01_DS_ALGO_RESERVED DS01_DS_ALGO_NOT_DS DS01_DS_ALGO_2_MISSING DS01_DIGEST_NOT_SUPPORTED_BY_ZM}] );

$zone = Zonemaster::Engine->zone( 'dnssec01-ds-algorithm-not-ds.zut-root.rd.nic.fr' );
zone_gives( 'dnssec01', $zone, [qw{DS01_DS_ALGO_NOT_DS DS01_DS_ALGO_2_MISSING DS01_DIGEST_NOT_SUPPORTED_BY_ZM}] );
zone_gives_not( 'dnssec01', $zone, [qw{DS01_DS_ALGO_DEPRECATED DS01_DS_ALGO_RESERVED}] );

$zone = Zonemaster::Engine->zone( 'dnssec01-ds-algorithm-deprecated1.zut-root.rd.nic.fr' );
zone_gives( 'dnssec01', $zone, [qw{DS01_DS_ALGO_DEPRECATED DS01_DS_ALGO_2_MISSING}] );
zone_gives_not( 'dnssec01', $zone, [qw{DS01_DS_ALGO_NOT_DS DS01_DS_ALGO_RESERVED DS01_DIGEST_NOT_SUPPORTED_BY_ZM}] );

$zone = Zonemaster::Engine->zone( 'dnssec01-ds-algorithm-deprecated3.zut-root.rd.nic.fr' );
zone_gives( 'dnssec01', $zone, [qw{DS01_DS_ALGO_DEPRECATED DS01_DS_ALGO_2_MISSING DS01_DIGEST_NOT_SUPPORTED_BY_ZM}] );
zone_gives_not( 'dnssec01', $zone, [qw{DS01_DS_ALGO_NOT_DS DS01_DS_ALGO_RESERVED}] );

$zone = Zonemaster::Engine->zone( 'dnssec01-ds-algorithm-reserved.zut-root.rd.nic.fr' );
zone_gives( 'dnssec01', $zone, [qw{DS01_DS_ALGO_RESERVED DS01_DS_ALGO_2_MISSING DS01_DIGEST_NOT_SUPPORTED_BY_ZM}] );
zone_gives_not( 'dnssec01', $zone, [qw{DS01_DS_ALGO_DEPRECATED DS01_DS_ALGO_NOT_DS}] );

###########
# dnssec02
###########
$zone = Zonemaster::Engine->zone( 'dnssec02-dnskey-ksk-not-sep.zut-root.rd.nic.fr' );
zone_gives( 'dnssec02', $zone, [qw{DS02_DNSKEY_NOT_SEP}] );
zone_gives_not( 'dnssec02', $zone, [qw{DS02_ALGO_NOT_SUPPORTED_BY_ZM DS02_DNSKEY_NOT_FOR_ZONE_SIGNING DS02_NO_DNSKEY_FOR_DS DS02_NO_MATCHING_DNSKEY_RRSIG DS02_NO_MATCH_DS_DNSKEY DS02_RRSIG_NOT_VALID_BY_DNSKEY DS02_NO_VALID_DNSKEY_FOR_ANY_DS DS02_DNSKEY_NOT_SIGNED_BY_ANY_DS}] );

$zone = Zonemaster::Engine->zone( 'dnssec02-no-common-keytags.zut-root.rd.nic.fr' );
zone_gives( 'dnssec02', $zone, [qw{DS02_NO_DNSKEY_FOR_DS DS02_NO_VALID_DNSKEY_FOR_ANY_DS}] );
zone_gives_not( 'dnssec02', $zone, [qw{DS02_ALGO_NOT_SUPPORTED_BY_ZM DS02_DNSKEY_NOT_FOR_ZONE_SIGNING DS02_DNSKEY_NOT_SEP DS02_NO_MATCHING_DNSKEY_RRSIG DS02_NO_MATCH_DS_DNSKEY DS02_RRSIG_NOT_VALID_BY_DNSKEY DS02_DNSKEY_NOT_SIGNED_BY_ANY_DS}] );

$zone = Zonemaster::Engine->zone( 'dnssec08-dnskey-not-signed.zut-root.rd.nic.fr' );
zone_gives( 'dnssec02', $zone, [qw{DS02_NO_MATCHING_DNSKEY_RRSIG DS02_DNSKEY_NOT_SIGNED_BY_ANY_DS}] );
zone_gives_not( 'dnssec02', $zone, [qw{DS02_ALGO_NOT_SUPPORTED_BY_ZM DS02_DNSKEY_NOT_FOR_ZONE_SIGNING DS02_DNSKEY_NOT_SEP DS02_NO_DNSKEY_FOR_DS DS02_NO_MATCH_DS_DNSKEY DS02_RRSIG_NOT_VALID_BY_DNSKEY DS02_NO_VALID_DNSKEY_FOR_ANY_DS}] );

$zone = Zonemaster::Engine->zone( 'dnssec02-ds-does-not-match-dnskey.zut-root.rd.nic.fr' );
zone_gives( 'dnssec02', $zone, [qw{DS02_NO_MATCH_DS_DNSKEY}] );
zone_gives_not( 'dnssec02', $zone, [qw{DS02_ALGO_NOT_SUPPORTED_BY_ZM DS02_DNSKEY_NOT_FOR_ZONE_SIGNING DS02_DNSKEY_NOT_SEP DS02_NO_DNSKEY_FOR_DS DS02_NO_MATCHING_DNSKEY_RRSIG DS02_RRSIG_NOT_VALID_BY_DNSKEY DS02_NO_VALID_DNSKEY_FOR_ANY_DS DS02_DNSKEY_NOT_SIGNED_BY_ANY_DS}] );

$zone = Zonemaster::Engine->zone( 'dnssec08-dnskey-signature-not-ok-broken.zut-root.rd.nic.fr' );
zone_gives( 'dnssec02', $zone, [qw{DS02_RRSIG_NOT_VALID_BY_DNSKEY DS02_NO_MATCHING_DNSKEY_RRSIG DS02_DNSKEY_NOT_SIGNED_BY_ANY_DS}] );
zone_gives_not( 'dnssec02', $zone, [qw{DS02_ALGO_NOT_SUPPORTED_BY_ZM DS02_DNSKEY_NOT_FOR_ZONE_SIGNING DS02_DNSKEY_NOT_SEP DS02_NO_DNSKEY_FOR_DS DS02_NO_MATCH_DS_DNSKEY DS02_NO_VALID_DNSKEY_FOR_ANY_DS}] );

###########
# dnssec04
###########
$zone = Zonemaster::Engine->zone( 'dnssec04-duration-long.zut-root.rd.nic.fr' );
zone_gives( 'dnssec04', $zone, [q{DURATION_LONG}] );

$zone = Zonemaster::Engine->zone( 'dnssec04-remaining-long.zut-root.rd.nic.fr' );
zone_gives( 'dnssec04', $zone, [q{REMAINING_LONG}] );

###########
# dnssec05
###########
$zone = Zonemaster::Engine->zone( 'dnssec05-algorithm-deprecated.zut-root.rd.nic.fr' );
zone_gives( 'dnssec05', $zone, [q{ALGORITHM_DEPRECATED}] );
zone_gives_not( 'dnssec05', $zone, [qw{ALGORITHM_RESERVED ALGORITHM_UNASSIGNED ALGORITHM_PRIVATE ALGORITHM_UNKNOWN}] );

$zone = Zonemaster::Engine->zone( 'dnssec05-algorithm-reserved.zut-root.rd.nic.fr' );
zone_gives( 'dnssec05', $zone, [q{ALGORITHM_RESERVED}] );
zone_gives_not( 'dnssec05', $zone,
    [qw{ALGORITHM_DEPRECATED ALGORITHM_UNASSIGNED ALGORITHM_PRIVATE ALGORITHM_UNKNOWN}] );

$zone = Zonemaster::Engine->zone( 'dnssec05-algorithm-unassigned.zut-root.rd.nic.fr' );
zone_gives( 'dnssec05', $zone, [q{ALGORITHM_UNASSIGNED}] );
zone_gives_not( 'dnssec05', $zone, [qw{ALGORITHM_DEPRECATED ALGORITHM_RESERVED ALGORITHM_PRIVATE ALGORITHM_UNKNOWN}] );

$zone = Zonemaster::Engine->zone( 'dnssec05-algorithm-private.zut-root.rd.nic.fr' );
zone_gives( 'dnssec05', $zone, [q{ALGORITHM_PRIVATE}] );
zone_gives_not( 'dnssec05', $zone,
    [qw{ALGORITHM_DEPRECATED ALGORITHM_RESERVED ALGORITHM_UNASSIGNED ALGORITHM_UNKNOWN}] );

###########
# dnssec06
###########
$zone = Zonemaster::Engine->zone( 'dnssec06-extra-processing-broken-1.zut-root.rd.nic.fr' );
zone_gives( 'dnssec06', $zone, [q{EXTRA_PROCESSING_BROKEN}] );
zone_gives_not( 'dnssec06', $zone, [q{EXTRA_PROCESSING_OK}] );

$zone = Zonemaster::Engine->zone( 'dnssec06-extra-processing-broken-2.zut-root.rd.nic.fr' );
zone_gives( 'dnssec06', $zone, [q{EXTRA_PROCESSING_BROKEN}] );
zone_gives_not( 'dnssec06', $zone, [q{EXTRA_PROCESSING_OK}] );

###########
# dnssec07
###########
$zone = Zonemaster::Engine->zone( 'dnssec07-dnskey-but-not-ds.zut-root.rd.nic.fr' );
zone_gives( 'dnssec07', $zone, [q{DNSKEY_BUT_NOT_DS}] );
zone_gives_not( 'dnssec07', $zone, [qw{DNSKEY_AND_DS DS_BUT_NOT_DNSKEY NEITHER_DNSKEY_NOR_DS}] );

$zone = Zonemaster::Engine->zone( 'dnssec07-neither-dnskey-nor-ds.zut-root.rd.nic.fr' );
zone_gives( 'dnssec07', $zone, [q{NEITHER_DNSKEY_NOR_DS}] );
zone_gives_not( 'dnssec07', $zone, [qw{DNSKEY_BUT_NOT_DS DNSKEY_AND_DS DS_BUT_NOT_DNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec07-ds-but-not-dnskey.zut-root.rd.nic.fr' );
zone_gives( 'dnssec07', $zone, [q{DS_BUT_NOT_DNSKEY}] );
zone_gives_not( 'dnssec07', $zone, [qw{NEITHER_DNSKEY_NOR_DS DNSKEY_BUT_NOT_DS DNSKEY_AND_DS}] );

###########
# dnssec08
###########
$zone = Zonemaster::Engine->zone( 'dnssec08-dnskey-signature-not-ok-broken.zut-root.rd.nic.fr' );
zone_gives( 'dnssec08', $zone, [qw{DS08_DNSKEY_RRSIG_EXPIRED DS08_RRSIG_NOT_VALID_BY_DNSKEY}] );
zone_gives_not( 'dnssec08', $zone, [qw{DS08_ALGO_NOT_SUPPORTED_BY_ZM DS08_DNSKEY_RRSIG_NOT_YET_VALID DS08_MISSING_RRSIG_IN_RESPONSE DS08_NO_MATCHING_DNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec08-dnskey-signature-not-ok.zut-root.rd.nic.fr' );
zone_gives_not( 'dnssec08', $zone, [qw{DS08_DNSKEY_RRSIG_EXPIRED DS08_ALGO_NOT_SUPPORTED_BY_ZM DS08_DNSKEY_RRSIG_NOT_YET_VALID DS08_MISSING_RRSIG_IN_RESPONSE DS08_NO_MATCHING_DNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec08-dnskey-not-signed.zut-root.rd.nic.fr' );
zone_gives( 'dnssec08', $zone, [q{DS08_MISSING_RRSIG_IN_RESPONSE}] );
zone_gives_not( 'dnssec08', $zone, [qw{DS08_ALGO_NOT_SUPPORTED_BY_ZM DS08_DNSKEY_RRSIG_EXPIRED DS08_DNSKEY_RRSIG_NOT_YET_VALID DS08_NO_MATCHING_DNSKEY DS08_RRSIG_NOT_VALID_BY_DNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec08-dnskey-rrsig-not-yet-valid.zft-root.rd.nic.fr' );
zone_gives( 'dnssec08', $zone, [q{DS08_DNSKEY_RRSIG_NOT_YET_VALID}] );
zone_gives_not( 'dnssec08', $zone, [qw{DS08_ALGO_NOT_SUPPORTED_BY_ZM DS08_DNSKEY_RRSIG_EXPIRED DS08_MISSING_RRSIG_IN_RESPONSE DS08_NO_MATCHING_DNSKEY DS08_RRSIG_NOT_VALID_BY_DNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec08-rrsig-no-matching-dnskey.zft-root.rd.nic.fr' );
zone_gives( 'dnssec08', $zone, [qw{DS08_NO_MATCHING_DNSKEY DS08_RRSIG_NOT_VALID_BY_DNSKEY}] );
zone_gives_not( 'dnssec08', $zone, [qw{DS08_ALGO_NOT_SUPPORTED_BY_ZM DS08_DNSKEY_RRSIG_EXPIRED DS08_DNSKEY_RRSIG_NOT_YET_VALID DS08_MISSING_RRSIG_IN_RESPONSE}] );

###########
# dnssec09
###########
$zone = Zonemaster::Engine->zone( 'dnssec09-soa-rrsig-not-yet-valid.zft-root.rd.nic.fr' );
zone_gives( 'dnssec09', $zone, [qw{DS09_SOA_RRSIG_NOT_YET_VALID}] );
zone_gives_not( 'dnssec09', $zone, [qw{DS09_ALGO_NOT_SUPPORTED_BY_ZM DS09_MISSING_RRSIG_IN_RESPONSE DS09_NO_MATCHING_DNSKEY DS09_RRSIG_NOT_VALID_BY_DNSKEY DS09_SOA_RRSIG_EXPIRED}] );

$zone = Zonemaster::Engine->zone( 'dnssec09-rrsig-no-matching-dnskey.zft-root.rd.nic.fr' );
zone_gives( 'dnssec09', $zone, [qw{DS09_NO_MATCHING_DNSKEY}] );
zone_gives_not( 'dnssec09', $zone, [qw{DS09_ALGO_NOT_SUPPORTED_BY_ZM DS09_MISSING_RRSIG_IN_RESPONSE DS09_RRSIG_NOT_VALID_BY_DNSKEY DS09_SOA_RRSIG_EXPIRED DS09_SOA_RRSIG_NOT_YET_VALID}] );

$zone = Zonemaster::Engine->zone( 'dnssec09-soa-not-signed.zft-root.rd.nic.fr' );
zone_gives( 'dnssec09', $zone, [qw{DS09_MISSING_RRSIG_IN_RESPONSE}] );
zone_gives_not( 'dnssec09', $zone, [qw{DS09_ALGO_NOT_SUPPORTED_BY_ZM DS09_NO_MATCHING_DNSKEY DS09_RRSIG_NOT_VALID_BY_DNSKEY DS09_SOA_RRSIG_EXPIRED DS09_SOA_RRSIG_NOT_YET_VALID}] );

$zone = Zonemaster::Engine->zone( 'dnssec09-soa-rrsig-expired.zft-root.rd.nic.fr' );
zone_gives( 'dnssec09', $zone, [qw{DS09_SOA_RRSIG_EXPIRED}] );
zone_gives_not( 'dnssec09', $zone, [qw{DS09_ALGO_NOT_SUPPORTED_BY_ZM DS09_MISSING_RRSIG_IN_RESPONSE DS09_NO_MATCHING_DNSKEY DS09_RRSIG_NOT_VALID_BY_DNSKEY DS09_SOA_RRSIG_NOT_YET_VALID}] );

$zone = Zonemaster::Engine->zone( 'dnssec09-rrsig-not-valid-by-dnskey.zft-root.rd.nic.fr' );
zone_gives( 'dnssec09', $zone, [qw{DS09_RRSIG_NOT_VALID_BY_DNSKEY}] );
zone_gives_not( 'dnssec09', $zone, [qw{DS09_ALGO_NOT_SUPPORTED_BY_ZM DS09_MISSING_RRSIG_IN_RESPONSE DS09_NO_MATCHING_DNSKEY DS09_SOA_RRSIG_EXPIRED DS09_SOA_RRSIG_NOT_YET_VALID}] );

###########
# dnssec10
###########
$zone = Zonemaster::Engine->zone( 'dnssec10-non-existent-domain-name-exists-01.zft-root.rd.nic.fr' );
zone_gives_not( 'dnssec10', $zone, [qw{DS10_ALGO_NOT_SUPPORTED_BY_ZM DS10_ANSWER_VERIFY_ERROR DS10_HAS_NSEC DS10_HAS_NSEC3 DS10_INCONSISTENT_NSEC_NSEC3 DS10_MISSING_NSEC_NSEC3 DS10_MIXED_NSEC_NSEC3 DS10_NAME_NOT_COVERED_BY_NSEC DS10_NAME_NOT_COVERED_BY_NSEC3 DS10_NON_EXISTENT_RESPONSE_ERROR DS10_NSEC3_MISSING_SIGNATURE DS10_NSEC3_RRSIG_VERIFY_ERROR DS10_NSEC_MISSING_SIGNATURE DS10_NSEC_RRSIG_VERIFY_ERROR DS10_UNSIGNED_ANSWER}] );

$zone = Zonemaster::Engine->zone( 'dnssec10-non-existent-domain-name-exists-02.zft-root.rd.nic.fr' );
zone_gives_not( 'dnssec10', $zone, [qw{DS10_ALGO_NOT_SUPPORTED_BY_ZM DS10_ANSWER_VERIFY_ERROR DS10_HAS_NSEC DS10_HAS_NSEC3 DS10_INCONSISTENT_NSEC_NSEC3 DS10_MISSING_NSEC_NSEC3 DS10_MIXED_NSEC_NSEC3 DS10_NAME_NOT_COVERED_BY_NSEC DS10_NAME_NOT_COVERED_BY_NSEC3 DS10_NON_EXISTENT_RESPONSE_ERROR DS10_NSEC3_MISSING_SIGNATURE DS10_NSEC3_RRSIG_VERIFY_ERROR DS10_NSEC_MISSING_SIGNATURE DS10_NSEC_RRSIG_VERIFY_ERROR DS10_UNSIGNED_ANSWER}] );

$zone = Zonemaster::Engine->zone( 'dnssec10-non-existent-domain-name-exists-03.zft-root.rd.nic.fr' );
zone_gives( 'dnssec10', $zone, [qw{DS10_HAS_NSEC DS10_NAME_NOT_COVERED_BY_NSEC}] );
zone_gives_not( 'dnssec10', $zone, [qw{DS10_ALGO_NOT_SUPPORTED_BY_ZM DS10_ANSWER_VERIFY_ERROR DS10_HAS_NSEC3 DS10_INCONSISTENT_NSEC_NSEC3 DS10_MISSING_NSEC_NSEC3 DS10_MIXED_NSEC_NSEC3 DS10_NAME_NOT_COVERED_BY_NSEC3 DS10_NON_EXISTENT_RESPONSE_ERROR DS10_NSEC3_MISSING_SIGNATURE DS10_NSEC3_RRSIG_VERIFY_ERROR DS10_NSEC_MISSING_SIGNATURE DS10_NSEC_RRSIG_VERIFY_ERROR DS10_UNSIGNED_ANSWER}] );

$zone = Zonemaster::Engine->zone( 'dnssec10-non-existent-domain-name-exists-04.zft-root.rd.nic.fr' );
zone_gives_not( 'dnssec10', $zone, [qw{DS10_ALGO_NOT_SUPPORTED_BY_ZM DS10_ANSWER_VERIFY_ERROR DS10_HAS_NSEC DS10_HAS_NSEC3 DS10_INCONSISTENT_NSEC_NSEC3 DS10_MISSING_NSEC_NSEC3 DS10_MIXED_NSEC_NSEC3 DS10_NAME_NOT_COVERED_BY_NSEC DS10_NAME_NOT_COVERED_BY_NSEC3 DS10_NON_EXISTENT_RESPONSE_ERROR DS10_NSEC3_MISSING_SIGNATURE DS10_NSEC3_RRSIG_VERIFY_ERROR DS10_NSEC_MISSING_SIGNATURE DS10_NSEC_RRSIG_VERIFY_ERROR DS10_UNSIGNED_ANSWER}] );

$zone = Zonemaster::Engine->zone( 'dnssec10-non-existent-domain-name-exists-05.zft-root.rd.nic.fr' );
zone_gives( 'dnssec10', $zone, [q{DS10_ANSWER_VERIFY_ERROR}] );
zone_gives_not( 'dnssec10', $zone, [qw{DS10_ALGO_NOT_SUPPORTED_BY_ZM DS10_HAS_NSEC DS10_HAS_NSEC3 DS10_INCONSISTENT_NSEC_NSEC3 DS10_MISSING_NSEC_NSEC3 DS10_MIXED_NSEC_NSEC3 DS10_NAME_NOT_COVERED_BY_NSEC DS10_NAME_NOT_COVERED_BY_NSEC3 DS10_NON_EXISTENT_RESPONSE_ERROR DS10_NSEC3_MISSING_SIGNATURE DS10_NSEC3_RRSIG_VERIFY_ERROR DS10_NSEC_MISSING_SIGNATURE DS10_NSEC_RRSIG_VERIFY_ERROR DS10_UNSIGNED_ANSWER}] );

$zone = Zonemaster::Engine->zone( 'dnssec11-inconsistent-dnskey.zft-root.rd.nic.fr' );
zone_gives( 'dnssec10', $zone, [q{DS10_MISSING_NSEC_NSEC3}] );
zone_gives_not( 'dnssec10', $zone, [qw{DS10_ALGO_NOT_SUPPORTED_BY_ZM DS10_ANSWER_VERIFY_ERROR DS10_HAS_NSEC DS10_HAS_NSEC3 DS10_INCONSISTENT_NSEC_NSEC3 DS10_MIXED_NSEC_NSEC3 DS10_NAME_NOT_COVERED_BY_NSEC DS10_NAME_NOT_COVERED_BY_NSEC3 DS10_NON_EXISTENT_RESPONSE_ERROR DS10_NSEC3_MISSING_SIGNATURE DS10_NSEC3_RRSIG_VERIFY_ERROR DS10_NSEC_MISSING_SIGNATURE DS10_NSEC_RRSIG_VERIFY_ERROR DS10_UNSIGNED_ANSWER}] );

$zone = Zonemaster::Engine->zone( 'dnssec10-inconsistent-nsec-nsec3.zft-root.rd.nic.fr' );
zone_gives( 'dnssec10', $zone, [q{DS10_INCONSISTENT_NSEC_NSEC3}] );
zone_gives_not( 'dnssec10', $zone, [qw{DS10_ALGO_NOT_SUPPORTED_BY_ZM DS10_ANSWER_VERIFY_ERROR DS10_HAS_NSEC DS10_HAS_NSEC3 DS10_MISSING_NSEC_NSEC3 DS10_MIXED_NSEC_NSEC3 DS10_NAME_NOT_COVERED_BY_NSEC DS10_NAME_NOT_COVERED_BY_NSEC3 DS10_NON_EXISTENT_RESPONSE_ERROR DS10_NSEC3_MISSING_SIGNATURE DS10_NSEC_MISSING_SIGNATURE DS10_NSEC_RRSIG_VERIFY_ERROR DS10_UNSIGNED_ANSWER}] );

$zone = Zonemaster::Engine->zone( 'se' );
zone_gives( 'dnssec10', $zone, [q{DS10_HAS_NSEC}] );
zone_gives_not( 'dnssec10', $zone, [qw{DS10_ALGO_NOT_SUPPORTED_BY_ZM DS10_ANSWER_VERIFY_ERROR DS10_HAS_NSEC3 DS10_INCONSISTENT_NSEC_NSEC3 DS10_MISSING_NSEC_NSEC3 DS10_MIXED_NSEC_NSEC3 DS10_NAME_NOT_COVERED_BY_NSEC DS10_NAME_NOT_COVERED_BY_NSEC3 DS10_NON_EXISTENT_RESPONSE_ERROR DS10_NSEC3_MISSING_SIGNATURE DS10_NSEC3_RRSIG_VERIFY_ERROR DS10_NSEC_MISSING_SIGNATURE DS10_NSEC_RRSIG_VERIFY_ERROR DS10_UNSIGNED_ANSWER}] );

$zone = Zonemaster::Engine->zone( 'zonemaster.fr' );
zone_gives( 'dnssec10', $zone, [q{DS10_HAS_NSEC3}] );
zone_gives_not( 'dnssec10', $zone, [qw{DS10_ALGO_NOT_SUPPORTED_BY_ZM DS10_ANSWER_VERIFY_ERROR DS10_HAS_NSEC DS10_INCONSISTENT_NSEC_NSEC3 DS10_MISSING_NSEC_NSEC3 DS10_MIXED_NSEC_NSEC3 DS10_NAME_NOT_COVERED_BY_NSEC DS10_NAME_NOT_COVERED_BY_NSEC3 DS10_NON_EXISTENT_RESPONSE_ERROR DS10_NSEC3_MISSING_SIGNATURE DS10_NSEC3_RRSIG_VERIFY_ERROR DS10_NSEC_MISSING_SIGNATURE DS10_NSEC_RRSIG_VERIFY_ERROR DS10_UNSIGNED_ANSWER}] );

# GOST
#$zone = Zonemaster::Engine->zone( 'caint.su' );
#@res = Zonemaster::Engine->test_method( 'DNSSEC', 'dnssec08', $zone );
#ok( ( grep { $_->string =~ /error=no GOST support/s } @res ), $zone->name->string . " no GOST support" );
#@res = Zonemaster::Engine->test_method( 'DNSSEC', 'dnssec09', $zone );
#ok( ( grep { $_->string =~ /error=no GOST support/s } @res ), $zone->name->string . " no GOST support" );
#@res = Zonemaster::Engine->test_method( 'DNSSEC', 'dnssec10', $zone );
#ok( ( grep { $_->string =~ /error=no GOST support/s } @res ), $zone->name->string . " no GOST support" );


###########
# dnssec11
###########
$zone = Zonemaster::Engine->zone( 'zone-does-not-exist.zut-root.rd.nic.fr' );
zone_gives( 'dnssec11', $zone, [qw{DS11_UNDETERMINED_DS}] );
zone_gives_not( 'dnssec11', $zone, [qw{DS11_INCONSISTENT_DS DS11_INCONSISTENT_SIGNED_ZONE DS11_UNDETERMINED_SIGNED_ZONE DS11_PARENT_WITHOUT_DS DS11_PARENT_WITH_DS DS11_NS_WITH_SIGNED_ZONE DS11_NS_WITH_UNSIGNED_ZONE DS11_DS_BUT_UNSIGNED_ZONE}] );

$zone = Zonemaster::Engine->zone( 'dnssec11-inconsistent-ds.dnssec11-parent.zft-root.rd.nic.fr' );
zone_gives( 'dnssec11', $zone, [qw{DS11_INCONSISTENT_DS DS11_PARENT_WITHOUT_DS DS11_PARENT_WITH_DS}] );
zone_gives_not( 'dnssec11', $zone, [qw{DS11_INCONSISTENT_SIGNED_ZONE DS11_UNDETERMINED_DS DS11_UNDETERMINED_SIGNED_ZONE DS11_NS_WITH_SIGNED_ZONE DS11_NS_WITH_UNSIGNED_ZONE DS11_DS_BUT_UNSIGNED_ZONE}] );

$zone = Zonemaster::Engine->zone( 'dnssec11-ds-but-unsigned.zft-root.rd.nic.fr' );
zone_gives( 'dnssec11', $zone, [qw{DS11_DS_BUT_UNSIGNED_ZONE}] );
zone_gives_not( 'dnssec11', $zone, [qw{DS11_INCONSISTENT_DS DS11_INCONSISTENT_SIGNED_ZONE DS11_UNDETERMINED_DS DS11_UNDETERMINED_SIGNED_ZONE DS11_PARENT_WITHOUT_DS DS11_PARENT_WITH_DS DS11_NS_WITH_SIGNED_ZONE DS11_NS_WITH_UNSIGNED_ZONE}] );

$zone = Zonemaster::Engine->zone( 'dnssec11-inconsistent-dnskey.zft-root.rd.nic.fr' );
zone_gives( 'dnssec11', $zone, [qw{DS11_INCONSISTENT_SIGNED_ZONE DS11_NS_WITH_UNSIGNED_ZONE DS11_NS_WITH_SIGNED_ZONE}] );
zone_gives_not( 'dnssec11', $zone, [qw{DS11_INCONSISTENT_DS DS11_UNDETERMINED_DS DS11_UNDETERMINED_SIGNED_ZONE DS11_PARENT_WITHOUT_DS DS11_PARENT_WITH_DS DS11_DS_BUT_UNSIGNED_ZONE}] );

###########
# dnssec13
###########

$zone = Zonemaster::Engine->zone( 'dnssec13-algo-not-signed-dnskey.zft-root.rd.nic.fr' );
zone_gives_not('dnssec13', $zone, [qw{DS13_ALGO_NOT_SIGNED_NS DS13_ALGO_NOT_SIGNED_SOA}] );

$zone = Zonemaster::Engine->zone( 'dnssec13-algo-not-signed-ns.zft-root.rd.nic.fr' );
zone_gives( 'dnssec13', $zone, [qw{DS13_ALGO_NOT_SIGNED_NS}] );
zone_gives_not('dnssec13', $zone, [qw{DS13_ALGO_NOT_SIGNED_DNSKEY DS13_ALGO_NOT_SIGNED_SOA}] );

$zone = Zonemaster::Engine->zone( 'dnssec13-algo-not-signed-soa.zft-root.rd.nic.fr' );
zone_gives( 'dnssec13', $zone, [qw{DS13_ALGO_NOT_SIGNED_SOA}] );
zone_gives_not('dnssec13', $zone, [qw{DS13_ALGO_NOT_SIGNED_DNSKEY DS13_ALGO_NOT_SIGNED_NS}] );

$zone = Zonemaster::Engine->zone( 'afnic.fr' );
zone_gives_not('dnssec13', $zone, [qw{DS13_ALGO_NOT_SIGNED_DNSKEY DS13_ALGO_NOT_SIGNED_NS DS13_ALGO_NOT_SIGNED_SOA}] );

###########
# dnssec15
###########

$zone = Zonemaster::Engine->zone( 'dnssec15-no-cds-no-cdnskey.zft-root.rd.nic.fr' );
zone_gives( 'dnssec15', $zone, [q{DS15_NO_CDS_CDNSKEY}] );
zone_gives_not('dnssec15', $zone, [qw{DS15_HAS_CDNSKEY_NO_CDS DS15_HAS_CDS_AND_CDNSKEY DS15_HAS_CDS_NO_CDNSKEY DS15_INCONSISTENT_CDNSKEY DS15_INCONSISTENT_CDS DS15_MISMATCH_CDS_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec15-cds-no-cdnskey.zft-root.rd.nic.fr' );
zone_gives( 'dnssec15', $zone, [q{DS15_HAS_CDS_NO_CDNSKEY}] );
zone_gives_not('dnssec15', $zone, [qw{DS15_HAS_CDNSKEY_NO_CDS DS15_HAS_CDS_AND_CDNSKEY DS15_INCONSISTENT_CDNSKEY DS15_INCONSISTENT_CDS DS15_MISMATCH_CDS_CDNSKEY DS15_NO_CDS_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec15-cdnskey-no-cds.zft-root.rd.nic.fr' );
zone_gives( 'dnssec15', $zone, [q{DS15_HAS_CDNSKEY_NO_CDS}] );
zone_gives_not('dnssec15', $zone, [qw{DS15_HAS_CDS_AND_CDNSKEY DS15_HAS_CDS_NO_CDNSKEY DS15_INCONSISTENT_CDNSKEY DS15_INCONSISTENT_CDS DS15_MISMATCH_CDS_CDNSKEY DS15_NO_CDS_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec15-cds-cdnskey-01.zft-root.rd.nic.fr' );
zone_gives( 'dnssec15', $zone, [q{DS15_HAS_CDS_AND_CDNSKEY}] );
zone_gives_not('dnssec15', $zone, [qw{DS15_HAS_CDNSKEY_NO_CDS DS15_HAS_CDS_NO_CDNSKEY DS15_INCONSISTENT_CDNSKEY DS15_INCONSISTENT_CDS DS15_MISMATCH_CDS_CDNSKEY DS15_NO_CDS_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec15-cds-cdnskey-02.zft-root.rd.nic.fr' );
zone_gives( 'dnssec15', $zone, [q{DS15_HAS_CDS_AND_CDNSKEY}] );
zone_gives_not('dnssec15', $zone, [qw{DS15_HAS_CDNSKEY_NO_CDS DS15_HAS_CDS_NO_CDNSKEY DS15_INCONSISTENT_CDNSKEY DS15_INCONSISTENT_CDS DS15_MISMATCH_CDS_CDNSKEY DS15_NO_CDS_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec15-cds-cdnskey-03.zft-root.rd.nic.fr' );
zone_gives( 'dnssec15', $zone, [q{DS15_HAS_CDS_AND_CDNSKEY}] );
zone_gives_not('dnssec15', $zone, [qw{DS15_HAS_CDNSKEY_NO_CDS DS15_HAS_CDS_NO_CDNSKEY DS15_INCONSISTENT_CDNSKEY DS15_INCONSISTENT_CDS DS15_MISMATCH_CDS_CDNSKEY DS15_NO_CDS_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec15-inconsistent-cds-01.zft-root.rd.nic.fr' );
zone_gives( 'dnssec15', $zone, [qw{DS15_HAS_CDS_NO_CDNSKEY DS15_INCONSISTENT_CDS}] );
zone_gives_not('dnssec15', $zone, [qw{DS15_HAS_CDNSKEY_NO_CDS DS15_HAS_CDS_AND_CDNSKEY DS15_INCONSISTENT_CDNSKEY DS15_MISMATCH_CDS_CDNSKEY DS15_NO_CDS_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec15-inconsistent-cds-02.zft-root.rd.nic.fr' );
zone_gives( 'dnssec15', $zone, [qw{DS15_HAS_CDS_NO_CDNSKEY DS15_INCONSISTENT_CDS}] );
zone_gives_not('dnssec15', $zone, [qw{DS15_HAS_CDNSKEY_NO_CDS DS15_HAS_CDS_AND_CDNSKEY DS15_INCONSISTENT_CDNSKEY DS15_MISMATCH_CDS_CDNSKEY DS15_NO_CDS_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec15-inconsistent-cds-03.zft-root.rd.nic.fr' );
zone_gives( 'dnssec15', $zone, [qw{DS15_HAS_CDS_NO_CDNSKEY DS15_INCONSISTENT_CDS}] );
zone_gives_not('dnssec15', $zone, [qw{DS15_HAS_CDNSKEY_NO_CDS DS15_HAS_CDS_AND_CDNSKEY DS15_INCONSISTENT_CDNSKEY DS15_MISMATCH_CDS_CDNSKEY DS15_NO_CDS_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec15-inconsistent-cds-04.zft-root.rd.nic.fr' );
zone_gives( 'dnssec15', $zone, [qw{DS15_HAS_CDS_NO_CDNSKEY DS15_INCONSISTENT_CDS}] );
zone_gives_not('dnssec15', $zone, [qw{DS15_HAS_CDNSKEY_NO_CDS DS15_HAS_CDS_AND_CDNSKEY DS15_INCONSISTENT_CDNSKEY DS15_MISMATCH_CDS_CDNSKEY DS15_NO_CDS_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec15-inconsistent-cdnskey-01.zft-root.rd.nic.fr' );
zone_gives( 'dnssec15', $zone, [qw{DS15_HAS_CDNSKEY_NO_CDS DS15_INCONSISTENT_CDNSKEY}] );
zone_gives_not('dnssec15', $zone, [qw{DS15_HAS_CDS_AND_CDNSKEY DS15_HAS_CDS_NO_CDNSKEY DS15_INCONSISTENT_CDS DS15_MISMATCH_CDS_CDNSKEY DS15_NO_CDS_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec15-inconsistent-cdnskey-02.zft-root.rd.nic.fr' );
zone_gives( 'dnssec15', $zone, [qw{DS15_HAS_CDNSKEY_NO_CDS DS15_INCONSISTENT_CDNSKEY}] );
zone_gives_not('dnssec15', $zone, [qw{DS15_HAS_CDS_AND_CDNSKEY DS15_HAS_CDS_NO_CDNSKEY DS15_INCONSISTENT_CDS DS15_MISMATCH_CDS_CDNSKEY DS15_NO_CDS_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec15-inconsistent-cdnskey-03.zft-root.rd.nic.fr' );
zone_gives( 'dnssec15', $zone, [qw{DS15_HAS_CDNSKEY_NO_CDS DS15_INCONSISTENT_CDNSKEY}] );
zone_gives_not('dnssec15', $zone, [qw{DS15_HAS_CDS_AND_CDNSKEY DS15_HAS_CDS_NO_CDNSKEY DS15_INCONSISTENT_CDS DS15_MISMATCH_CDS_CDNSKEY DS15_NO_CDS_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec15-inconsistent-cdnskey-04.zft-root.rd.nic.fr' );
zone_gives( 'dnssec15', $zone, [qw{DS15_HAS_CDNSKEY_NO_CDS DS15_INCONSISTENT_CDNSKEY}] );
zone_gives_not('dnssec15', $zone, [qw{DS15_HAS_CDS_AND_CDNSKEY DS15_HAS_CDS_NO_CDNSKEY DS15_INCONSISTENT_CDS DS15_MISMATCH_CDS_CDNSKEY DS15_NO_CDS_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec15-mismatch-cds-cdnskey.zft-root.rd.nic.fr' );
zone_gives( 'dnssec15', $zone, [qw{DS15_HAS_CDS_AND_CDNSKEY DS15_MISMATCH_CDS_CDNSKEY}] );
zone_gives_not('dnssec15', $zone, [qw{DS15_HAS_CDNSKEY_NO_CDS DS15_HAS_CDS_NO_CDNSKEY DS15_INCONSISTENT_CDNSKEY DS15_INCONSISTENT_CDS DS15_NO_CDS_CDNSKEY}] );

###########
# dnssec16 -- See t/Test-dnssec16.t instead.
###########

###########
# dnssec17
###########

$zone = Zonemaster::Engine->zone( 'dnssec16-cds-cdnskey-signed.zft-root.rd.nic.fr' );
zone_gives_not('dnssec17', $zone, [qw{DS17_CDNSKEY_INVALID_RRSIG DS17_CDNSKEY_IS_NON_SEP DS17_CDNSKEY_IS_NON_ZONE DS17_CDNSKEY_MATCHES_NO_DNSKEY DS17_CDNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY DS17_CDNSKEY_UNSIGNED DS17_CDNSKEY_WITHOUT_DNSKEY DS17_DELETE_CDNSKEY DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_MIXED_DELETE_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec16-cds-cdnskey-unsigned.zft-root.rd.nic.fr' );
zone_gives( 'dnssec17', $zone, [qw{DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_CDNSKEY_NOT_SIGNED_BY_CDNSKEY}]);
zone_gives_not('dnssec17', $zone, [qw{DS17_CDNSKEY_INVALID_RRSIG DS17_CDNSKEY_IS_NON_SEP DS17_CDNSKEY_IS_NON_ZONE DS17_CDNSKEY_MATCHES_NO_DNSKEY DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY DS17_CDNSKEY_UNSIGNED DS17_CDNSKEY_WITHOUT_DNSKEY DS17_DELETE_CDNSKEY DS17_MIXED_DELETE_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec16-cds-cdnskey-invalid-rrsig-01.zft-root.rd.nic.fr' );
zone_gives( 'dnssec17', $zone, [q{DS17_CDNSKEY_INVALID_RRSIG}]);
zone_gives_not('dnssec17', $zone, [qw{DS17_CDNSKEY_IS_NON_SEP DS17_CDNSKEY_IS_NON_ZONE DS17_CDNSKEY_MATCHES_NO_DNSKEY DS17_CDNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY DS17_CDNSKEY_UNSIGNED DS17_CDNSKEY_WITHOUT_DNSKEY DS17_DELETE_CDNSKEY DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_MIXED_DELETE_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec16-cds-cdnskey-invalid-rrsig-02.zft-root.rd.nic.fr' );
zone_gives( 'dnssec17', $zone, [q{DS17_CDNSKEY_INVALID_RRSIG}]);
zone_gives_not('dnssec17', $zone, [qw{DS17_CDNSKEY_IS_NON_SEP DS17_CDNSKEY_IS_NON_ZONE DS17_CDNSKEY_MATCHES_NO_DNSKEY DS17_CDNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY DS17_CDNSKEY_UNSIGNED DS17_CDNSKEY_WITHOUT_DNSKEY DS17_DELETE_CDNSKEY DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_MIXED_DELETE_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec17-cdnskey-unsigned.zft-root.rd.nic.fr' );
zone_gives( 'dnssec17', $zone, [qw{DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_CDNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_CDNSKEY_UNSIGNED}]);
zone_gives_not('dnssec17', $zone, [qw{DS17_CDNSKEY_INVALID_RRSIG DS17_CDNSKEY_IS_NON_SEP DS17_CDNSKEY_IS_NON_ZONE DS17_CDNSKEY_MATCHES_NO_DNSKEY DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY DS17_CDNSKEY_WITHOUT_DNSKEY DS17_DELETE_CDNSKEY DS17_MIXED_DELETE_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec16-cds-without-dnskey.zft-root.rd.nic.fr' );
zone_gives( 'dnssec17', $zone, [q{DS17_CDNSKEY_WITHOUT_DNSKEY}]);
zone_gives_not('dnssec17', $zone, [qw{DS17_CDNSKEY_INVALID_RRSIG DS17_CDNSKEY_IS_NON_SEP DS17_CDNSKEY_IS_NON_ZONE DS17_CDNSKEY_MATCHES_NO_DNSKEY DS17_CDNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY DS17_CDNSKEY_UNSIGNED DS17_DELETE_CDNSKEY DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_MIXED_DELETE_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec17-cdnskey-signed-by-unknown-dnskey.zft-root.rd.nic.fr' );
zone_gives_not('dnssec17', $zone, [qw{DS17_CDNSKEY_INVALID_RRSIG DS17_CDNSKEY_IS_NON_ZONE DS17_CDNSKEY_MATCHES_NO_DNSKEY DS17_CDNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_CDNSKEY_UNSIGNED DS17_CDNSKEY_WITHOUT_DNSKEY DS17_DELETE_CDNSKEY DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_MIXED_DELETE_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec17-cdnskey-matches-no-dnskey.zft-root.rd.nic.fr' );
zone_gives( 'dnssec17', $zone, [qw{DS17_CDNSKEY_MATCHES_NO_DNSKEY DS17_CDNSKEY_IS_NON_SEP}]);
zone_gives_not('dnssec17', $zone, [qw{DS17_CDNSKEY_INVALID_RRSIG DS17_CDNSKEY_IS_NON_ZONE DS17_CDNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY DS17_CDNSKEY_UNSIGNED DS17_CDNSKEY_WITHOUT_DNSKEY DS17_DELETE_CDNSKEY DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_MIXED_DELETE_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec17-delete-cdnskey.zft-root.rd.nic.fr' );
zone_gives( 'dnssec17', $zone, [q{DS17_DELETE_CDNSKEY}]);
zone_gives_not('dnssec17', $zone, [qw{DS17_CDNSKEY_INVALID_RRSIG DS17_CDNSKEY_IS_NON_SEP DS17_CDNSKEY_IS_NON_ZONE DS17_CDNSKEY_MATCHES_NO_DNSKEY DS17_CDNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY DS17_CDNSKEY_UNSIGNED DS17_CDNSKEY_WITHOUT_DNSKEY DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_MIXED_DELETE_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec17-mixed-delete-cdnskey.zft-root.rd.nic.fr' );
zone_gives( 'dnssec17', $zone, [q{DS17_MIXED_DELETE_CDNSKEY}]);
zone_gives_not('dnssec17', $zone, [qw{DS17_CDNSKEY_INVALID_RRSIG DS17_CDNSKEY_IS_NON_SEP DS17_CDNSKEY_IS_NON_ZONE DS17_CDNSKEY_MATCHES_NO_DNSKEY DS17_CDNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY DS17_CDNSKEY_UNSIGNED DS17_CDNSKEY_WITHOUT_DNSKEY DS17_DELETE_CDNSKEY DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec17-cdnskey-is-non-zone.zft-root.rd.nic.fr' );
zone_gives( 'dnssec17', $zone, [q{DS17_CDNSKEY_IS_NON_ZONE}]);
zone_gives_not('dnssec17', $zone, [qw{DS17_CDNSKEY_INVALID_RRSIG DS17_CDNSKEY_IS_NON_SEP DS17_CDNSKEY_MATCHES_NO_DNSKEY DS17_CDNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY DS17_CDNSKEY_UNSIGNED DS17_CDNSKEY_WITHOUT_DNSKEY DS17_DELETE_CDNSKEY DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_MIXED_DELETE_CDNSKEY}] );

###########
# dnssec18
###########
$zone = Zonemaster::Engine->zone( 'dnssec18-no-match-cds-rrsig-ds.zft-root.rd.nic.fr' );
zone_gives( 'dnssec18', $zone, [q{DS18_NO_MATCH_CDS_RRSIG_DS}]);
zone_gives_not( 'dnssec18', $zone, [q{DS18_NO_MATCH_CDNSKEY_RRSIG_DS}]);

$zone = Zonemaster::Engine->zone( 'dnssec18-no-match-cdnskey-rrsig-ds.zft-root.rd.nic.fr' );
zone_gives( 'dnssec18', $zone, [q{DS18_NO_MATCH_CDNSKEY_RRSIG_DS}]);
zone_gives_not( 'dnssec18', $zone, [q{DS18_NO_MATCH_CDS_RRSIG_DS}]);

TODO: {
    local $TODO = "Need to find/create zones with that error";

    # dnssec02
    ok( $tag{DS02_ALGO_NOT_SUPPORTED_BY_ZM}, q{DS02_ALGO_NOT_SUPPORTED_BY_ZM} );
    ok( $tag{DS02_DNSKEY_NOT_FOR_ZONE_SIGNING}, q{DS02_DNSKEY_NOT_FOR_ZONE_SIGNING} );
    # dnssec05 (cannot exist in a live domain...)
    ok( $tag{ALGORITHM_UNKNOWN}, q{ALGORITHM_UNKNOWN} );
    # dnssec06
    ok( $tag{EXTRA_PROCESSING_BROKEN}, q{EXTRA_PROCESSING_BROKEN} );
    # dnssec07 (need complete analyze with broken zone)
    ok( $tag{ADDITIONAL_DNSKEY_SKIPPED}, q{ADDITIONAL_DNSKEY_SKIPPED} );

    local $TODO = "Need to check these zones with that error";

    # dnssec08: dnssec08-dnskey-signature-not-ok.zut-root.rd.nic.fr
    # Commented out for now because zone doesn't give this message tag anymore. Reason unknown, investigation required. See https://github.com/zonemaster/zonemaster-engine/pull/1147#issuecomment-1318896623
    ok( $tag{DS08_RRSIG_NOT_VALID_BY_DNSKEY}, q{DS08_RRSIG_NOT_VALID_BY_DNSKEY});

    # dnssec10: dnssec10-inconsistent-nsec-nsec3.zft-root.rd.nic.fr
    # Removed 'DS10_NSEC3_RRSIG_VERIFY_ERROR' from 'zone_gives_not' below because zone now gives this message tag. Reason unknown, investigation required. See https://github.com/zonemaster/zonemaster-engine/pull/1147#issuecomment-1318896623
    ok( $tag{DS10_NSEC3_RRSIG_VERIFY_ERROR}, q{DS10_NSEC3_RRSIG_VERIFY_ERROR} );

    # dnssec13: dnssec13-algo-not-signed-dnskey.zft-root.rd.nic.fr
    # Commented out for now because zone doesn't give this message tag anymore. Reason unknown, investigation required. See https://github.com/zonemaster/zonemaster-engine/pull/1147#issuecomment-1318896623
    ok( $tag{DS13_ALGO_NOT_SIGNED_DNSKEY}, q{DS13_ALGO_NOT_SIGNED_DNSKEY} );

    # dnssec17: dnssec17-cdnskey-signed-by-unknown-dnskey.zft-root.rd.nic.fr
    # Commented out for now because zone doesn't give these message tags anymore. Reason unknown, investigation required. See https://github.com/zonemaster/zonemaster-engine/pull/1147#issuecomment-1318896623
    ok( $tag{DS17_CDNSKEY_IS_NON_SEP}, q{DS17_CDNSKEY_IS_NON_SEP} );
    ok( $tag{DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY}, q{DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY} );


}

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
