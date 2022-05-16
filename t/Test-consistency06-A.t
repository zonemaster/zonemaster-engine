use Test::More;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Consistency} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $datafile = q{t/Test-consistency06-A.data};

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine->profile->set( q{no_network}, 1 );
}

Zonemaster::Engine->add_fake_delegation(
    'a.consistency06.exempelvis.se' => {
        'ns1.a.consistency06.exempelvis.se' => [ '46.21.97.97',    '2a02:750:12:77::97' ],
        'ns2.a.consistency06.exempelvis.se' => [ '194.18.226.122', '2001:2040:2b:1c13::53' ],
    },
    fill_in_empty_oob_glue => 0,
);

my $zone = Zonemaster::Engine->zone( q{a.consistency06.exempelvis.se} );

my %res = map { $_->tag => $_ } Zonemaster::Engine::Test::Consistency->consistency06( $zone );

ok( !$res{NO_RESPONSE},           q{should not emit NO_RESPONSE} );
ok( !$res{NO_RESPONSE_SOA_QUERY}, q{should not emit NO_RESPONSE_SOA_QUERY} );
ok( $res{ONE_SOA_MNAME},          q{should emit ONE_SOA_MNAME} );
ok( !$res{MULTIPLE_SOA_MNAMES},   q{should not emit MULTIPLE_SOA_MNAMES} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
