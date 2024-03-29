use Test::More;
use File::Slurp;

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

my $datafile = 't/Test-dnssec-more.data';
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die "Stored data file missing" if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

my ($json, $profile_test);
$json         = read_file( 't/profiles/Test-dnssec-more-all.json' );
$profile_test = Zonemaster::Engine::Profile->from_json( $json );
Zonemaster::Engine::Profile->effective->merge( $profile_test );

my $zone;
my @res;
my %tag;

SKIP: {
    skip "dnssec01 tests are now in a separate file.", 1;
    @res = Zonemaster::Engine->test_module( 'DNSSEC', 'loopia.se' );
    %tag = map { $_->tag => 1 } @res;
    ok( $tag{NO_RESPONSE_DS}, 'NO_RESPONSE_DS' );
}

$zone = Zonemaster::Engine->zone( 'rsa4096.nxdomain.se' );
zone_gives_not( 'dnssec03', $zone, ['TOO_MANY_ITERATIONS'] );

# dnssec10
SKIP: {
    skip "Need to configure another zone for this test cases.", 3;

    $zone = Zonemaster::Engine->zone( 'wwwyahoo.se' );
    zone_gives( 'dnssec10', $zone, ['INVALID_NAME_RCODE']);

    $zone = Zonemaster::Engine->zone( 'denki.se' );
    zone_gives( 'dnssec10', $zone, ['NSEC3_COVERS_NOT']);

    $zone = Zonemaster::Engine->zone( 'retailacademicsconsulting.se' );
    zone_gives( 'dnssec10', $zone, ['NSEC3_SIG_VERIFY_ERROR']);
}

$zone = Zonemaster::Engine->zone( 'y.nu' );
zone_gives_not( 'dnssec03', $zone, ['TOO_MANY_ITERATIONS'] );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
