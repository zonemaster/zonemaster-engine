use Test::More;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Nameserver} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $datafile = q{t/Test-nameserver01-D.data};

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine->profile->set( q{no_network}, 1 );
}

Zonemaster::Engine->add_fake_delegation(
    'd.nameserver01.exempelvis.se' => {
        'resolver1.exempelvis.se' => ['8.8.8.8'],
        'resolver2.exempelvis.se' => ['9.9.9.9'],
    },
    fill_in_empty_oob_glue => 0,
);

my $zone = Zonemaster::Engine->zone( q{d.nameserver01.exempelvis.se} );

my %res = map { $_->tag => $_ } Zonemaster::Engine::Test::Nameserver->nameserver01( $zone );

ok( !$res{NO_RESPONSE},  q{should not emit NO_RESPONSE} );
ok( $res{IS_A_RECURSOR}, q{should emit IS_A_RECURSOR} );
ok( !$res{NO_RECURSOR},  q{should not emit NO_RECURSOR} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
