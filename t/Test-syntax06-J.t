use Test::More;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Syntax} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $datafile = q{t/Test-syntax06-J.data};

if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine->profile->set( q{no_network}, 1 );
}

Zonemaster::Engine->add_fake_delegation(
    'j.syntax06.exempelvis.se' => {
        'ns1.j.syntax06.exempelvis.se' => [ '46.21.97.97',   '2a02:750:12:77::97' ],
        'ns2.j.syntax06.exempelvis.se' => [ '37.123.169.91', '2001:9b0:1:1c13::53' ],
    }
);

my $zone = Zonemaster::Engine->zone( q{j.syntax06.exempelvis.se} );

my %res = map { $_->tag => $_ } Zonemaster::Engine::Test::Syntax->syntax06( $zone );

ok( !$res{NO_RESPONSE},              q{should not emit NO_RESPONSE} );
ok( !$res{NO_RESPONSE_SOA_QUERY},    q{should not emit NO_RESPONSE_SOA_QUERY} );
ok( !$res{RNAME_RFC822_INVALID},     q{should not emit RNAME_RFC822_INVALID} );
ok( $res{RNAME_MAIL_DOMAIN_INVALID}, q{should emit RNAME_MAIL_DOMAIN_INVALID} );
ok( !$res{RNAME_RFC822_VALID},       q{should not emit RNAME_RFC822_VALID} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
