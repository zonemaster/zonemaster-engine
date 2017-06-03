use Test::More;

use List::MoreUtils qw[uniq none any];

BEGIN {
    use_ok( 'Zonemaster::Engine' );
    use_ok( 'Zonemaster::Engine::Test::DNSSEC' );
}

my $checking_module = q{DNSSEC};

sub zone_gives {
    my ( $test, $zone, $gives_ref ) = @_;

    Zonemaster::Engine->logger->clear_history();
    my @res = Zonemaster::Engine->test_method( $checking_module, $test, $zone );
    foreach my $gives ( @{$gives_ref} ) {
        ok( ( grep { $_->tag eq $gives } @res ), $zone->name->string . " gives $gives" );
    }
    return scalar( @res );
}

sub zone_gives_not {
    my ( $test, $zone, $gives_ref ) = @_;

    Zonemaster::Engine->logger->clear_history();
    my @res = Zonemaster::Engine->test_method( $checking_module, $test, $zone );
    foreach my $gives ( @{$gives_ref} ) {
        ok( !( grep { $_->tag eq $gives } @res ), $zone->name->string . " does not give $gives" );
    }
    return scalar( @res );
}

my $datafile = 't/Test-dnssec.data';
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die "Stored data file missing" if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine->config->no_network( 1 );
}

# Find a way for dnssec06 which have a dependence...
foreach my $testcase ( qw{dnssec01 dnssec02 dnssec03 dnssec04 dnssec05 dnssec07 dnssec08 dnssec09 dnssec10 dnssec11} ) {
    Zonemaster::Engine->config->load_policy_file( 't/policies/Test-'.$testcase.'-only.json' );
    my @testcases;
    Zonemaster::Engine->logger->clear_history();
    foreach my $result ( Zonemaster::Engine->test_module( q{dnssec}, q{nic.se} ) ) {
        foreach my $trace (@{$result->trace}) {
            push @testcases, grep /Zonemaster::Engine::Test::DNSSEC::dnssec/, @$trace;
        }
    }
    @testcases = uniq sort @testcases;
    is( scalar( @testcases ), 1, 'only one test-case' );
    is( $testcases[0], 'Zonemaster::Engine::Test::DNSSEC::'.$testcase, 'expected test-case' );
}

Zonemaster::Engine->config->load_policy_file( 't/policies/Test-dnssec-all.json' );

my $zone;
my @res;
my %tag;

$zone = Zonemaster::Engine->zone( 'nic.se' );

@res = grep {$_->tag ne 'START_TIME' and $_->tag ne 'TEST_ARGS' } Zonemaster::Engine->test_method( 'DNSSEC', 'dnssec01', $zone );
foreach my $msg ( @res ) {
    is( $msg->tag, 'DS_DIGTYPE_OK', 'DS_DIGTYPE_OK' );
}

my $zone2 = Zonemaster::Engine->zone( 'seb.se' );
is( zone_gives( 'dnssec01', $zone2, [q{NO_DS}] ), 3, 'Only one (useful) message' );

zone_gives( 'dnssec02', $zone, [qw{DS_MATCHES_DNSKEY COMMON_KEYTAGS DS_MATCH_FOUND DS_FOUND}] );

is( zone_gives( 'dnssec02', $zone2, [q{NO_DS}] ), 3, 'Only one (useful) message' );

my $zone3 = Zonemaster::Engine->zone( 'com' );
is( zone_gives( 'dnssec03', $zone3, [q{ITERATIONS_OK}] ), 3, 'Only one (useful) message' );

@res = Zonemaster::Engine->test_method( 'DNSSEC', 'dnssec04', $zone );
%tag = map { $_->tag => 1 } @res;
ok( ( $tag{DURATION_OK} || $tag{REMAINING_SHORT} || $tag{RRSIG_EXPIRED} ), 'DURATION_OK (sort of)' );

zone_gives( 'dnssec05', $zone, [q{ALGORITHM_OK}] );

zone_gives( 'dnssec06', $zone, [q{EXTRA_PROCESSING_OK}] );

zone_gives( 'dnssec07', $zone, q{DNSKEY_AND_DS} );
zone_gives_not( 'dnssec07', $zone, [qw{NEITHER_DNSKEY_NOR_DS DNSKEY_BUT_NOT_DS DS_BUT_NOT_DNSKEY}] );

zone_gives( 'dnssec08', $zone, [qw{DNSKEY_SIGNATURE_OK DNSKEY_SIGNED}] );

zone_gives( 'dnssec09', $zone, [qw{SOA_SIGNATURE_OK SOA_SIGNED}] );

zone_gives( 'dnssec10', $zone, [qw{HAS_NSEC NSEC_SIGNED NSEC_COVERS}] );

zone_gives( 'dnssec10', $zone3, [qw{HAS_NSEC3 NSEC3_SIGNED NSEC3_COVERS}] );

# dnssec01
$zone = Zonemaster::Engine->zone( 'dnssec01-ds-digtype-not-ok.zut-root.rd.nic.fr' );
zone_gives( 'dnssec01', $zone, [q{DS_DIGTYPE_NOT_OK}] );
zone_gives_not( 'dnssec01', $zone, [qw{DS_DIGTYPE_OK NO_DS}] );

# dnssec02
$zone = Zonemaster::Engine->zone( 'dnssec02-no-dnskey.zut-root.rd.nic.fr' );
zone_gives( 'dnssec02', $zone, [q{NO_DNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec02-ds-does-not-match-dnskey.zut-root.rd.nic.fr' );
zone_gives_not( 'dnssec02', $zone, q{NO_DS} );
zone_gives( 'dnssec02', $zone, [qw{DS_FOUND DS_MATCH_NOT_FOUND DS_DOES_NOT_MATCH_DNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec02-no-common-keytags.zut-root.rd.nic.fr' );
zone_gives( 'dnssec02', $zone, [qw{DS_FOUND NO_COMMON_KEYTAGS}] );

# dnssec03
$zone = Zonemaster::Engine->zone( 'dnssec03-many-iterations.zut-root.rd.nic.fr' );
zone_gives( 'dnssec03', $zone, [q{MANY_ITERATIONS}] );

$zone = Zonemaster::Engine->zone( 'dnssec03-no-nsec3param.zut-root.rd.nic.fr' );
zone_gives( 'dnssec03', $zone, [q{NO_NSEC3PARAM}] );

$zone = Zonemaster::Engine->zone( 'dnssec03-too-many-iterations.zut-root.rd.nic.fr' );
zone_gives( 'dnssec03', $zone, [q{TOO_MANY_ITERATIONS}] );

# dnssec04
$zone = Zonemaster::Engine->zone( 'dnssec04-duration-long.zut-root.rd.nic.fr' );
zone_gives( 'dnssec04', $zone, [q{DURATION_LONG}] );

$zone = Zonemaster::Engine->zone( 'dnssec04-remaining-long.zut-root.rd.nic.fr' );
zone_gives( 'dnssec04', $zone, [q{REMAINING_LONG}] );

# dnssec05
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

# dnssec06
$zone = Zonemaster::Engine->zone( 'dnssec06-extra-processing-broken-1.zut-root.rd.nic.fr' );
zone_gives( 'dnssec06', $zone, [q{EXTRA_PROCESSING_BROKEN}] );
zone_gives_not( 'dnssec06', $zone, [q{EXTRA_PROCESSING_OK}] );

$zone = Zonemaster::Engine->zone( 'dnssec06-extra-processing-broken-2.zut-root.rd.nic.fr' );
zone_gives( 'dnssec06', $zone, [q{EXTRA_PROCESSING_BROKEN}] );
zone_gives_not( 'dnssec06', $zone, [q{EXTRA_PROCESSING_OK}] );

# dnssec07
$zone = Zonemaster::Engine->zone( 'dnssec07-dnskey-but-not-ds.zut-root.rd.nic.fr' );
zone_gives( 'dnssec07', $zone, [q{DNSKEY_BUT_NOT_DS}] );
zone_gives_not( 'dnssec07', $zone, [qw{DNSKEY_AND_DS DS_BUT_NOT_DNSKEY NEITHER_DNSKEY_NOR_DS}] );

$zone = Zonemaster::Engine->zone( 'dnssec07-neither-dnskey-nor-ds.zut-root.rd.nic.fr' );
zone_gives( 'dnssec07', $zone, [q{NEITHER_DNSKEY_NOR_DS}] );
zone_gives_not( 'dnssec07', $zone, [qw{DNSKEY_BUT_NOT_DS DNSKEY_AND_DS DS_BUT_NOT_DNSKEY}] );

$zone = Zonemaster::Engine->zone( 'dnssec07-ds-but-not-dnskey.zut-root.rd.nic.fr' );
zone_gives( 'dnssec07', $zone, [q{DS_BUT_NOT_DNSKEY}] );
zone_gives_not( 'dnssec07', $zone, [qw{NEITHER_DNSKEY_NOR_DS DNSKEY_BUT_NOT_DS DNSKEY_AND_DS}] );

# dnssec08
$zone = Zonemaster::Engine->zone( 'dnssec08-dnskey-not-signed.zut-root.rd.nic.fr' );
zone_gives( 'dnssec08', $zone, [qw{DNSKEY_NOT_SIGNED DNSKEY_SIGNATURE_NOT_OK}] );

$zone = Zonemaster::Engine->zone( 'dnssec08-dnskey-signature-not-ok.zut-root.rd.nic.fr' );
zone_gives( 'dnssec08', $zone, [qw{DNSKEY_SIGNED DNSKEY_SIGNATURE_NOT_OK DNSKEY_SIGNATURE_OK}] );

$zone = Zonemaster::Engine->zone( 'dnssec08-no-keys-or-no-sigs-1.zut-root.rd.nic.fr' );
zone_gives( 'dnssec08', $zone, [q{NO_KEYS_OR_NO_SIGS}] );
zone_gives( 'dnssec09', $zone, [q{NO_KEYS_OR_NO_SIGS_OR_NO_SOA}] );

$zone = Zonemaster::Engine->zone( 'dnssec08-no-keys-or-no-sigs-2.zut-root.rd.nic.fr' );
zone_gives( 'dnssec08', $zone, [q{NO_KEYS_OR_NO_SIGS}] );

# dnssec09
$zone = Zonemaster::Engine->zone( 'dnssec09-soa-signature-not-ok.zut-root.rd.nic.fr' );
zone_gives( 'dnssec09', $zone, [qw{SOA_NOT_SIGNED SOA_SIGNATURE_NOT_OK}] );

# dnssec10
$zone = Zonemaster::Engine->zone( 'fr'  );
zone_gives( 'dnssec10', $zone, ['HAS_NSEC3_OPTOUT'] );

$zone = Zonemaster::Engine->zone( 'ma'  );
zone_gives_not( 'dnssec10', $zone, ['HAS_NSEC3_OPTOUT'] );

# GOST
#$zone = Zonemaster::Engine->zone( 'caint.su' );
#@res = Zonemaster::Engine->test_method( 'DNSSEC', 'dnssec08', $zone );
#ok( ( grep { $_->string =~ /error=no GOST support/s } @res ), $zone->name->string . " no GOST support" );
#@res = Zonemaster::Engine->test_method( 'DNSSEC', 'dnssec09', $zone );
#ok( ( grep { $_->string =~ /error=no GOST support/s } @res ), $zone->name->string . " no GOST support" );
#@res = Zonemaster::Engine->test_method( 'DNSSEC', 'dnssec10', $zone );
#ok( ( grep { $_->string =~ /error=no GOST support/s } @res ), $zone->name->string . " no GOST support" );

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
