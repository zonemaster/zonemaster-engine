use Test::More;

use Zonemaster::Engine::Net::IP;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Nameserver} );
    use_ok( q{Zonemaster::Engine::Test::Address} );
}

my $datafile = q{t/Test-address.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die "Stored data file missing" if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine->config->no_network( 1 );
}


ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{0.255.255.255} )
        )
    ),
    q{bad address 0.255.255.255}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{10.255.255.255} )
        )
    ),
    q{bad address 10.255.255.255}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{192.168.255.255} )
        )
    ),
    q{bad address 192.168.255.255}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{172.17.255.255} )
        )
    ),
    q{bad address 172.17.255.255}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{100.65.255.255} )
        )
    ),
    q{bad address 100.65.255.255}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{127.255.255.255} )
        )
    ),
    q{bad address 127.255.255.255}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{169.254.255.255} )
        )
    ),
    q{bad address 169.254.255.255}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{192.0.0.255} )
        )
    ),
    q{bad address 192.0.0.255}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{192.0.0.7} )
        )
    ),
    q{bad address 192.0.0.7}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{192.0.0.170} )
        )
    ),
    q{bad address 192.0.0.170}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{192.0.0.171} )
        )
    ),
    q{bad address 192.0.0.171}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{192.0.2.255} )
        )
    ),
    q{bad address 192.0.2.255}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{198.51.100.255} )
        )
    ),
    q{bad address 198.51.100.255}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{203.0.113.255} )
        )
    ),
    q{bad address 203.0.113.255}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{192.88.99.255} )
        )
    ),
    q{bad address 192.88.99.255}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{198.19.255.255} )
        )
    ),
    q{bad address 198.19.255.255}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{240.255.255.255} )
        )
    ),
    q{bad address 240.255.255.255}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{255.255.255.255} )
        )
    ),
    q{bad address 255.255.255.255}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{::1} )
        )
    ),
    q{bad address ::1}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{::} )
        )
    ),
    q{bad address ::}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{::ffff:cafe:cafe} )
        )
    ),
    q{bad address ::ffff:cafe:cafe}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{64:ff9b::cafe:cafe} )
        )
    ),
    q{bad address 64:ff9b::cafe:cafe}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{100::cafe:cafe:cafe:cafe} )
        )
    ),
    q{bad address 100::cafe:cafe:cafe:cafe}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{2001:1ff:cafe:cafe:cafe:cafe:cafe:cafe} )
        )
    ),
    q{bad address 2001:1ff:cafe:cafe:cafe:cafe:cafe:cafe}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{2001::cafe:cafe:cafe:cafe:cafe:cafe} )
        )
    ),
    q{bad address 2001::cafe:cafe:cafe:cafe:cafe:cafe}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{2001:2::cafe:cafe:cafe:cafe:cafe} )
        )
    ),
    q{bad address 2001:2::cafe:cafe:cafe:cafe:cafe}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{2001:db8:cafe:cafe:cafe:cafe:cafe:cafe} )
        )
    ),
    q{bad address 2001:db8:cafe:cafe:cafe:cafe:cafe:cafe}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{2001:1f::cafe:cafe:cafe:cafe:cafe} )
        )
    ),
    q{bad address 2001:1f::cafe:cafe:cafe:cafe:cafe}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{2002:cafe:cafe:cafe:cafe:cafe:cafe:cafe} )
        )
    ),
    q{bad address 2002:cafe:cafe:cafe:cafe:cafe:cafe:cafe}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{fdff:cafe:cafe:cafe:cafe:cafe:cafe:cafe} )
        )
    ),
    q{bad address fdff:cafe:cafe:cafe:cafe:cafe:cafe:cafe}
);

ok(
    defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{febf:cafe:cafe:cafe:cafe:cafe:cafe:cafe} )
        )
    ),
    q{bad address febf:cafe:cafe:cafe:cafe:cafe:cafe:cafe}
);

SKIP: {
    skip "::cafe:cafe Was RFC4291: Deprecated (IPv4-compatible Address) (Zonemaster::Engine::Constants prior to 1.2.0 version)", 1;
    ok(
        defined(
            Zonemaster::Engine::Test::Address->find_special_address(
                Zonemaster::Engine::Net::IP->new( q{::cafe:cafe} )
            )
        ),
        q{bad address ::cafe:cafe}
    );
}

SKIP: {
    skip "5fff:cafe:cafe:cafe:cafe:cafe:cafe:cafe Was RFC3701: unallocated (ex 6bone) (Zonemaster::Engine::Constants prior to 1.2.0 version)", 1;
    ok(
        defined(
            Zonemaster::Engine::Test::Address->find_special_address(
                Zonemaster::Engine::Net::IP->new( q{5fff:cafe:cafe:cafe:cafe:cafe:cafe:cafe} )
            )
        ),
        q{bad address 5fff:cafe:cafe:cafe:cafe:cafe:cafe:cafe}
    );
}

SKIP: {
    skip "ffff:cafe:cafe:cafe:cafe:cafe:cafe:cafe Was RFC4291: IPv6 multicast addresses (Zonemaster::Engine::Constants prior to 1.2.0 version)", 1;
    ok(
        defined(
            Zonemaster::Engine::Test::Address->find_special_address(
                Zonemaster::Engine::Net::IP->new( q{ffff:cafe:cafe:cafe:cafe:cafe:cafe:cafe} )
            )
        ),
        q{bad address ffff:cafe:cafe:cafe:cafe:cafe:cafe:cafe}
    );
}

ok(
    !defined(
        Zonemaster::Engine::Test::Address->find_special_address(
            Zonemaster::Engine::Net::IP->new( q{192.134.4.45} )
        )
    ),
    q{good address 192.134.4.45}
);

my %res;

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{address}, q{nic.fr} );
ok( $res{NAMESERVER_IP_PTR_MISMATCH},  q{Nameserver IP PTR mismatch} );
ok( $res{NO_IP_PRIVATE_NETWORK},       q{All Nameserver addresses are in the routable public addressing space} );
ok( $res{NAMESERVERS_IP_WITH_REVERSE}, q{Reverse DNS entry exist for all Nameserver IP addresses} );

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{address}, q{address02.zut-root.rd.nic.fr} );
ok( $res{NAMESERVER_IP_WITHOUT_REVERSE}, q{Nameserver IP without PTR} );

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{address}, q{is.se} );
ok( $res{NAMESERVER_IP_PTR_MATCH}, q{All reverse DNS entry matches name server name} );

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{address}, q{address01.zut-root.rd.nic.fr} );
ok( $res{NAMESERVER_IP_PRIVATE_NETWORK}, q{Nameserver address in non routable public addressing space} );

my $torsasse =  Zonemaster::Engine->zone( q{torsas.se} );
my @res = Zonemaster::Engine->test_method( q{Address}, q{address02}, $torsasse );
ok( !( grep { $_->tag eq 'NAMESERVER_IP_WITHOUT_REVERSE' } @res ), 'Classless in-addr.arpa properly handled when querying PTR.' );
@res = Zonemaster::Engine->test_method( q{Address}, q{address03}, $torsasse );
ok( !( grep { $_->tag eq 'NAMESERVER_IP_WITHOUT_REVERSE' } @res ), 'Classless in-addr.arpa properly handled when querying PTR.' );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
