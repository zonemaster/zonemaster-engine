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

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{basic}, q{birgerjarlhotel.se} );
ok( $res{A_QUERY_NO_RESPONSES}, q{A_QUERY_NO_RESPONSES} );

###########
# basic01
###########
$zone = Zonemaster::Engine->zone( 'exampledomain.fake' );
zone_gives('basic01', $zone, [qw{B01_PARENT_FOUND B01_NO_CHILD}] );
zone_gives_not( 'basic01', $zone, [qw{B01_CHILD_IS_ALIAS B01_CHILD_FOUND B01_CHILD_NOT_EXIST B01_INCONSISTENT_ALIAS B01_INCONSISTENT_DELEGATION B01_PARENT_UNDETERMINED B01_UNEXPECTED_NS_RESPONSE}] );

$zone = Zonemaster::Engine->zone( 'afnic.fr' );
zone_gives('basic01', $zone, [qw{B01_PARENT_FOUND B01_CHILD_FOUND}] );
zone_gives_not( 'basic01', $zone, [qw{B01_CHILD_IS_ALIAS B01_CHILD_NOT_EXIST B01_INCONSISTENT_ALIAS B01_INCONSISTENT_DELEGATION B01_NO_CHILD B01_PARENT_UNDETERMINED B01_UNEXPECTED_NS_RESPONSE}] );

###########
# basic02
###########
$zone = Zonemaster::Engine->zone( 'exampledomain.fake' );
zone_gives('basic02', $zone, [qw{B02_NO_DELEGATION}] );
zone_gives_not( 'basic02', $zone, [qw{B02_AUTH_RESPONSE_SOA B02_NO_WORKING_NS B02_NS_BROKEN B02_NS_NOT_AUTH B02_NS_NO_IP_ADDR B02_NS_NO_RESPONSE B02_UNEXPECTED_RCODE}] );

$zone = Zonemaster::Engine->zone( 'lame-ns-no-name.dufberg.se' );
zone_gives('basic02', $zone, [qw{B02_NO_WORKING_NS B02_NS_NO_IP_ADDR}] );
zone_gives_not( 'basic02', $zone, [qw{B02_AUTH_RESPONSE_SOA B02_NO_DELEGATION B02_NS_BROKEN B02_NS_NOT_AUTH B02_NS_NO_RESPONSE B02_UNEXPECTED_RCODE}] );

$zone = Zonemaster::Engine->zone( 'lame-ns-no-addr.dufberg.se' );
zone_gives('basic02', $zone, [qw{B02_NO_WORKING_NS B02_NS_NO_IP_ADDR}] );
zone_gives_not( 'basic02', $zone, [qw{B02_AUTH_RESPONSE_SOA B02_NO_DELEGATION B02_NS_BROKEN B02_NS_NOT_AUTH B02_NS_NO_RESPONSE B02_UNEXPECTED_RCODE}] );

$zone = Zonemaster::Engine->zone( 'lame-ns-no-glue.dufberg.se' );
zone_gives('basic02', $zone, [qw{B02_NO_WORKING_NS B02_NS_NO_IP_ADDR}] );
zone_gives_not( 'basic02', $zone, [qw{B02_AUTH_RESPONSE_SOA B02_NO_DELEGATION B02_NS_BROKEN B02_NS_NOT_AUTH B02_NS_NO_RESPONSE B02_UNEXPECTED_RCODE}] );

$zone = Zonemaster::Engine->zone( 'lame-ns-no-response.dufberg.se' );
zone_gives('basic02', $zone, [qw{B02_NO_WORKING_NS B02_NS_NO_RESPONSE}] );
zone_gives_not( 'basic02', $zone, [qw{B02_AUTH_RESPONSE_SOA B02_NO_DELEGATION B02_NS_BROKEN B02_NS_NOT_AUTH B02_NS_NO_IP_ADDR B02_UNEXPECTED_RCODE}] );

$zone = Zonemaster::Engine->zone( 'lame-ns-refused.dufberg.se' );
zone_gives('basic02', $zone, [qw{B02_NO_WORKING_NS B02_UNEXPECTED_RCODE}] );
zone_gives_not( 'basic02', $zone, [qw{B02_AUTH_RESPONSE_SOA B02_NO_DELEGATION B02_NS_BROKEN B02_NS_NOT_AUTH B02_NS_NO_RESPONSE B02_NS_NO_IP_ADDR}] );

$zone = Zonemaster::Engine->zone( 'lame-ns-servfail.dufberg.se' );
zone_gives('basic02', $zone, [qw{B02_NO_WORKING_NS B02_UNEXPECTED_RCODE}] );
zone_gives_not( 'basic02', $zone, [qw{B02_AUTH_RESPONSE_SOA B02_NO_DELEGATION B02_NS_BROKEN B02_NS_NOT_AUTH B02_NS_NO_RESPONSE B02_NS_NO_IP_ADDR}] );

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

    # basic01
    ok( $tag{B01_CHILD_IS_ALIAS}, q{B01_CHILD_IS_ALIAS} );
    ok( $tag{B01_CHILD_NOT_EXIST}, q{B01_CHILD_NOT_EXIST} );
    ok( $tag{B01_INCONSISTENT_ALIAS}, q{B01_INCONSISTENT_ALIAS} );
    ok( $tag{B01_INCONSISTENT_DELEGATION}, q{B01_INCONSISTENT_DELEGATION} );
    ok( $tag{B01_PARENT_UNDETERMINED}, q{B01_PARENT_UNDETERMINED} );
    ok( $tag{B01_UNEXPECTED_NS_RESPONSE}, q{B01_UNEXPECTED_NS_RESPONSE} );
}

done_testing;
