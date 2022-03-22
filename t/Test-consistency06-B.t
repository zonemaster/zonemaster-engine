use Test::More;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Consistency} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $datafile = q{t/Test-consistency06-B.data};

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine->profile->set( q{no_network}, 1 );
}

Zonemaster::Engine->add_fake_delegation_raw(
    'b.consistency06.exempelvis.se' => {
        'drip.ip.se' => ['192.0.2.1'],
        'drop.ip.se' => ['192.0.2.2'],
    }
);

my $zone = Zonemaster::Engine->zone( q{b.consistency06.exempelvis.se} );

my %res = map { $_->tag => $_ } Zonemaster::Engine::Test::Consistency->consistency06( $zone );

ok( $res{NO_RESPONSE},            q{should emit NO_RESPONSE} );
ok( !$res{NO_RESPONSE_SOA_QUERY}, q{should not emit NO_RESPONSE_SOA_QUERY} );
ok( !$res{ONE_SOA_MNAME},         q{should not emit ONE_SOA_MNAME} );
ok( !$res{MULTIPLE_SOA_MNAMES},   q{should not emit MULTIPLE_SOA_MNAMES} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
