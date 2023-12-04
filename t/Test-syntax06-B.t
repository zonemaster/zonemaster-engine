use Test::More;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Syntax} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $datafile = q{t/Test-syntax06-B.data};

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine->profile->set( q{no_network}, 1 );
}

Zonemaster::Engine->add_fake_delegation(
    'b.syntax06.exempelvis.se' => {
        'drip.ip.se' => ['192.0.2.1'],
        'drop.ip.se' => ['192.0.2.2'],
    },
    fill_in_empty_oob_glue => 0,
);

my $zone = Zonemaster::Engine->zone( q{b.syntax06.exempelvis.se} );

my %res = map { $_->tag => $_ } Zonemaster::Engine::Test::Syntax->syntax06( $zone );

ok( $res{NO_RESPONSE},                q{should emit NO_RESPONSE} );
ok( !$res{NO_RESPONSE_SOA_QUERY},     q{should not emit NO_RESPONSE_SOA_QUERY} );
ok( !$res{RNAME_RFC822_INVALID},      q{should not emit RNAME_RFC822_INVALID} );
ok( !$res{RNAME_MAIL_DOMAIN_INVALID}, q{should not emit RNAME_MAIL_DOMAIN_INVALID} );
ok( !$res{RNAME_RFC822_VALID},        q{should not emit RNAME_RFC822_VALID} );
ok( !$res{RNAME_MAIL_ILLEGAL_CNAME},    q{should not emit RNAME_MAIL_ILLEGAL_CNAME} );
ok( !$res{RNAME_MAIL_DOMAIN_LOCALHOST}, q{should not emit RNAME_MAIL_DOMAIN_LOCALHOST} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
