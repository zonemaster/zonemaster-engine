use strict;
use warnings;

use Test::More;
use Test::Exception;

BEGIN { use_ok( 'Zonemaster::Engine::Nameserver' ); }
use Zonemaster::Engine;
use Zonemaster::Engine::Util;
use Zonemaster::Engine::Constants qw( :misc );

my $datafile = 't/nameserver.data';
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die "Stored data file missing" if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

my $nsv6 = new_ok( 'Zonemaster::Engine::Nameserver' => [ { name => 'ns.nic.se', address => '2001:67c:124c:100a::45' } ] );
my $nsv4 = new_ok( 'Zonemaster::Engine::Nameserver' => [ { name => 'ns.nic.se', address => '91.226.36.45' } ] );

eval { Zonemaster::Engine::Nameserver->new( { name => 'dummy' } ); };
like( $@, qr/Attribute \(address\) is required/, 'create fails without address.' );

isa_ok( $nsv6->address, 'Net::IP::XS' );
isa_ok( $nsv6->name,    'Zonemaster::Engine::DNSName' );
is( $nsv6->dns->retry, 2 );

my $p1 = $nsv6->query( 'iis.se', 'SOA' );
my $p2 = $nsv6->query( 'iis.se', 'SOA', { dnssec => 1 } );
my $p3 = $nsv6->query( 'iis.se', 'SOA', { dnssec => 1 } );
my $p4 = $nsv4->query( 'iis.se', 'SOA', { dnssec => 1 } );

isa_ok( $p1, 'Zonemaster::Engine::Packet' );
isa_ok( $p2, 'Zonemaster::Engine::Packet' );
my ( $soa ) = grep { $_->type eq 'SOA' } $p1->answer;
is( scalar( $p1->answer ), 1, 'one answer RR present ' );
ok( $soa, 'it is a SOA RR' );
is( lc( $soa->rname ), 'hostmaster.nic.se.', 'RNAME has expected format' );
is( scalar( grep { $_->type eq 'SOA' or $_->type eq 'RRSIG' } $p2->answer ), 2, 'SOA and RRSIG RRs present' );
ok( $p3 eq $p2,          'Same packet object returned' );
ok( $p3 ne $p4,          'Same packet object not returned from other server' );
ok( $p3 ne $p1,          'Same packet object not returned with other flag' );

my $nscopy = Zonemaster::Engine->ns( 'ns.nic.se.', '2001:67c:124c:100a:0000::45' );
ok( $nsv6 eq $nscopy, 'Same nameserver object returned' );
my $nssame = Zonemaster::Engine->ns( 'foo.example.org', '2001:67c:124c:100a:0000::45' );
ok(
    ( $nssame ne $nsv6 and $nssame->cache eq $nsv6->cache ),
    'Different name, same IP are different but has same cache'
);

SKIP: {
    skip '/tmp not writable', 2 unless -w '/tmp';
    my $name = "/tmp/nameserver_test_$$";
    Zonemaster::Engine::Nameserver->save( $name );
    my $count = keys %Zonemaster::Engine::Nameserver::object_cache;
    undef %Zonemaster::Engine::Nameserver::object_cache;
    is( scalar( keys %Zonemaster::Engine::Nameserver::object_cache ), 0, 'Nameserver cache is empty after clear.' );
    Zonemaster::Engine::Nameserver->restore( $name );
    is( scalar( keys %Zonemaster::Engine::Nameserver::object_cache ),
        $count, 'Same number of top-level keys in cache after restore.' );
    unlink $name;
}

my $broken = new_ok( 'Zonemaster::Engine::Nameserver' => [ { name => 'ns.not.existing', address => '192.0.2.17' } ] );
my $p = $broken->query( 'www.iis.se' );
ok( !$p, 'no response from broken server' );

my $googlens = ns( 'ns1.google.com', '216.239.32.10' );
my $save = Zonemaster::Engine::Profile->effective->get( q{no_network} );
Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
delete( $googlens->cache->{'www.google.com'} );
eval { $googlens->query( 'www.google.com', 'TXT' ) };
like( $@,
    qr{External query for www.google.com, TXT attempted to ns1.google.com/216.239.32.10 while running with no_network}
);
Zonemaster::Engine::Profile->effective->set( q{no_network}, $save );

@{ $nsv6->times } = ( qw[2 4 4 4 5 5 7 9] );
is( $nsv6->stddev_time, 2, 'known value check' );
is( $nsv6->average_time, 5 );
is( $nsv6->median_time,  4.5 );
is( $nsv6->max_time,     9 );
is( $nsv6->min_time,     2 );
@{ $nsv6->times } = ( qw[2 4 4 4 5 5 7] );
is( $nsv6->median_time, 4 );

foreach my $ns ( Zonemaster::Engine::Nameserver->all_known_nameservers ) {
    isa_ok( $ns, 'Zonemaster::Engine::Nameserver' );
}

ok( scalar( keys %Zonemaster::Engine::Nameserver::Cache::object_cache ) >= 4 );

Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 0 );
Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 0 );
my $p5 = $nsv6->query( 'iis.se', 'SOA', { dnssec => 1 } );
my $p6 = $nsv4->query( 'iis.se', 'SOA', { dnssec => 1 } );
ok( !defined( $p5 ), 'IPv4 blocked' );
ok( !defined( $p6 ), 'IPv6 blocked' );

Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 1 );
Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 1 );
$p5 = $nsv6->query( 'iis.se', 'SOA', { dnssec => 1 } );
$p6 = $nsv4->query( 'iis.se', 'SOA', { dnssec => 1 } );
ok( defined( $p5 ), 'IPv4 not blocked' );
ok( defined( $p6 ), 'IPv6 not blocked' );

is( $p5->edns_size,  4096, 'EDNS0 size' );
is( $p5->edns_rcode, 0,    'EDNS0 rcode' );

$p5->unique_push( 'additional', Zonemaster::LDNS::RR->new( 'www.iis.se.		26	IN	A	91.226.36.46' ) );
my ( $rr ) = $p5->additional;
isa_ok( $rr, 'Zonemaster::LDNS::RR::A' );

$nsv4->add_fake_ds( 'iis.se' => [ { keytag => 16696, algorithm => 5, type => 1, digest => 'DEADBEEF' } ] );
ok( $nsv4->fake_ds->{'iis.se'}, 'Fake DS data added' );
my $p7 = $nsv4->query( 'iis.se', 'DS', { class => 'IN' } );
isa_ok( $p7, 'Zonemaster::Engine::Packet' );
my ( $dsrr ) = $p7->answer;
isa_ok( $dsrr, 'Zonemaster::LDNS::RR::DS' );
is( $dsrr->keytag,    16696,      'Expected keytag' );
is( $dsrr->hexdigest, 'deadbeef', 'Expected digest data' );

subtest 'dnssec, edns_size and edns_details{do, size} flags behavior for queries' => sub {
    my $ns = new_ok( 'Zonemaster::Engine::Nameserver' => [ { name => 'd.nic.fr', address => '194.0.9.1' } ] );

    my $p = $ns->query( 'fr', 'SOA' );
    if ( $ENV{ZONEMASTER_RECORD} ) {
        ok( !$ns->dns->dnssec, 'dnssec flag is unset' );
        is( $ns->dns->edns_size, 0, 'edns_size flag is unset' );
    }
    else {
        SKIP: {
            skip "no live recording - dnssec and edns_size flags in query can't be checked", 2;
        };
    }
    ok( (!$p->has_edns and !$p->do), 'non-EDNS response received on query with all default parameters' );

    $p = $ns->query( 'fr', 'SOA', { "dnssec" => 0 } );
    if ( $ENV{ZONEMASTER_RECORD} ) {
        ok( !$ns->dns->dnssec, 'dnssec flag is unset' );
        is( $ns->dns->edns_size, 0, 'edns_size flag is unset' );
    }
    else {
        SKIP: {
            skip "no live recording - dnssec and edns_size flags in query can't be checked", 2;
        };
    }
    ok( (!$p->has_edns and !$p->do), 'non-EDNS response received on query with dnssec unset' );

    # Note that the following tests also implicitly test that flags are correctly re-evaluated between
    # each consecutive queries.

    $p = $ns->query( 'a.fr', 'SOA', { "dnssec" => 1 } );
    if ( $ENV{ZONEMASTER_RECORD} ) {
        ok( $ns->dns->dnssec, 'dnssec flag is set' );
        is( $ns->dns->edns_size, $EDNS_UDP_PAYLOAD_DNSSEC_DEFAULT, 'edns_size uses default DNSSEC query value' );
    }
    else {
        SKIP: {
            skip "no live recording - dnssec and edns_size flags in query can't be checked", 2;
        };
    }
    ok( ($p->has_edns and $p->do), 'DNSSEC response received on query with dnssec set' );

    $p = $ns->query( 'b.fr', 'SOA', { "edns_size" => 1000 } );
    if ( $ENV{ZONEMASTER_RECORD} ) {
        ok( !$ns->dns->dnssec, 'dnssec flag is unset' );
        is( $ns->dns->edns_size, 1000, 'edns_size uses given value' );
    }
    else {
        SKIP: {
            skip "no live recording - dnssec and edns_size flags in query can't be checked", 2;
        };
    }
    ok( ($p->has_edns and !$p->do), 'non-DNSSEC EDNS response received on query with edns_size set' );

    $p = $ns->query( 'c.fr', 'SOA', { "dnssec" => 0, "edns_size" => 1001 } );
    if ( $ENV{ZONEMASTER_RECORD} ) {
        ok( !$ns->dns->dnssec, 'dnssec flag is unset' );
        is( $ns->dns->edns_size, 1001, 'edns_size uses given value instead of default for non-DNSSEC EDNS queries' );
    }
    else {
        SKIP: {
            skip "no live recording - dnssec and edns_size flags in query can't be checked", 2;
        };
    }
    ok( ($p->has_edns and !$p->do), 'non-DNSSEC EDNS response received on query with dnssec unset and edns_size set' );

    $p = $ns->query( 'd.fr', 'SOA', { "dnssec" => 1, "edns_size" => 1002 } );
    if ( $ENV{ZONEMASTER_RECORD} ) {
        ok( $ns->dns->dnssec, 'dnssec flag is set' );
        is( $ns->dns->edns_size, 1002, 'edns_size uses given value instead of default for DNSSEC queries' );
    }
    else {
        SKIP: {
            skip "no live recording - dnssec and edns_size flags in query can't be checked", 2;
        };
    }
    ok( ($p->has_edns and $p->do), 'DNSSEC response received on query with dnssec set and edns_size set' );

    $p = $ns->query( 'e.fr', 'SOA', { "edns_details" => {} } );
    if ( $ENV{ZONEMASTER_RECORD} ) {
        ok( !$ns->dns->dnssec, 'dnssec flag is unset' );
        is( $ns->dns->edns_size, $EDNS_UDP_PAYLOAD_DEFAULT, 'edns_size uses default EDNS query value for non-DNSSEC EDNS queries' );
    }
    else {
        SKIP: {
            skip "no live recording - dnssec and edns_size flags in query can't be checked", 2;
        };
    }
    ok( ($p->has_edns and !$p->do), 'non-DNSSEC EDNS response received on query with edns_details set' );

    $p = $ns->query( 'f.fr', 'SOA', { "edns_details" => { "do" => 1 } } );
    if ( $ENV{ZONEMASTER_RECORD} ) {
        ok( $ns->dns->dnssec, 'dnssec flag is also set via edns_details{do}' );
        is( $ns->dns->edns_size, $EDNS_UDP_PAYLOAD_DNSSEC_DEFAULT, 'edns_size also uses default DNSSEC query value when set with edns_details{do}' );
    }
    else {
        SKIP: {
            skip "no live recording - dnssec and edns_size flags in query can't be checked", 2;
        };
    }
    ok( ($p->has_edns and $p->do), 'DNSSEC response received on query with edns_details{do} set' );

    $p = $ns->query( 'g.fr', 'SOA', { "edns_details" => { "size" => 900 } } );
    if ( $ENV{ZONEMASTER_RECORD} ) {
        ok( !$ns->dns->dnssec, 'dnssec flag is unset' );
        is( $ns->dns->edns_size, 900, 'edns_size also uses given value when set with edns_details{size}' );
    }
    else {
        SKIP: {
            skip "no live recording - dnssec and edns_size flags in query can't be checked", 2;
        };
    }
    ok( ($p->has_edns and !$p->do), 'non-DNSSEC EDNS response received on query with edns_details{size} set' );

    $p = $ns->query( 'h.fr', 'SOA', { "edns_details" => { "size" => 0 } } );
    if ( $ENV{ZONEMASTER_RECORD} ) {
        ok( !$ns->dns->dnssec, 'dnssec flag is unset' );
        is( $ns->dns->edns_size, 0, 'edns_size also uses given value when set with edns_details{size}' );
    }
    else {
        SKIP: {
            skip "no live recording - dnssec and edns_size flags in query can't be checked", 2;
        };
    }
    ok( ($p->has_edns and !$p->do), 'non-DNSSEC EDNS response received on query even with edns_details{size} set to 0' );

    $p = $ns->query( 'i.fr', 'SOA', { "dnssec" => 1, "edns_details" => { "do" => 0 } } );
    if ( $ENV{ZONEMASTER_RECORD} ) {
        ok( !$ns->dns->dnssec, 'edns_details{do} takes precedence over dnssec for (un)setting the dnssec flag' );
        is( $ns->dns->edns_size, $EDNS_UDP_PAYLOAD_DEFAULT, 'edns_size uses default EDNS query value when dnssec flag is unset by edns_details{do}' );
    }
    else {
        SKIP: {
            skip "no live recording - dnssec and edns_size flags in query can't be checked", 2;
        };
    }
    ok( ($p->has_edns and !$p->do), 'non-DNSSEC EDNS response received on query with dnssec unset by edns_details{do}' );

    $p = $ns->query( 'j.fr', 'SOA', { "edns_size" => 1003, "edns_details" => { "size" => 901 } } );
    if ( $ENV{ZONEMASTER_RECORD} ) {
        ok( !$ns->dns->dnssec, 'dnssec flag is unset' );
        is( $ns->dns->edns_size, 901, 'edns_details{size} takes precedence over edns_size for setting the edns_size flag' );
    }
    else {
        SKIP: {
            skip "no live recording - dnssec and edns_size flags in query can't be checked", 2;
        };
    }
    ok( ($p->has_edns and !$p->do), 'non-DNSSEC EDNS response received on query with edns_size and edns_details{size} set' );

    $p = $ns->query( 'k.fr', 'SOA', { "dnssec" => 1, "edns_size" => 1004, "edns_details" => { "size" => 0 } } );
    if ( $ENV{ZONEMASTER_RECORD} ) {
        ok( $ns->dns->dnssec, 'dnssec flag is set' );
        is( $ns->dns->edns_size, 0, 'edns_size is unset' );
    }
    else {
        SKIP: {
            skip "no live recording - dnssec and edns_size flags in query can't be checked", 2;
        };
    }
    ok( ($p->has_edns and $p->do), 'DNSSEC response received on query with dnssec set and even with edns_details{size} set to 0' );

    $p = $ns->query( 'l.fr', 'SOA', { "dnssec" => 0, "edns_size" => 1005, "edns_details" => { "do" => 1, "size" => 0 } } );
    if ( $ENV{ZONEMASTER_RECORD} ) {
        ok( $ns->dns->dnssec, 'dnssec flag is set' );
        is( $ns->dns->edns_size, 0, 'edns_size is unset' );
    }
    else {
        SKIP: {
            skip "no live recording - dnssec and edns_size flags in query can't be checked", 2;
        };
    }
    ok( ($p->has_edns and $p->do), 'DNSSEC response received on query with dnssec set by edns_details{do} and even with edns_details{size} set to 0' );

    dies_ok { $p = $ns->query( 'fr', 'SOA', { "edns_size" => 65536 } ); }                    "dies when edns_size exceeds 65535";
    dies_ok { $p = $ns->query( 'fr', 'SOA', { "edns_details" => { "size" => 65536 } } ); }   "dies when edns_size (set with edns_details->size) exceeds 65535";
    dies_ok { $p = $ns->query( 'fr', 'SOA', { "edns_size" => -1 } ); }                       "dies when edns_size is lower than 0";
    dies_ok { $p = $ns->query( 'fr', 'SOA', { "edns_details" => { "size" => -1 } } ); }      "dies when edns_size (set with edns_details->size) is lower than 0";
};

Zonemaster::Engine::Profile->effective->set( q{resolver.source4}, q{127.0.0.1} );
my $ns_test = new_ok( 'Zonemaster::Engine::Nameserver' => [ { name => 'ns.nic.se', address => '212.247.7.228' } ] );
is($ns_test->dns->source, '127.0.0.1', 'Source IPv4 address set.');

Zonemaster::Engine::Profile->effective->set( q{resolver.source6}, q{::1} );
$ns_test = new_ok( 'Zonemaster::Engine::Nameserver' => [ { name => 'ns.nic.se', address => '2001:67c:124c:100a::45' } ] );
is($ns_test->dns->source, '::1', 'Source IPv6 address set.');

# We have to make a query to test the following message tags, so no_network must be false.
Zonemaster::Engine::Profile->effective->set( q{no_network}, 0 );

# 192.0.2.17 is part of TEST-NET-1 IP address range (see RFC6890) and reserved
# for documentation.
my $fail_ns = Zonemaster::Engine::Nameserver->new( { name => 'fail', address => '192.0.2.17' } );
my $fail_p = $fail_ns->query( 'example.org', 'SOA', {} );
is( $fail_p, undef, 'No return from broken server' );
my ( $e ) = grep { $_->tag eq 'LOOKUP_ERROR' } @{ Zonemaster::Engine->logger->entries };
isa_ok( $e, 'Zonemaster::Engine::Logger::Entry' );

( $e ) = grep { $_->tag eq 'BLACKLISTING' } @{ Zonemaster::Engine->logger->entries };
is( %{$e->args}{proto}, 'UDP', 'Name server is blacklisted for UDP on non-EDNS SOA UDP query' );

Zonemaster::Engine->logger->clear_history();

my $fail_p_tcp = $fail_ns->query( 'example.org', 'SOA', { usevc => 1 } );
( $e ) = grep { $_->tag eq 'BLACKLISTING' } @{ Zonemaster::Engine->logger->entries };
is( %{$e->args}{proto}, 'TCP', 'Name server is blacklisted for TCP on non-EDNS SOA TCP query' );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}
done_testing;
