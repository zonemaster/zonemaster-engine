use Test::More;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Basic} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $datafile = q{t/Test-basic02-B.data};

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

Zonemaster::Engine->add_fake_delegation(
    'zonemaster.net' => {
        'g.root-servers.net' => [ '192.112.36.4', '2001:500:12::d0d' ],
        'a.root-servers.net' => [ '198.41.0.4', '2001:503:ba3e::2:30' ]
    },
    fill_in_empty_oob_glue => 0,
);

my $zone = Zonemaster::Engine->zone( 'zonemaster.net' );

my %res =  map { $_->tag => $_ } Zonemaster::Engine::Test::Basic->basic02( $zone );

ok( $res{B02_NO_WORKING_NS},      q{should emit B02_NO_WORKING_NS} );
ok( $res{B02_NS_NOT_AUTH},        q{should emit B02_NS_NOT_AUTH} );
ok( !$res{B02_AUTH_RESPONSE_SOA}, q{should not emit B02_AUTH_RESPONSE_SOA} );
ok( !$res{B02_NO_DELEGATION},     q{should not emit B02_NO_DELEGATION} );
ok( !$res{B02_NS_BROKEN},         q{should not emit B02_NS_BROKEN} );
ok( !$res{B02_NS_NO_RESPONSE},    q{should not emit B02_NS_NO_RESPONSE} );
ok( !$res{B02_NS_NO_IP_ADDR},     q{should not emit B02_NS_NO_IP_ADDR} );
ok( !$res{B02_UNEXPECTED_RCODE},  q{should not emit B02_UNEXPECTED_RCODE} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;