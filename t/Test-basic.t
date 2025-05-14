use Test::More;
use File::Slurp;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Nameserver} );
    use_ok( q{Zonemaster::Engine::Test::Basic} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $checking_module = q{Basic};

sub name_gives {
    my ( $test, $name, $gives ) = @_;

    my @res = Zonemaster::Engine->test_method( q{Basic}, $test, $name );

    ok( ( grep { $_->tag eq $gives } @res ), "$name gives $gives" );
}

sub name_gives_not {
    my ( $test, $name, $gives ) = @_;

    my @res = Zonemaster::Engine->test_method( q{Basic}, $test, $name );

    ok( !( grep { $_->tag eq $gives } @res ), "$name does not give $gives" );
}

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

my $datafile = q{t/Test-basic.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

my ($json, $profile_test);
$json         = read_file( 't/profiles/Test-basic-all.json' );
$profile_test = Zonemaster::Engine::Profile->from_json( $json );
Zonemaster::Engine::Profile->effective->merge( $profile_test );

my %res;
my $zone;

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{basic}, q{nic.tf} );
ok( $res{B02_AUTH_RESPONSE_SOA},        q{B02_AUTH_RESPONSE_SOA} );
ok( $res{HAS_NAMESERVER_NO_WWW_A_TEST}, q{HAS_NAMESERVER_NO_WWW_A_TEST} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

Zonemaster::Engine::Profile->effective->set( q{no_network}, 0 );
Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 0 );
Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 0 );

$zone = Zonemaster::Engine->zone( q{afnic.fr} );
zone_gives( q{basic02}, $zone, [qw{NO_NETWORK}] );
zone_gives_not( q{basic02}, $zone, [qw{IPV4_ENABLED}] );
zone_gives_not( q{basic02}, $zone, [qw{IPV6_ENABLED}] );
zone_gives_not( q{basic02}, $zone, [qw{IPV4_DISABLED}] );
zone_gives_not( q{basic02}, $zone, [qw{IPV6_DISABLED}] );
zone_gives( q{basic03}, $zone, [qw{NO_NETWORK}] );
zone_gives_not( q{basic03}, $zone, [qw{IPV4_ENABLED}] );
zone_gives_not( q{basic03}, $zone, [qw{IPV6_ENABLED}] );
zone_gives_not( q{basic03}, $zone, [qw{IPV4_DISABLED}] );
zone_gives_not( q{basic03}, $zone, [qw{IPV6_DISABLED}] );

Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );

TODO: {
    local $TODO = "Need to find/create zones with that error";

    #basic03
    ok( $tag{A_QUERY_NO_RESPONSES}, q{A_QUERY_NO_RESPONSES} );
    ok( $tag{HAS_A_RECORDS}, q{HAS_A_RECORDS} );
    ok( $tag{NO_A_RECORDS}, q{NO_A_RECORDS} );
}

done_testing;
