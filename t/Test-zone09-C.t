use Test::More;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Zone} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $datafile = q{t/Test-zone09-C.data};

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

Zonemaster::Engine->add_fake_delegation(
    'xc' => {
        'zonemaster01-prd.iis.se' => ['45.155.96.81', '2001:67c:124c:7316::81'],
        'zonemaster05-prd.iis.se' => ['45.155.96.85', '2001:67c:124c:7316::85'],
    },
    fill_in_empty_oob_glue => 0,
);

my $zone = Zonemaster::Engine->zone( q{xc} );

my %res = map { $_->tag => $_ } Zonemaster::Engine::Test::Zone->zone09( $zone );

ok( !$res{Z09_INCONSISTENT_MX},         q{should not emit Z09_INCONSISTENT_MX} );
ok( $res{Z09_INCONSISTENT_MX_DATA},     q{should emit Z09_INCONSISTENT_MX_DATA} );
ok( !$res{Z09_MISSING_MAIL_TARGET},     q{should not emit Z09_MISSING_MAIL_TARGET} );
ok( $res{Z09_MX_DATA},                  q{should emit Z09_MX_DATA} );
ok( !$res{Z09_MX_FOUND},                q{should not emit Z09_NO_MX_FOUND} );
ok( !$res{Z09_NON_AUTH_MX_RESPONSE},    q{should not emit Z09_NON_AUTH_MX_RESPONSE} );
ok( !$res{Z09_NO_MX_FOUND},             q{should not emit Z09_NO_MX_FOUND} );
ok( !$res{Z09_NO_RESPONSE_MX_QUERY},    q{should not emit Z09_NO_RESPONSE_MX_QUERY} );
ok( !$res{Z09_NULL_MX_NON_ZERO_PREF},   q{should not emit Z09_NULL_MX_NON_ZERO_PREF} );
ok( !$res{Z09_NULL_MX_WITH_OTHER_MX},   q{should not emit Z09_NULL_MX_WITH_OTHER_MX} );
ok( !$res{Z09_ROOT_EMAIL_DOMAIN},       q{should not emit Z09_ROOT_EMAIL_DOMAIN} );
ok( !$res{Z09_TLD_EMAIL_DOMAIN},        q{should not emit Z09_TLD_EMAIL_DOMAIN} );
ok( !$res{Z09_UNEXPECTED_RCODE_MX},     q{should not emit Z09_UNEXPECTED_RCODE_MX} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;