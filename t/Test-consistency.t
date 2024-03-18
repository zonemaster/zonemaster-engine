use Test::More;
use Test::Differences;
use File::Slurp;

use List::MoreUtils qw[uniq none any];

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Consistency} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $datafile = q{t/Test-consistency.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

my ($json, $profile_test);
foreach my $testcase ( qw{consistency01 consistency02 consistency03 consistency04} ) {
    $json         = read_file( 't/profiles/Test-'.$testcase.'-only.json' );
    $profile_test = Zonemaster::Engine::Profile->from_json( $json );
    Zonemaster::Engine::Profile->effective->merge( $profile_test );
    my %testcases;
    Zonemaster::Engine->logger->clear_history();
    foreach my $result ( Zonemaster::Engine->test_module( q{consistency}, q{afnic.fr} ) ) {
        if ( $result->testcase && $result->testcase ne 'Unspecified' ) {
            $testcases{$result->testcase} = 1;
        }
    }
    eq_or_diff( [ map { lc $_ } keys %testcases ], [ $testcase ], 'expected test-case ('. $testcase .')' );
}

$json         = read_file( 't/profiles/Test-consistency-all.json' );
$profile_test = Zonemaster::Engine::Profile->from_json( $json );
Zonemaster::Engine::Profile->effective->merge( $profile_test );

my @res;
my %res;

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{consistency}, q{consistency01.zut-root.rd.nic.fr} );
ok( $res{SOA_SERIAL_VARIATION}, q{Big variation between multiple SOA serials} );
ok( $res{MULTIPLE_SOA_SERIALS}, q{Multiple SOA serials} );
ok( $res{SOA_SERIAL},           q{SOA serial details} );
ok( $res{ONE_NS_SET},           q{A unique NS set was seen} );

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{consistency}, q{consistency02.zut-root.rd.nic.fr} );
ok( $res{MULTIPLE_SOA_RNAMES}, q{Multiple SOA rname} );
ok( $res{SOA_RNAME},           q{SOA rname details} );

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{consistency}, q{consistency03.zut-root.rd.nic.fr} );
ok( $res{MULTIPLE_SOA_TIME_PARAMETER_SET}, q{Multiple SOA time parameters} );
ok( $res{SOA_TIME_PARAMETER_SET},          q{SOA time parameters details} );

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{consistency}, q{consistency04.zut-root.rd.nic.fr} );
ok( $res{MULTIPLE_NS_SET}, q{Saw several NS set} );
ok( $res{NS_SET},          q{NS set details} );

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{consistency}, q{afnic.fr} );
ok( $res{ONE_SOA_SERIAL},             q{One SOA serial} );
ok( $res{ONE_SOA_RNAME},              q{One SOA rname} );
ok( $res{ONE_SOA_TIME_PARAMETER_SET}, q{One SOA time parameters set} );
ok( $res{ADDRESSES_MATCH},            q{Addresses IP match} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

Zonemaster::Engine::Profile->effective->set( q{no_network}, 0 );
Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 0 );
Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 0 );
@res = Zonemaster::Engine->test_method( 'Consistency', 'consistency01', Zonemaster::Engine->zone( q{afnic.fr} ) );
ok( ( any { $_->tag eq 'NO_NETWORK' } @res ), 'IPv6 and IPv4 disabled' );
ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'No network' );
ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'No network' );
@res = Zonemaster::Engine->test_method( 'Consistency', 'consistency02', Zonemaster::Engine->zone( q{afnic.fr} ) );
ok( ( any { $_->tag eq 'NO_NETWORK' } @res ), 'IPv6 and IPv4 disabled' );
ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'No network' );
ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'No network' );
@res = Zonemaster::Engine->test_method( 'Consistency', 'consistency03', Zonemaster::Engine->zone( q{afnic.fr} ) );
ok( ( any { $_->tag eq 'NO_NETWORK' } @res ), 'IPv6 and IPv4 disabled' );
ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'No network' );
ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'No network' );
@res = Zonemaster::Engine->test_method( 'Consistency', 'consistency04', Zonemaster::Engine->zone( q{afnic.fr} ) );
ok( ( any { $_->tag eq 'NO_NETWORK' } @res ), 'IPv6 and IPv4 disabled' );
ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'No network' );
ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'No network' );

#Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 1 );
#Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 0 );
#@res = Zonemaster::Engine->test_method( 'Consistency', 'consistency01', Zonemaster::Engine->zone( q{afnic.fr} ) );
#ok( ( any { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 disabled' );
#ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#@res = Zonemaster::Engine->test_method( 'Consistency', 'consistency02', Zonemaster::Engine->zone( q{afnic.fr} ) );
#ok( ( any { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 disabled' );
#ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#@res = Zonemaster::Engine->test_method( 'Consistency', 'consistency03', Zonemaster::Engine->zone( q{afnic.fr} ) );
#ok( ( any { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 disabled' );
#ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#@res = Zonemaster::Engine->test_method( 'Consistency', 'consistency04', Zonemaster::Engine->zone( q{afnic.fr} ) );
#ok( ( any { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 disabled' );
#ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#
#if ( Zonemaster::Engine::Util::supports_ipv6() ) {
#
#    Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 0 );
#    Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 1 );
#    @res = Zonemaster::Engine->test_method( 'Consistency', 'consistency01', Zonemaster::Engine->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( any { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 disabled' );
#    @res = Zonemaster::Engine->test_method( 'Consistency', 'consistency02', Zonemaster::Engine->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( any { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 disabled' );
#    @res = Zonemaster::Engine->test_method( 'Consistency', 'consistency03', Zonemaster::Engine->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( any { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 disabled' );
#    @res = Zonemaster::Engine->test_method( 'Consistency', 'consistency04', Zonemaster::Engine->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( any { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 disabled' );
#
#    Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 1 );
#    Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 1 );
#    @res = Zonemaster::Engine->test_method( 'Consistency', 'consistency01', Zonemaster::Engine->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#    @res = Zonemaster::Engine->test_method( 'Consistency', 'consistency02', Zonemaster::Engine->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#    @res = Zonemaster::Engine->test_method( 'Consistency', 'consistency03', Zonemaster::Engine->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#    @res = Zonemaster::Engine->test_method( 'Consistency', 'consistency04', Zonemaster::Engine->zone( q{afnic.fr} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#
#}

Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );

done_testing;
