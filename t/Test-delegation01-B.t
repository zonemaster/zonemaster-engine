use Test::More;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Delegation} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $datafile = q{t/Test-delegation01-B.data};

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine->config->no_network( 1 );
}

Zonemaster::Engine->add_fake_delegation(
    'b.delegation01.exempelvis.se' => {
        'ns1.b.delegation01.exempelvis.se' => [ '2a02:750:12:77::97', '46.21.97.97' ]
    }
);

my $zone = Zonemaster::Engine->zone( 'b.delegation01.exempelvis.se' );
my %res = map { $_->tag => $_ } Zonemaster::Engine::Test::Delegation->delegation01( $zone );
ok( $res{NOT_ENOUGH_NS_DEL}, q{should emit NOT_ENOUGH_NS_DEL} );
ok( !$res{ENOUGH_NS_DEL},    q{should not emit ENOUGH_NS_DEL} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
