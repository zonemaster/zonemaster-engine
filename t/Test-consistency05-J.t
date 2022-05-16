use Test::More;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Consistency} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $datafile = q{t/Test-consistency05-J.data};

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine->profile->set( q{no_network}, 1 );
}

Zonemaster::Engine->add_fake_delegation(
    'j.consistency05.exempelvis.se' => {
        'ns1.a.consistency05.exempelvis.se' => [ '46.21.97.97',    '2a02:750:12:77::97' ],
        'ns2.a.consistency05.exempelvis.se' => [ '194.18.226.122', '2001:2040:2b:1c13::53' ],
    },
    fill_in_empty_ib => 0,
);

my $zone = Zonemaster::Engine->zone( q{j.consistency05.exempelvis.se} );

my %res = map { $_->tag => $_ } Zonemaster::Engine::Test::Consistency->consistency05( $zone );

ok( !$res{CHILD_NS_FAILED},                q{should not emit CHILD_NS_FAILED} );
ok( !$res{NO_RESPONSE},                    q{should not emit NO_RESPONSE} );
ok( !$res{CHILD_ZONE_LAME},                q{should not emit CHILD_ZONE_LAME} );
ok( !$res{IN_BAILIWICK_ADDR_MISMATCH},     q{should not emit IN_BAILIWICK_ADDR_MISMATCH} );
ok( !$res{OUT_OF_BAILIWICK_ADDR_MISMATCH}, q{should not emit OUT_OF_BAILIWICK_ADDR_MISMATCH} );
ok( !$res{EXTRA_ADDRESS_CHILD},            q{should not emit EXTRA_ADDRESS_CHILD} );
ok( $res{ADDRESSES_MATCH},                 q{should emit ADDRESSES_MATCH} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
