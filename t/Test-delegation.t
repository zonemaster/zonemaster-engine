use Test::More;
use File::Slurp;

use List::MoreUtils qw[uniq none any];

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Test::Delegation} );
    use_ok( q{Zonemaster::Engine::Util} );
}

my $datafile = q{t/Test-delegation.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

my ($json, $profile_test);
$json         = read_file( 't/profiles/Test-delegation-all.json' );
$profile_test = Zonemaster::Engine::Profile->from_json( $json );
Zonemaster::Engine::Profile->effective->merge( $profile_test );

my @res;
my %res;

my $iis = Zonemaster::Engine->zone( q{iis.se} );
%res = map { $_->tag => $_ } Zonemaster::Engine::Test::Delegation->all( $iis );
ok( $res{NAMES_MATCH},      q{NAMES_MATCH} );
ok( $res{REFERRAL_SIZE_OK}, q{REFERRAL_SIZE_OK} );

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{delegation}, q{crystone.se} );
ok( $res{EXTRA_NAME_PARENT},    q{EXTRA_NAME_PARENT} );
ok( $res{EXTRA_NAME_CHILD},     q{EXTRA_NAME_CHILD} );
ok( $res{TOTAL_NAME_MISMATCH},  q{TOTAL_NAME_MISMATCH} );
ok( $res{NO_NS_CNAME},          q{NO_NS_CNAME} );
ok( $res{SOA_EXISTS},           q{SOA_EXISTS} );
ok( $res{ARE_AUTHORITATIVE},    q{ARE_AUTHORITATIVE} );

%res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{delegation}, q{woli.se} );
ok( $res{SOA_NOT_EXISTS}, q{SOA_NOT_EXISTS} );

TODO: {
    local $TODO = "Need to find domain name with that error";

    %res = map { $_->tag => 1 } Zonemaster::Engine->test_module( q{delegation}, q{elsine.se} );
    ok( $res{IS_NOT_AUTHORITATIVE}, q{IS_NOT_AUTHORITATIVE} );

    ok( $res{NS_IS_CNAME}, q{NS_IS_CNAME} );

    ok( $res{REFERRAL_SIZE_LARGE}, q{REFERRAL_SIZE_LARGE} );
}

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

Zonemaster::Engine::Profile->effective->set( q{no_network}, 0 );
Zonemaster::Engine::Profile->effective->set( q{net.ipv4}, 0 );
Zonemaster::Engine::Profile->effective->set( q{net.ipv6}, 0 );
@res = Zonemaster::Engine->test_method( 'Delegation', 'delegation04', Zonemaster::Engine->zone( q{iis.se} ) );
ok( ( any { $_->tag eq 'NO_NETWORK' } @res ), 'IPv6 and IPv4 disabled' );
ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'No network' );
ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'No network' );
@res = Zonemaster::Engine->test_method( 'Delegation', 'delegation06', Zonemaster::Engine->zone( q{iis.se} ) );
ok( ( any { $_->tag eq 'NO_NETWORK' } @res ), 'IPv6 and IPv4 disabled' );
ok( ( none { $_->tag eq 'IPV6_DISABLED' } @res ), 'No network' );
ok( ( none { $_->tag eq 'IPV4_DISABLED' } @res ), 'No network' );


Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );

done_testing;
