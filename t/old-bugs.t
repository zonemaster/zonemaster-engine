use Test::More;

use Zonemaster::Engine;
use Zonemaster::Engine::Nameserver;
use Zonemaster::Engine::Test::Delegation;
use Zonemaster::Engine::Test::Nameserver;

use List::MoreUtils qw[any none];

sub zone_gives {
    my ( $checking_module, $test, $zone, $gives_ref ) = @_;

    Zonemaster::Engine->logger->clear_history();
    my @res = Zonemaster::Engine->test_method( $checking_module, $test, $zone );
    foreach my $gives ( @{$gives_ref} ) {
        ok( ( grep { $_->tag eq $gives } @res ), $zone->name->string . " gives $gives" );
    }
    return scalar( @res );
}

sub zone_gives_not {
    my ( $checking_module, $test, $zone, $gives_ref ) = @_;

    Zonemaster::Engine->logger->clear_history();
    my @res = Zonemaster::Engine->test_method( $checking_module, $test, $zone );
    foreach my $gives ( @{$gives_ref} ) {
        ok( !( grep { $_->tag eq $gives } @res ), $zone->name->string . " does not give $gives" );
    }
    return scalar( @res );
}

my $datafile = q{t/old-bugs.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine->config->no_network( 1 );
}

my @res = Zonemaster::Engine->test_method( 'Syntax', 'syntax03', 'XN--MGBERP4A5D4AR' );
is( $res[2]->tag, q{NO_DOUBLE_DASH}, 'No complaint for XN--MGBERP4A5D4AR' );

my $zft_zone = Zonemaster::Engine->zone( 'zft.rd.nic.fr' );
is( scalar( @{ $zft_zone->ns } ), 2, 'Two nameservers for zft.rd.nic.fr.' );

my $root = Zonemaster::Engine->zone( '.' );
my @msg = Zonemaster::Engine->test_method( 'Delegation', 'delegation03', $root );

ok( any { $_->tag eq 'REFERRAL_SIZE_OK' } @msg );
ok( none { $_->tag eq 'MODULE_ERROR' } @msg );

my $nf = Zonemaster::Engine->zone( 'nic.fr' );
is( scalar( @{ $nf->glue_names } ), 6, 'All glue names' );
is( scalar( @{ $nf->glue } ),       11, 'All glue objects' );
is( scalar( @{ $nf->ns_names } ),   6, 'All NS names' );
is( scalar( @{ $nf->ns } ),         11, 'All NS objects' );

my $rootfr = Zonemaster::Engine->zone( 'root.fr' );
@res = Zonemaster::Engine->test_method( 'DNSSEC', 'dnssec02', $rootfr );
ok( ( none { $_->tag eq 'MODULE_ERROR' } @res ), 'No crash in dnssec02' );

my $gnames = Zonemaster::Engine->zone( 'nameserver06-no-resolution.zut-root.rd.nic.fr' )->glue_names;
is( scalar( @$gnames ), 2, 'Two glue names' );

my $tld = Zonemaster::Engine->zone( 'abogado' );
@res = Zonemaster::Engine->test_method( 'DNSSEC', 'dnssec10', $tld );
ok( ( none { $_->tag eq 'INVALID_NAME_FOUND' } @res ), 'NSEC3 test works for domain with wildcard.' );
ok( ( any { $_->tag eq 'NSEC3_COVERS' } @res ), 'NSEC3 test works for domain with wildcard.' );

my $bobo = Zonemaster::Engine->zone( 'bobo.nl' );
@res = Zonemaster::Engine->test_method('Address', 'address03', $bobo);
ok( ( none { $_->tag eq 'NO_RESPONSE_PTR_QUERY' } @res ), 'Recursor can deal with CNAMEs when recursing.' );

my $zone = Zonemaster::Engine->zone( 'tirsen-aili.se' );
# Old version of nameserver01 Result
#zone_gives( q{Nameserver}, 'nameserver01', $zone, [q{NO_RECURSOR}] );
zone_gives( q{Nameserver}, 'nameserver01', $zone, [q{RECURSIVITY_UNDEF}] );
zone_gives_not( q{Nameserver}, 'nameserver01', $zone, [q{IS_A_RECURSOR}] );

$zone = Zonemaster::Engine->zone( '.' );
zone_gives_not( q{Nameserver}, 'nameserver01', $zone, [q{IS_A_RECURSOR}] );
zone_gives( q{Nameserver}, 'nameserver01', $zone, [q{NO_RECURSOR}] );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
