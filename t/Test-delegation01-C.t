use Test::More;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Delegation} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $datafile = q{t/Test-delegation01-C.data};

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine->profile->set( q{no_network}, 1 );
}

Zonemaster::Engine->add_fake_delegation(
    'c.delegation01.exempelvis.se' => {
        'ns1.c.delegation01.exempelvis.se' => ['2a02:750:12:77::97'],
        'ns2.c.delegation01.exempelvis.se' => ['2001:2040:2b:1c13::53'],
    },
    fill_in_empty_oob_glue => 0,
);

my $zone = Zonemaster::Engine->zone( 'c.delegation01.exempelvis.se' );
my %res = map { $_->tag => $_ } Zonemaster::Engine::Test::Delegation->delegation01( $zone );

ok( $res{NO_IPV4_NS_DEL},          q{should emit NO_IPV4_NS_DEL} );
ok( !$res{NOT_ENOUGH_IPV4_NS_DEL}, q{should not emit NOT_ENOUGH_IPV4_NS_DEL} );
ok( !$res{ENOUGH_IPV4_NS_DEL},     q{should not emit ENOUGH_IPV4_NS_DEL} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
