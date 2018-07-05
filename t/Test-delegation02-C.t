use strict;
use Test::More;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Delegation} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $datafile = q{t/Test-delegation02-C.data};

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine->config->no_network( 1 );
}

Zonemaster::Engine->add_fake_delegation(
    'c.delegation02.exempelvis.se' => {
        'ns1.c.delegation02.exempelvis.se' => [ '46.21.97.97',   '2a02:750:12:77::97' ],
        'ns2.c.delegation02.exempelvis.se' => [ '37.123.169.91', '2001:9b0:1:1c13::53' ],
    },
);

my $zone = Zonemaster::Engine->zone( q{c.delegation02.exempelvis.se} );

my %res = map { $_->tag => $_ } Zonemaster::Engine::Test::Delegation->delegation02( $zone );

ok( !$res{DEL_NS_SAME_IP},       q{should not emit DEL_NS_SAME_IP} );
ok( $res{CHILD_NS_SAME_IP},      q{should emit CHILD_NS_SAME_IP} );
ok( $res{DEL_DISTINCT_NS_IP},    q{should emit DEL_DISTINCT_NS_IP} );
ok( !$res{CHILD_DISTINCT_NS_IP}, q{should not emit CHILD_DISTINCT_NS_IP} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
