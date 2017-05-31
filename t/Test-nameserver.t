use Test::More;

use List::MoreUtils qw[uniq none any];

BEGIN {
    use_ok( q{Zonemaster} );
    use_ok( q{Zonemaster::Engine::Test::Nameserver} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $checking_module = q{Nameserver};

sub zone_gives {
    my ( $test, $zone, $gives_ref ) = @_;

    Zonemaster->logger->clear_history();
    my @res = Zonemaster->test_method( $checking_module, $test, $zone );
    foreach my $gives ( @{$gives_ref} ) {
        ok( ( grep { $_->tag eq $gives } @res ), $zone->name->string . " gives $gives" );
    }
    return scalar( @res );
}

sub zone_gives_not {
    my ( $test, $zone, $gives_ref ) = @_;

    Zonemaster->logger->clear_history();
    my @res = Zonemaster->test_method( $checking_module, $test, $zone );
    foreach my $gives ( @{$gives_ref} ) {
        ok( !( grep { $_->tag eq $gives } @res ), $zone->name->string . " does not give $gives" );
    }
    return scalar( @res );
}

my $datafile = q{t/Test-nameserver.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster->config->no_network( 1 );
}

my @testcases_with_network = (qw{nameserver01 nameserver02 nameserver06 nameserver07 nameserver08 nameserver09});
foreach my $testcase ( qw{nameserver01 nameserver02 nameserver03 nameserver04 nameserver05 nameserver06 nameserver07 nameserver08 nameserver09} ) {
    next if grep { $_ eq $testcase } @testcases_with_network;
    Zonemaster->config->load_policy_file( 't/policies/Test-'.$testcase.'-only.json' );
    my @testcases;
    Zonemaster->logger->clear_history();
    foreach my $result ( Zonemaster->test_module( q{nameserver}, q{afnic.fr} ) ) {
        foreach my $trace (@{$result->trace}) {
            push @testcases, grep /Zonemaster::Engine::Test::Nameserver::nameserver/, @$trace;
        }
    }
    @testcases = uniq sort @testcases;
    is( scalar( @testcases ), 1, 'only one test-case' );
    is( $testcases[0], 'Zonemaster::Engine::Test::Nameserver::'.$testcase, 'expected test-case' );
}
Zonemaster->config->load_policy_file( 't/policies/Test-nameserver-all.json' );

my $zone;
my @res;
my %tag;

# nameserver01
$zone = Zonemaster->zone( 'fr' );
zone_gives( 'nameserver01', $zone, [q{NO_RECURSOR}] );
zone_gives_not( 'nameserver01', $zone, [q{IS_A_RECURSOR}] );

# nameserver02
$zone = Zonemaster->zone( 'perennaguiden.se' );
zone_gives( 'nameserver02', $zone, ['EDNS0_BAD_ANSWER']);

$zone = Zonemaster->zone( 'pricelessstockolm.se' );
zone_gives( 'nameserver02', $zone, ['EDNS0_BAD_QUERY'] );

$zone = Zonemaster->zone( 'dyad.se' );
zone_gives( 'nameserver02', $zone, ['EDNS0_SUPPORT'] );

# nameserver03
$zone = Zonemaster->zone( 'nameserver03-axfr-failure.zut-root.rd.nic.fr' );
zone_gives( 'nameserver03', $zone, [q{AXFR_FAILURE}] );
zone_gives_not( 'nameserver03', $zone, [q{AXFR_AVAILABLE}] );

# nameserver04
$zone = Zonemaster->zone( 'afnic.fr' );
zone_gives( 'nameserver04', $zone, [q{SAME_SOURCE_IP}] );

# nameserver05
$zone = Zonemaster->zone( 'afnic.fr' );
zone_gives( 'nameserver05', $zone, [q{AAAA_WELL_PROCESSED}] );

$zone = Zonemaster->zone( 'uddevallafiber.se' );
zone_gives( 'nameserver05', $zone, ['QUERY_DROPPED'] );

# nameserver06
$zone = Zonemaster->zone( 'nameserver06-can-not-be-resolved.zut-root.rd.nic.fr' );
zone_gives( 'nameserver06', $zone, [q{CAN_NOT_BE_RESOLVED}] );

$zone = Zonemaster->zone( 'nameserver06-no-resolution.zut-root.rd.nic.fr' );
zone_gives( 'nameserver06', $zone, [q{NO_RESOLUTION}] );

$zone = Zonemaster->zone( 'nameserver06-can-be-resolved.zut-root.rd.nic.fr' );
zone_gives( 'nameserver06', $zone, [q{CAN_BE_RESOLVED}] );

# nameserver07
$zone = Zonemaster->zone( '.' );
zone_gives( 'nameserver07', $zone, [q{UPWARD_REFERRAL_IRRELEVANT}] );
zone_gives_not( 'nameserver07', $zone, [qw{UPWARD_REFERRAL NO_UPWARD_REFERRAL}] );

SKIP: {
    skip "Zone does not actually have tested problem", 1,
    $zone = Zonemaster->zone( 'escargot.se' );
    zone_gives( 'nameserver05', $zone, ['ANSWER_BAD_RCODE'] );
}

TODO: {
    local $TODO = "Need to find/create zones with that error";

    # nameserver04
    ok( $tag{DIFFERENT_SOURCE_IP}, q{DIFFERENT_SOURCE_IP} );

    # nameserver07
    ok( $tag{UPWARD_REFERRAL}, q{UPWARD_REFERRAL} );
    ok( $tag{NO_UPWARD_REFERRAL}, q{NO_UPWARD_REFERRAL} );

    # nameserver08
    ok( $tag{QNAME_CASE_INSENSITIVE}, q{QNAME_CASE_INSENSITIVE} );
    ok( $tag{QNAME_CASE_SENSITIVE}, q{QNAME_CASE_SENSITIVE} );
}

SKIP: {
    # Default behaviour changed. It's always skipped unless we have network
    # available.
    skip 'no network', 3 if not $ENV{ZONEMASTER_RECORD};

    # AXFR results not well cached. Can not test cases where AXFR is avaibale
    # without network, even in case of ZONEMASTER_RECORD is not set.
    $zone = Zonemaster->zone( 'nameserver03-axfr-available.zut-root.rd.nic.fr' );
    zone_gives( 'nameserver03', $zone, [q{AXFR_AVAILABLE}] );
    $zone = Zonemaster->zone( 'arpa' );
    zone_gives( 'nameserver03', $zone, [q{AXFR_AVAILABLE}] );
    zone_gives( 'nameserver03', $zone, [q{AXFR_FAILURE}] );
}

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

Zonemaster->config->no_network( 0 );
Zonemaster->config->ipv6_ok( 0 );
Zonemaster->config->ipv4_ok( 0 );
$zone = Zonemaster->zone( 'fr' );
zone_gives( 'nameserver01', $zone, [q{NO_NETWORK}] );
zone_gives_not( 'nameserver01', $zone, [qw{NO_RECURSOR IS_A_RECURSOR}] );
$zone = Zonemaster->zone( 'perennaguiden.se' );
zone_gives( 'nameserver02', $zone, [q{NO_NETWORK}] );
zone_gives_not( 'nameserver02', $zone, [qw{EDNS0_BAD_ANSWER EDNS0_BAD_QUERY EDNS0_SUPPORT}] );
$zone = Zonemaster->zone( 'nameserver03-axfr-failure.zut-root.rd.nic.fr' );
zone_gives( 'nameserver03', $zone, [q{NO_NETWORK}] );
zone_gives_not( 'nameserver03', $zone, [qw{AXFR_FAILURE AXFR_AVAILABLE}] );
$zone = Zonemaster->zone( 'afnic.fr' );
zone_gives( 'nameserver04', $zone, [q{NO_NETWORK}] );
zone_gives_not( 'nameserver04', $zone, [qw{SAME_SOURCE_IP DIFFERENT_SOURCE_IP}] );
zone_gives( 'nameserver05', $zone, [q{NO_NETWORK}] );
zone_gives_not( 'nameserver05', $zone, [qw{IPV6_DISABLED IPV4_DISABLED}] );
$zone = Zonemaster->zone( 'nameserver06-can-not-be-resolved.zut-root.rd.nic.fr' );
zone_gives( 'nameserver06', $zone, [q{NO_NETWORK}] );
zone_gives_not( 'nameserver06', $zone, [qw{CAN_NOT_BE_RESOLVED NO_RESOLUTION CAN_BE_RESOLVED}] );
$zone = Zonemaster->zone( '.' );
zone_gives( 'nameserver07', $zone, [q{NO_NETWORK}] );
zone_gives_not( 'nameserver07', $zone, [qw{UPWARD_REFERRAL_IRRELEVANT UPWARD_REFERRAL NO_UPWARD_REFERRAL}] );
zone_gives( 'nameserver08', $zone, [q{NO_NETWORK}] );
zone_gives_not( 'nameserver08', $zone, [qw{QNAME_CASE_INSENSITIVE QNAME_CASE_SENSITIVE}] );


#Zonemaster->config->ipv6_ok( 0 );
#Zonemaster->config->ipv4_ok( 1 );
#$zone = Zonemaster->zone( 'fr' );
#zone_gives( 'nameserver01', $zone, [q{NO_RECURSOR}] );
#zone_gives_not( 'nameserver01', $zone, [qw{NO_NETWORK IS_A_RECURSOR}] );
#$zone = Zonemaster->zone( 'afnic.fr' );
#zone_gives( 'nameserver05', $zone, [q{IPV6_DISABLED}] );
#zone_gives_not( 'nameserver05', $zone, [qw{NO_NETWORK IPV4_DISABLED}] );
#
#if ( Zonemaster::Engine::Util::supports_ipv6() ) {
#
#    Zonemaster->config->ipv6_ok( 1 );
#    Zonemaster->config->ipv4_ok( 0 );
#    $zone = Zonemaster->zone( 'fr' );
#    zone_gives( 'nameserver01', $zone, [q{NO_RECURSOR}] );
#    zone_gives_not( 'nameserver01', $zone, [qw{NO_NETWORK IS_A_RECURSOR}] );
#    $zone = Zonemaster->zone( 'afnic.fr' );
#    zone_gives( 'nameserver05', $zone, [q{IPV4_DISABLED}] );
#    zone_gives_not( 'nameserver05', $zone, [qw{NO_NETWORK IPV6_DISABLED}] );
#
#    Zonemaster->config->ipv6_ok( 1 );
#    Zonemaster->config->ipv4_ok( 1 );
#    $zone = Zonemaster->zone( 'fr' );
#    zone_gives( 'nameserver01', $zone, [q{NO_RECURSOR}] );
#    zone_gives_not( 'nameserver01', $zone, [qw{NO_NETWORK IS_A_RECURSOR}] );
#    $zone = Zonemaster->zone( 'afnic.fr' );
#    zone_gives_not( 'nameserver05', $zone, [qw{NO_NETWORK IPV4_DISABLED IPV6_DISABLED}] );
#
#}

Zonemaster->config->no_network( 1 );

done_testing;
