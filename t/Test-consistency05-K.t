use Test::More;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Consistency} );
}

my $datafile = q{t/Test-consistency05-K.data};

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine->profile->set( q{no_network}, 1 );
}

Zonemaster::Engine->profile->set( q{net.ipv6}, 0 );
Zonemaster::Engine->add_fake_delegation(
    'fi' => {
        'a.fi' => [ '193.166.4.1', '2001:708:10:53::53' ],
        'b.fi' => [ '194.146.106.26', '2001:67c:1010:6::53' ],
        'c.fi' => [ '194.0.11.104', '2001:678:e:104::53' ],
        'd.fi' => [ '77.72.229.253', '2a01:3f0:0:302::53' ],
        'e.fi' => [ '194.0.1.14', '2001:678:4::e' ],
        'f.fi' => [ '87.239.127.198', '2a00:13f0:0:3::aaaa' ],
        'g.fi' => [ '204.61.216.98', '1.1.1.1', '2001:500:14:6098:ad::1' ],
        'h.fi' => [ '87.239.120.11', '2001:678:a0::aaaa' ],
        'i.fi' => [ '194.0.25.30', '2001:678:20::30' ],
    },
    fill_in_empty_oob_glue => 0,
);

my $zone = Zonemaster::Engine->zone( 'fi' );
my %res = map { $_->tag => $_ } Zonemaster::Engine::Test::Consistency->consistency05( $zone );
ok( !$res{ADDRESSES_MATCH},           q{should not emit ADDRESSES_MATCH} );
ok( $res{IN_BAILIWICK_ADDR_MISMATCH}, q{should emit IN_BAILIWICK_ADDR_MISMATCH} );
ok( !$res{EXTRA_ADDRESS_CHILD},       q{should not emit EXTRA_ADDRESS_CHILD} );
ok( !$res{NO_RESPONSE},               q{should not emit NO_RESPONSE} );
ok( !$res{LAME_DELEGATION},           q{should not emit LAME_DELEGATION} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
