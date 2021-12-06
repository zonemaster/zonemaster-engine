use Test::More;

use strict;
use 5.14.2;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Nameserver} );
}

my $datafile = 't/zone.data';
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die "Stored data file missing" if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

BEGIN { use_ok( 'Zonemaster::Engine::Zone' ) }

my $zone = Zonemaster::Engine->zone( 'iis.se' );

isa_ok( $zone->parent, 'Zonemaster::Engine::Zone' );
is( $zone->parent->name, 'se' );

my $root = Zonemaster::Engine->zone( '.' );
is( $root->parent, $root );

isa_ok( $zone->glue_names, 'ARRAY' );
is_deeply( $zone->glue_names, [qw(i.ns.se ns.nic.se ns3.nic.se)] );

isa_ok( $zone->glue, 'ARRAY' );
ok( @{ $zone->glue } > 0, 'glue list not empty' );
isa_ok( $_, 'Zonemaster::Engine::Nameserver' ) for @{ $zone->glue };

isa_ok( $zone->ns_names, 'ARRAY' );
is_deeply( $zone->ns_names, [qw(i.ns.se ns.nic.se ns3.nic.se)] );
isa_ok( $zone->ns, 'ARRAY' );
ok( @{ $zone->ns } > 0, 'NS list not empty' );
isa_ok( $_, 'Zonemaster::Engine::Nameserver' ) for @{ $zone->ns };

isa_ok( $zone->glue_addresses, 'ARRAY' );
isa_ok( $_, 'Zonemaster::LDNS::RR' ) for @{ $zone->glue_addresses };

my $p = $zone->query_one( 'www.iis.se', 'A' );
isa_ok( $p, 'Zonemaster::Engine::Packet' );
my @rrs = $p->get_records( 'a', 'answer' );
is( scalar( @rrs ), 1, 'one answer A RR' );
is( $rrs[0]->address, '91.226.37.214', 'expected address' );
Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 0 );
Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 0 );
Zonemaster::Engine->logger->clear_history();
$p = $zone->query_one( 'www.iis.se', 'A' );
ok( ( grep { $_->tag eq 'SKIP_IPV6_DISABLED' } @{Zonemaster::Engine->logger->entries} ), "query_one: IPv6 disabled" );
ok( ( grep { $_->tag eq 'SKIP_IPV4_DISABLED' } @{Zonemaster::Engine->logger->entries} ), "query_one: IPv4 disabled" );
$p = $zone->query_auth( 'www.iis.se', 'A' );
ok( ( grep { $_->tag eq 'SKIP_IPV6_DISABLED' } @{Zonemaster::Engine->logger->entries} ), "query_auth: IPv6 disabled" );
ok( ( grep { $_->tag eq 'SKIP_IPV4_DISABLED' } @{Zonemaster::Engine->logger->entries} ), "query_auth: IPv4 disabled" );
$p = $zone->query_persistent( 'www.iis.se', 'A' );
ok( ( grep { $_->tag eq 'SKIP_IPV6_DISABLED' } @{Zonemaster::Engine->logger->entries} ), "query_persistent: IPv6 disabled" );
ok( ( grep { $_->tag eq 'SKIP_IPV4_DISABLED' } @{Zonemaster::Engine->logger->entries} ), "query_persistent: IPv4 disabled" );
Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 0 );
Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 1 );
Zonemaster::Engine->logger->clear_history();
$p = $zone->query_one( 'www.iis.se', 'A' );
ok( !( grep { $_->tag eq 'SKIP_IPV6_DISABLED' } @{Zonemaster::Engine->logger->entries} ), "query_one: IPv6 not disabled" );
$p = $zone->query_auth( 'www.iis.se', 'A' );
ok( !( grep { $_->tag eq 'SKIP_IPV6_DISABLED' } @{Zonemaster::Engine->logger->entries} ), "query_auth: IPv6 not disabled" );
$p = $zone->query_persistent( 'www.iis.se', 'A' );
ok( !( grep { $_->tag eq 'SKIP_IPV6_DISABLED' } @{Zonemaster::Engine->logger->entries} ), "query_persistent: IPv6 not disabled" );
Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 1 );
Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 0 );
Zonemaster::Engine->logger->clear_history();
$p = $zone->query_one( 'www.iis.se', 'A' );
ok( !( grep { $_->tag eq 'SKIP_IPV4_DISABLED' } @{Zonemaster::Engine->logger->entries} ), "query_one: IPv4 not disabled" );
$p = $zone->query_auth( 'www.iis.se', 'A' );
ok( !( grep { $_->tag eq 'SKIP_IPV4_DISABLED' } @{Zonemaster::Engine->logger->entries} ), "query_auth: IPv4 not disabled" );
$p = $zone->query_persistent( 'www.iis.se', 'A' );
ok( !( grep { $_->tag eq 'SKIP_IPV4_DISABLED' } @{Zonemaster::Engine->logger->entries} ), "query_persistent: IPv4 not disabled" );
Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 1 );
Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 1 );
Zonemaster::Engine->logger->clear_history();
$p = $zone->query_one( 'www.iis.se', 'A' );
ok( !( grep { $_->tag eq 'SKIP_IPV6_DISABLED' } @{Zonemaster::Engine->logger->entries} ), "query_one: IPv6 not disabled" );
ok( !( grep { $_->tag eq 'SKIP_IPV4_DISABLED' } @{Zonemaster::Engine->logger->entries} ), "query_one: IPv4 not disabled" );
$p = $zone->query_auth( 'www.iis.se', 'A' );
ok( !( grep { $_->tag eq 'SKIP_IPV6_DISABLED' } @{Zonemaster::Engine->logger->entries} ), "query_auth: IPv6 not disabled" );
ok( !( grep { $_->tag eq 'SKIP_IPV4_DISABLED' } @{Zonemaster::Engine->logger->entries} ), "query_auth: IPv4 not disabled" );
$p = $zone->query_persistent( 'www.iis.se', 'A' );
ok( !( grep { $_->tag eq 'SKIP_IPV6_DISABLED' } @{Zonemaster::Engine->logger->entries} ), "query_persistent: IPv6 not disabled" );
ok( !( grep { $_->tag eq 'SKIP_IPV4_DISABLED' } @{Zonemaster::Engine->logger->entries} ), "query_persistent: IPv4 not disabled" );

$p = $zone->query_persistent( 'www.iis.se', 'A' );
isa_ok( $p, 'Zonemaster::Engine::Packet' );
@rrs = $p->get_records( 'a', 'answer' );
is( scalar( @rrs ), 1, 'one answer A RR' );
is( $rrs[0]->address, '91.226.37.214', 'expected address' );

$p = $zone->query_auth( 'www.iis.se', 'A' );
isa_ok( $p, 'Zonemaster::Engine::Packet' );
@rrs = $p->get_records( 'a', 'answer' );
is( scalar( @rrs ), 1, 'one answer A RR' );
is( $rrs[0]->address, '91.226.37.214', 'expected address' );

my $ary = $zone->query_all( 'www.iis.se', 'A' );
isa_ok( $ary, 'ARRAY' );
foreach my $p ( @$ary ) {
    isa_ok( $p, 'Zonemaster::Engine::Packet' );
    my @rrs = $p->get_records( 'a', 'answer' );
    is( scalar( @rrs ), 1, 'one answer A RR' );
    is( $rrs[0]->address, '91.226.37.214', 'expected address' );
}

$ary = $zone->query_all( 'www.iis.se', 'A', { dnssec => 1 } );
isa_ok( $ary, 'ARRAY' );
foreach my $p ( @$ary ) {
    isa_ok( $p, 'Zonemaster::Engine::Packet' );
    my @a_rrs = $p->get_records( 'a', 'answer' );
    is( scalar( @a_rrs ), 1, 'one answer A RR' );
    my @sigs = $p->get_records( 'RRSIG', 'ANSWER' );
    is( scalar( @sigs ), 1, 'one signature for A RR' );
}

ok( $zone->is_in_zone( 'www.iis.se', 'www.iis.se is in zone iis.se' ) );
ok( not $zone->is_in_zone( 'www.google.se', 'www.google.se is not in zone iis.se' ) );

my $net = Zonemaster::Engine->zone( 'net' );
ok( not( $net->is_in_zone( 'k.gtld-servers.net.' ) ), 'k.gtld-servers.net is not in zone' );
ok( Zonemaster::Engine->zone( 'gtld-servers.net' )->is_in_zone( 'k.gtld-servers.net.' ),
    'k.gtld-servers.net is in zone' );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
