use Test::More;

use List::MoreUtils qw[uniq none any];

BEGIN {
    use_ok( q{Zonemaster} );
    use_ok( q{Zonemaster::Engine::Test::Delegation} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $datafile = q{t/Test-delegation.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster->config->no_network( 1 );
}

my @res;
my %res;

my $iis = Zonemaster->zone( q{iis.se} );
%res = map { $_->tag => $_ } Zonemaster::Engine::Test::Delegation->all( $iis );
ok( $res{ENOUGH_NS},       q{ENOUGH_NS} );
ok( $res{ENOUGH_NS_GLUE},  q{ENOUGH_NS_GLUE} );
ok( $res{ENOUGH_NS_TOTAL}, q{ENOUGH_NS_TOTAL} );
ok( $res{NAMES_MATCH},     q{NAMES_MATCH} );
ok( $res{REFERRAL_SIZE_OK}, q{REFERRAL_SIZE_OK} );

%res = map { $_->tag => 1 } Zonemaster->test_module( q{delegation}, q{crystone.se} );
ok( $res{SAME_IP_ADDRESS},      q{SAME_IP_ADDRESS} );
ok( $res{EXTRA_NAME_PARENT},    q{EXTRA_NAME_PARENT} );
ok( $res{EXTRA_NAME_CHILD},     q{EXTRA_NAME_CHILD} );
ok( $res{TOTAL_NAME_MISMATCH},  q{TOTAL_NAME_MISMATCH} );
ok( !$res{DISTINCT_IP_ADDRESS}, q{No DISTINCT_IP_ADDRESS} );
ok( $res{NS_RR_NO_CNAME},       q{NS_RR_NO_CNAME} );
ok( $res{SOA_EXISTS},           q{SOA_EXISTS} );
ok( $res{ARE_AUTHORITATIVE},    q{ARE_AUTHORITATIVE} );

%res = map { $_->tag => 1 } Zonemaster->test_module( q{delegation}, q{delegation02.zut-root.rd.nic.fr} );
ok( $res{NOT_ENOUGH_NS_TOTAL}, q{NOT_ENOUGH_NS_TOTAL} );
ok( $res{NOT_ENOUGH_NS},       q{NOT_ENOUGH_NS} );
ok( $res{NOT_ENOUGH_NS_GLUE},  q{NOT_ENOUGH_NS_GLUE} );

%res = map { $_->tag => 1 } Zonemaster->test_module( q{delegation}, q{woli.se} );
ok( $res{SOA_NOT_EXISTS}, q{SOA_NOT_EXISTS} );

TODO: {
    local $TODO = "Need to find domain name with that error";

    %res = map { $_->tag => 1 } Zonemaster->test_module( q{delegation}, q{elsine.se} );
    ok( $res{IS_NOT_AUTHORITATIVE}, q{IS_NOT_AUTHORITATIVE} );

    ok( $res{NS_RR_IS_CNAME}, q{NS_RR_IS_CNAME} );

    ok( $res{REFERRAL_SIZE_LARGE}, q{REFERRAL_SIZE_LARGE} );
}

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

Zonemaster->config->no_network( 0 );
Zonemaster->config->ipv6_ok( 0 );
Zonemaster->config->ipv4_ok( 0 );
@res = Zonemaster->test_method( 'Delegation', 'delegation04', Zonemaster->zone( q{iis.se} ) );
ok( ( any { $_->tag eq 'NO_NETWORK' } @res ), 'IPv6 and IPv4 disabled' );
ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'No network' );
ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'No network' );
@res = Zonemaster->test_method( 'Delegation', 'delegation06', Zonemaster->zone( q{iis.se} ) );
ok( ( any { $_->tag eq 'NO_NETWORK' } @res ), 'IPv6 and IPv4 disabled' );
ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'No network' );
ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'No network' );

#Zonemaster->config->ipv6_ok( 0 );
#Zonemaster->config->ipv4_ok( 1 );
#@res = Zonemaster->test_method( 'Delegation', 'delegation04', Zonemaster->zone( q{iis.se} ) );
#ok( ( any { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 disabled' );
#ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#@res = Zonemaster->test_method( 'Delegation', 'delegation06', Zonemaster->zone( q{iis.se} ) );
#ok( ( any { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 disabled' );
#ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#
#if ( Zonemaster::Engine::Util::supports_ipv6() ) {
#
#    Zonemaster->config->ipv6_ok( 1 );
#    Zonemaster->config->ipv4_ok( 0 );
#    @res = Zonemaster->test_method( 'Delegation', 'delegation04', Zonemaster->zone( q{iis.se} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( any { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 disabled' );
#    @res = Zonemaster->test_method( 'Delegation', 'delegation06', Zonemaster->zone( q{iis.se} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( any { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 disabled' );
#
#    Zonemaster->config->ipv6_ok( 1 );
#    Zonemaster->config->ipv4_ok( 1 );
#    @res = Zonemaster->test_method( 'Delegation', 'delegation04', Zonemaster->zone( q{iis.se} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#    @res = Zonemaster->test_method( 'Delegation', 'delegation06', Zonemaster->zone( q{iis.se} ) );
#    ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'IPv6 not disabled' );
#    ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'IPv4 not disabled' );
#
#}

Zonemaster->config->no_network( 1 );

done_testing;
