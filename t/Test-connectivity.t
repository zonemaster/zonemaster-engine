use Test::More;
use File::Slurp;

use List::MoreUtils qw[uniq none any];

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Nameserver} );
    use_ok( q{Zonemaster::Engine::Test::Connectivity} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $datafile = q{t/Test-connectivity.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

my ($json, $profile_test);
foreach my $testcase ( qw{connectivity01 connectivity02 connectivity03} ) {
    $json          = read_file( 't/profiles/Test-'.$testcase.'-only.json' );
    $profile_test  = Zonemaster::Engine::Profile->from_json( $json );
    Zonemaster::Engine::Profile->effective->merge( $profile_test );
    my @testcases;
    foreach my $result ( Zonemaster::Engine->test_module( q{connectivity}, q{afnic.fr} ) ) {
        foreach my $trace (@{$result->trace}) {
            push @testcases, grep /Zonemaster::Engine::Test::Connectivity::connectivity/, @$trace;
        }
    }
    @testcases = uniq sort @testcases;
    is( scalar( @testcases ), 1, 'only one test-case ('.$testcase.')' );
    is( $testcases[0], 'Zonemaster::Engine::Test::Connectivity::'.$testcase, 'expected test-case ('.$testcases[0].')' );
}

$json         = read_file( 't/profiles/Test-connectivity-all.json' );
$profile_test = Zonemaster::Engine::Profile->from_json( $json );
Zonemaster::Engine::Profile->effective->merge( $profile_test );

my @res;
my %res;

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{connectivity}, q{afnic.fr} );
ok( !$res{MODULE_ERROR},                q{Test module completes normally} );
ok( $res{NAMESERVER_HAS_UDP_53},        q{Nameserver has UDP port 53 reachable} );
ok( $res{NAMESERVER_HAS_TCP_53},        q{Nameserver has TCP port 53 reachable} );
ok( $res{IPV4_DIFFERENT_ASN},           q{IPv4 Nameservers with multiple AS} );
ok( !$res{IPV4_ONE_ASN},                q{IPv4 Nameservers with multiple AS (double check)} );
ok( !$res{IPV4_SAME_ASN},               q{IPv4 Nameservers with multiple AS (triple check)} );
ok( $res{IPV6_DIFFERENT_ASN},           q{IPv6 Nameservers with multiple AS} );
ok( !$res{IPV6_ONE_ASN},                q{IPv6 Nameservers with multiple AS (double check)} );
ok( !$res{IPV6_SAME_ASN},               q{IPv6 Nameservers with multiple AS (triple check)} );

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{connectivity}, q{001.tf} );
ok( $res{IPV6_ONE_ASN}, q{Nameservers IPv6 with Uniq AS} );

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{connectivity}, q{go.tf} );
ok( $res{IPV4_ONE_ASN},      q{IPv4 Nameservers with Uniq AS} );
ok( !$res{IPV4_DIFFERENT_ASN}, q{IPv4 Nameservers with Uniq AS (double check)} );

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{connectivity}, q{iphones.se} );
ok( $res{NAMESERVER_NO_UDP_53}, q{Nameserver UDP port 53 unreachable} );
ok( $res{NAMESERVER_NO_TCP_53}, q{Nameserver TCP port 53 unreachable} );

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{connectivity}, q{zut-root.rd.nic.fr} );
ok( $res{IPV4_ONE_ASN},      q{Nameservers with Uniq AS} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

Zonemaster::Engine::Profile->effective->set( q{no_network}, 0 );
Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 0 );
Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 0 );
@res = Zonemaster::Engine->test_method( 'Connectivity', 'connectivity01', Zonemaster::Engine->zone( q{afnic.fr} ) );
ok( ( any { $_->tag eq 'NO_NETWORK' } @res ), 'IPv6 and IPv4 disabled' );
ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'No network' );
ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'No network' );
@res = Zonemaster::Engine->test_method( 'Connectivity', 'connectivity02', Zonemaster::Engine->zone( q{afnic.fr} ) );
ok( ( any { $_->tag eq 'NO_NETWORK' } @res ), 'IPv6 and IPv4 disabled' );
ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'No network' );
ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'No network' );

#Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 1 );
#Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 0 );
#@res = Zonemaster::Engine->test_method( 'Connectivity', 'connectivity01', Zonemaster::Engine->zone( q{afnic.fr} ) );
#ok( ( any { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 disabled' );
#ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#@res = Zonemaster::Engine->test_method( 'Connectivity', 'connectivity02', Zonemaster::Engine->zone( q{afnic.fr} ) );
#ok( ( any { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 disabled' );
#ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#
#if ( Zonemaster::Engine::Util::supports_ipv6() ) {
#
#    Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 1 );
#    Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 0 );
#    @res = Zonemaster::Engine->test_method( 'Connectivity', 'connectivity01', Zonemaster::Engine->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( any { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 disabled' );
#    @res = Zonemaster::Engine->test_method( 'Connectivity', 'connectivity02', Zonemaster::Engine->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( any { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 disabled' );
#
#    Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 1 );
#    Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 1 );
#    @res = Zonemaster::Engine->test_method( 'Connectivity', 'connectivity01', Zonemaster::Engine->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#    @res = Zonemaster::Engine->test_method( 'Connectivity', 'connectivity02', Zonemaster::Engine->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#
#}

Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );

done_testing;
