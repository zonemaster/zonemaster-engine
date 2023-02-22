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

my @res;
my %res;

my $ns_ok       = Zonemaster::Engine::DNSName->new( q{ns1.nic.fr} );
my $ns_too_long = Zonemaster::Engine::DNSName->new(
q{ns123456789012345678901234567890123456789012345678901234567890.dom123456789012345678901234567890123456789012345678901234567890.dom123456789012345678901234567890123456789012345678901234567890.tld123456789012345678901234567890123456789012345678901234567890}
);
my $ns_ok_long = Zonemaster::Engine::DNSName->new(
q{ns23456789012345678901234567890123456789012345678901234567890.dom123456789012345678901234567890123456789012345678901234567890.dom123456789012345678901234567890123456789012345678901234567890.tld123456789012345678901234567890123456789012345678901234567890}
);
name_gives( q{basic00}, $ns_too_long, q{DOMAIN_NAME_TOO_LONG} );
%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{basic}, $ns_too_long );
ok( $res{DOMAIN_NAME_TOO_LONG}, q{DOMAIN_NAME_TOO_LONG} );
name_gives_not( q{basic00}, $ns_ok, q{DOMAIN_NAME_TOO_LONG} );
%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{basic}, $ns_ok );
ok( !$res{DOMAIN_NAME_TOO_LONG}, q{Not DOMAIN_NAME_TOO_LONG} );
name_gives_not( q{basic00}, $ns_ok_long, q{DOMAIN_NAME_TOO_LONG} );
%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{basic}, $ns_ok_long );
ok( !$res{DOMAIN_NAME_TOO_LONG}, q{Not DOMAIN_NAME_TOO_LONG} );

my $ns_label_too_long = Zonemaster::Engine::DNSName->new( q{ns1234567890123456789012345678901234567890123456789012345678901234567890.nic.fr} );
name_gives( q{basic00}, $ns_label_too_long, q{DOMAIN_NAME_LABEL_TOO_LONG} );
%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{basic}, $ns_label_too_long );
ok( $res{DOMAIN_NAME_LABEL_TOO_LONG}, q{DOMAIN_NAME_LABEL_TOO_LONG} );
name_gives_not( q{basic00}, $ns_ok, q{DOMAIN_NAME_LABEL_TOO_LONG} );
%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{basic}, $ns_ok );
ok( !$res{DOMAIN_NAME_LABEL_TOO_LONG}, q{Not DOMAIN_NAME_LABEL_TOO_LONG} );

my $ns_null_label = Zonemaster::Engine::DNSName->new( q{dom12134..fr} );
name_gives( q{basic00}, $ns_null_label, q{DOMAIN_NAME_ZERO_LENGTH_LABEL} );
%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{basic}, $ns_null_label );
ok( $res{DOMAIN_NAME_ZERO_LENGTH_LABEL}, q{DOMAIN_NAME_ZERO_LENGTH_LABEL} );

my $zone;

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{basic}, q{nic.tf} );
ok( $res{B02_AUTH_RESPONSE_SOA},        q{B02_AUTH_RESPONSE_SOA} );
ok( $res{HAS_NAMESERVER_NO_WWW_A_TEST}, q{HAS_NAMESERVER_NO_WWW_A_TEST} );

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{basic}, q{birgerjarlhotel.se} );
ok( $res{A_QUERY_NO_RESPONSES}, q{A_QUERY_NO_RESPONSES} );

$zone = Zonemaster::Engine->zone( q{exampledomain.fake} );
zone_gives('basic02', $zone, [qw{B02_NO_DELEGATION}] );

$zone = Zonemaster::Engine->zone( q{afnic.fr} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

Zonemaster::Engine::Profile->effective->set( q{no_network}, 0 );
Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 0 );
Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 0 );
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

    # basic02
    ok( $res{B02_NO_WORKING_NS},    q{B02_NO_WORKING_NS} );
    ok( $tag{B02_NS_BROKEN},        q{B02_NS_BROKEN} );
    ok( $tag{B02_NS_NOT_AUTH},      q{B02_NS_NOT_AUTH} );
    ok( $tag{B02_NS_NO_IP_ADDR},    q{B02_NS_NO_IP_ADDR} );
    ok( $tag{B02_NS_NO_RESPONSE},   q{B02_NS_NO_RESPONSE} );
    ok( $tag{B02_UNEXPECTED_RCODE}, q{B02_UNEXPECTED_RCODE} );
}

done_testing;

