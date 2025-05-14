use Test::More;
use File::Slurp;

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Nameserver} );
    use_ok( q{Zonemaster::Engine::Test::Address} );
}

my $datafile = q{t/Test-address.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die "Stored data file missing" if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

my $json          = read_file( "t/profiles/Test-address-all.json" );
my $profile_test  = Zonemaster::Engine::Profile->from_json( $json );
Zonemaster::Engine::Profile->effective->merge( $profile_test );

my @special_addresses = qw(0.255.255.255
                            10.255.255.255
                            192.168.255.255
                            172.17.255.255
                            100.65.255.255
                            127.255.255.255
                            169.254.255.255
                            192.0.0.255
                            192.0.0.7
                            192.0.0.170
                            192.0.0.171
                            192.0.2.255
                            198.51.100.255
                            203.0.113.255
                            192.88.99.255
                            198.19.255.255
                            240.255.255.255
                            255.255.255.255
                            ::1
                            ::
                            ::ffff:cafe:cafe
                            64:ff9b::cafe:cafe
                            100::cafe:cafe:cafe:cafe
                            2001:1ff:cafe:cafe:cafe:cafe:cafe:cafe
                            2001::cafe:cafe:cafe:cafe:cafe:cafe
                            2001:2::cafe:cafe:cafe:cafe:cafe
                            2001:db8:cafe:cafe:cafe:cafe:cafe:cafe
                            2001:1f::cafe:cafe:cafe:cafe:cafe
                            2002:cafe:cafe:cafe:cafe:cafe:cafe:cafe
                            fdff:cafe:cafe:cafe:cafe:cafe:cafe:cafe
                            febf:cafe:cafe:cafe:cafe:cafe:cafe:cafe
);

foreach my $addr ( @special_addresses ) {
    ok(
        defined(
            Zonemaster::Engine::Test::Address->_find_special_address(
                Net::IP::XS->new( $addr )
            )
        ),
        "Special address: $addr"
    );
}

###########
# address
###########

my %res;
%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{address}, q{nic.fr} );

ok( $res{NAMESERVER_IP_PTR_MISMATCH},  q{Nameserver IP PTR mismatch} );
ok( $res{A01_GLOBALLY_REACHABLE_ADDR}, q{All Nameserver addresses are in the routable public addressing space} );
ok( $res{NAMESERVERS_IP_WITH_REVERSE}, q{Reverse DNS entry exist for all Nameserver IP addresses} );

###########
# address01
###########

# See t/Test-address01.t

###########
# address02
###########

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{address}, q{address02.zut-root.rd.nic.fr} );
ok( $res{NAMESERVER_IP_WITHOUT_REVERSE}, q{Nameserver IP without PTR} );

my $zone = Zonemaster::Engine->zone( q{torsas.se} );
my @res = Zonemaster::Engine->test_method( q{Address}, q{address02}, $zone );
ok( !( grep { $_->tag eq 'NAMESERVER_IP_WITHOUT_REVERSE' } @res ), 'Classless in-addr.arpa properly handled when querying PTR.' );

###########
# address03
###########
%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{address}, q{is.se} );
ok( $res{NAMESERVER_IP_PTR_MATCH}, q{All reverse DNS entry matches name server name} );

@res = Zonemaster::Engine->test_method( q{Address}, q{address03}, $zone );
ok( !( grep { $_->tag eq 'NAMESERVER_IP_WITHOUT_REVERSE' } @res ), 'Classless in-addr.arpa properly handled when querying PTR.' );

###########

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
