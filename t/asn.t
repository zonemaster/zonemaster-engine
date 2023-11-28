use Test::More;
use Zonemaster::Engine::Nameserver;

BEGIN { use_ok( 'Zonemaster::Engine::ASNLookup' ) }

my $datafile = 't/asn.data';
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die "Stored data file missing" if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

Zonemaster::Engine::Profile->effective->set(q{asn_db.style}, "cymru" );
Zonemaster::Engine::Profile->effective->set(q{asn_db.sources}, { cymru => [ "asnlookup.zonemaster.net", "asn.cymru.com" ] });

my ( $asn1, $prefix1 ) = Zonemaster::Engine::ASNLookup->get_with_prefix( '8.8.8.8' );
is $asn1->[0], 15169, '8.8.8.8 is in AS15169';
is $prefix1->prefix, '8.8.8.0/24', '8.8.8.8 is in 8.8.8.0/24';

my ( $asn2, $prefix2 ) = Zonemaster::Engine::ASNLookup->get_with_prefix( '91.226.36.46' );
is $asn2->[0], 197564, '91.226.36.46 is in AS197564';
is $prefix2->prefix, '91.226.36.0/23', '91.226.36.46 is in 91.226.36.0/24';

my @asn3 = Zonemaster::Engine::ASNLookup->get( '2001:503:ba3e::2:30' );
is( scalar( @asn3 ), 1, 'Only one result' );
ok $asn3[0] >= 390000, '2001:503:ba3e::2:30 is in AS' . $asn3[0];

my ( $asn4, $prefix4 ) = Zonemaster::Engine::ASNLookup->get_with_prefix( '192.168.0.1' );
ok( scalar @{$asn4} == 0, '192.168.0.1 (RFC1918 address) is in no AS' );

Zonemaster::Engine::Profile->effective->set(q{asn_db.sources}, { cymru => [ "asnlookup.dufberg.se" ] });

my ( $asn5, $prefix5 ) = Zonemaster::Engine::ASNLookup->get_with_prefix( '3.124.111.178' );
is $asn5->[0], 16509, '3.124.111.178 is in AS16509';
is $prefix5->prefix, '3.124.0.0/14', '3.124.111.178 is in 3.124.0.0/14';

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
