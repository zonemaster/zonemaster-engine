use Test::More;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Zone} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $datafile = q{t/Test-zone01-B.data};

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

Zonemaster::Engine->add_fake_delegation(
    'xa' => {
        'ibdns01.labs.prive.nic.fr' => ['10.1.72.23'],
        'ibdns01-24.labs.prive.nic.fr' => ['10.1.72.24'],
    },
    fill_in_empty_oob_glue => 0,
);

my $zone = Zonemaster::Engine->zone( q{multi-mname-not-master.zone01.xa} );

my %res = map { $_->tag => $_ } Zonemaster::Engine::Test::Zone->zone01( $zone );

ok( !$res{Z01_MNAME_HAS_LOCALHOST_ADDR},   q{should not emit Z01_MNAME_HAS_LOCALHOST_ADDR} );
ok( !$res{Z01_MNAME_IS_DOT},               q{should not emit Z01_MNAME_IS_DOT} );
ok( !$res{Z01_MNAME_IS_LOCALHOST},         q{should not emit Z01_MNAME_IS_LOCALHOST} );
ok( $res{Z01_MNAME_IS_MASTER},             q{should emit Z01_MNAME_IS_MASTER} );
ok( !$res{Z01_MNAME_MISSING_SOA_RECORD},   q{should not emit Z01_MNAME_MISSING_SOA_RECORD} );
ok( !$res{Z01_MNAME_NO_RESPONSE},          q{should not emit Z01_MNAME_NO_RESPONSE} );
ok( !$res{Z01_MNAME_NOT_AUTHORITATIVE},    q{should not emit Z01_MNAME_NOT_AUTHORITATIVE} );
ok( !$res{Z01_MNAME_NOT_IN_NS_LIST},       q{should not emit Z01_MNAME_NOT_IN_NS_LIST} );
ok( $res{Z01_MNAME_NOT_MASTER},            q{should emit Z01_MNAME_NOT_MASTER} );
ok( !$res{Z01_MNAME_NOT_RESOLVE},          q{should not emit Z01_MNAME_NOT_RESOLVE} );
ok( !$res{Z01_MNAME_UNEXPECTED_RCODE},     q{should not emit Z01_MNAME_UNEXPECTED_RCODE} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;