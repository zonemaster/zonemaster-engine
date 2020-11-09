use Test::More;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Consistency} );
}

my $datafile = q{t/Test-consistency05-L.data};

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine->profile->set( q{no_network}, 1 );
}

Zonemaster::Engine->profile->set( q{net.ipv6}, 0 );
Zonemaster::Engine->add_fake_delegation(
    'no' => {
        'a.nic.no' => [ '46.21.96.58',  '2a02:750:12::53' ],
        'b.nic.no' => [ '212.85.74.18', '2001:470:28:5a0::53' ],
    },
);

my $zone = Zonemaster::Engine->zone( 'no' );
my %res = map { $_->tag => $_ } Zonemaster::Engine::Test::Consistency->consistency05( $zone );
ok( !$res{ADDRESSES_MATCH},           q{should not emit ADDRESSES_MATCH} );
ok( $res{IN_BAILIWICK_ADDR_MISMATCH}, q{should emit IN_BAILIWICK_ADDR_MISMATCH} );
ok( $res{EXTRA_ADDRESS_CHILD},        q{should emit EXTRA_ADDRESS_CHILD} );
ok( $res{NO_RESPONSE},                q{should emit NO_RESPONSE} );
ok( !$res{LAME_DELEGATION},           q{should not emit LAME_DELEGATION} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
