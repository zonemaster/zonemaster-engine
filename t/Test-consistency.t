use Test::More;

use List::MoreUtils qw[uniq none any];

BEGIN {
    use_ok( q{Zonemaster} );
    use_ok( q{Zonemaster::Engine::Test::Consistency} );
    use_ok( q{Zonemaster::Util} );
}

my $datafile = q{t/Test-consistency.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster->config->no_network( 1 );
}

foreach my $testcase ( qw{consistency01 consistency02 consistency03 consistency04 consistency05} ) {
    Zonemaster->config->load_policy_file( 't/policies/Test-'.$testcase.'-only.json' );
    my @testcases;
    Zonemaster->logger->clear_history();
    foreach my $result ( Zonemaster->test_module( q{consistency}, q{afnic.fr} ) ) {
        foreach my $trace (@{$result->trace}) {
            push @testcases, grep /Zonemaster::Engine::Test::Consistency::consistency/, @$trace;
        }
    }
    @testcases = uniq sort @testcases;
    is( scalar( @testcases ), 1, 'only one test-case' );
    is( $testcases[0], 'Zonemaster::Engine::Test::Consistency::'.$testcase, 'expected test-case' );
}

Zonemaster->config->load_policy_file( 't/policies/Test-consistency-all.json' );

my @res;
my %res;

%res = map { $_->tag => 1 } Zonemaster->test_module( q{consistency}, q{zft-sandoche.rd.nic.fr} );
ok( $res{MULTIPLE_NS_SET}, q{Saw several NS set} );
ok( $res{NS_SET},          q{NS set details} );

%res = map { $_->tag => 1 } Zonemaster->test_module( q{consistency}, q{consistency01.zut-root.rd.nic.fr} );
ok( $res{SOA_SERIAL_VARIATION}, q{Big variation between multiple SOA serials} );
ok( $res{MULTIPLE_SOA_SERIALS}, q{Multiple SOA serials} );
ok( $res{SOA_SERIAL},           q{SOA serial details} );
ok( $res{ONE_NS_SET},           q{A unique NS set was seen} );

%res = map { $_->tag => 1 } Zonemaster->test_module( q{consistency}, q{consistency02.zut-root.rd.nic.fr} );
ok( $res{MULTIPLE_SOA_RNAMES}, q{Multiple SOA rname} );
ok( $res{SOA_RNAME},           q{SOA rname details} );

%res = map { $_->tag => 1 } Zonemaster->test_module( q{consistency}, q{consistency03.zut-root.rd.nic.fr} );
ok( $res{MULTIPLE_SOA_TIME_PARAMETER_SET}, q{Multiple SOA time parameters} );
ok( $res{SOA_TIME_PARAMETER_SET},          q{SOA time parameters details} );

%res = map { $_->tag => 1 } Zonemaster->test_module( q{consistency}, q{afnic.fr} );
ok( $res{ONE_SOA_SERIAL},             q{One SOA serial} );
ok( $res{ONE_SOA_RNAME},              q{One SOA rname} );
ok( $res{ONE_SOA_TIME_PARAMETER_SET}, q{One SOA time parameters set} );
ok( $res{ADDRESSES_MATCH},            q{Addresses IP match} );

%res = map { $_->tag => 1 } Zonemaster->test_module( q{consistency}, q{ci} );
ok( $res{EXTRA_ADDRESS_PARENT}, q{Extra IP parent} );
ok( $res{EXTRA_ADDRESS_CHILD},  q{Extra IP parent} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

Zonemaster->config->no_network( 0 );
Zonemaster->config->ipv6_ok( 0 );
Zonemaster->config->ipv4_ok( 0 );
@res = Zonemaster->test_method( 'Consistency', 'consistency01', Zonemaster->zone( q{afnic.fr} ) );
ok( ( any { $_->tag eq 'NO_NETWORK' } @res ), 'IPv6 and IPv4 disabled' );
ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'No network' );
ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'No network' );
@res = Zonemaster->test_method( 'Consistency', 'consistency02', Zonemaster->zone( q{afnic.fr} ) );
ok( ( any { $_->tag eq 'NO_NETWORK' } @res ), 'IPv6 and IPv4 disabled' );
ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'No network' );
ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'No network' );
@res = Zonemaster->test_method( 'Consistency', 'consistency03', Zonemaster->zone( q{afnic.fr} ) );
ok( ( any { $_->tag eq 'NO_NETWORK' } @res ), 'IPv6 and IPv4 disabled' );
ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'No network' );
ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'No network' );
@res = Zonemaster->test_method( 'Consistency', 'consistency04', Zonemaster->zone( q{afnic.fr} ) );
ok( ( any { $_->tag eq 'NO_NETWORK' } @res ), 'IPv6 and IPv4 disabled' );
ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'No network' );
ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'No network' );

#Zonemaster->config->ipv6_ok( 0 );
#Zonemaster->config->ipv4_ok( 1 );
#@res = Zonemaster->test_method( 'Consistency', 'consistency01', Zonemaster->zone( q{afnic.fr} ) );
#ok( ( any { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 disabled' );
#ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#@res = Zonemaster->test_method( 'Consistency', 'consistency02', Zonemaster->zone( q{afnic.fr} ) );
#ok( ( any { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 disabled' );
#ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#@res = Zonemaster->test_method( 'Consistency', 'consistency03', Zonemaster->zone( q{afnic.fr} ) );
#ok( ( any { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 disabled' );
#ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#@res = Zonemaster->test_method( 'Consistency', 'consistency04', Zonemaster->zone( q{afnic.fr} ) );
#ok( ( any { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 disabled' );
#ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#
#if ( Zonemaster::Util::supports_ipv6() ) {
#
#    Zonemaster->config->ipv6_ok( 1 );
#    Zonemaster->config->ipv4_ok( 0 );
#    @res = Zonemaster->test_method( 'Consistency', 'consistency01', Zonemaster->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( any { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 disabled' );
#    @res = Zonemaster->test_method( 'Consistency', 'consistency02', Zonemaster->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( any { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 disabled' );
#    @res = Zonemaster->test_method( 'Consistency', 'consistency03', Zonemaster->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( any { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 disabled' );
#    @res = Zonemaster->test_method( 'Consistency', 'consistency04', Zonemaster->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( any { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 disabled' );
#
#    Zonemaster->config->ipv6_ok( 1 );
#    Zonemaster->config->ipv4_ok( 1 );
#    @res = Zonemaster->test_method( 'Consistency', 'consistency01', Zonemaster->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#    @res = Zonemaster->test_method( 'Consistency', 'consistency02', Zonemaster->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#    @res = Zonemaster->test_method( 'Consistency', 'consistency03', Zonemaster->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#    @res = Zonemaster->test_method( 'Consistency', 'consistency04', Zonemaster->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#
#}

Zonemaster->config->no_network( 1 );

done_testing;
