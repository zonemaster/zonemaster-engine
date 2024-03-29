use Test::More;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::DNSSEC} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $datafile = q{t/Test-dnssec05-A.data};

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine->profile->set( q{no_network}, 1 );
}

Zonemaster::Engine->add_fake_delegation(
    'a.dnssec05.exempelvis.se' => {
        'drip.ip.se' => ['192.0.2.1'],
        'drop.ip.se' => ['192.0.2.2'],
    },
    fill_in_empty_oob_glue => 0,
);

my $zone = Zonemaster::Engine->zone( q{a.dnssec05.exempelvis.se} );

my %res = map { $_->tag => $_ } Zonemaster::Engine::Test::DNSSEC->dnssec05( $zone );

ok( $res{NO_RESPONSE},              q{should emit NO_RESPONSE} );
ok( !$res{NO_RESPONSE_DNSKEY},      q{should not emit NO_RESPONSE_DNSKEY} );
ok( !$res{ALGORITHM_DEPRECATED},    q{should not emit ALGORITHM_DEPRECATED} );
ok( !$res{ALGORITHM_RESERVED},      q{should not emit ALGORITHM_RESERVED} );
ok( !$res{ALGORITHM_UNASSIGNED},    q{should not emit ALGORITHM_UNASSIGNED} );
ok( !$res{ALGORITHM_PRIVATE},       q{should not emit ALGORITHM_PRIVATE} );
ok( !$res{ALGORITHM_NOT_ZONE_SIGN}, q{should not emit ALGORITHM_NOT_ZONE_SIGN} );
ok( !$res{ALGORITHM_OK},            q{should not emit ALGORITHM_OK} );

ok( !$res{ALGORITHM_NOT_RECOMMENDED}, q{should not emit ALGORITHM_NOT_RECOMMENDED} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
