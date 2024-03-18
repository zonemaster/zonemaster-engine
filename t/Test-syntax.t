use Test::More;
use Test::Differences;
use File::Slurp;

use List::MoreUtils qw[uniq none any];

BEGIN {
    use_ok( q{Zonemaster::Engine} );
    use_ok( q{Zonemaster::Engine::Nameserver} );
    use_ok( q{Zonemaster::Engine::DNSName} );
    use_ok( q{Zonemaster::Engine::Zone} );
    use_ok( q{Zonemaster::Engine::Test::Syntax} );
}

sub zone_gives {
    my ( $test, $zone, $gives ) = @_;

    my @res = Zonemaster::Engine->test_method( q{Syntax}, $test, $zone );
    ok( ( grep { $_->tag eq $gives } @res ), $zone->name->string . " gives $gives" );
}

sub zone_gives_not {
    my ( $test, $zone, $gives ) = @_;

    my @res = Zonemaster::Engine->test_method( q{Syntax}, $test, $zone );
    ok( !( grep { $_->tag eq $gives } @res ), $zone->name->string . " does not give $gives" );
}

my $datafile = q{t/Test-syntax.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine::Profile->effective->set( q{no_network}, 1 );
}

# Find a way with dependences for syntax04 syntax05 syntax06 syntax07 syntax08
my ($json, $profile_test);
foreach my $testcase ( qw{syntax01 syntax02 syntax03} ) {
    $json         = read_file( 't/profiles/Test-'.$testcase.'-only.json' );
    $profile_test = Zonemaster::Engine::Profile->from_json( $json );
    Zonemaster::Engine::Profile->effective->merge( $profile_test );
    my %testcases;
    foreach my $result ( Zonemaster::Engine->test_module( q{syntax}, q{afnic.fr} ) ) {
        if ( $result->testcase && $result->testcase ne 'Unspecified' ) {
            $testcases{$result->testcase} = 1;
        }
    }
    eq_or_diff( [ map { lc $_ } keys %testcases ], [ $testcase ], 'expected test-case ('. $testcase .')' );
}

$json         = read_file( 't/profiles/Test-syntax-all.json' );
$profile_test = Zonemaster::Engine::Profile->from_json( $json );
Zonemaster::Engine::Profile->effective->merge( $profile_test );

my $ns_ok = Zonemaster::Engine->zone( q{ns1.nic.fr} );
my $dn_ok = Zonemaster::Engine->zone( q{www.nic.se} );
my $dn_ko = Zonemaster::Engine->zone( q{www.nic&nac.se} );
zone_gives( q{syntax01}, $dn_ok, q{ONLY_ALLOWED_CHARS} );
zone_gives_not( q{syntax01}, $dn_ko, q{ONLY_ALLOWED_CHARS} );
zone_gives( q{syntax01}, $dn_ko, q{NON_ALLOWED_CHARS} );
zone_gives_not( q{syntax01}, $dn_ok, q{NON_ALLOWED_CHARS} );

$dn_ko = Zonemaster::Engine->zone( q{www.-nic.se} );
zone_gives( q{syntax02}, $dn_ko, q{INITIAL_HYPHEN} );
zone_gives_not( q{syntax02}, $dn_ko, q{NO_ENDING_HYPHENS} );
zone_gives_not( q{syntax02}, $dn_ok, q{INITIAL_HYPHEN} );
zone_gives( q{syntax02}, $dn_ok, q{NO_ENDING_HYPHENS} );

$dn_ko = Zonemaster::Engine->zone( q{www.nic-.se} );
zone_gives( q{syntax02}, $dn_ko, q{TERMINAL_HYPHEN} );
zone_gives_not( q{syntax02}, $dn_ko, q{NO_ENDING_HYPHENS} );
zone_gives_not( q{syntax02}, $dn_ok, q{TERMINAL_HYPHEN} );

my $dn_idn_ok = Zonemaster::Engine->zone( q{www.xn--nic.se} );
$dn_ko = Zonemaster::Engine->zone( q{www.ni--c.se} );
zone_gives( q{syntax03}, $dn_ko, q{DISCOURAGED_DOUBLE_DASH} );
zone_gives_not( q{syntax03}, $dn_ko,     q{NO_DOUBLE_DASH} );
zone_gives_not( q{syntax03}, $dn_ok,     q{DISCOURAGED_DOUBLE_DASH} );
zone_gives_not( q{syntax03}, $dn_idn_ok, q{DISCOURAGED_DOUBLE_DASH} );
zone_gives( q{syntax03}, $dn_ok,     q{NO_DOUBLE_DASH} );
zone_gives( q{syntax03}, $dn_idn_ok, q{NO_DOUBLE_DASH} );

my $ns_double_dash = Zonemaster::Engine->zone( q{ns1.ns--nic.fr} );
zone_gives( q{syntax04}, $ns_double_dash, q{NAMESERVER_DISCOURAGED_DOUBLE_DASH} );
zone_gives_not( q{syntax04}, $ns_ok, q{NAMESERVER_DISCOURAGED_DOUBLE_DASH} );

my $ns_num_tld = Zonemaster::Engine->zone( q{ns1.nic.47} );
zone_gives( q{syntax04}, $ns_num_tld, q{NAMESERVER_NUMERIC_TLD} );
zone_gives_not( q{syntax04}, $ns_ok, q{NAMESERVER_NUMERIC_TLD} );

my %res;
my $zone;

$zone = Zonemaster::Engine->zone( q{afnic.fr} );
zone_gives( q{syntax05}, $zone, q{RNAME_NO_AT_SIGN} );
zone_gives_not( q{syntax05}, $zone, q{RNAME_MISUSED_AT_SIGN} );
zone_gives( q{syntax06}, $zone, q{RNAME_RFC822_VALID} );
zone_gives_not( q{syntax06}, $zone, q{RNAME_RFC822_INVALID} );
zone_gives_not( q{syntax06}, $zone, q{NO_RESPONSE_SOA_QUERY} );
zone_gives_not( q{syntax06}, $zone, q{RNAME_MAIL_ILLEGAL_CNAME} );
zone_gives_not( q{syntax06}, $zone, q{RNAME_MAIL_DOMAIN_LOCALHOST} );
zone_gives_not( q{syntax07}, $zone, q{MNAME_DISCOURAGED_DOUBLE_DASH} );
zone_gives_not( q{syntax07}, $zone, q{MNAME_NUMERIC_TLD} );
zone_gives_not( q{syntax07}, $zone, q{NO_RESPONSE_SOA_QUERY} );
zone_gives_not( q{syntax08}, $zone, q{MX_DISCOURAGED_DOUBLE_DASH} );
zone_gives_not( q{syntax08}, $zone, q{MX_NUMERIC_TLD} );
zone_gives_not( q{syntax08}, $zone, q{NO_RESPONSE_MX_QUERY} );

$zone = Zonemaster::Engine->zone( q{syntax01.zut-root.rd.nic.fr} );
zone_gives( q{syntax05}, $zone, q{RNAME_MISUSED_AT_SIGN} );
zone_gives_not( q{syntax05}, $zone, q{RNAME_NO_AT_SIGN} );
zone_gives_not( q{syntax06}, $zone, q{RNAME_RFC822_VALID} );
zone_gives( q{syntax06}, $zone, q{RNAME_RFC822_INVALID} );
zone_gives_not( q{syntax06}, $zone, q{NO_RESPONSE} );
zone_gives_not( q{syntax06}, $zone, q{NO_RESPONSE_SOA_QUERY} );
zone_gives_not( q{syntax06}, $zone, q{RNAME_MAIL_ILLEGAL_CNAME} );
zone_gives_not( q{syntax06}, $zone, q{RNAME_MAIL_DOMAIN_LOCALHOST} );
zone_gives( q{syntax07}, $zone, q{MNAME_DISCOURAGED_DOUBLE_DASH} );
zone_gives( q{syntax07}, $zone, q{MNAME_NUMERIC_TLD} );
zone_gives( q{syntax08}, $zone, q{MX_NUMERIC_TLD} );
zone_gives( q{syntax08}, $zone, q{MX_DISCOURAGED_DOUBLE_DASH} );
zone_gives_not( q{syntax08}, $zone, q{NO_RESPONSE_MX_QUERY} );

$zone = Zonemaster::Engine->zone( 'name.doesnotexist' );
%res = map { $_->tag => 1 } Zonemaster::Engine->test_method( q{Syntax}, q{syntax05}, $zone );
ok( $res{NO_RESPONSE_SOA_QUERY}, q{No response from nameserver(s) on SOA queries} );
%res = map { $_->tag => 1 } Zonemaster::Engine->test_method( q{Syntax}, q{syntax07}, $zone );
ok( $res{NO_RESPONSE_SOA_QUERY}, q{No response from nameserver(s) on SOA queries} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
