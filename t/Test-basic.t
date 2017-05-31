use Test::More;

BEGIN {
    use_ok( q{Zonemaster} );
    use_ok( q{Zonemaster::Engine::Nameserver} );
    use_ok( q{Zonemaster::Engine::Test::Basic} );
    use_ok( q{Zonemaster::Engine::Util} );
}

sub name_gives {
    my ( $test, $name, $gives ) = @_;

    my @res = Zonemaster->test_method( q{Basic}, $test, $name );
foreach my $t ( @res ) { print $t->tag, "\n"; }
    ok( ( grep { $_->tag eq $gives } @res ), "$name gives $gives" );
}

sub name_gives_not {
    my ( $test, $name, $gives ) = @_;

    my @res = Zonemaster->test_method( q{Basic}, $test, $name );
    ok( !( grep { $_->tag eq $gives } @res ), "$name does not give $gives" );
}

sub zone_gives {
    my ( $test, $zone, $gives ) = @_;

    my @res = Zonemaster->test_method( q{Basic}, $test, $zone );
    foreach my $item (@res) {
        print $item->tag, "\n";
    }
    ok( ( grep { $_->tag eq $gives } @res ), $zone->name->string . " gives $gives" );
}

sub zone_gives_not {
    my ( $test, $zone, $gives ) = @_;

    my @res = Zonemaster->test_method( q{Basic}, $test, $zone );
    ok( !( grep { $_->tag eq $gives } @res ), $zone->name->string . " does not give $gives" );
}

my $datafile = q{t/Test-basic.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster->config->no_network( 1 );
}

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
%res = map { $_->tag => 1 } Zonemaster->test_module( q{basic}, $ns_too_long );
ok( $res{DOMAIN_NAME_TOO_LONG}, q{DOMAIN_NAME_TOO_LONG} );
name_gives_not( q{basic00}, $ns_ok,      q{DOMAIN_NAME_TOO_LONG} );
%res = map { $_->tag => 1 } Zonemaster->test_module( q{basic}, $ns_ok );
ok( !$res{DOMAIN_NAME_TOO_LONG}, q{Not DOMAIN_NAME_TOO_LONG} );
name_gives_not( q{basic00}, $ns_ok_long, q{DOMAIN_NAME_TOO_LONG} );
%res = map { $_->tag => 1 } Zonemaster->test_module( q{basic}, $ns_ok_long );
ok( !$res{DOMAIN_NAME_TOO_LONG}, q{Not DOMAIN_NAME_TOO_LONG} );

my $ns_label_too_long = Zonemaster::Engine::DNSName->new( q{ns1234567890123456789012345678901234567890123456789012345678901234567890.nic.fr} );
name_gives( q{basic00}, $ns_label_too_long, q{DOMAIN_NAME_LABEL_TOO_LONG} );
%res = map { $_->tag => 1 } Zonemaster->test_module( q{basic}, $ns_label_too_long );
ok( $res{DOMAIN_NAME_LABEL_TOO_LONG}, q{DOMAIN_NAME_LABEL_TOO_LONG} );
name_gives_not( q{basic00}, $ns_ok, q{DOMAIN_NAME_LABEL_TOO_LONG} );
%res = map { $_->tag => 1 } Zonemaster->test_module( q{basic}, $ns_ok );
ok( !$res{DOMAIN_NAME_LABEL_TOO_LONG}, q{Not DOMAIN_NAME_LABEL_TOO_LONG} );

my $ns_null_label = Zonemaster::Engine::DNSName->new( q{dom12134..fr} );
name_gives( q{basic00}, $ns_null_label, q{DOMAIN_NAME_ZERO_LENGTH_LABEL} );
%res = map { $_->tag => 1 } Zonemaster->test_module( q{basic}, $ns_null_label );
ok( $res{DOMAIN_NAME_ZERO_LENGTH_LABEL}, q{DOMAIN_NAME_ZERO_LENGTH_LABEL} );

my $zone;

SKIP: {
    skip "Zone does not longer have tested problem", 2;
    zone_gives( q{basic02}, $zone, q{NS_FAILED} );
    zone_gives( q{basic02}, $zone, q{NS_NO_RESPONSE} );
}

%res = map { $_->tag => 1 } Zonemaster->test_module( q{basic}, q{aff.tf} );
ok( $res{HAS_NAMESERVERS},              q{HAS_NAMESERVERS} );
ok( $res{HAS_NAMESERVER_NO_WWW_A_TEST}, q{HAS_NAMESERVER_NO_WWW_A_TEST} );

SKIP: {
    skip "Zone does not actually have tested problem", 3;
    %res = map { $_->tag => 1 } Zonemaster->test_module( q{basic}, q{melbourneit.com.au} );
    ok( $res{NO_GLUE_PREVENTS_NAMESERVER_TESTS}, q{NO_GLUE_PREVENTS_NAMESERVER_TESTS} );
    %res = map { $_->tag => 1 } Zonemaster->test_module( q{basic}, q{maxan.se} );
    ok( $res{HAS_A_RECORDS}, q{HAS_A_RECORDS} );
    $zone = Zonemaster->zone( q{unknown-tld.unkunk} );
    zone_gives( q{basic01}, $zone, q{NO_DOMAIN} );
}

%res = map { $_->tag => 1 } Zonemaster->test_module( q{basic}, q{birgerjarlhotel.se} );
ok( $res{A_QUERY_NO_RESPONSES}, q{A_QUERY_NO_RESPONSES} );

$zone = Zonemaster->zone( q{afnic.fr} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

Zonemaster->config->no_network( 0 );
Zonemaster->config->ipv4_ok( 0 );
Zonemaster->config->ipv6_ok( 0 );
zone_gives( q{basic02}, $zone, q{NO_NETWORK} );
zone_gives_not( q{basic02}, $zone, q{IPV4_ENABLED} );
zone_gives_not( q{basic02}, $zone, q{IPV6_ENABLED} );
zone_gives_not( q{basic02}, $zone, q{IPV4_DISABLED} );
zone_gives_not( q{basic02}, $zone, q{IPV6_DISABLED} );
zone_gives( q{basic03}, $zone, q{NO_NETWORK} );
zone_gives_not( q{basic03}, $zone, q{IPV4_ENABLED} );
zone_gives_not( q{basic03}, $zone, q{IPV6_ENABLED} );
zone_gives_not( q{basic03}, $zone, q{IPV4_DISABLED} );
zone_gives_not( q{basic03}, $zone, q{IPV6_DISABLED} );

#Zonemaster->config->ipv4_ok( 1 );
#Zonemaster->config->ipv6_ok( 0 );
#zone_gives( q{basic02}, $zone, q{IPV4_ENABLED} );
#zone_gives( q{basic02}, $zone, q{IPV6_DISABLED} );
#zone_gives_not( q{basic02}, $zone, q{IPV4_DISABLED} );
#zone_gives_not( q{basic02}, $zone, q{IPV6_ENABLED} );
#zone_gives( q{basic03}, $zone, q{IPV4_ENABLED} );
#zone_gives( q{basic03}, $zone, q{IPV6_DISABLED} );
#zone_gives_not( q{basic03}, $zone, q{IPV4_DISABLED} );
#zone_gives_not( q{basic03}, $zone, q{IPV6_ENABLED} );
#
#if ( Zonemaster::Engine::Util::supports_ipv6() ) {
#
#    Zonemaster->config->ipv4_ok( 0 );
#    Zonemaster->config->ipv6_ok( 1 );
#    zone_gives_not( q{basic02}, $zone, q{IPV4_ENABLED} );
#    zone_gives_not( q{basic02}, $zone, q{IPV6_DISABLED} );
#    zone_gives( q{basic02}, $zone, q{IPV4_DISABLED} );
#    zone_gives( q{basic02}, $zone, q{IPV6_ENABLED} );
#    zone_gives_not( q{basic03}, $zone, q{IPV4_ENABLED} );
#    zone_gives_not( q{basic03}, $zone, q{IPV6_DISABLED} );
#    zone_gives( q{basic03}, $zone, q{IPV4_DISABLED} );
#    zone_gives( q{basic03}, $zone, q{IPV6_ENABLED} );
#
#    Zonemaster->config->ipv4_ok( 1 );
#    Zonemaster->config->ipv6_ok( 1 );
#    zone_gives( q{basic02}, $zone, q{IPV4_ENABLED} );
#    zone_gives( q{basic02}, $zone, q{IPV6_ENABLED} );
#    zone_gives_not( q{basic02}, $zone, q{IPV4_DISABLED} );
#    zone_gives_not( q{basic02}, $zone, q{IPV6_DISABLED} );
#    zone_gives( q{basic03}, $zone, q{IPV4_ENABLED} );
#    zone_gives( q{basic03}, $zone, q{IPV6_ENABLED} );
#    zone_gives_not( q{basic03}, $zone, q{IPV4_DISABLED} );
#    zone_gives_not( q{basic03}, $zone, q{IPV6_DISABLED} );
#
#}

Zonemaster->config->no_network( 1 );

done_testing;

