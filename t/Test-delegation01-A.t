use Test::More;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Delegation} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $datafile = q{t/Test-delegation01-A.data};

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine->config->no_network( 1 );
}

Zonemaster::Engine->add_fake_delegation(
    'a.delegation01.exempelvis.se' => {
        'ns2.a.delegation01.exempelvis.se' => [ '2001:9b0:1:1c13::53', '37.123.169.91' ],
        'ns1.a.delegation01.exempelvis.se' => [ '2a02:750:12:77::97',  '46.21.97.97' ]
    },
);

my $zone = Zonemaster::Engine->zone( q{a.delegation01.exempelvis.se} );

my %res = map { $_->tag => $_ } Zonemaster::Engine::Test::Delegation->delegation01( $zone );

ok( $res{ENOUGH_IPV4_NS_CHILD},      q{should emit ENOUGH_IPV4_NS_CHILD} );
ok( $res{ENOUGH_IPV4_NS_DEL},        q{should emit ENOUGH_IPV4_NS_DEL} );
ok( $res{ENOUGH_IPV6_NS_CHILD},      q{should emit ENOUGH_IPV6_NS_CHILD} );
ok( $res{ENOUGH_IPV6_NS_DEL},        q{should emit ENOUGH_IPV6_NS_DEL} );
ok( $res{ENOUGH_NS_CHILD},           q{should emit ENOUGH_NS_CHILD} );
ok( $res{ENOUGH_NS_DEL},             q{should emit ENOUGH_NS_DEL} );
ok( !$res{NO_IPV4_NS_CHILD},         q{should not emit NO_IPV4_NS_CHILD} );
ok( !$res{NO_IPV4_NS_DEL},           q{should not emit NO_IPV4_NS_DEL} );
ok( !$res{NO_IPV6_NS_CHILD},         q{should not emit NO_IPV6_NS_CHILD} );
ok( !$res{NO_IPV6_NS_DEL},           q{should not emit NO_IPV6_NS_DEL} );
ok( !$res{NOT_ENOUGH_IPV4_NS_CHILD}, q{should not emit NOT_ENOUGH_IPV4_NS_CHILD} );
ok( !$res{NOT_ENOUGH_IPV4_NS_DEL},   q{should not emit NOT_ENOUGH_IPV4_NS_DEL} );
ok( !$res{NOT_ENOUGH_IPV6_NS_CHILD}, q{should not emit NOT_ENOUGH_IPV6_NS_CHILD} );
ok( !$res{NOT_ENOUGH_IPV6_NS_DEL},   q{should not emit NOT_ENOUGH_IPV6_NS_DEL} );
ok( !$res{NOT_ENOUGH_NS_CHILD},      q{should not emit NOT_ENOUGH_NS_CHILD} );
ok( !$res{NOT_ENOUGH_NS_DEL},        q{should not emit NOT_ENOUGH_NS_DEL} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
