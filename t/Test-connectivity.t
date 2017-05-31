use Test::More;

use List::MoreUtils qw[uniq none any];

BEGIN {
    use_ok( q{Zonemaster} );
    use_ok( q{Zonemaster::Engine::Nameserver} );
    use_ok( q{Zonemaster::Engine::Test::Connectivity} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $datafile = q{t/Test-connectivity.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster->config->no_network( 1 );
}

foreach my $testcase ( qw{connectivity01 connectivity02 connectivity03} ) {
    Zonemaster->config->load_policy_file( 't/policies/Test-'.$testcase.'-only.json' );
    my @testcases;
    foreach my $result ( Zonemaster->test_module( q{connectivity}, q{afnic.fr} ) ) {
        foreach my $trace (@{$result->trace}) {
            push @testcases, grep /Zonemaster::Engine::Test::Connectivity::connectivity/, @$trace;
        }
    }
    @testcases = uniq sort @testcases;
    is( scalar( @testcases ), 1, 'only one test-case' );
    is( $testcases[0], 'Zonemaster::Engine::Test::Connectivity::'.$testcase, 'expected test-case' );
}

Zonemaster->config->load_policy_file( 't/policies/Test-connectivity-all.json' );

my @res;
my %res;

%res = map { $_->tag => 1 } Zonemaster->test_module( q{connectivity}, q{afnic.fr} );
ok( $res{NAMESERVER_HAS_UDP_53},        q{Nameserver has UDP port 53 reachable} );
ok( $res{NAMESERVER_HAS_TCP_53},        q{Nameserver has TCP port 53 reachable} );
ok( $res{NAMESERVERS_WITH_MULTIPLE_AS}, q{Nameservers with multiple AS} );
ok( $res{IPV4_ASN},                     'IPv4 AS list' );
ok( $res{IPV6_ASN},                     'IPv6 AS list' );

%res = map { $_->tag => 1 } Zonemaster->test_module( q{connectivity}, q{001.tf} );
ok( $res{NAMESERVERS_IPV6_WITH_UNIQ_AS}, q{Nameservers IPv6 with Uniq AS} );

%res = map { $_->tag => 1 } Zonemaster->test_module( q{connectivity}, q{go.tf} );
ok( $res{NAMESERVERS_WITH_UNIQ_AS},      q{Nameservers with Uniq AS} );
ok( !$res{NAMESERVERS_WITH_MULTIPLE_AS}, q{Nameservers with Uniq AS (double check)} );

%res = map { $_->tag => 1 } Zonemaster->test_module( q{connectivity}, q{iphones.se} );
ok( $res{NAMESERVER_NO_UDP_53}, q{Nameserver UDP port 53 unreachable} );
ok( $res{NAMESERVER_NO_TCP_53}, q{Nameserver TCP port 53 unreachable} );

%res = map { $_->tag => 1 } Zonemaster->test_module( q{connectivity}, q{zut-root.rd.nic.fr} );
ok( $res{NAMESERVERS_WITH_UNIQ_AS},      q{Nameservers with Uniq AS} );
ok( $res{NAMESERVERS_IPV4_WITH_UNIQ_AS}, q{Nameservers IPv4 with Uniq AS} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

Zonemaster->config->no_network( 0 );
Zonemaster->config->ipv6_ok( 0 );
Zonemaster->config->ipv4_ok( 0 );
@res = Zonemaster->test_method( 'Connectivity', 'connectivity01', Zonemaster->zone( q{afnic.fr} ) );
ok( ( any { $_->tag eq 'NO_NETWORK' } @res ), 'IPv6 and IPv4 disabled' );
ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'No network' );
ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'No network' );
@res = Zonemaster->test_method( 'Connectivity', 'connectivity02', Zonemaster->zone( q{afnic.fr} ) );
ok( ( any { $_->tag eq 'NO_NETWORK' } @res ), 'IPv6 and IPv4 disabled' );
ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'No network' );
ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'No network' );

#Zonemaster->config->ipv6_ok( 0 );
#Zonemaster->config->ipv4_ok( 1 );
#@res = Zonemaster->test_method( 'Connectivity', 'connectivity01', Zonemaster->zone( q{afnic.fr} ) );
#ok( ( any { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 disabled' );
#ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#@res = Zonemaster->test_method( 'Connectivity', 'connectivity02', Zonemaster->zone( q{afnic.fr} ) );
#ok( ( any { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 disabled' );
#ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#
#if ( Zonemaster::Engine::Util::supports_ipv6() ) {
#
#    Zonemaster->config->ipv6_ok( 1 );
#    Zonemaster->config->ipv4_ok( 0 );
#    @res = Zonemaster->test_method( 'Connectivity', 'connectivity01', Zonemaster->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( any { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 disabled' );
#    @res = Zonemaster->test_method( 'Connectivity', 'connectivity02', Zonemaster->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( any { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 disabled' );
#
#    Zonemaster->config->ipv6_ok( 1 );
#    Zonemaster->config->ipv4_ok( 1 );
#    @res = Zonemaster->test_method( 'Connectivity', 'connectivity01', Zonemaster->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#    @res = Zonemaster->test_method( 'Connectivity', 'connectivity02', Zonemaster->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#
#}

Zonemaster->config->no_network( 1 );

done_testing;
