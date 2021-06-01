use Test::More;
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

# Find a way for dnssec06 which have a dependence...
my ($json, $profile_test);
foreach my $testcase ( qw{dnssec01 dnssec02 dnssec03 dnssec04 dnssec05 dnssec07 dnssec08 dnssec09 dnssec10 dnssec11 dnssec13 dnssec14 dnssec15 dnssec16 dnssec17} ) {
    $json         = read_file( 't/profiles/Test-'.$testcase.'-only.json' );
    $profile_test = Zonemaster::Engine::Profile->from_json( $json );
    Zonemaster::Engine::Profile->effective->merge( $profile_test );
    my @testcases;
    Zonemaster::Engine->logger->clear_history();
    foreach my $result ( Zonemaster::Engine->test_module( q{dnssec}, q{nic.se} ) ) {
        foreach my $trace (@{$result->trace}) {
            push @testcases, grep /Zonemaster::Engine::Test::DNSSEC::dnssec/, @$trace;
        }
    }
    @testcases = uniq sort @testcases;
    is( scalar( @testcases ), 1, 'only one test-case ('.$testcase.')' );
    is( $testcases[0], 'Zonemaster::Engine::Test::DNSSEC::'.$testcase, 'expected test-case ('.$testcases[0].')' );
}

$json         = read_file( 't/profiles/Test-dnssec-all.json' );
$profile_test = Zonemaster::Engine::Profile->from_json( $json );
Zonemaster::Engine::Profile->effective->merge( $profile_test );

my $zone;
my @res;
my %tag;

$zone = Zonemaster::Engine->zone( 'nic.se' );
zone_gives( 'dnssec01', $zone, [qw{DS_ALGO_SHA1_DEPRECATED DS_ALGORITHM_OK}] );

my $zone2 = Zonemaster::Engine->zone( 'seb.se' );
is( zone_gives( 'dnssec01', $zone2, [q{DS_ALGORITHM_MISSING}] ), 22, 'Only one (useful) message' );

my $zone3 = Zonemaster::Engine->zone( 'com' );
is( zone_gives( 'dnssec03', $zone3, [q{ITERATIONS_OK}] ), 3, 'Only one (useful) message' );

@res = Zonemaster::Engine->test_method( 'DNSSEC', 'dnssec04', $zone );
%tag = map { $_->tag => 1 } @res;
ok( ( $tag{DURATION_OK} || $tag{REMAINING_SHORT} || $tag{RRSIG_EXPIRED} ), 'DURATION_OK (sort of)' );

my $zone4 = Zonemaster::Engine->zone( 'nic.fr' );
zone_gives( 'dnssec05', $zone4, [q{ALGORITHM_OK}] );

zone_gives( 'dnssec06', $zone, [q{EXTRA_PROCESSING_OK}] );

zone_gives( 'dnssec07', $zone, [q{DNSKEY_AND_DS}] );
zone_gives_not( 'dnssec07', $zone, [qw{NEITHER_DNSKEY_NOR_DS DNSKEY_BUT_NOT_DS DS_BUT_NOT_DNSKEY}] );

zone_gives( 'dnssec08', $zone, [qw{DNSKEY_SIGNATURE_OK DNSKEY_SIGNED}] );

zone_gives( 'dnssec09', $zone, [qw{SOA_SIGNATURE_OK SOA_SIGNED}] );

zone_gives( 'dnssec10', $zone, [qw{HAS_NSEC}] );
zone_gives_not( 'dnssec10', $zone, [qw{BROKEN_DNSSEC HAS_NSEC3 INCONSISTENT_DNSSEC INCONSISTENT_NSEC_NSEC3 MIXED_NSEC_NSEC3 NO_NSEC_NSEC3 NSEC3_COVERS_NOT NSEC3_NOT_SIGNED NSEC3_SIG_VERIFY_ERROR NSEC_COVERS_NOT NSEC_NOT_SIGNED NSEC_SIG_VERIFY_ERROR TEST_ABORTED}] );

zone_gives( 'dnssec10', $zone3, [qw{HAS_NSEC3}] );
zone_gives_not( 'dnssec10', $zone3, [qw{BROKEN_DNSSEC HAS_NSEC INCONSISTENT_DNSSEC INCONSISTENT_NSEC_NSEC3 MIXED_NSEC_NSEC3 NO_NSEC_NSEC3 NSEC3_COVERS_NOT NSEC3_NOT_SIGNED NSEC3_SIG_VERIFY_ERROR NSEC_COVERS_NOT NSEC_NOT_SIGNED NSEC_SIG_VERIFY_ERROR TEST_ABORTED}] );

###########
# dnssec01
###########
$zone = Zonemaster::Engine->zone( 'dnssec01-ds-algorithm-ok.zut-root.rd.nic.fr' );
zone_gives( 'dnssec01', $zone, [q{DS_ALGORITHM_OK}] );
zone_gives_not( 'dnssec01', $zone, [qw{DS_ALGORITHM_DEPRECATED DS_ALGO_SHA1_DEPRECATED DS_ALGORITHM_RESERVED DS_ALGORITHM_NOT_DS DS_ALGORITHM_MISSING}] );

$zone = Zonemaster::Engine->zone( 'dnssec01-nxdomain.zut-root.rd.nic.fr' );
zone_gives( 'dnssec01', $zone, [q{UNEXPECTED_RESPONSE_DS}] );

$zone = Zonemaster::Engine->zone( 'dnssec01-ds-algorithm-not-ds.zut-root.rd.nic.fr' );
zone_gives( 'dnssec01', $zone, [qw{DS_ALGORITHM_NOT_DS DS_ALGORITHM_MISSING}] );
zone_gives_not( 'dnssec01', $zone, [qw{DS_ALGORITHM_DEPRECATED DS_ALGO_SHA1_DEPRECATED DS_ALGORITHM_RESERVED DS_ALGORITHM_OK}] );

$zone = Zonemaster::Engine->zone( 'dnssec01-ds-algorithm-deprecated1.zut-root.rd.nic.fr' );
zone_gives( 'dnssec01', $zone, [qw{DS_ALGO_SHA1_DEPRECATED DS_ALGORITHM_MISSING}] );
zone_gives_not( 'dnssec01', $zone, [qw{DS_ALGORITHM_DEPRECATED DS_ALGORITHM_NOT_DS DS_ALGORITHM_RESERVED DS_ALGORITHM_OK}] );

$zone = Zonemaster::Engine->zone( 'dnssec01-ds-algorithm-deprecated3.zut-root.rd.nic.fr' );
zone_gives( 'dnssec01', $zone, [qw{DS_ALGORITHM_DEPRECATED DS_ALGORITHM_MISSING}] );
zone_gives_not( 'dnssec01', $zone, [qw{DS_ALGORITHM_NOT_DS DS_ALGO_SHA1_DEPRECATED DS_ALGORITHM_RESERVED DS_ALGORITHM_OK}] );

$zone = Zonemaster::Engine->zone( 'dnssec01-ds-algorithm-reserved.zut-root.rd.nic.fr' );
zone_gives( 'dnssec01', $zone, [qw{DS_ALGORITHM_RESERVED DS_ALGORITHM_MISSING}] );
zone_gives_not( 'dnssec01', $zone, [qw{DS_ALGORITHM_DEPRECATED DS_ALGO_SHA1_DEPRECATED DS_ALGORITHM_NOT_DS DS_ALGORITHM_OK}] );

###########
# dnssec02
###########
my $rootfr = Zonemaster::Engine->zone( 'root.fr' );
@res = Zonemaster::Engine->test_method( 'DNSSEC', 'dnssec02', $rootfr );
ok( ( none { $_->tag eq 'MODULE_ERROR' } @res ), 'No crash in dnssec02' );

$zone = Zonemaster::Engine->zone( 'nic.se' );
zone_gives( 'dnssec02', $zone, [qw{DS_MATCHES NO_RESPONSE}] );
zone_gives_not( 'dnssec02', $zone, [qw{BROKEN_DS BROKEN_RRSIG DNSKEY_KSK_NOT_SEP DNSKEY_NOT_ZONE_SIGN NO_RESPONSE_DNSKEY NO_MATCHING_DNSKEY NO_MATCHING_RRSIG NO_RRSIG_DNSKEY UNEXPECTED_RESPONSE_DS}] );

$zone = Zonemaster::Engine->zone( 'nic.fr' );
zone_gives( 'dnssec02', $zone, [q{DS_MATCHES}] );
zone_gives_not( 'dnssec02', $zone, [qw{BROKEN_DS BROKEN_RRSIG DNSKEY_KSK_NOT_SEP DNSKEY_NOT_ZONE_SIGN NO_RESPONSE NO_RESPONSE_DNSKEY NO_MATCHING_DNSKEY NO_MATCHING_RRSIG NO_RRSIG_DNSKEY UNEXPECTED_RESPONSE_DS}] );

$zone = Zonemaster::Engine->zone( 'dnssec02-no-dnskey.zut-root.rd.nic.fr' );
zone_gives( 'dnssec02', $zone, [q{NO_RESPONSE_DNSKEY}] );
zone_gives_not( 'dnssec02', $zone, [qw{BROKEN_DS BROKEN_RRSIG DNSKEY_KSK_NOT_SEP DNSKEY_NOT_ZONE_SIGN DS_MATCHES NO_MATCHING_DNSKEY NO_MATCHING_RRSIG NO_RESPONSE NO_RRSIG_DNSKEY UNEXPECTED_RESPONSE_DS}] );

$zone = Zonemaster::Engine->zone( 'dnssec02-ds-does-not-match-dnskey.zut-root.rd.nic.fr' );
zone_gives( 'dnssec02', $zone, [q{BROKEN_DS}] );
zone_gives_not( 'dnssec02', $zone, [qw{BROKEN_RRSIG DNSKEY_KSK_NOT_SEP DNSKEY_NOT_ZONE_SIGN DS_MATCHES NO_MATCHING_DNSKEY NO_MATCHING_RRSIG NO_RESPONS NO_RESPONSE_DNSKEY NO_RRSIG_DNSKEY UNEXPECTED_RESPONSE_DS}] );

$zone = Zonemaster::Engine->zone( 'dnssec02-no-common-keytags.zut-root.rd.nic.fr' );
zone_gives( 'dnssec02', $zone, [qw{NO_MATCHING_DNSKEY NO_MATCHING_RRSIG}] );
zone_gives_not( 'dnssec02', $zone, [qw{BROKEN_DS BROKEN_RRSIG DNSKEY_KSK_NOT_SEP DNSKEY_NOT_ZONE_SIGN DS_MATCHES NO_RESPONS NO_RESPONSE_DNSKEY NO_RRSIG_DNSKEY UNEXPECTED_RESPONSE_DS}] );

$zone = Zonemaster::Engine->zone( 'dnssec08-dnskey-not-signed.zut-root.rd.nic.fr' );
zone_gives( 'dnssec02', $zone, [q{NO_RRSIG_DNSKEY}] );
zone_gives_not( 'dnssec02', $zone, [qw{BROKEN_DS BROKEN_RRSIG NO_MATCHING_DNSKEY DNSKEY_KSK_NOT_SEP DNSKEY_NOT_ZONE_SIGN DS_MATCHES NO_MATCHING_RRSIG NO_RESPONS NO_RESPONSE_DNSKEY UNEXPECTED_RESPONSE_DS}] );

$zone = Zonemaster::Engine->zone( 'dnssec08-dnskey-signature-not-ok-broken.zut-root.rd.nic.fr' );
zone_gives( 'dnssec02', $zone, [q{BROKEN_RRSIG}] );
zone_gives_not( 'dnssec02', $zone, [qw{BROKEN_DS NO_MATCHING_DNSKEY DNSKEY_KSK_NOT_SEP DNSKEY_NOT_ZONE_SIGN DS_MATCHES NO_MATCHING_RRSIG NO_RESPONS NO_RESPONSE_DNSKEY NO_RRSIG_DNSKEY UNEXPECTED_RESPONSE_DS}] );

$zone = Zonemaster::Engine->zone( 'dnssec02-dnskey-ksk-not-sep.zut-root.rd.nic.fr' );
zone_gives( 'dnssec02', $zone, [qw{DS_MATCHES DNSKEY_KSK_NOT_SEP}] );
zone_gives_not( 'dnssec02', $zone, [qw{BROKEN_DS BROKEN_RRSIG NO_RESPONSE DNSKEY_NOT_ZONE_SIGN NO_RESPONSE_DNSKEY NO_MATCHING_DNSKEY NO_MATCHING_RRSIG NO_RRSIG_DNSKEY UNEXPECTED_RESPONSE_DS}] );

# 2 cases missing
# DNSKEY_NOT_ZONE_SIGN
# UNEXPECTED_RESPONSE_DS

###########
# dnssec03
###########
$zone = Zonemaster::Engine->zone( 'dnssec03-many-iterations.zut-root.rd.nic.fr' );
zone_gives( 'dnssec03', $zone, [q{MANY_ITERATIONS}] );

$zone = Zonemaster::Engine->zone( 'dnssec03-no-nsec3param.zut-root.rd.nic.fr' );
zone_gives( 'dnssec03', $zone, [q{NO_NSEC3PARAM}] );

$zone = Zonemaster::Engine->zone( 'dnssec03-too-many-iterations.zut-root.rd.nic.fr' );
zone_gives( 'dnssec03', $zone, [q{TOO_MANY_ITERATIONS}] );

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
zone_gives( 'dnssec08', $zone, [qw{DNSKEY_NOT_SIGNED DNSKEY_SIGNATURE_NOT_OK}] );

$zone = Zonemaster::Engine->zone( 'dnssec08-dnskey-signature-not-ok.zut-root.rd.nic.fr' );
zone_gives( 'dnssec08', $zone, [qw{DNSKEY_SIGNED DNSKEY_SIGNATURE_NOT_OK DNSKEY_SIGNATURE_OK}] );

$zone = Zonemaster::Engine->zone( 'dnssec08-no-keys-or-no-sigs-1.zut-root.rd.nic.fr' );
zone_gives( 'dnssec08', $zone, [q{NO_KEYS_OR_NO_SIGS}] );
zone_gives( 'dnssec09', $zone, [q{NO_KEYS_OR_NO_SIGS_OR_NO_SOA}] );

$zone = Zonemaster::Engine->zone( 'dnssec08-no-keys-or-no-sigs-2.zut-root.rd.nic.fr' );
zone_gives( 'dnssec08', $zone, [q{NO_KEYS_OR_NO_SIGS}] );

###########
# dnssec09
###########
$zone = Zonemaster::Engine->zone( 'dnssec09-soa-signature-not-ok.zut-root.rd.nic.fr' );
zone_gives( 'dnssec09', $zone, [qw{SOA_NOT_SIGNED SOA_SIGNATURE_NOT_OK}] );

###########
# dnssec10
###########
SKIP: {
    skip "Opt-out was tested in former dnssec10 version. Is it somethong we want to test again ?", 2;

    $zone = Zonemaster::Engine->zone( 'fr'  );
    zone_gives( 'dnssec10', $zone, ['HAS_NSEC3_OPTOUT'] );

    $zone = Zonemaster::Engine->zone( 'ma'  );
    zone_gives_not( 'dnssec10', $zone, ['HAS_NSEC3_OPTOUT'] );
}

# GOST
#$zone = Zonemaster::Engine->zone( 'caint.su' );
#@res = Zonemaster::Engine->test_method( 'DNSSEC', 'dnssec08', $zone );
#ok( ( grep { $_->string =~ /error=no GOST support/s } @res ), $zone->name->string . " no GOST support" );
#@res = Zonemaster::Engine->test_method( 'DNSSEC', 'dnssec09', $zone );
#ok( ( grep { $_->string =~ /error=no GOST support/s } @res ), $zone->name->string . " no GOST support" );
#@res = Zonemaster::Engine->test_method( 'DNSSEC', 'dnssec10', $zone );
#ok( ( grep { $_->string =~ /error=no GOST support/s } @res ), $zone->name->string . " no GOST support" );

###########
# dnssec13
###########

$zone = Zonemaster::Engine->zone( 'dnssec09-soa-signature-not-ok.zut-root.rd.nic.fr' );
zone_gives( 'dnssec13', $zone, [qw{RRSIG_BROKEN}] );
zone_gives_not('dnssec13', $zone, [qw{ALL_ALGO_SIGNED ALGO_NOT_SIGNED_RRSET RRSET_NOT_SIGNED}] );

$zone = Zonemaster::Engine->zone( 'dnssec08-dnskey-signature-not-ok.zut-root.rd.nic.fr' );
zone_gives( 'dnssec13', $zone, [qw{RRSIG_BROKEN}] );
zone_gives_not('dnssec13', $zone, [qw{ALL_ALGO_SIGNED RRSET_NOT_SIGNED RRSIG_NOT_MATCH_DNSKEY ALGO_NOT_SIGNED_RRSET}] );

$zone = Zonemaster::Engine->zone( 'dnssec08-dnskey-not-signed.zut-root.rd.nic.fr' );
zone_gives( 'dnssec13', $zone, [qw{RRSET_NOT_SIGNED}] );
zone_gives_not('dnssec13', $zone, [qw{ALL_ALGO_SIGNED RRSIG_NOT_MATCH_DNSKEY ALGO_NOT_SIGNED_RRSET}] );

$zone = Zonemaster::Engine->zone( 'afnic.fr' );
zone_gives( 'dnssec13', $zone, [qw{ALL_ALGO_SIGNED}] );
zone_gives_not('dnssec13', $zone, [qw{ALGO_NOT_SIGNED_RRSET NO_RESPONSE NO_RESPONSE_RRSET RRSET_NOT_SIGNED RRSIG_BROKEN RRSIG_NOT_MATCH_DNSKEY}] );

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

###########
# dnssec16
###########

$zone = Zonemaster::Engine->zone( 'dnssec16-cds-cdnskey-signed.zft-root.rd.nic.fr' );
zone_gives_not('dnssec16', $zone, [qw{DS16_CDS_INVALID_RRSIG DS16_CDS_MATCHES_NO_DNSKEY DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY DS16_CDS_UNSIGNED DS16_CDS_WITHOUT_DNSKEY DS16_DELETE_CDS DS16_DNSKEY_NOT_SIGNED_BY_CDS DS16_MIXED_DELETE_CDS}] );

$zone = Zonemaster::Engine->zone( 'dnssec16-cds-cdnskey-unsigned.zft-root.rd.nic.fr' );
zone_gives( 'dnssec16', $zone, [q{DS16_DNSKEY_NOT_SIGNED_BY_CDS}] );
zone_gives_not('dnssec16', $zone, [qw{DS16_CDS_INVALID_RRSIG DS16_CDS_MATCHES_NO_DNSKEY DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY DS16_CDS_UNSIGNED DS16_CDS_WITHOUT_DNSKEY DS16_DELETE_CDS DS16_MIXED_DELETE_CDS}] );

$zone = Zonemaster::Engine->zone( 'dnssec16-cds-cdnskey-invalid-rrsig-01.zft-root.rd.nic.fr' );
zone_gives( 'dnssec16', $zone, [q{DS16_CDS_INVALID_RRSIG}] );
zone_gives_not('dnssec16', $zone, [qw{DS16_CDS_MATCHES_NO_DNSKEY DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY DS16_CDS_UNSIGNED DS16_CDS_WITHOUT_DNSKEY DS16_DELETE_CDS DS16_DNSKEY_NOT_SIGNED_BY_CDS DS16_MIXED_DELETE_CDS}] );

$zone = Zonemaster::Engine->zone( 'dnssec16-cds-cdnskey-invalid-rrsig-02.zft-root.rd.nic.fr' );
zone_gives( 'dnssec16', $zone, [q{DS16_CDS_INVALID_RRSIG}] );
zone_gives_not('dnssec16', $zone, [qw{DS16_CDS_MATCHES_NO_DNSKEY DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY DS16_CDS_UNSIGNED DS16_CDS_WITHOUT_DNSKEY DS16_DELETE_CDS DS16_DNSKEY_NOT_SIGNED_BY_CDS DS16_MIXED_DELETE_CDS}] );

$zone = Zonemaster::Engine->zone( 'dnssec16-cds-unsigned.zft-root.rd.nic.fr' );
zone_gives( 'dnssec16', $zone, [qw{DS16_DNSKEY_NOT_SIGNED_BY_CDS DS16_CDS_UNSIGNED}] );
zone_gives_not('dnssec16', $zone, [qw{DS16_CDS_INVALID_RRSIG DS16_CDS_MATCHES_NO_DNSKEY DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY DS16_CDS_WITHOUT_DNSKEY DS16_DELETE_CDS DS16_MIXED_DELETE_CDS}] );

$zone = Zonemaster::Engine->zone( 'dnssec16-delete-cds.zft-root.rd.nic.fr' );
zone_gives( 'dnssec16', $zone, [q{DS16_DELETE_CDS}] );
zone_gives_not('dnssec16', $zone, [qw{DS16_CDS_INVALID_RRSIG DS16_CDS_MATCHES_NO_DNSKEY DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY DS16_CDS_UNSIGNED DS16_CDS_WITHOUT_DNSKEY DS16_DNSKEY_NOT_SIGNED_BY_CDS DS16_MIXED_DELETE_CDS}] );

$zone = Zonemaster::Engine->zone( 'dnssec16-cds-without-dnskey.zft-root.rd.nic.fr' );
zone_gives( 'dnssec16', $zone, [qw{DS16_CDS_WITHOUT_DNSKEY}]);
zone_gives_not('dnssec16', $zone, [qw{DS16_CDS_INVALID_RRSIG DS16_CDS_MATCHES_NO_DNSKEY DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY DS16_CDS_UNSIGNED DS16_DELETE_CDS DS16_DNSKEY_NOT_SIGNED_BY_CDS DS16_MIXED_DELETE_CDS}] );

$zone = Zonemaster::Engine->zone( 'dnssec16-mixed-delete-cds.zft-root.rd.nic.fr' );
zone_gives( 'dnssec16', $zone, [q{DS16_MIXED_DELETE_CDS}]);
zone_gives_not('dnssec16', $zone, [qw{DS16_CDS_INVALID_RRSIG DS16_CDS_MATCHES_NO_DNSKEY DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY DS16_CDS_UNSIGNED DS16_CDS_WITHOUT_DNSKEY DS16_DELETE_CDS DS16_DNSKEY_NOT_SIGNED_BY_CDS}] );

$zone = Zonemaster::Engine->zone( 'dnssec16-cds-matches-no-dnskey.zft-root.rd.nic.fr' );
zone_gives( 'dnssec16', $zone, [q{DS16_CDS_MATCHES_NO_DNSKEY}]);
zone_gives_not('dnssec16', $zone, [qw{DS16_CDS_INVALID_RRSIG DS16_CDS_SIGNED_BY_UNKNOWN_DNSKEY DS16_CDS_UNSIGNED DS16_CDS_WITHOUT_DNSKEY DS16_DELETE_CDS DS16_DNSKEY_NOT_SIGNED_BY_CDS DS16_MIXED_DELETE_CDS}] );

###########
# dnssec17
###########

$zone = Zonemaster::Engine->zone( 'dnssec16-cds-cdnskey-signed.zft-root.rd.nic.fr' );
zone_gives_not('dnssec17', $zone, [qw{DS17_CDNSKEY_INVALID_RRSIG DS17_CDNSKEY_MATCHES_NO_DNSKEY DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY DS17_CDNSKEY_UNSIGNED DS17_CDNSKEY_WITHOUT_DNSKEY DS17_DELETE_CDNSKEY DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_MIXED_DELETE_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec16-cds-cdnskey-unsigned.zft-root.rd.nic.fr' );
zone_gives( 'dnssec17', $zone, [q{DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY}]);
zone_gives_not('dnssec17', $zone, [qw{DS17_CDNSKEY_INVALID_RRSIG DS17_CDNSKEY_MATCHES_NO_DNSKEY DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY DS17_CDNSKEY_UNSIGNED DS17_CDNSKEY_WITHOUT_DNSKEY DS17_DELETE_CDNSKEY DS17_MIXED_DELETE_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec16-cds-cdnskey-invalid-rrsig-01.zft-root.rd.nic.fr' );
zone_gives( 'dnssec17', $zone, [q{DS17_CDNSKEY_INVALID_RRSIG}]);
zone_gives_not('dnssec17', $zone, [qw{DS17_CDNSKEY_MATCHES_NO_DNSKEY DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY DS17_CDNSKEY_UNSIGNED DS17_CDNSKEY_WITHOUT_DNSKEY DS17_DELETE_CDNSKEY DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_MIXED_DELETE_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec16-cds-cdnskey-invalid-rrsig-02.zft-root.rd.nic.fr' );
zone_gives( 'dnssec17', $zone, [q{DS17_CDNSKEY_INVALID_RRSIG}]);
zone_gives_not('dnssec17', $zone, [qw{DS17_CDNSKEY_MATCHES_NO_DNSKEY DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY DS17_CDNSKEY_UNSIGNED DS17_CDNSKEY_WITHOUT_DNSKEY DS17_DELETE_CDNSKEY DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_MIXED_DELETE_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec17-cdnskey-unsigned.zft-root.rd.nic.fr' );
zone_gives( 'dnssec17', $zone, [qw{DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_CDNSKEY_UNSIGNED}]);
zone_gives_not('dnssec17', $zone, [qw{DS17_CDNSKEY_INVALID_RRSIG DS17_CDNSKEY_MATCHES_NO_DNSKEY DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY DS17_CDNSKEY_WITHOUT_DNSKEY DS17_DELETE_CDNSKEY DS17_MIXED_DELETE_CDNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec16-cds-without-dnskey.zft-root.rd.nic.fr' );
zone_gives( 'dnssec17', $zone, [q{DS17_CDNSKEY_WITHOUT_DNSKEY}]);
zone_gives_not('dnssec17', $zone, [qw{DS17_CDNSKEY_INVALID_RRSIG DS17_CDNSKEY_MATCHES_NO_DNSKEY DS17_CDNSKEY_SIGNED_BY_UNKNOWN_DNSKEY DS17_CDNSKEY_UNSIGNED DS17_DELETE_CDNSKEY DS17_DNSKEY_NOT_SIGNED_BY_CDNSKEY DS17_MIXED_DELETE_CDNSKEY}] );

TODO: {
    local $TODO = "Need to find/create zones with that error";

    # dnssec05 (can not exist in a live domain...)
    ok( $tag{ALGORITHM_UNKNOWN}, q{ALGORITHM_UNKNOWN} );
    # dnssec06
    ok( $tag{EXTRA_PROCESSING_BROKEN}, q{EXTRA_PROCESSING_BROKEN} );
    # dnssec07 (need complete analyze with broken zone)
    ok( $tag{ADDITIONAL_DNSKEY_SKIPPED}, q{ADDITIONAL_DNSKEY_SKIPPED} );
    # dnssec10
    ok( $tag{NSEC_COVERS_NOT},        q{NSEC_COVERS_NOT} );
    ok( $tag{NSEC_SIG_VERIFY_ERROR},  q{NSEC_SIG_VERIFY_ERROR} );
    ok( $tag{NSEC_NOT_SIGNED},        q{NSEC_NOT_SIGNED} );
    ok( $tag{NSEC3_NOT_SIGNED},       q{NSEC3_NOT_SIGNED} );
}

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
