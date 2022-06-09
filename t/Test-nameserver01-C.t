use Test::More;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Nameserver} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $datafile = q{t/Test-nameserver01-C.data};

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine->profile->set( q{no_network}, 1 );
}

Zonemaster::Engine->add_fake_delegation(
    'c.nameserver01.exempelvis.se' => {
        'ns1.c.nameserver01.exempelvis.se' => [ '46.21.97.97',    '2a02:750:12:77::97' ],
        'ns2.c.nameserver01.exempelvis.se' => [ '194.18.226.122', '2001:2040:2b:1c13::53' ],
    },
    fill_in_empty_oob_glue => 0,
);

my $zone = Zonemaster::Engine->zone( q{c.nameserver01.exempelvis.se} );

my %res = map { $_->tag => $_ } Zonemaster::Engine::Test::Nameserver->nameserver01( $zone );

ok( !$res{NO_RESPONSE},   q{should not emit NO_RESPONSE} );
ok( !$res{IS_A_RECURSOR}, q{should not emit IS_A_RECURSOR} );
ok( $res{NO_RECURSOR},    q{should emit NO_RECURSOR} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
