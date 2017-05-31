use Test::More;

use List::MoreUtils qw[uniq none any];

BEGIN {
    use_ok( q{Zonemaster} );
    use_ok( q{Zonemaster::Engine::Test::Nameserver} );
    use_ok( q{Zonemaster::Util} );
}

my $checking_module;

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

my $datafile = q{t/Test-lastcases.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster->config->no_network( 1 );
}

my $zone;
my @res;
my %tag;

$checking_module = q{Nameserver};

# nameserver01
$zone = Zonemaster->zone( 'nameserver06-can-be-resolved.zut-root.rd.nic.fr' );
zone_gives_not( 'nameserver01', $zone, [q{NO_RECURSOR}] );
zone_gives( 'nameserver01', $zone, [q{IS_A_RECURSOR}] );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
