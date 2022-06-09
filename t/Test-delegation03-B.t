use Test::More;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Delegation} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $datafile = q{t/Test-delegation03-B.data};

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine->profile->set( q{no_network}, 1 );
}

Zonemaster::Engine->add_fake_delegation(
    'b.delegation03.exempelvis.se' => {
        'abcdefgh.abcdefghijklmnopqrstuvwxyz.ns1.b.delegation03.exempelvis.se' => [ '46.21.97.97' ],
        'abcdefgh.abcdefghijklmnopqrstuvwxyz.ns2.b.delegation03.exempelvis.se' => [ '194.18.226.122' ],
        'abcdefgh.abcdefghijklmnopqrstuvwxyz.ns3.b.delegation03.exempelvis.se' => [ '2a02:750:12:77::97' ],
        'abcdefgh.abcdefghijklmnopqrstuvwxyz.ns4.b.delegation03.exempelvis.se' => [ '2001:2040:2b:1c13::53' ],
    },
    fill_in_empty_oob_glue => 0,
);

my $zone = Zonemaster::Engine->zone( q{b.delegation03.exempelvis.se} );

my %res = map { $_->tag => $_ } Zonemaster::Engine::Test::Delegation->delegation03( $zone );

ok( !$res{REFERRAL_SIZE_OK},       q{should not emit REFERRAL_SIZE_OK} );
ok( $res{REFERRAL_SIZE_TOO_LARGE}, q{should emit REFERRAL_TOO_LARGE} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
