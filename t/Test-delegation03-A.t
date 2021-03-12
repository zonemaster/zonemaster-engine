use Test::More;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Delegation} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $datafile = q{t/Test-delegation03-A.data};

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine->profile->set( q{no_network}, 1 );
}

Zonemaster::Engine->add_fake_delegation(
    'a.delegation03.exempelvis.se' => {
        'ns1.a.delegation03.exempelvis.se' => [ '46.21.97.97',    '2a02:750:12:77::97' ],
        'ns2.a.delegation03.exempelvis.se' => [ '194.18.226.122', '2001:2040:2b:1c13::53' ],
    }
);

my $zone = Zonemaster::Engine->zone( q{a.delegation03.exempelvis.se} );

my %res = map { $_->tag => $_ } Zonemaster::Engine::Test::Delegation->delegation03( $zone );

ok( $res{REFERRAL_SIZE_OK},         q{should emit REFERRAL_SIZE_OK} );
ok( !$res{REFERRAL_SIZE_TOO_LARGE}, q{should not emit REFERRAL_TOO_LARGE} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
